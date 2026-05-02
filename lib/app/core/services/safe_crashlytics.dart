import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Records to Crashlytics when Firebase is initialized (e.g. unit tests are not).
void safeRecordError(
  Object error,
  StackTrace? stack, {
  String? reason,
}) {
  try {
    FirebaseCrashlytics.instance.recordError(
      error,
      stack,
      reason: reason,
    );
  } catch (_) {
    // No default Firebase app in test / some headless environments.
  }
}
