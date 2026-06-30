import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

import '../observability/crashlytics_observability.dart';

/// Records a **non-fatal** issue to Crashlytics when Firebase is initialized.
///
/// Optional [domain] and [operation] set custom keys ([CrashlyticsObsKey]) so
/// consoles can filter sync vs profile vs cases failures.
///
/// Tests / headless environments: no default Firebase app → no-op.
void safeRecordError(
  Object error,
  StackTrace? stack, {
  String? reason,
  bool fatal = false,
  String? domain,
  String? operation,
}) {
  scheduleMicrotask(() async {
    await _safeRecordErrorAsync(
      error,
      stack,
      reason: reason,
      fatal: fatal,
      domain: domain,
      operation: operation,
    );
  });
}

Future<void> _safeRecordErrorAsync(
  Object error,
  StackTrace? stack, {
  String? reason,
  required bool fatal,
  String? domain,
  String? operation,
}) async {
  try {
    final c = FirebaseCrashlytics.instance;
    if (domain != null) {
      await c.setCustomKey(CrashlyticsObsKey.domain, domain);
    }
    if (operation != null) {
      await c.setCustomKey(CrashlyticsObsKey.operation, operation);
    }
    await c.setCustomKey(
      CrashlyticsObsKey.reportKind,
      fatal
          ? CrashlyticsReportKind.explicitFatal
          : CrashlyticsReportKind.nonFatalHandled,
    );
    await c.recordError(
      error,
      stack,
      reason: reason,
      fatal: fatal,
    );
  } catch (_) {
    // No default Firebase app in test / some headless environments.
  }
}
