// Smoke test for the App-engagement handoff restyle of the Dossier detail
// screen. Verifies the status-driven step checklist renders and that the red
// "Your turn" badge is bound to a REAL student-action status (documentsNeeded),
// not a mocked toggle.
//
// Run locally with:
//   flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
// (GetMaterialApp here has no translations wired, so `.tr` yields the raw key —
// assertions use keys / structural finders rather than localized strings.)

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/cases/case_detail_screen.dart';
import 'package:karatou/app/features/cases/case_status_timeline.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  group('CaseDetailScreen restyle', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    testWidgets('renders the status-driven checklist and a "Your turn" badge',
        (tester) async {
      final now = DateTime(2026, 6, 1);
      final testCase = StudentCase(
        id: 'case-abc',
        referenceCode: 'KPB-DOC',
        type: CaseType.applicationSupport,
        title: const LocalizedText(
            fr: 'Dossier master France', en: 'Master case France'),
        description: const LocalizedText(fr: 'Desc', en: 'Desc'),
        contextLabel:
            const LocalizedText(fr: 'France • master', en: 'France • master'),
        status: CaseStatus.documentsNeeded,
        preferredContactMethod: ContactMethod.inApp,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
        nextStepTitle: const LocalizedText(
            fr: 'Envoie tes relevés', en: 'Send transcripts'),
        nextStepDescription: const LocalizedText(fr: '', en: ''),
        timeline: <CaseTimelineEvent>[
          CaseTimelineEvent(
            id: 'evt-1',
            title: const LocalizedText(fr: 'Reçu', en: 'Received'),
            description: const LocalizedText(fr: '', en: ''),
            createdAt: now.subtract(const Duration(days: 1)),
            status: CaseStatus.submitted,
          ),
        ],
        messages: const [],
        documentRequests: const [
          DocumentRequest(
            id: 'doc-1',
            title: LocalizedText(fr: 'Relevés', en: 'Transcripts'),
            isProvided: false,
          ),
        ],
      );

      await _pumpDetail(tester, 'case-abc', testCase);

      // Header binds to the real case title + reference (each once).
      expect(find.text('Dossier master France'), findsOneWidget);
      expect(find.text('KPB-DOC'), findsOneWidget);

      // The design's step checklist renders.
      expect(find.byType(CaseStatusTimeline), findsOneWidget);

      // "Your turn" badge appears exactly once — bound to the real
      // documentsNeeded (student-action) status, not a fake toggle.
      // (`.tr` returns the key here since translations aren't wired in tests.)
      expect(find.text('case_step_your_turn'), findsOneWidget);

      // The green WhatsApp CTA is present.
      expect(find.text('case_continue_whatsapp'), findsOneWidget);
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  String caseId,
  StudentCase testCase,
) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupPlatformChannelMocks();

  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    cases: [testCase],
  );

  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(body: CaseDetailScreen(caseId: caseId)),
      debugShowCheckedModeBanner: false,
    ),
  );
  await tester.pumpAndSettle();
}
