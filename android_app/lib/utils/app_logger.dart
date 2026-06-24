import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message) {
    _log('INFO', message);
  }

  static void warn(String message) {
    _log('WARN', message);
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    final buffer = StringBuffer(message);
    if (error != null) {
      buffer.write(' ');
      buffer.write(error);
    }

    _log('ERROR', buffer.toString());

    if (!kReleaseMode && stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static void _log(String level, String message) {
    if (kReleaseMode && level == 'INFO') {
      return;
    }

    debugPrint('[$level] $message');
  }
}
