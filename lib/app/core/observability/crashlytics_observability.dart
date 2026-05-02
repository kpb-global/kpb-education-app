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
