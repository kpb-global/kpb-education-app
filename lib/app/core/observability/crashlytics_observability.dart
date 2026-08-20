import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Custom keys written next to handled errors for Crashlytics filtering.
///
/// Use with [safeRecordError]; see [`docs/observability-dashboards.md`](../../../../docs/observability-dashboards.md).
abstract final class CrashlyticsObsKey {
  static const domain = 'obs_domain';
  static const operation = 'obs_operation';
  static const reportKind = 'obs_report_kind';
}

/// Values for [CrashlyticsObsKey.reportKind].
abstract final class CrashlyticsReportKind {
  static const nonFatalHandled = 'non_fatal_handled';
  static const explicitFatal = 'explicit_fatal';
}

/// Typical [CrashlyticsObsKey.domain] values (filter groups in Crashlytics).
abstract final class CrashlyticsObsDomain {
  static const sync = 'sync';
  static const cases = 'cases';
  static const savedItems = 'saved_items';
  static const profile = 'profile';
}

/// Applies the user's "Analyse d'usage" decision to **crash diagnostics**.
///
/// The profile switch used to flip Firebase Analytics and PostHog only, so a
/// refusal left crash reports flowing — which forced the Play data form to
/// declare "Crash logs" as REQUIRED. Routing the same decision here is what
/// lets that answer be "optional" and makes the switch tell the truth.
///
/// Called from `AnalyticsService.setCollectionEnabled` (the single funnel used
/// both by the toggle and by the boot-time re-application of the persisted
/// choice) — never called directly, so no code path can flip crash collection
/// without also flipping the other two collectors.
///
/// Throws when Firebase is not initialized (tests, headless): the caller owns
/// the catch, one per collector, so a failure here cannot leave the others on.
Future<void> applyCrashlyticsConsent(bool enabled) async {
  final crashlytics = FirebaseCrashlytics.instance;
  await crashlytics.setCrashlyticsCollectionEnabled(enabled);
  if (enabled) return;
  // A refusal must also drop what is already queued on disk. Crashlytics keeps
  // unsent reports across launches, so stopping collection alone would still
  // upload reports gathered before the refusal — on the next launch, after the
  // user said no. Disabling collection does not discard that queue on its own;
  // that is why this call is here and not omitted as redundant.
  await crashlytics.deleteUnsentReports();
}
