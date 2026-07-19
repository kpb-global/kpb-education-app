import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart' show NavigatorObserver;
import 'package:posthog_flutter/posthog_flutter.dart';

import '../config/app_config.dart';
import '../observability/analytics_event_contract.dart';
import '../utils/app_logger.dart';

/// Thin wrapper around FirebaseAnalytics with typed event helpers.
/// All calls are fire-and-forget — never throw to the caller.
///
/// Every event is mirrored to PostHog when [AppConfig.posthogEnabled] (see
/// [_mirror] / [_mirrorScreen]); when no PostHog key is configured the mirror
/// calls are cheap no-ops and only Firebase runs. PostHog is set up in
/// `main()` — this service only emits events, identifies the user, and exposes
/// the navigator observer used for automatic screen capture.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  // Lazily initialized so unit tests (where Firebase is not bootstrapped) can
  // call any analytics method safely — the LateInitializationError propagates
  // into the surrounding try-catch that every method already provides.
  late final _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Navigator observers to install on the app. Includes PostHog's
  /// [PosthogObserver] (screen views + survey triggers) only when configured.
  /// Built once and cached — GetX rebuilds the root app on every
  /// `controller.update()`, and a fresh observer per rebuild would re-subscribe
  /// the Navigator each time.
  late final List<NavigatorObserver> navigatorObservers = [
    observer,
    if (AppConfig.posthogEnabled) PosthogObserver(),
  ];

  /// Mirrors a Firebase event to PostHog. No-op when PostHog is not configured;
  /// fire-and-forget and never throws (a mirror failure must not break the
  /// Firebase path or the caller).
  void _mirror(String event, [Map<String, Object>? properties]) {
    if (!AppConfig.posthogEnabled) return;
    try {
      unawaited(Posthog().capture(eventName: event, properties: properties));
    } catch (e, s) {
      _logError('posthog.$event', e, s);
    }
  }

  void _mirrorScreen(String screenName) {
    if (!AppConfig.posthogEnabled) return;
    try {
      unawaited(Posthog().screen(screenName: screenName));
    } catch (e, s) {
      _logError('posthog.screen', e, s);
    }
  }

  // ── Identity ────────────────────────────────────────────────────────────

  /// Ties the current PostHog session (and any recorded replay) to the backend
  /// user id — a UUID, not PII. Call on login and on cold start when already
  /// signed in. No-op without PostHog. With `personProfiles: identifiedOnly`,
  /// no person profile is created until this runs.
  Future<void> identifyUser(String userId) async {
    if (!AppConfig.posthogEnabled || userId.trim().isEmpty) return;
    try {
      await Posthog().identify(userId: userId.trim());
    } catch (e, s) {
      _logError('identifyUser', e, s);
    }
  }

  /// Clears the PostHog identity so a subsequent user on the same device starts
  /// a fresh, unlinked session. Called from [logLogout].
  Future<void> _resetIdentity() async {
    if (!AppConfig.posthogEnabled) return;
    try {
      await Posthog().reset();
    } catch (e, s) {
      _logError('resetIdentity', e, s);
    }
  }

  // ── Consent ──────────────────────────────────────────────────────────────

  /// Turns product analytics collection on/off at runtime for BOTH Firebase
  /// Analytics and PostHog (events + session replay). Wired to the profile
  /// opt-out toggle and re-applied on every boot from the persisted choice
  /// (`AppController.applyAnalyticsConsent`). When [enabled] is false, PostHog
  /// stops capturing and recording immediately. Never throws.
  Future<void> setCollectionEnabled(bool enabled) async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(enabled);
    } catch (e, s) {
      _logError('setCollectionEnabled.firebase', e, s);
    }
    if (!AppConfig.posthogEnabled) return;
    try {
      enabled ? await Posthog().enable() : await Posthog().disable();
    } catch (e, s) {
      _logError('setCollectionEnabled.posthog', e, s);
    }
  }

  static void _logError(String operation, Object error, StackTrace stackTrace) {
    if (error is FirebaseException &&
        error.plugin == 'core' &&
        error.code == 'no-app') {
      return;
    }
    AppLogger.error(
      operation,
      error: error,
      stackTrace: stackTrace,
      tag: 'analytics',
    );
  }

  // ── Screen tracking ────────────────────────────────────────────────────────

  Future<void> logScreen(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      _mirrorScreen(screenName);
    } catch (e, s) {
      _logError('logScreen', e, s);
    }
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
      _mirror('login', {'method': method});
    } catch (e, s) {
      _logError('logLogin', e, s);
    }
  }

  Future<void> logRegister({String method = 'email'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
      _mirror('sign_up', {'method': method});
    } catch (e, s) {
      _logError('logRegister', e, s);
    }
  }

  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.logout);
      _mirror(AnalyticsEventName.logout);
      // Unlink the device from the signed-out user so the next session (and any
      // replay) is not attributed to them.
      await _resetIdentity();
    } catch (e, s) {
      _logError('logLogout', e, s);
    }
  }

  // ── Orientation events ────────────────────────────────────────────────────

  Future<void> logOrientationStart() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.orientationStart);
      _mirror(AnalyticsEventName.orientationStart);
    } catch (e, s) {
      _logError('logOrientationStart', e, s);
    }
  }

  Future<void> logOrientationComplete({
    required int totalQuestions,
    required int matchCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.orientationComplete,
        parameters: {
          AnalyticsParamKey.totalQuestions: totalQuestions,
          AnalyticsParamKey.matchCount: matchCount,
        },
      );
      _mirror(AnalyticsEventName.orientationComplete, {
        AnalyticsParamKey.totalQuestions: totalQuestions,
        AnalyticsParamKey.matchCount: matchCount,
      });
    } catch (e, s) {
      _logError('logOrientationComplete', e, s);
    }
  }

  // ── Search events ─────────────────────────────────────────────────────────

  Future<void> logSearch(String query) async {
    try {
      await _analytics.logSearch(searchTerm: query);
      _mirror('search', {'search_term': query});
    } catch (e, s) {
      _logError('logSearch', e, s);
    }
  }

  // ── Referral loop (KPB-69) ──────────────────────────────────────────────────

  Future<void> logReferralInviteShared() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.referralInviteShared);
      _mirror(AnalyticsEventName.referralInviteShared);
    } catch (e, s) {
      _logError('logReferralInviteShared', e, s);
    }
  }

  Future<void> logReferralRedeemed() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.referralRedeemed);
      _mirror(AnalyticsEventName.referralRedeemed);
    } catch (e, s) {
      _logError('logReferralRedeemed', e, s);
    }
  }

  // ── Content events ────────────────────────────────────────────────────────

  Future<void> logSaveItem({
    required String itemId,
    required String itemType,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.saveItem,
        parameters: {
          AnalyticsParamKey.itemId: itemId,
          AnalyticsParamKey.itemType: itemType,
        },
      );
      _mirror(AnalyticsEventName.saveItem, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.itemType: itemType,
      });
    } catch (e, s) {
      _logError('logSaveItem', e, s);
    }
  }

  Future<void> logUnsaveItem({
    required String itemId,
    required String itemType,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.unsaveItem,
        parameters: {
          AnalyticsParamKey.itemId: itemId,
          AnalyticsParamKey.itemType: itemType,
        },
      );
      _mirror(AnalyticsEventName.unsaveItem, {
        AnalyticsParamKey.itemId: itemId,
        AnalyticsParamKey.itemType: itemType,
      });
    } catch (e, s) {
      _logError('logUnsaveItem', e, s);
    }
  }

  Future<void> logViewInstitution(String institutionId) async {
    try {
      await _analytics.logViewItem(
        items: [
          AnalyticsEventItem(itemId: institutionId, itemCategory: 'institution')
        ],
      );
      _mirror('view_item', {
        AnalyticsParamKey.itemId: institutionId,
        'item_category': 'institution',
      });
    } catch (e, s) {
      _logError('logViewInstitution', e, s);
    }
  }

  Future<void> logViewScholarship(String scholarshipId) async {
    try {
      await _analytics.logViewItem(
        items: [
          AnalyticsEventItem(itemId: scholarshipId, itemCategory: 'scholarship')
        ],
      );
      _mirror('view_item', {
        AnalyticsParamKey.itemId: scholarshipId,
        'item_category': 'scholarship',
      });
    } catch (e, s) {
      _logError('logViewScholarship', e, s);
    }
  }

  Future<void> logCompareInstitutions(List<String> ids) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.compareInstitutions,
        parameters: {
          AnalyticsParamKey.count: ids.length,
          AnalyticsParamKey.ids: ids.join(','),
        },
      );
      _mirror(AnalyticsEventName.compareInstitutions, {
        AnalyticsParamKey.count: ids.length,
        AnalyticsParamKey.ids: ids.join(','),
      });
    } catch (e, s) {
      _logError('logCompareInstitutions', e, s);
    }
  }

  // ── Cases events ──────────────────────────────────────────────────────────

  Future<void> logCaseCreated({required String caseType}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseCreated,
        parameters: {AnalyticsParamKey.caseType: caseType},
      );
      _mirror(AnalyticsEventName.caseCreated,
          {AnalyticsParamKey.caseType: caseType});
    } catch (e, s) {
      _logError('logCaseCreated', e, s);
    }
  }

  Future<void> logCaseViewed(String caseId) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseViewed,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
      _mirror(
          AnalyticsEventName.caseViewed, {AnalyticsParamKey.caseId: caseId});
    } catch (e, s) {
      _logError('logCaseViewed', e, s);
    }
  }

  Future<void> logDocumentUploaded({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.documentUploaded,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
      _mirror(AnalyticsEventName.documentUploaded,
          {AnalyticsParamKey.caseId: caseId});
    } catch (e, s) {
      _logError('logDocumentUploaded', e, s);
    }
  }

  Future<void> logMessageSent({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseMessageSent,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
      _mirror(AnalyticsEventName.caseMessageSent,
          {AnalyticsParamKey.caseId: caseId});
    } catch (e, s) {
      _logError('logMessageSent', e, s);
    }
  }

  // ── Conversion events ─────────────────────────────────────────────────────

  /// Fired the instant a user is handed off to a KPB advisor on WhatsApp — the
  /// core lead→advisor-contact conversion step. [source] is the call site
  /// (e.g. 'case_detail', 'program_detail', 'service_packages') and
  /// [contextType] the kind of context attached (e.g. 'case', 'program',
  /// 'service', 'destination', 'fraud_report', 'unknown'). [success] is false
  /// when WhatsApp could not be opened — a lost conversion, which would
  /// otherwise be invisible in the funnel.
  Future<void> logWhatsAppHandoff({
    String source = 'unknown',
    String contextType = 'unknown',
    bool success = true,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.whatsappHandoff,
        parameters: {
          AnalyticsParamKey.source: source,
          AnalyticsParamKey.contextType: contextType,
          AnalyticsParamKey.success: success ? 1 : 0,
        },
      );
      _mirror(AnalyticsEventName.whatsappHandoff, {
        AnalyticsParamKey.source: source,
        AnalyticsParamKey.contextType: contextType,
        AnalyticsParamKey.success: success ? 1 : 0,
      });
    } catch (e, s) {
      _logError('logWhatsAppHandoff', e, s);
    }
  }

  // ── Profile events ────────────────────────────────────────────────────────

  Future<void> logProfileUpdated() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.profileUpdated);
      _mirror(AnalyticsEventName.profileUpdated);
    } catch (e, s) {
      _logError('logProfileUpdated', e, s);
    }
  }

  Future<void> logThemeToggled(bool isDark) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.themeToggled,
        parameters: {AnalyticsParamKey.theme: isDark ? 'dark' : 'light'},
      );
      _mirror(AnalyticsEventName.themeToggled,
          {AnalyticsParamKey.theme: isDark ? 'dark' : 'light'});
    } catch (e, s) {
      _logError('logThemeToggled', e, s);
    }
  }

  // ── Sync telemetry (Phase 3 data reliability) ─────────────────────────────

  Future<void> logFullSyncResult({
    required bool success,
    required int elapsedMs,
    required int catalogHiveFallbackCount,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.syncFullComplete,
        parameters: {
          AnalyticsParamKey.success: success ? 1 : 0,
          AnalyticsParamKey.elapsedMs: elapsedMs,
          AnalyticsParamKey.catalogHiveFallbackCount: catalogHiveFallbackCount,
        },
      );
      _mirror(AnalyticsEventName.syncFullComplete, {
        AnalyticsParamKey.success: success ? 1 : 0,
        AnalyticsParamKey.elapsedMs: elapsedMs,
        AnalyticsParamKey.catalogHiveFallbackCount: catalogHiveFallbackCount,
      });
    } catch (e, s) {
      _logError('logFullSyncResult', e, s);
    }
  }

  Future<void> logSyncConflict({
    required String domain,
    required String resolution,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.syncConflictResolved,
        parameters: {
          AnalyticsParamKey.domain: domain,
          AnalyticsParamKey.resolution: resolution,
        },
      );
      _mirror(AnalyticsEventName.syncConflictResolved, {
        AnalyticsParamKey.domain: domain,
        AnalyticsParamKey.resolution: resolution,
      });
    } catch (e, s) {
      _logError('logSyncConflict', e, s);
    }
  }

  Future<void> logCatalogSyncFallback({
    required String resource,
    required int attempts,
  }) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.syncCatalogHiveFallback,
        parameters: {
          AnalyticsParamKey.resource: resource,
          AnalyticsParamKey.attempts: attempts,
        },
      );
      _mirror(AnalyticsEventName.syncCatalogHiveFallback, {
        AnalyticsParamKey.resource: resource,
        AnalyticsParamKey.attempts: attempts,
      });
    } catch (e, s) {
      _logError('logCatalogSyncFallback', e, s);
    }
  }
}
