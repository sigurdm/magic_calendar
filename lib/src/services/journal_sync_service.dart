import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/garden/field_journal_entry.dart';
import '../core/garden/garden_note_share.dart';
import 'journal_sqlite_store_stub.dart'
    if (dart.library.io) 'journal_sqlite_store.dart';
import 'journal_sync_io_stub.dart' if (dart.library.io) 'journal_sync_io.dart';

export 'journal_sync_io_stub.dart'
    if (dart.library.io) 'journal_sync_io.dart'
    show DirectoryGardenSyncTransport, HttpException;

/// Provider-agnostic cloud or shared-folder blob transport for syncing
/// content-addressed monthly SQLite shards (`shards/YYYY-MM.<digest>.sqlite`)
/// and shared garden metadata (`meta.<digest>.sqlite`).
abstract interface class GardenSyncTransport {
  /// Human-readable label for the transport (e.g. `'Shared Folder'`, `'WebDAV'`).
  String get displayName;

  /// Lists object names matching [prefix] (e.g. `'shards/'` or `'meta.'`).
  Future<List<String>> list(String prefix);

  /// Downloads the raw bytes of [name], or returns `null` if not found.
  Future<Uint8List?> getBytes(String name);

  /// Uploads [bytes] to [name].
  Future<void> putBytes(String name, Uint8List bytes);

  /// Deletes [name] if present (best-effort garbage collection of merged ancestors).
  Future<void> delete(String name);

  /// Releases any underlying HTTP clients or file resources.
  void close() {}
}

final RegExp _validBlobPathPattern = RegExp(
  r'^(meta\.[0-9a-f]{24}\.sqlite|shards/\d{4}-(0[1-9]|1[0-2])\.[0-9a-f]{24}\.sqlite|media/[0-9a-f]{64}\.(jpg|png|webp))$',
);

final RegExp _shardBlobExtractPattern = RegExp(
  r'^shards/(\d{4}-(0[1-9]|1[0-2]))\.([0-9a-f]{24})\.sqlite$',
);

final RegExp _metaBlobExtractPattern = RegExp(
  r'^meta\.([0-9a-f]{24})\.sqlite$',
);

void _validateBlobName(String name) {
  if (!_validBlobPathPattern.hasMatch(name)) {
    throw ArgumentError.value(
      name,
      'name',
      'Must be a canonical content-addressed shard or meta blob path',
    );
  }
}

/// In-memory implementation of [GardenSyncTransport] for testing multi-gardener
/// offline edits and concurrent uploads.
final class InMemoryGardenSyncTransport implements GardenSyncTransport {
  final Map<String, Uint8List> _objects = {};

  /// Creates an empty [InMemoryGardenSyncTransport].
  InMemoryGardenSyncTransport();

  @override
  String get displayName => 'In-Memory Cloud Bucket';

  /// Snapshot of all object names currently stored in memory.
  List<String> get storedObjectNames =>
      _objects.keys.toList(growable: false)..sort();

  @override
  Future<List<String>> list(String prefix) async {
    return _objects.keys
        .where((k) => k.startsWith(prefix))
        .toList(growable: false)
      ..sort();
  }

  @override
  Future<Uint8List?> getBytes(String name) async {
    _validateBlobName(name);
    final data = _objects[name];
    return data == null ? null : Uint8List.fromList(data);
  }

  @override
  Future<void> putBytes(String name, Uint8List bytes) async {
    _validateBlobName(name);
    _objects[name] = Uint8List.fromList(bytes);
  }

  @override
  Future<void> delete(String name) async {
    _validateBlobName(name);
    _objects.remove(name);
  }

  @override
  void close() {}
}

/// WebDAV / HTTP REST implementation of [GardenSyncTransport].
///
/// Interfaces with any WebDAV server (Nextcloud, ownCloud, Fastmail, Hetzner
/// Storage Share) or simple HTTP blob endpoint supporting `PROPFIND`/`GET`/`PUT`/`DELETE`.
final class WebDavGardenSyncTransport implements GardenSyncTransport {
  /// Base HTTPS URL of the shared garden folder.
  final Uri baseUri;

  /// Optional HTTP `Authorization` header value (e.g. `'Bearer ...'` or `'Basic ...'`).
  final String? authorizationHeader;

  final http.Client _client;
  final bool _ownsClient;

