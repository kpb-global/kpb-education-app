// Smoke test for the honest App-engagement "post-decision / plan B" screen.
// It is keyed off a REAL rejected case and binds its plan B to the real
// controller.institutionMatch ranking — no fabricated reason or success-rate
// statistic. Translations aren't wired here, so `.tr` yields the raw key and
// assertions use keys / the real (resolved) case title.
//
// Run locally with:
//   flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/cases/post_decision_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('PostDecisionScreen (honest plan B)', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      resetGetxSingleton();
    });

    testWidgets(
        'renders the refused decision, a real plan B, and the '
        'WhatsApp counselor CTA', (tester) async {
      final now = DateTime(2026, 7, 1);
      final rejected = StudentCase(
        id: 'case-refus',
        referenceCode: 'KPB-REF',
        type: CaseType.applicationSupport,
        title: const LocalizedText(
            fr: 'Candidature master', en: 'Master application'),
        description: const LocalizedText(fr: '', en: ''),
        contextLabel: const LocalizedText(
            fr: 'Master • gestion', en: 'Master • management'),
        status: CaseStatus.rejected,
        preferredContactMethod: ContactMethod.inApp,
        createdAt: now.subtract(const Duration(days: 5)),
        updatedAt: now,
        nextStepTitle: const LocalizedText(fr: '', en: ''),
        nextStepDescription: const LocalizedText(fr: '', en: ''),
        timeline: const [],
        messages: const [],
        documentRequests: const [],
      );

      await pumpTestApp(
        tester,
        child: const PostDecisionScreen(caseId: 'case-refus'),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
          cases: [rejected],
        ),
      );

      // Header + refused application card bound to the real case.
      expect(find.text('post_decision_title'), findsOneWidget);
      expect(find.text('Candidature master'), findsOneWidget);
      // "Refused" chip reuses the real case-status key.
      expect(find.text('status_rejected'), findsOneWidget);

      // Honest encouragement — NOT a fabricated reason or "1 in 3" statistic.
      expect(find.text('post_decision_encouragement'), findsOneWidget);

      // Plan B is populated from the real (mock-catalog) institution ranking.
      expect(find.text('post_decision_plan_b_title'), findsOneWidget);
      // At least one alternative renders a real match percentage.
      expect(find.textContaining('%'), findsWidgets);

      // Counselor hand-off → WhatsApp (no in-app payment).
      expect(find.text('post_decision_counselor_title'), findsOneWidget);
    });
  });
}
