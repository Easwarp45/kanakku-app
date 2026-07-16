import 'package:flutter/foundation.dart';

/// Lightweight app logger that uses [debugPrint] (safe on all platforms).
/// Wraps calls in try/catch to ensure logger never crashes the app.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  AppLogger._internal();

  factory AppLogger() => _instance;

  void v(dynamic message) {
    try {
      if (kDebugMode) {
        debugPrint('[VERBOSE] $message');
      }
    } catch (_) {}
  }

  void d(dynamic message) {
    try {
      if (kDebugMode) {
        debugPrint('[DEBUG] $message');
      }
    } catch (_) {}
  }

  void i(dynamic message) {
    try {
      if (kDebugMode) {
        debugPrint('[INFO] $message');
      }
    } catch (_) {}
  }

  void w(dynamic message) {
    try {
      if (kDebugMode) {
        debugPrint('[WARN] $message');
      }
    } catch (_) {}
  }

  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    try {
      if (kDebugMode) {
        debugPrint('[ERROR] $message');
        if (error != null) debugPrint('  Error: $error');
        if (stackTrace != null) debugPrint('  Stack: $stackTrace');
      }
    } catch (_) {}
  }

  void init() {
    i('AppLogger initialized');
  }
}

final logger = AppLogger();
