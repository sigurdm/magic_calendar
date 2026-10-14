import 'ics_file_saver_stub.dart'
    if (dart.library.io) 'ics_file_saver_io.dart'
    as impl;

/// Saves an RFC 5545 `.ics` calendar string to disk with [fileName] and returns
/// the absolute path of the written file, or `null` when file system access is
/// unavailable on the current platform.
Future<String?> saveIcsFile({
  required String fileName,
  required String content,
  String? directoryPath,
}) => impl.saveIcsFile(
  fileName: fileName,
  content: content,
  directoryPath: directoryPath,
);
