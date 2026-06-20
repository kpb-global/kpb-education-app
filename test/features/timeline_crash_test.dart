import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/cases/case_detail_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  group('CaseDetailScreen Timeline Stability', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('renders CaseDetailScreen and timeline events without crash',
        (tester) async {
      final now = DateTime(2026, 5, 21);
      final testCase = StudentCase(
        id: 'case-123',
        referenceCode: 'KPB-999',
        type: CaseType.applicationSupport,
        title: const LocalizedText(fr: 'Mon dossier master', en: 'My master case'),
        description: const LocalizedText(fr: 'Description', en: 'Description'),
        contextLabel: const LocalizedText(fr: 'KPB', en: 'KPB'),
        status: CaseStatus.underReview,
        preferredContactMethod: ContactMethod.inApp,
        createdAt: now.subtract(const Duration(days: 2)),
        updatedAt: now,
        nextStepTitle: const LocalizedText(fr: 'Attente de validation', en: 'Awaiting validation'),
        nextStepDescription: const LocalizedText(fr: 'Description de validation', en: 'Validation description'),
        timeline: <CaseTimelineEvent>[
          CaseTimelineEvent(
            id: 'evt-1',
            title: const LocalizedText(fr: 'Dossier soumis', en: 'Case submitted'),
            description: const LocalizedText(fr: 'Soumission initiale', en: 'Initial submission'),
            createdAt: now.subtract(const Duration(days: 1)),
            status: CaseStatus.submitted,
          ),
          CaseTimelineEvent(
            id: 'evt-2',
            title: const LocalizedText(fr: 'Dossier en revue', en: 'Under review'),
            description: const LocalizedText(fr: 'Revue par le conseiller', en: 'Review by advisor'),
            createdAt: now,
            status: CaseStatus.underReview,
          ),
        ],
        messages: const [],
        documentRequests: const [],
      );

      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        cases: [testCase],
      );

      await _pumpCaseDetailScreen(tester, 'case-123', snapshot);

      // Verify the screen title and details render correctly
      expect(find.text('Mon dossier master'), findsOneWidget);
      expect(find.text('KPB-999'), findsOneWidget);

      // Verify both timeline event titles render successfully, confirming no timeline crash occurs
      expect(find.text('Dossier soumis'), findsOneWidget);
      expect(find.text('Dossier en revue'), findsOneWidget);
    });
  });
}

Future<void> _pumpCaseDetailScreen(
  WidgetTester tester,
  String caseId,
  AppSnapshot snapshot,
) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupPlatformChannelMocks();

  // Set larger physical size to avoid NestedScrollView flexible header constraints overflow
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final repository = FakeRepository(snapshot: snapshot);
  final controller = AppController(
    repository: repository,
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      home: Scaffold(
        body: CaseDetailScreen(caseId: caseId),
      ),
      debugShowCheckedModeBanner: false,
    ),
  );
  await tester.pumpAndSettle();
}