  /// Creates a [WebDavGardenSyncTransport].
  ///
  /// The [baseUri] must use `https` (or `http` strictly for `localhost`/`127.0.0.1` in tests).
  WebDavGardenSyncTransport({
    required this.baseUri,
    this.authorizationHeader,
    http.Client? client,
  }) : _client = client ?? http.Client(),
       _ownsClient = client == null {
    final isLocalhost =
        baseUri.host == 'localhost' || baseUri.host == '127.0.0.1';
    if (baseUri.scheme != 'https' &&
        !(baseUri.scheme == 'http' && isLocalhost)) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'Must use https (or http on localhost)',
      );
    }
  }

  @override
  String get displayName => 'WebDAV (${baseUri.host})';

  Map<String, String> _headers([Map<String, String>? extra]) => {
    if (authorizationHeader != null && authorizationHeader!.isNotEmpty)
      'Authorization': authorizationHeader!,
    ...?extra,
  };

  Uri _resolveObjectUri(String name) {
    _validateBlobName(name);
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    return baseUri.replace(path: '$basePath$name');
  }

  @override
  Future<List<String>> list(String prefix) async {
    final isShards = prefix.startsWith('shards');
    final isMedia = prefix.startsWith('media');
    final basePath = baseUri.path.endsWith('/')
        ? baseUri.path
        : '${baseUri.path}/';
    final subPath = isShards
        ? '${basePath}shards/'
        : (isMedia ? '${basePath}media/' : basePath);
    final targetUri = baseUri.replace(path: subPath);
    final req = http.Request('PROPFIND', targetUri);
    req.headers.addAll(_headers({'Depth': '1'}));
    final streamed = await _client.send(req);
    if (streamed.statusCode == 404) return const [];
    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw HttpException(
        'WebDAV PROPFIND failed with status ${streamed.statusCode}',
        uri: targetUri,
      );
    }
    final body = await streamed.stream.bytesToString();
    final matches = RegExp(
      r'(?:shards/)?\d{4}-(?:0[1-9]|1[0-2])\.[0-9a-f]{24}\.sqlite|meta\.[0-9a-f]{24}\.sqlite|(?:media/)?[0-9a-f]{64}\.(?:jpg|png|webp)',
    ).allMatches(body);
    final found = <String>{};
    for (final m in matches) {
      final token = m.group(0)!;
      final String normalized;
      if (token.startsWith('meta.') ||
          token.startsWith('shards/') ||
          token.startsWith('media/')) {
        normalized = token;
      } else if (token.endsWith('.sqlite')) {
        normalized = 'shards/$token';
      } else {
        normalized = 'media/$token';
      }
      if (normalized.startsWith(prefix) &&
          _validBlobPathPattern.hasMatch(normalized)) {
        found.add(normalized);
      }
    }
    return found.toList()..sort();
  }

  @override
  Future<Uint8List?> getBytes(String name) async {
    final uri = _resolveObjectUri(name);
    final resp = await _client.get(uri, headers: _headers());
    if (resp.statusCode == 404) return null;
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'WebDAV GET failed with status ${resp.statusCode}',
        uri: uri,
      );
    }
    return resp.bodyBytes;
  }

  @override
  Future<void> putBytes(String name, Uint8List bytes) async {
    final uri = _resolveObjectUri(name);
    final contentType = switch (p.extension(name)) {
      '.jpg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'application/vnd.sqlite3',
    };
    final resp = await _client.put(
      uri,
      headers: _headers({'Content-Type': contentType}),
      body: bytes,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'WebDAV PUT failed with status ${resp.statusCode}',
        uri: uri,
      );
    }
  }

  @override
  Future<void> delete(String name) async {
    final uri = _resolveObjectUri(name);
    await _client.delete(uri, headers: _headers());
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// Callback that returns a valid OAuth 2.0 Bearer access token for the
/// Google Drive v3 API (`https://www.googleapis.com/auth/drive.file` or
/// `https://www.googleapis.com/auth/drive`).
///
/// On Android and iOS, wire this to `GoogleSignInAccount.authentication.accessToken`.
typedef GoogleDriveAccessTokenProvider = Future<String> Function();

/// Metadata returned when creating or inspecting a shared garden folder on Google Drive.
final class GoogleDriveGardenFolderInfo {
  /// Google Drive file ID of the folder.
  final String folderId;

  /// Human-readable folder name on Google Drive.
  final String name;

  /// Direct browser/app link to open the folder in Google Drive.
  final Uri webViewLink;

  /// Creates an immutable [GoogleDriveGardenFolderInfo].
  const GoogleDriveGardenFolderInfo({
    required this.folderId,
    required this.name,
    required this.webViewLink,
  });

  /// Shareable [GardenInviteLink] for inviting co-gardeners to join this folder.
  GardenInviteLink get inviteLink =>
      GardenInviteLink(driveFolderId: folderId, gardenName: name);
}

/// Google Drive REST API v3 implementation of [GardenSyncTransport] for mobile
/// (Android / iOS) and desktop co-gardener synchronization.
///
/// Stores content-addressed SQLite shards (`meta.<digest>.sqlite`,
/// `shards/YYYY-MM.<digest>.sqlite`) and photo attachments (`media/<sha256>.<ext>`)
/// inside a shared Google Drive folder (`[rootFolderId]`), and supports creating
/// shared folders and inviting co-gardeners via Drive permissions.
final class GoogleDriveGardenSyncTransport implements GardenSyncTransport {
  static const String _folderMimeType = 'application/vnd.google-apps.folder';

  static final RegExp _driveIdPattern = RegExp(r'^[A-Za-z0-9_-]{6,128}$');
  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  static String _escapeDriveQueryValue(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll("'", r"\'");

  /// Google Drive folder ID hosting the shared garden (`meta.*.sqlite`, `shards/`, `media/`).
  final String rootFolderId;

  /// Optional human-readable name of the shared garden.
  final String? gardenName;

  /// Supplies a fresh OAuth2 Bearer access token for Google Drive requests.
  final GoogleDriveAccessTokenProvider tokenProvider;

  /// Base URI for Google Drive v3 metadata/file endpoints.
  final Uri apiBaseUri;

  /// Base URI for Google Drive v3 multipart upload endpoints.
  final Uri uploadBaseUri;

  final http.Client _client;
  final bool _ownsClient;
  final Map<String, String> _subfolderIdCache = {};
  final Map<String, String> _blobFileIdCache = {};

  /// Creates a [GoogleDriveGardenSyncTransport] rooted at [rootFolderId].
  ///
  /// The [rootFolderId] must be a valid alphanumeric Google Drive file ID.
  GoogleDriveGardenSyncTransport({
    required this.rootFolderId,
    required this.tokenProvider,
    this.gardenName,
    Uri? apiBaseUri,
    Uri? uploadBaseUri,
    http.Client? client,
  }) : apiBaseUri =
           apiBaseUri ?? Uri.parse('https://www.googleapis.com/drive/v3'),
       uploadBaseUri =
           uploadBaseUri ??
           Uri.parse('https://www.googleapis.com/upload/drive/v3'),
       _client = client ?? http.Client(),
       _ownsClient = client == null {
    if (!_driveIdPattern.hasMatch(rootFolderId)) {
      throw ArgumentError.value(
        rootFolderId,
        'rootFolderId',
        'Must be a valid alphanumeric Google Drive folder ID',
      );
    }
  }

  @override
  String get displayName =>
      (gardenName != null && gardenName!.trim().isNotEmpty)
      ? 'Google Drive (${gardenName!.trim()})'
      : 'Google Drive ($rootFolderId)';

  /// Shareable [GardenInviteLink] for inviting other gardeners to join this Drive folder.
  GardenInviteLink get inviteLink =>
      GardenInviteLink(driveFolderId: rootFolderId, gardenName: gardenName);

  Future<Map<String, String>> _authHeaders([Map<String, String>? extra]) async {
    final token = (await tokenProvider()).trim();
    if (token.isEmpty) {
      throw StateError(
        'GoogleDriveAccessTokenProvider returned an empty token',
      );
    }
    return <String, String>{'Authorization': 'Bearer $token', ...?extra};
  }

  /// Creates a new shared garden folder on Google Drive and returns its
  /// [GoogleDriveGardenFolderInfo].
  static Future<GoogleDriveGardenFolderInfo> createSharedGardenFolder({
    required GoogleDriveAccessTokenProvider tokenProvider,
    required String gardenName,
    Uri? apiBaseUri,
    http.Client? client,
  }) async {
    final trimmedName = gardenName.trim().isNotEmpty
        ? gardenName.trim()
        : 'Shared Biodynamic Garden';
    final base = apiBaseUri ?? Uri.parse('https://www.googleapis.com/drive/v3');
    final ownsClient = client == null;
    final httpClient = client ?? http.Client();
    try {
      final token = (await tokenProvider()).trim();
      if (token.isEmpty) {
        throw StateError(
          'GoogleDriveAccessTokenProvider returned an empty token',
        );
      }

      final uri = base.replace(
        path: '${base.path}/files',
        queryParameters: const <String, String>{
          'fields': 'id,name,webViewLink',
          'supportsAllDrives': 'true',
        },
      );

      final resp = await httpClient.post(
        uri,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode(<String, Object?>{
          'name': trimmedName,
          'mimeType': _folderMimeType,
        }),
      );

      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException(
          'Google Drive folder creation failed with status ${resp.statusCode}',
          uri: uri,
        );
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is! Map) {
        throw const FormatException('Invalid Google Drive folder response');
      }
      final id = decoded['id'];
      if (id is! String || id.isEmpty) {
        throw const FormatException('Google Drive folder response missing id');
      }
      final name = decoded['name'] is String
          ? decoded['name'] as String
          : trimmedName;
      final webLinkRaw = decoded['webViewLink'];
      final webUri = (webLinkRaw is String && Uri.tryParse(webLinkRaw) != null)
          ? Uri.parse(webLinkRaw)
          : Uri.https('drive.google.com', '/drive/folders/$id');

      return GoogleDriveGardenFolderInfo(
        folderId: id,
        name: name,
        webViewLink: webUri,
      );
    } finally {
      if (ownsClient) {
        httpClient.close();
      }
    }
  }

  /// Grants [emailAddress] access (`'writer'` or `'reader'`) to [rootFolderId]
  /// on Google Drive so a co-gardener can sync or view the shared diary.
  Future<void> shareFolderWithEmail({
    required String emailAddress,
    String role = 'writer',
    bool sendNotificationEmail = true,
  }) async {
    final trimmedEmail = emailAddress.trim();
    if (!_emailPattern.hasMatch(trimmedEmail) || trimmedEmail.length < 5) {
      throw ArgumentError.value(
        emailAddress,
        'emailAddress',
        'Must be a valid email address',
      );
    }
    if (role != 'writer' && role != 'reader') {
      throw ArgumentError.value(
        role,
        'role',
        'Must be either "writer" or "reader"',
      );
    }

    final uri = apiBaseUri.replace(
      path: '${apiBaseUri.path}/files/$rootFolderId/permissions',
      queryParameters: <String, String>{
        'sendNotificationEmail': sendNotificationEmail ? 'true' : 'false',
        'supportsAllDrives': 'true',
      },
    );

    final resp = await _client.post(
      uri,
      headers: await _authHeaders(const <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      }),
      body: jsonEncode(<String, Object?>{
        'type': 'user',
        'role': role,
        'emailAddress': trimmedEmail,
      }),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'Google Drive permission grant failed with status ${resp.statusCode}',
        uri: uri,
      );
    }
  }

  Future<String?> _findOrCreateSubfolder(
    String subfolderName, {
    required bool createIfMissing,
  }) async {
    if (_subfolderIdCache[subfolderName] case final cachedId?) {
      return cachedId;
    }

    final safeRootId = _escapeDriveQueryValue(rootFolderId);
    final safeSubfolderName = _escapeDriveQueryValue(subfolderName);
    final query =
        "'$safeRootId' in parents and name = '$safeSubfolderName' and mimeType = '$_folderMimeType' and trashed = false";
    final listUri = apiBaseUri.replace(
      path: '${apiBaseUri.path}/files',
      queryParameters: <String, String>{
        'q': query,
        'fields': 'files(id,name)',
        'pageSize': '10',
        'includeItemsFromAllDrives': 'true',
        'supportsAllDrives': 'true',
      },
    );

    final listResp = await _client.get(listUri, headers: await _authHeaders());
    if (listResp.statusCode < 200 || listResp.statusCode >= 300) {
      throw HttpException(
        'Google Drive subfolder lookup failed with status ${listResp.statusCode}',
        uri: listUri,
      );
    }

    final decoded = jsonDecode(listResp.body);
    if (decoded is Map && decoded['files'] is List) {
      final files = decoded['files'] as List;
      for (final f in files) {
        if (f is Map && f['id'] is String) {
          final id = f['id'] as String;
          _subfolderIdCache[subfolderName] = id;
          return id;
        }
      }
    }

    if (!createIfMissing) return null;

    final createUri = apiBaseUri.replace(
      path: '${apiBaseUri.path}/files',
      queryParameters: const <String, String>{
        'fields': 'id,name',
        'supportsAllDrives': 'true',
      },
    );
    final createResp = await _client.post(
      createUri,
      headers: await _authHeaders(const <String, String>{
        'Content-Type': 'application/json; charset=utf-8',
      }),
      body: jsonEncode(<String, Object?>{
        'name': subfolderName,
        'mimeType': _folderMimeType,
        'parents': <String>[rootFolderId],
      }),
    );

    if (createResp.statusCode < 200 || createResp.statusCode >= 300) {
      throw HttpException(
        'Google Drive subfolder creation failed with status ${createResp.statusCode}',
        uri: createUri,
      );
    }

    final createdJson = jsonDecode(createResp.body);
    if (createdJson is Map && createdJson['id'] is String) {
      final id = createdJson['id'] as String;
      _subfolderIdCache[subfolderName] = id;
      return id;
    }
    throw const FormatException('Google Drive subfolder response missing id');
  }

  Future<List<(String id, String name)>> _listFilesInDriveFolder(
    String folderId,
  ) async {
    final results = <(String id, String name)>[];
    String? pageToken;
    final safeFolderId = _escapeDriveQueryValue(folderId);

    do {
      final uri = apiBaseUri.replace(
        path: '${apiBaseUri.path}/files',
        queryParameters: <String, String>{
          'q': "'$safeFolderId' in parents and trashed = false",
          'fields': 'nextPageToken,files(id,name)',
          'pageSize': '200',
          'includeItemsFromAllDrives': 'true',
          'supportsAllDrives': 'true',
          'pageToken': ?pageToken,
        },
      );
      final resp = await _client.get(uri, headers: await _authHeaders());
      if (resp.statusCode == 404) return const [];
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw HttpException(
          'Google Drive files.list failed with status ${resp.statusCode}',
          uri: uri,
        );
      }

      final decoded = jsonDecode(resp.body);
      if (decoded is Map) {
        final files = decoded['files'];
        if (files is List) {
          for (final item in files) {
            if (item is Map && item['id'] is String && item['name'] is String) {
              results.add((item['id'] as String, item['name'] as String));
            }
          }
        }
        final next = decoded['nextPageToken'];
        pageToken = (next is String && next.isNotEmpty) ? next : null;
      } else {
        pageToken = null;
      }
    } while (pageToken != null);

    return results;
  }

  @override
  Future<List<String>> list(String prefix) async {
    final matched = <String>{};

    if (prefix.isEmpty || prefix.startsWith('meta')) {
      final rootFiles = await _listFilesInDriveFolder(rootFolderId);
      for (final (id, fileName) in rootFiles) {
        if (fileName.startsWith(prefix) &&
            _validBlobPathPattern.hasMatch(fileName)) {
          _blobFileIdCache[fileName] = id;
          matched.add(fileName);
        }
      }
    }

    if (prefix.isEmpty || prefix.startsWith('shards')) {
      final shardsFolderId = await _findOrCreateSubfolder(
        'shards',
        createIfMissing: false,
      );
      if (shardsFolderId != null) {
        final shardFiles = await _listFilesInDriveFolder(shardsFolderId);
        for (final (id, fileName) in shardFiles) {
          final fullPath = 'shards/$fileName';
          if (fullPath.startsWith(prefix) &&
              _validBlobPathPattern.hasMatch(fullPath)) {
            _blobFileIdCache[fullPath] = id;
            matched.add(fullPath);
          }
        }
      }
    }

    if (prefix.isEmpty || prefix.startsWith('media')) {
      final mediaFolderId = await _findOrCreateSubfolder(
        'media',
        createIfMissing: false,
      );
      if (mediaFolderId != null) {
        final mediaFiles = await _listFilesInDriveFolder(mediaFolderId);
        for (final (id, fileName) in mediaFiles) {
          final fullPath = 'media/$fileName';
          if (fullPath.startsWith(prefix) &&
              _validBlobPathPattern.hasMatch(fullPath)) {
            _blobFileIdCache[fullPath] = id;
            matched.add(fullPath);
          }
        }
      }
    }

    return matched.toList()..sort();
  }

  Future<String?> _resolveBlobFileId(String name) async {
    _validateBlobName(name);
    if (_blobFileIdCache[name] case final cached?) {
      return cached;
    }

    if (name.startsWith('shards/')) {
      await list('shards/');
    } else if (name.startsWith('media/')) {
      await list('media/');
    } else {
      await list('meta.');
    }
    return _blobFileIdCache[name];
  }

  @override
  Future<Uint8List?> getBytes(String name) async {
    final fileId = await _resolveBlobFileId(name);
    if (fileId == null) return null;

    final uri = apiBaseUri.replace(
      path: '${apiBaseUri.path}/files/$fileId',
      queryParameters: const <String, String>{
        'alt': 'media',
        'supportsAllDrives': 'true',
      },
    );
    final resp = await _client.get(uri, headers: await _authHeaders());
    if (resp.statusCode == 404) {
      _blobFileIdCache.remove(name);
      return null;
    }
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'Google Drive file download failed with status ${resp.statusCode}',
        uri: uri,
      );
    }
    return resp.bodyBytes;
  }

  @override
  Future<void> putBytes(String name, Uint8List bytes) async {
    _validateBlobName(name);
    String parentFolderId = rootFolderId;
    String leafFileName = name;

    if (name.startsWith('shards/')) {
      parentFolderId = (await _findOrCreateSubfolder(
        'shards',
        createIfMissing: true,
      ))!;
      leafFileName = name.substring('shards/'.length);
    } else if (name.startsWith('media/')) {
      parentFolderId = (await _findOrCreateSubfolder(
        'media',
        createIfMissing: true,
      ))!;
      leafFileName = name.substring('media/'.length);
    }

    final contentType = switch (p.extension(leafFileName)) {
      '.jpg' => 'image/jpeg',
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      _ => 'application/vnd.sqlite3',
    };

    const boundary = 'magic_calendar_drive_multipart_boundary';
    final metaJson = jsonEncode(<String, Object?>{
      'name': leafFileName,
      'parents': <String>[parentFolderId],
    });

    final bodyBuilder = BytesBuilder(copy: false)
      ..add(
        utf8.encode(
          '--$boundary\r\n'
          'Content-Type: application/json; charset= UTF-8\r\n\r\n'
          '$metaJson\r\n'
          '--$boundary\r\n'
          'Content-Type: $contentType\r\n\r\n',
        ),
      )
      ..add(bytes)
      ..add(utf8.encode('\r\n--$boundary--\r\n'));

    final uri = uploadBaseUri.replace(
      path: '${uploadBaseUri.path}/files',
      queryParameters: const <String, String>{
        'uploadType': 'multipart',
        'fields': 'id,name',
        'supportsAllDrives': 'true',
      },
    );

    final resp = await _client.post(
      uri,
      headers: await _authHeaders(<String, String>{
        'Content-Type': 'multipart/related; boundary=$boundary',
      }),
      body: bodyBuilder.takeBytes(),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'Google Drive multipart upload failed with status ${resp.statusCode}',
        uri: uri,
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is Map && decoded['id'] is String) {
      _blobFileIdCache[name] = decoded['id'] as String;
    }
  }

  @override
  Future<void> delete(String name) async {
    final fileId = await _resolveBlobFileId(name);
    if (fileId == null) return;

    final uri = apiBaseUri.replace(
      path: '${apiBaseUri.path}/files/$fileId',
      queryParameters: const <String, String>{'supportsAllDrives': 'true'},
    );
    final resp = await _client.delete(uri, headers: await _authHeaders());
    _blobFileIdCache.remove(name);
    if (resp.statusCode == 404) return;
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw HttpException(
        'Google Drive file delete failed with status ${resp.statusCode}',
        uri: uri,
      );
    }
  }

  @override
  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}

