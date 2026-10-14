/// Stub implementation of [saveIcsFile] for platforms without `dart:io`.
Future<String?> saveIcsFile({
  required String fileName,
  required String content,
  String? directoryPath,
}) async => null;
