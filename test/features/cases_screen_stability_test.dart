import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/core/ui/skeleton.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  group('CasesScreen Stability', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('shows skeleton when syncing and no cases', (tester) async {
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await _pumpCasesScreen(tester, snapshot);

      final controller = Get.find<AppController>();
      controller
        ..isSyncing = true
        ..syncError = null
        ..update();
      await tester.pump();

      expect(find.byType(CasesScreenSkeleton), findsOneWidget);
      expect(find.byType(KpbErrorState), findsNothing);
    });

    testWidgets('shows retry error state when sync fails and no cases',
        (tester) async {
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await _pumpCasesScreen(tester, snapshot);

      final controller = Get.find<AppController>();
      controller
        ..isSyncing = false
        ..syncError = 'network timeout'
        ..update();
      await tester.pump();

      expect(find.byType(KpbErrorState), findsOneWidget);
      expect(find.byType(CasesScreenSkeleton), findsNothing);
    });

    testWidgets('keeps rendered case list when syncError exists but data is present',
        (tester) async {
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        cases: <StudentCase>[
          _buildCase(id: 'case-1', reference: 'KPB-001'),
        ],
      );

      await _pumpCasesScreen(tester, snapshot);

      final controller = Get.find<AppController>();
      controller
        ..isSyncing = false
        ..syncError = 'temporary api error'
        ..update();
      await tester.pump();

      expect(find.byType(KpbErrorState), findsNothing);
      expect(find.text('KPB-001'), findsOneWidget);
    });
  });
}

Future<void> _pumpCasesScreen(WidgetTester tester, AppSnapshot snapshot) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupPlatformChannelMocks();

  final repository = FakeRepository(snapshot: snapshot);
  final controller = AppController(
    repository: repository,
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(
    const GetMaterialApp(
      home: Scaffold(body: CasesScreen()),
      debugShowCheckedModeBanner: false,
    ),
  );
  await tester.pump();
}

StudentCase _buildCase({required String id, required String reference}) {
  final now = DateTime(2026, 1, 20);
  return StudentCase(
    id: id,
    referenceCode: reference,
    type: CaseType.consultation,
    title: const LocalizedText(fr: 'Dossier test', en: 'Test case'),
    description: const LocalizedText(fr: 'Description', en: 'Description'),
    contextLabel: const LocalizedText(fr: 'KPB Education', en: 'KPB Education'),
    status: CaseStatus.submitted,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: now,
    updatedAt: now,
    nextStepTitle: const LocalizedText(fr: 'Prochaine etape', en: 'Next step'),
    nextStepDescription:
        const LocalizedText(fr: 'Etape suivante', en: 'Follow-up step'),
    timeline: const <CaseTimelineEvent>[],
    messages: const <CaseMessage>[],
    documentRequests: const <DocumentRequest>[],
  );
}