/// Summary report of a completed [GardenSyncEngine.sync] pass.
final class GardenSyncReport {
  /// Timestamp when the sync completed.
  final DateTime completedAt;

  /// Monthly shard keys (`YYYY-MM`) that downloaded and merged remote changes.
  final List<String> mergedShardKeys;

  /// Monthly shard keys (`YYYY-MM`) that uploaded new merged or local state.
  final List<String> uploadedShardKeys;

  /// Historical remote shard keys discovered on the cloud that were left unhydrated
  /// on disk until the user scrolls to them.
  final List<String> lazyUnhydratedShardKeys;

  /// Content-addressed photo blobs (`media/<sha256>.<ext>`) uploaded during this sync pass.
  final List<String> uploadedMediaBlobs;

  /// Number of superseded ancestor blobs garbage-collected on the remote transport.
  final int deletedAncestorBlobs;

  /// Creates a [GardenSyncReport].
  GardenSyncReport({
    required this.completedAt,
    Iterable<String> mergedShardKeys = const [],
    Iterable<String> uploadedShardKeys = const [],
    Iterable<String> lazyUnhydratedShardKeys = const [],
    Iterable<String> uploadedMediaBlobs = const [],
    this.deletedAncestorBlobs = 0,
  }) : mergedShardKeys = List<String>.unmodifiable(mergedShardKeys),
       uploadedShardKeys = List<String>.unmodifiable(uploadedShardKeys),
       lazyUnhydratedShardKeys = List<String>.unmodifiable(
         lazyUnhydratedShardKeys,
       ),
       uploadedMediaBlobs = List<String>.unmodifiable(uploadedMediaBlobs);
}

