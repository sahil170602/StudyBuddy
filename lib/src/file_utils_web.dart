// lib/src/file_utils_web.dart
// Implementation for web (uses dart:html to trigger browser download)

import 'dart:typed_data';
import 'dart:html' as html;

/// Triggers browser download and returns pseudo path (url) — or empty string.
Future<String> saveBytesToDevice(Uint8List bytes, String filename) async {
  final blob = html.Blob([bytes], 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = filename;
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
  return url; // note: not a real filesystem path
}
