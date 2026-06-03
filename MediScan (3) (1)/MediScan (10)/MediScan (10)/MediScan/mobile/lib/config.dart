import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Config {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:5000';
    } else if (Platform.isAndroid) {
      return 'http://10.0.2.2:5000';
    } else {
      return 'http://127.0.0.1:5000';
    }
  }

  static String get apiBaseUrl => '$baseUrl/api';
  static String get authBaseUrl => '$baseUrl/api/auth';
  static String get cartBaseUrl => '$baseUrl/api/cart';
}
