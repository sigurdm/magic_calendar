import 'dart:io';
import 'dart:typed_data';

/// Whether native browser file-input photo selection is available.
const bool supportsBrowserPhotoFilePicker = false;

/// Reads raw image bytes from [filePath] on platforms with `dart:io`.
///
/// Throws a [FormatException] if the file does not exist.
Future<Uint8List> readLocalPhotoFileBytes(String filePath) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw const FormatException('Selected image file does not exist');
  }
  return file.readAsBytes();
}

/// Stub for browser file picker on non-web platforms.
Future<Uint8List?> pickBrowserPhotoBytes() async => null;