/// Coordinates conflict-free synchronization between a local
/// [ShardedSqliteJournalStore] and any [GardenSyncTransport].
final class GardenSyncEngine {
  /// Local sharded SQLite store.
  final ShardedSqliteJournalStore store;

  /// Remote or shared-folder blob transport.
  final GardenSyncTransport transport;

  /// Creates a [GardenSyncEngine].
  const GardenSyncEngine({required this.store, required this.transport});

  /// Synchronizes `garden_meta.sqlite` and active monthly shards (`YYYY-MM.sqlite`).
  ///
  /// When [hydrateAllShards] is `false` (the default for mobile memory/storage
  /// efficiency), remote shards outside `[activeWindowStart, activeWindowEnd]`
  /// that do not yet exist locally are cataloged for on-demand hydration via
  /// [hydrateShard] when the user scrolls the timeline or diary to that month.
  Future<GardenSyncReport> sync({
    DateTime? activeWindowStart,
    DateTime? activeWindowEnd,
    bool hydrateAllShards = false,
  }) async {
    int deletedAncestors = 0;
    final mergedShards = <String>[];
    final uploadedShards = <String>[];

    // 1. Sync garden_meta.sqlite
    deletedAncestors += await _syncMeta();

    // 2. Discover remote monthly shard heads via a single `list('shards/')` call
    final remoteObjects = await transport.list('shards/');
    final remoteBlobsByShard = <String, List<String>>{};
    for (final obj in remoteObjects) {
      final match = _shardBlobExtractPattern.firstMatch(obj);
      if (match == null) continue;
      final shardKey = match.group(1)!;
      (remoteBlobsByShard[shardKey] ??= <String>[]).add(obj);
    }
    store.updateRemoteShardCatalog(remoteBlobsByShard);

    // 3. Determine which shards to sync eagerly vs leave lazy on the cloud
    final activeShardSet = <String>{
      ...store.listLocalShardKeys(),
      if (activeWindowStart != null && activeWindowEnd != null)
        ...ShardedSqliteJournalStore.shardKeysInRange(
          activeWindowStart,
          activeWindowEnd,
        ),
      if (hydrateAllShards) ...remoteBlobsByShard.keys,
    };

    final sortedTargetShards = activeShardSet.toList()
      ..sort((a, b) => b.compareTo(a));

    for (final shardKey in sortedTargetShards) {
      final remoteHeads = remoteBlobsByShard[shardKey] ?? const <String>[];
      final result = await _syncSingleShard(shardKey, remoteHeads);
      if (result.mergedRemote) mergedShards.add(shardKey);
      if (result.uploadedLocal) uploadedShards.add(shardKey);
      deletedAncestors += result.deletedAncestors;
    }

    // 4. Upload any local content-addressed photo blobs (`media/<sha256>.<ext>`)
    // not yet present on the remote transport. Remote photos are NOT eagerly
    // downloaded here—inline thumbnails are already inside `YYYY-MM.sqlite` and
    // full-resolution photos are fetched lazily on demand via [fetchAttachmentMedia].
    final uploadedMedia = await _uploadMissingLocalMedia();

    return GardenSyncReport(
      completedAt: DateTime.now(),
      mergedShardKeys: mergedShards,
      uploadedShardKeys: uploadedShards,
      lazyUnhydratedShardKeys: store.listUnhydratedRemoteShardKeys(),
      uploadedMediaBlobs: uploadedMedia,
      deletedAncestorBlobs: deletedAncestors,
    );
  }

