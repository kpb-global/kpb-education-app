import 'package:firebase_analytics/firebase_analytics.dart';

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
      await _analytics.logEvent(name: 'logout');
    } catch (e, s) {
      AppLogger.error('logLogout', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Orientation events ────────────────────────────────────────────────────

  Future<void> logOrientationStart() async {
    try {
      await _analytics.logEvent(name: 'orientation_start');
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
        name: 'orientation_complete',
        parameters: {
          'total_questions': totalQuestions,
          'match_count': matchCount,
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
        name: 'save_item',
        parameters: {'item_id': itemId, 'item_type': itemType},
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
        name: 'unsave_item',
        parameters: {'item_id': itemId, 'item_type': itemType},
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
        name: 'compare_institutions',
        parameters: {'count': ids.length, 'ids': ids.join(',')},
      );
    } catch (e, s) {
      AppLogger.error('logCompareInstitutions', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Cases events ──────────────────────────────────────────────────────────

  Future<void> logCaseCreated({required String caseType}) async {
    try {
      await _analytics.logEvent(
        name: 'case_created',
        parameters: {'case_type': caseType},
      );
    } catch (e, s) {
      AppLogger.error('logCaseCreated', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logCaseViewed(String caseId) async {
    try {
      await _analytics.logEvent(
        name: 'case_viewed',
        parameters: {'case_id': caseId},
      );
    } catch (e, s) {
      AppLogger.error('logCaseViewed', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logDocumentUploaded({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: 'document_uploaded',
        parameters: {'case_id': caseId},
      );
    } catch (e, s) {
      AppLogger.error('logDocumentUploaded', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logMessageSent({required String caseId}) async {
    try {
      await _analytics.logEvent(
        name: 'case_message_sent',
        parameters: {'case_id': caseId},
      );
    } catch (e, s) {
      AppLogger.error('logMessageSent', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  // ── Profile events ────────────────────────────────────────────────────────

  Future<void> logProfileUpdated() async {
    try {
      await _analytics.logEvent(name: 'profile_updated');
    } catch (e, s) {
      AppLogger.error('logProfileUpdated', error: e, stackTrace: s, tag: 'analytics');
    }
  }

  Future<void> logThemeToggled(bool isDark) async {
    try {
      await _analytics.logEvent(
        name: 'theme_toggled',
        parameters: {'theme': isDark ? 'dark' : 'light'},
      );
    } catch (e, s) {
      AppLogger.error('logThemeToggled', error: e, stackTrace: s, tag: 'analytics');
    }
  }
}
