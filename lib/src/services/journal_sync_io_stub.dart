import 'dart:typed_data';

import 'journal_sqlite_store_stub.dart';
import 'journal_sync_service.dart';

/// Exception thrown when an HTTP sync request fails on platforms without `dart:io`.
class HttpException implements Exception {
  /// Human-readable description of the HTTP error.
  final String message;

  /// Optional URI of the failing HTTP request.
  final Uri? uri;

  /// Creates an [HttpException].
  const HttpException(this.message, {this.uri});

  @override
  String toString() => uri == null
      ? 'HttpException: $message'
      : 'HttpException: $message ($uri)';
}

/// Stub directory descriptor for [DirectoryGardenSyncTransport] on platforms without `dart:io`.
final class StubSyncDirectory {
  /// Directory path string.
  final String path;

  /// Creates a [StubSyncDirectory].
  const StubSyncDirectory(this.path);
}

/// Stub implementation of [DirectoryGardenSyncTransport] for platforms without `dart:io`.
final class DirectoryGardenSyncTransport implements GardenSyncTransport {
  /// Root directory descriptor of the shared garden folder.
  final StubSyncDirectory directory;

  /// Creates a [DirectoryGardenSyncTransport] rooted at [directoryPath].
  DirectoryGardenSyncTransport(String directoryPath)
    : directory = StubSyncDirectory(directoryPath);

  @override
  String get displayName => 'Shared Folder (${directory.path})';

  @override
  Future<List<String>> list(String prefix) async => const [];

  @override
  Future<Uint8List?> getBytes(String name) async => null;

  @override
  Future<void> putBytes(String name, Uint8List bytes) async {
    throw UnsupportedError(
      'DirectoryGardenSyncTransport requires dart:io file system access',
    );
  }

  @override
  Future<void> delete(String name) async {}

  @override
  void close() {}
}

/// Stub for merging remote metadata bytes on platforms without `dart:io`.
Future<void> mergeRemoteMetaBytesToStore(
  ShardedSqliteJournalStore store,
  String blobName,
  Uint8List bytes,
) async {}

/// Stub for merging remote shard bytes on platforms without `dart:io`.
Future<void> mergeRemoteShardBytesToStore(
  ShardedSqliteJournalStore store,
  String shardKey,
  String remoteDigest,
  String blobName,
  Uint8List bytes,
) async {}
