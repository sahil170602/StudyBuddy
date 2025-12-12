// lib/src/file_utils.dart
// Use conditional imports so calling code can call saveBytesToDevice without worrying about platform.

export 'file_utils_io.dart'
    if (dart.library.html) 'file_utils_web.dart';
