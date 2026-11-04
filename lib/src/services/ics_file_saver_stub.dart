import 'dart:convert';
import 'dart:js_interop';

@JS('document')
external _JSDocument? get _document;

extension type _JSDocument._(JSObject _) implements JSObject {
  external _JSAnchorElement createElement(String tagName);
  external _JSElement? get body;
}

extension type _JSElement._(JSObject _) implements JSObject {
  external void appendChild(_JSElement child);
  external void removeChild(_JSElement child);
}

extension type _JSAnchorElement._(JSObject _) implements _JSElement {
  external set href(String value);
  external set download(String value);
  external void click();
}

/// Triggers a browser download of [content] as an `.ics` file on Flutter Web.
Future<String?> saveIcsFile({
  required String fileName,
  required String content,
  String? directoryPath,
}) async {
  final sanitizedName = fileName
      .replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '-')
      .replaceAll(RegExp(r'-{2,}'), '-');
  final effectiveName = sanitizedName.endsWith('.ics')
      ? sanitizedName
      : '$sanitizedName.ics';
  try {
    final doc = _document;
    final body = doc?.body;
    if (doc == null || body == null) return effectiveName;
    final dataUri = Uri.dataFromString(
      content,
      mimeType: 'text/calendar',
      encoding: utf8,
    ).toString();
    final anchor = doc.createElement('a')
      ..href = dataUri
      ..download = effectiveName;
    body.appendChild(anchor);
    anchor.click();
    body.removeChild(anchor);
    return effectiveName;
  } catch (_) {
    return effectiveName;
  }
}
