import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

@JS('document')
external _JSDocument? get _document;

extension type _JSDocument._(JSObject _) implements JSObject {
  external _JSInputElement createElement(String tagName);
}

extension type _JSInputElement._(JSObject _) implements JSObject {
  external set type(String value);
  external set accept(String value);
  external _JSFileList? get files;
  external set onchange(JSFunction? callback);
  external void click();
}

extension type _JSFileList._(JSObject _) implements JSObject {
  external int get length;
  external JSObject? item(int index);
}

@JS('FileReader')
extension type _JSFileReader._(JSObject _) implements JSObject {
  external factory _JSFileReader();
  external JSAny? get result;
  external set onload(JSFunction? callback);
  external set onerror(JSFunction? callback);
  external void readAsArrayBuffer(JSObject blob);
}

/// Whether native browser file-input photo selection is available.
const bool supportsBrowserPhotoFilePicker = true;

/// Stub for local filesystem path reading on Flutter Web.
///
/// Throws a [FormatException] because arbitrary filesystem paths cannot be
/// read directly in the browser.
Future<Uint8List> readLocalPhotoFileBytes(String filePath) async {
  throw const FormatException(
    'Direct file path access is not available in the browser.',
  );
}

/// Opens a browser file picker (`<input type="file" accept="image/png,image/jpeg,image/webp">`)
/// and returns the selected file's bytes, or `null` if cancelled.
Future<Uint8List?> pickBrowserPhotoBytes() async {
  final doc = _document;
  if (doc == null) return null;
  final input = doc.createElement('input')
    ..type = 'file'
    ..accept = 'image/png,image/jpeg,image/webp';

  final completer = Completer<Uint8List?>();
  input.onchange = ((JSAny? _) {
    final files = input.files;
    if (files == null || files.length == 0) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final file = files.item(0);
    if (file == null) {
      if (!completer.isCompleted) completer.complete(null);
      return;
    }
    final reader = _JSFileReader();
    reader.onload = ((JSAny? _) {
      final res = reader.result;
      if (res != null && res.isA<JSArrayBuffer>()) {
        final buffer = (res as JSArrayBuffer).toDart;
        if (!completer.isCompleted) {
          completer.complete(buffer.asUint8List());
        }
      } else {
        if (!completer.isCompleted) completer.complete(null);
      }
    }).toJS;
    reader.onerror = ((JSAny? _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS;
    reader.readAsArrayBuffer(file);
  }).toJS;

  input.click();
  return completer.future;
}
