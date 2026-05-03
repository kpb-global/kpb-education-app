/// Canonical Firebase Analytics **event names** (snake_case, GA4-friendly).
///
/// Keep in sync with [`docs/analytics-event-contract.md`](../../../../docs/analytics-event-contract.md).
abstract final class AnalyticsEventName {
  static const logout = 'logout';
  static const orientationStart = 'orientation_start';
  static const orientationComplete = 'orientation_complete';
  static const saveItem = 'save_item';
  static const unsaveItem = 'unsave_item';
  static const compareInstitutions = 'compare_institutions';
  static const caseCreated = 'case_created';
  static const caseViewed = 'case_viewed';
  static const documentUploaded = 'document_uploaded';
  static const caseMessageSent = 'case_message_sent';
  static const profileUpdated = 'profile_updated';
  static const themeToggled = 'theme_toggled';

  /// Sync / catalog observability (paired with [AnalyticsService] helpers).
  static const syncFullComplete = 'sync_full_complete';
  static const syncConflictResolved = 'sync_conflict_resolved';
  static const syncCatalogHiveFallback = 'sync_catalog_hive_fallback';
}

/// Standard parameter keys for custom events (snake_case).
abstract final class AnalyticsParamKey {
  static const totalQuestions = 'total_questions';
  static const matchCount = 'match_count';
  static const itemId = 'item_id';
  static const itemType = 'item_type';
  static const count = 'count';
  static const ids = 'ids';
  static const caseType = 'case_type';
  static const caseId = 'case_id';
  static const theme = 'theme';

  static const success = 'success';
  static const elapsedMs = 'elapsed_ms';
  static const catalogHiveFallbackCount = 'catalog_hive_fallback_count';

  static const domain = 'domain';
  static const resolution = 'resolution';

  static const resource = 'resource';
  static const attempts = 'attempts';
}