  /// Lazily downloads, verifies (SHA-256 + magic bytes), and caches the
  /// full-resolution image bytes for [attachment] from [transport].
  ///
  /// If the verified full-resolution file is already cached in [store], it is
  /// returned immediately without network I/O.
  ///
  /// Throws a [FormatException] if the remote blob fails SHA-256 or magic-byte verification.
  Future<Uint8List?> fetchAttachmentMedia(JournalAttachment attachment) async {
    final localBytes = store.readLocalMediaBytes(attachment);
    if (localBytes != null) return localBytes;

    final remoteBytes = await transport.getBytes(attachment.remoteBlobName);
    if (remoteBytes == null) return null;

    // Verifies magic bytes and SHA-256 content address before writing to disk.
    store.saveMediaBytesForAttachment(attachment, remoteBytes);
    return remoteBytes;
  }

  Future<List<String>> _uploadMissingLocalMedia() async {
    final localMedia = store.listLocalMediaBlobNames();
    if (localMedia.isEmpty) return const [];
    final remoteMedia = (await transport.list('media/')).toSet();
    final uploaded = <String>[];
    for (final blobName in localMedia) {
      if (remoteMedia.contains(blobName)) continue;
      final bytes = store.readLocalMediaBlobByName(blobName);
      if (bytes == null) continue;
      await transport.putBytes(blobName, bytes);
      uploaded.add(blobName);
    }
    return uploaded;
  }

