import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'journal_sqlite_store.dart';
import 'journal_sync_service.dart';

export 'dart:io' show HttpException;

final RegExp _validBlobPathPattern = RegExp(
  r'^(meta\.[0-9a-f]{24}\.sqlite|shards/\d{4}-(0[1-9]|1[0-2])\.[0-9a-f]{24}\.sqlite|media/[0-9a-f]{64}\.(jpg|png|webp))$',
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

  @override
  void close() {}
}

/// Writes [bytes] to a temporary file in [store] and merges it into `garden_meta.sqlite`.
Future<void> mergeRemoteMetaBytesToStore(
  ShardedSqliteJournalStore store,
  String blobName,
  Uint8List bytes,
) async {
  final tmpFile = File(
    p.join(store.rootDirectory.path, 'sync_remote_${p.basename(blobName)}'),
  );
  try {
    await tmpFile.writeAsBytes(bytes, flush: true);
    store.mergeRemoteMetaFile(tmpFile.path);
    store.markBlobMerged(blobName);
  } finally {
    if (await tmpFile.exists()) await tmpFile.delete();
  }
}

/// Writes [bytes] to a temporary file in [store] and merges it into [shardKey].
Future<void> mergeRemoteShardBytesToStore(
  ShardedSqliteJournalStore store,
  String shardKey,
  String remoteDigest,
  String blobName,
  Uint8List bytes,
) async {
  final tmpFile = File(
    p.join(
      store.rootDirectory.path,
      'sync_remote_${shardKey}_$remoteDigest.sqlite',
    ),
  );
  try {
    await tmpFile.writeAsBytes(bytes, flush: true);
    store.mergeRemoteShardFile(shardKey, tmpFile.path);
    store.markBlobMerged(blobName);
  } finally {
    if (await tmpFile.exists()) await tmpFile.delete();
  }
}
