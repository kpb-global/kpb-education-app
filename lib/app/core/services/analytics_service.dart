import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

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
    } catch (e, s) {
      _logError('logScreen', e, s);
    }
  }

  // ── Auth events ───────────────────────────────────────────────────────────

  Future<void> logLogin({String method = 'email'}) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e, s) {
      _logError('logLogin', e, s);
    }
  }

  Future<void> logRegister({String method = 'email'}) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
    } catch (e, s) {
      _logError('logRegister', e, s);
    }
  }

  Future<void> logLogout() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.logout);
    } catch (e, s) {
      _logError('logLogout', e, s);
    }
  }

  // ── Orientation events ────────────────────────────────────────────────────

  Future<void> logOrientationStart() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.orientationStart);
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
    } catch (e, s) {
      _logError('logOrientationComplete', e, s);
    }
  }

  // ── Search events ─────────────────────────────────────────────────────────

  Future<void> logSearch(String query) async {
    try {
      await _analytics.logSearch(searchTerm: query);
    } catch (e, s) {
      _logError('logSearch', e, s);
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
    } catch (e, s) {
      _logError('logMessageSent', e, s);
    }
  }

  // ── Profile events ────────────────────────────────────────────────────────

  Future<void> logProfileUpdated() async {
    try {
      await _analytics.logEvent(name: AnalyticsEventName.profileUpdated);
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
    } catch (e, s) {
      _logError('logCatalogSyncFallback', e, s);
    }
  }
}
