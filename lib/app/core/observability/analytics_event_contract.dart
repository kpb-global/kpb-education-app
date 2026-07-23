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

  /// Guest mode (KPB-156): a visitor chose to explore without an account, and
  /// the moment a guest heads to sign-up (with the gate `source`). Makes the
  /// guest → signup → activation funnel attributable — otherwise guest usage is
  /// invisible.
  static const guestModeEntered = 'guest_mode_entered';
  static const guestToSignup = 'guest_to_signup';

  /// Onboarding funnel (KPB-158): a step became visible, plus completion / skip,
  /// so drop-off across the multi-page stepper is visible. `auth_failed` records
  /// a failed sign-in/up attempt with method + coarse reason (auth drop-off by
  /// method). The signup method itself rides the built-in `sign_up` event's
  /// `method` param (see [AnalyticsService.logRegister]).
  static const onboardingStepViewed = 'onboarding_step_viewed';
  static const onboardingCompleted = 'onboarding_completed';
  static const onboardingSkipped = 'onboarding_skipped';
  static const authFailed = 'auth_failed';

  /// Conversion: the moment a user is handed off to a KPB advisor on WhatsApp.
  /// This is the core lead→advisor-contact step the funnel is measured on.
  static const whatsappHandoff = 'whatsapp_handoff';

  /// Referral loop (KPB-69): an invite shared via WhatsApp, and a code redeemed
  /// by a referee. Combined with case_created, this makes the referral →
  /// signup → case-created funnel attributable.
  static const referralInviteShared = 'referral_invite_shared';
  static const referralRedeemed = 'referral_redeemed';

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

  /// WhatsApp hand-off attribution.
  static const source = 'source';
  static const contextType = 'context_type';

  static const success = 'success';
  static const elapsedMs = 'elapsed_ms';
  static const catalogHiveFallbackCount = 'catalog_hive_fallback_count';

  static const domain = 'domain';
  static const resolution = 'resolution';

  static const resource = 'resource';
  static const attempts = 'attempts';

  /// Onboarding funnel + auth attribution (KPB-158).
  static const step = 'step';
  static const stepCount = 'step_count';
  static const accountType = 'account_type';
  static const method = 'method';
  static const reason = 'reason';
}
