import 'dart:io';

/// Writes [content] to a `.ics` file named [fileName] inside [directoryPath]
/// (or a subdirectory of [Directory.systemTemp] when omitted) and returns the
/// saved file's path.
Future<String?> saveIcsFile({
  required String fileName,
  required String content,
  String? directoryPath,
}) async {
  final sanitized = fileName
      .replaceAll(RegExp(r'[^A-Za-z0-9_.\-]'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  final effectiveName = sanitized.endsWith('.ics')
      ? sanitized
      : '$sanitized.ics';
  final targetDirectory = directoryPath != null
      ? Directory(directoryPath)
      : Directory('${Directory.systemTemp.path}/magic_calendar_exports');
  await targetDirectory.create(recursive: true);
  final file = File('${targetDirectory.path}/$effectiveName');
  await file.writeAsString(content);
  return file.path;
}
