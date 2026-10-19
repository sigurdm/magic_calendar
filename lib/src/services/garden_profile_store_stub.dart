import 'garden_service.dart';

/// Creates a persistent [GardenProfileStore] at [filePath], or returns `null`
/// on platforms without a local file system.
GardenProfileStore? createFileGardenProfileStore(String filePath) => null;

/// Creates a monthly SQLite-sharded [ShardedSqliteJournalStore] rooted at [dirPath],
/// or returns `null` on unsupported platforms.
ShardedSqliteJournalStore? createShardedSqliteJournalStore(String dirPath) =>
    null;
