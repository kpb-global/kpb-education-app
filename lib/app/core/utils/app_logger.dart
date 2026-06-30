import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppLogger {
  AppLogger._();

  /// Logs general informational messages, only visible in debug mode.
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('🔵 INFO: $prefix$message');
    }
  }

  /// Logs non-critical warnings.
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      final prefix = tag != null ? '[$tag] ' : '';
      debugPrint('🟠 WARN: $prefix$message');
    }
  }

  /// Logs errors and automatically reports them to Firebase Crashlytics in production.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    bool fatal = false,
  }) {
    final prefix = tag != null ? '[$tag] ' : '';

    if (kDebugMode) {
      debugPrint('🔴 ERROR: $prefix$message');
      if (error != null) debugPrint(error.toString());
      if (stackTrace != null) debugPrint(stackTrace.toString());
    } else {
      // Send to Crashlytics in production
      FirebaseCrashlytics.instance.recordError(
        error ?? Exception(message),
        stackTrace,
        reason: '$prefix$message',
        fatal: fatal,
      );
    }
  }
}
