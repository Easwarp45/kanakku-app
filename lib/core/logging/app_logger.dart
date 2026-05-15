import 'package:logger/logger.dart';

class AppLogger {
  static final AppLogger _instance = AppLogger._internal();
  late final Logger _logger;

  AppLogger._internal() {
    _logger = Logger(
      printer: PrettyPrinter(methodCount: 0),
    );
  }

  factory AppLogger() => _instance;

  void v(dynamic message) => _logger.v(message);
  void d(dynamic message) => _logger.d(message);
  void i(dynamic message) => _logger.i(message);
  void w(dynamic message) => _logger.w(message);
  void e(dynamic message, [dynamic error, StackTrace? stackTrace]) => _logger.e(message, error, stackTrace);

  void init() {
    // Placeholder for future remote logger attachments (Sentry/Datadog)
    i('AppLogger initialized');
  }
}

final logger = AppLogger();