  /// Lazily downloads and merges a single historical month shard [shardKey] on demand.
  Future<bool> hydrateShard(String shardKey) async {
    ShardedSqliteJournalStore.validateShardKey(shardKey);
    final remoteHeads = await transport.list('shards/$shardKey.');
    if (remoteHeads.isEmpty) return false;
    final res = await _syncSingleShard(shardKey, remoteHeads);
    return res.mergedRemote || store.hasLocalShard(shardKey);
  }

  Future<int> _syncMeta() async {
    int deleted = 0;
    final remoteMetaBlobs = await transport.list('meta.');
    final validRemoteMeta = <String>[];
    for (final blob in remoteMetaBlobs) {
      if (_metaBlobExtractPattern.hasMatch(blob)) {
        validRemoteMeta.add(blob);
      }
    }

    for (final blob in validRemoteMeta) {
      if (store.isBlobMerged(blob)) continue;
      final bytes = await transport.getBytes(blob);
      if (bytes == null) continue;
      await mergeRemoteMetaBytesToStore(store, blob, bytes);
    }

    final localDigest = store.computeMetaDigest();
    final targetBlob = 'meta.$localDigest.sqlite';
    final alreadyOnRemote =
        validRemoteMeta.length == 1 && validRemoteMeta.first == targetBlob;

    if (!alreadyOnRemote) {
      final exported = store.exportMetaBytes();
      await transport.putBytes(targetBlob, exported);
      store.markBlobMerged(targetBlob);
      for (final ancestor in validRemoteMeta) {
        if (ancestor != targetBlob) {
          await transport.delete(ancestor);
          deleted += 1;
        }
      }
    } else {
      store.markBlobMerged(targetBlob);
    }
    return deleted;
  }

