import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../core/garden/field_journal_entry.dart';
import 'journal_sqlite_store.dart';

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
}

/// File-system directory implementation of [GardenSyncTransport].
///
/// Works with any locally mounted or OS-synced shared folder (iCloud Drive,
/// Google Drive Desktop, Syncthing, Dropbox, Nextcloud folder, or Android SAF).
final class DirectoryGardenSyncTransport implements GardenSyncTransport {
  /// Canonicalized root directory of the shared garden folder.
  final Directory directory;

  /// Creates a [DirectoryGardenSyncTransport] rooted at [directoryPath].
  DirectoryGardenSyncTransport(String directoryPath)
    : directory = Directory(p.canonicalize(directoryPath));

  @override
  String get displayName => 'Shared Folder (${p.basename(directory.path)})';

  File _resolveSafeFile(String name) {
    _validateBlobName(name);
    final parts = name.split('/');
    final safeParts = [for (final part in parts) p.basename(part)];
    final resolved = p.canonicalize(p.joinAll([directory.path, ...safeParts]));
    final rootPrefix = '${directory.path}${p.separator}';
    if (!resolved.startsWith(rootPrefix)) {
      throw ArgumentError.value(
        name,
        'name',
        'Must stay within root directory',
      );
    }
    return File(resolved);
  }

  @override
  Future<List<String>> list(String prefix) async {
    if (!await directory.exists()) return const [];
    final results = <String>[];

    if (prefix.startsWith('meta')) {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.startsWith(prefix) && _validBlobPathPattern.hasMatch(name)) {
          results.add(name);
        }
      }
    }

    if (prefix.isEmpty || prefix.startsWith('shards')) {
      final shardsDir = Directory(p.join(directory.path, 'shards'));
      if (await shardsDir.exists()) {
        await for (final entity in shardsDir.list(followLinks: false)) {
          if (entity is! File) continue;
          final rel = 'shards/${p.basename(entity.path)}';
          if (rel.startsWith(prefix) && _validBlobPathPattern.hasMatch(rel)) {
            results.add(rel);
          }
        }
      }
    }

    if (prefix.isEmpty || prefix.startsWith('media')) {
      final mediaDir = Directory(p.join(directory.path, 'media'));
      if (await mediaDir.exists()) {
        await for (final entity in mediaDir.list(followLinks: false)) {
          if (entity is! File) continue;
          final rel = 'media/${p.basename(entity.path)}';
          if (rel.startsWith(prefix) && _validBlobPathPattern.hasMatch(rel)) {
            results.add(rel);
          }
        }
      }
    }

    results.sort();
    return results;
  }

  @override
  Future<Uint8List?> getBytes(String name) async {
    final file = _resolveSafeFile(name);
    if (!await file.exists()) return null;
    return await file.readAsBytes();
  }

  @override
  Future<void> putBytes(String name, Uint8List bytes) async {
    final file = _resolveSafeFile(name);
    await file.parent.create(recursive: true);
    final tempFile = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await tempFile.writeAsBytes(bytes, flush: true);
    await tempFile.rename(file.path);
  }

  @override
  Future<void> delete(String name) async {
    final file = _resolveSafeFile(name);
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {
        // Best-effort garbage collection.
      }
    }
  }
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

  /// Creates a [WebDavGardenSyncTransport].
  ///
  /// The [baseUri] must use `https` (or `http` strictly for `localhost`/`127.0.0.1` in tests).
  WebDavGardenSyncTransport({
    required this.baseUri,
    this.authorizationHeader,
    http.Client? client,
  }) : _client = client ?? http.Client() {
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
      final tmpFile = File(
        p.join(store.rootDirectory.path, 'sync_remote_${p.basename(blob)}'),
      );
      try {
        await tmpFile.writeAsBytes(bytes, flush: true);
        store.mergeRemoteMetaFile(tmpFile.path);
        store.markBlobMerged(blob);
      } finally {
        if (await tmpFile.exists()) await tmpFile.delete();
      }
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
      final tmpFile = File(
        p.join(
          store.rootDirectory.path,
          'sync_remote_${shardKey}_$remoteDigest.sqlite',
        ),
      );
      try {
        await tmpFile.writeAsBytes(bytes, flush: true);
        store.mergeRemoteShardFile(shardKey, tmpFile.path);
        store.markBlobMerged(blob);
        mergedAny = true;
      } finally {
        if (await tmpFile.exists()) await tmpFile.delete();
      }
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
