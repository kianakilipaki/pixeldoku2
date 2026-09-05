import 'package:flutter/foundation.dart';

class AppLogger {
  const AppLogger._();

  static void log(String message) {
    debugPrint('LOGS: $message');
  }

  static void error(String message, Object error, [StackTrace? stackTrace]) {
    debugPrint('LOGS: $message | error=$error');
    if (stackTrace != null) {
      debugPrint('LOGS: stack=$stackTrace');
    }
  }
}
