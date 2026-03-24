import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Default API/socket base (no trailing slash). Android emulator → host loopback.
String defaultServerBaseUrl() {
  if (kIsWeb) return 'http://localhost:3001';
  if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:3001';
  return 'http://127.0.0.1:3001';
}
