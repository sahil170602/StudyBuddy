// lib/src/file_utils_io.dart
// Implementation for dart:io platforms (mobile & desktop)

import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Saves bytes to a file on device and returns the absolute path.
/// On Android/iOS it uses application documents directory. On desktop it uses documents directory.
Future<String> saveBytesToDevice(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  // Try to use Downloads folder on desktop if available (best-effort)
  try {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final downloads = Directory('${dir.path}/Downloads');
      if (!await downloads.exists()) {
        await downloads.create(recursive: true);
      }
      final out = File('${downloads.path}/$filename');
      await out.writeAsBytes(bytes);
      return out.path;
    }
  } catch (_) {
    // fallback to app doc dir
  }

  final out = File('${dir.path}/$filename');
  await out.writeAsBytes(bytes);
  return out.path;
}
