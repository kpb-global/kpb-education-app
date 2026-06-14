import 'package:firebase_analytics/firebase_analytics.dart';

import '../observability/analytics_event_contract.dart';
import '../utils/app_logger.dart';

/// Thin wrapper around FirebaseAnalytics with typed event helpers.
/// All calls are fire-and-forget — never throw to the caller.
class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  // Lazily initialized so unit tests (where Firebase is not bootstrapped) can
  // call any analytics method safely — the LateInitializationError propagates
  // into the surrounding try-catch that every method already provides.
  late final _analytics = FirebaseAnalytics.instance;

  FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  // ── Screen tracking ────────────────────────────────────────────────────────

  Future<void> logScreen(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e, s) {
      AppLogger.error('logScreen', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e, s) {
      AppLogger.error('logLogin', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logRegister({String method = 'email'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e, s) {
      AppLogger.error('logRegister', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.logout);
    } catch (e, s) {
      AppLogger.error('logLogout', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Orientation events ────────────────────────────────────────────────────

  Future<void> logOrientationStart() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.orientationStart);
    } catch (e, s) {
      AppLogger.error('logOrientationStart', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logOrientationComplete', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Search events ─────────────────────────────────────────────────────────

  Future<void> logSearch(String query) async {
    try {
      await _analytics.logSearch(searchTerm: query);
    } catch (e, s) {
      AppLogger.error('logSearch', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logSaveItem', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logUnsaveItem', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logViewInstitution(String institutionId) async {
    try {
      await _analytics.logViewItem(
        items: [
          AnalyticsEventItem(itemId: institutionId, itemCategory: 'institution')
        ],
      );
    } catch (e, s) {
      AppLogger.error('logViewInstitution', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logViewScholarship(String scholarshipId) async {
    try {
      await _analytics.logViewItem(
        items: [
          AnalyticsEventItem(itemId: scholarshipId, itemCategory: 'scholarship')
        ],
      );
    } catch (e, s) {
      AppLogger.error('logViewScholarship', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logCompareInstitutions', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Cases events ──────────────────────────────────────────────────────────

  Future<void> logCaseCreated({required String caseType}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseCreated,
        parameters: {AnalyticsParamKey.caseType: caseType},
      );
    } catch (e, s) {
      AppLogger.error('logCaseCreated', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logCaseViewed(String caseId) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseViewed,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
    } catch (e, s) {
      AppLogger.error('logCaseViewed', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logDocumentUploaded({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.documentUploaded,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
    } catch (e, s) {
      AppLogger.error('logDocumentUploaded', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logMessageSent({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.caseMessageSent,
        parameters: {AnalyticsParamKey.caseId: caseId},
      );
    } catch (e, s) {
      AppLogger.error('logMessageSent', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Profile events ────────────────────────────────────────────────────────

  Future<void> logProfileUpdated() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.profileUpdated);
    } catch (e, s) {
      AppLogger.error('logProfileUpdated', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logThemeToggled(bool isDark) async {
    try {
      await _analytics.logEvent(
        name: AnalyticsEventName.themeToggled,
        parameters: {AnalyticsParamKey.theme: isDark ? 'dark' : 'light'},
      );
    } catch (e, s) {
      AppLogger.error('logThemeToggled', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logFullSyncResult', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logSyncConflict', error: e, stackTrace: s, tag: 'analytics');
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
    } catch (e, s) {
      AppLogger.error('logCatalogSyncFallback', error: e, stackTrace: s, tag: 'analytics');
    }
  }
}
