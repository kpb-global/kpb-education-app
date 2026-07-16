// Smoke tests for the Notifications center.
//
// It combines durable scholarship-opening notifications with rows derived from
// real StudentCase state. When neither source has content, an honest empty
// state shows.
// Translations aren't wired here, so `.tr` yields the raw key and assertions
// use keys.
//
// Run locally with:
//   flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/notifications/notifications_screen.dart';

import '../../widget_test_helpers.dart';

StudentCase _case({
  required String id,
  required CaseStatus status,
  required DateTime updatedAt,
  String nextStep = '',
  String title = 'Master application',
}) {
  return StudentCase(
    id: id,
    referenceCode: 'KPB-$id',
    type: CaseType.applicationSupport,
    title: LocalizedText(fr: title, en: title),
    description: const LocalizedText(fr: '', en: ''),
    contextLabel: const LocalizedText(fr: '', en: ''),
    status: status,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: updatedAt.subtract(const Duration(days: 3)),
    updatedAt: updatedAt,
    nextStepTitle: LocalizedText(fr: nextStep, en: nextStep),
    nextStepDescription: const LocalizedText(fr: '', en: ''),
    timeline: const [],
    messages: const [],
    documentRequests: const [],
  );
}

void main() {
  group('NotificationsScreen', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      resetGetxSingleton();
    });

    testWidgets(
        'derives real items from cases — action-needed + decision-received — '
        'and opens the real plan B screen on tap', (tester) async {
      final now = DateTime(2026, 7, 8);
      final actionCase = _case(
        id: 'case-docs',
        status: CaseStatus.documentsNeeded,
        updatedAt: now.subtract(const Duration(hours: 2)),
        nextStep: 'Upload your transcript',
      );
      final rejectedCase = _case(
        id: 'case-refus',
        status: CaseStatus.rejected,
        updatedAt: now,
      );

      await pumpTestApp(
        tester,
        child: const NotificationsScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'en',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [actionCase, rejectedCase],
        ),
      );

      // Header + a "mark all read" affordance (items exist).
      expect(find.text('notifications_title'), findsWidgets);
      expect(find.text('notifications_mark_all_read'), findsOneWidget);

      // Both real derived rows render; empty state does NOT.
      expect(find.text('notif_decision_received_title'), findsOneWidget);
      expect(find.text('notif_action_needed_title'), findsOneWidget);
      expect(find.text('notifications_empty_title'), findsNothing);

      // Real push control is present (single row, no fabricated per-type
      // toggles).
      expect(find.text('notifications_push_section'), findsOneWidget);
      expect(find.text('notifications_enable_push_title'), findsOneWidget);

      // The "decision received" row navigates to the REAL PostDecisionScreen.
      await tester.tap(find.text('notif_decision_received_title'));
      await tester.pumpAndSettle();
      expect(find.text('post_decision_title'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the honest empty state when no case qualifies',
        (tester) async {
      final underReview = _case(
        id: 'case-review',
        status: CaseStatus.underReview,
        updatedAt: DateTime(2026, 7, 8),
      );

      await pumpTestApp(
        tester,
        child: const NotificationsScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'en',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [underReview],
        ),
      );

      // Honest empty state — NOT a fabricated feed.
      expect(find.text('notifications_empty_title'), findsOneWidget);
      expect(find.text('notifications_empty_body'), findsOneWidget);

      // No derived rows, and nothing to "mark read".
      expect(find.text('notif_decision_received_title'), findsNothing);
      expect(find.text('notif_action_needed_title'), findsNothing);
      expect(find.text('notifications_mark_all_read'), findsNothing);

      // The real push control is still offered.
      expect(find.text('notifications_push_section'), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a durable scholarship-opening notification',
        (tester) async {
      final api = MockApiClient();
      when(() => api.fetchUserNotifications(any())).thenAnswer(
        (_) async => <String, dynamic>{
          'items': <dynamic>[
            <String, dynamic>{
              'id': 'notif-1',
              'kind': 'scholarship_opened',
              'title': 'La bourse Chevening est ouverte',
              'body': 'Les candidatures sont ouvertes.',
              'route': '/scholarships',
              'readAt': null,
              'createdAt': '2026-07-16T10:00:00.000Z',
            },
          ],
          'unreadCount': 1,
        },
      );

      await pumpTestApp(
        tester,
        child: const NotificationsScreen(),
        mockApiClient: api,
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(preferredLanguage: 'fr'),
        ),
      );

      expect(find.text('La bourse Chevening est ouverte'), findsOneWidget);
      expect(find.text('Les candidatures sont ouvertes.'), findsOneWidget);
      expect(find.text('notifications_empty_title'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