  Future<({bool mergedRemote, bool uploadedLocal, int deletedAncestors})>
  _syncSingleShard(String shardKey, List<String> remoteHeads) async {
    bool mergedAny = false;
    bool uploaded = false;
    int deleted = 0;

    for (final blob in remoteHeads) {
      final match = _shardBlobExtractPattern.firstMatch(blob);
      if (match == null) continue;
      final remoteDigest = match.group(3)!;
      if (store.isBlobMerged(blob)) continue;
      if (store.hasLocalShard(shardKey) &&
          store.computeShardDigest(shardKey) == remoteDigest) {
        store.markBlobMerged(blob);
        continue;
      }

      final bytes = await transport.getBytes(blob);
      if (bytes == null) continue;
      await mergeRemoteShardBytesToStore(
        store,
        shardKey,
        remoteDigest,
        blob,
        bytes,
      );
      mergedAny = true;
    }

    if (!store.hasLocalShard(shardKey)) {
      return (
        mergedRemote: mergedAny,
        uploadedLocal: false,
        deletedAncestors: 0,
      );
    }

    final localDigest = store.computeShardDigest(shardKey);
    final targetBlob = 'shards/$shardKey.$localDigest.sqlite';
    final exactSingleHead =
        remoteHeads.length == 1 && remoteHeads.first == targetBlob;

    if (!exactSingleHead) {
      final exported = store.exportShardBytes(shardKey);
      await transport.putBytes(targetBlob, exported);
      store.markBlobMerged(targetBlob);
      uploaded = true;

      for (final ancestor in remoteHeads) {
        if (ancestor != targetBlob) {
          await transport.delete(ancestor);
          deleted += 1;
        }
      }
    } else {
      store.markBlobMerged(targetBlob);
    }

    return (
      mergedRemote: mergedAny,
      uploadedLocal: uploaded,
      deletedAncestors: deleted,
    );
  }
}
