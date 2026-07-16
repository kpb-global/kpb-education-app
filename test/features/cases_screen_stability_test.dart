// Widget tests call `AppController.hydrate()`, which runs remote sync when
// `KPB_ENABLE_REMOTE_SYNC` is true (compile-time default). Run locally with:
//   flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
// (matches CI) to avoid sync/network side effects.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/core/ui/skeleton.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

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

      await _pumpCasesScreen(
        tester,
        snapshot,
        afterHydrate: (c) => c
          ..isSyncing = true
          ..syncError = null,
      );

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

      await _pumpCasesScreen(
        tester,
        snapshot,
        afterHydrate: (c) => c
          ..isSyncing = false
          ..syncError = 'network timeout',
      );

      expect(find.byType(KpbErrorState), findsOneWidget);
      expect(find.byType(CasesScreenSkeleton), findsNothing);
    });

    testWidgets('shows empty state when not syncing, no error and no cases',
        (tester) async {
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await _pumpCasesScreen(
        tester,
        snapshot,
        afterHydrate: (c) => c
          ..isSyncing = false
          ..syncError = null,
      );

      expect(find.byType(CasesScreenSkeleton), findsNothing);
      expect(find.byType(KpbErrorState), findsNothing);
      expect(find.byType(KpbEmptyState), findsOneWidget);
      expect(find.text('no_cases'.tr), findsOneWidget);
    });

    testWidgets(
        'shows empty state (not a blank screen) when offline sync failed '
        'and no cases are cached', (tester) async {
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
      );

      await _pumpCasesScreen(
        tester,
        snapshot,
        afterHydrate: (c) => c
          ..isSyncing = false
          ..syncError = 'network unreachable',
      );

      // With zero cases and a sync error we must render SOMETHING actionable:
      // either the retry error state or the empty state — never a blank body.
      expect(find.byType(CasesScreenSkeleton), findsNothing);
      final hasErrorState = find.byType(KpbErrorState).evaluate().isNotEmpty;
      final hasEmptyState = find.byType(KpbEmptyState).evaluate().isNotEmpty;
      expect(hasErrorState || hasEmptyState, isTrue,
          reason: 'Dossiers tab must never render blank offline');
    });

    testWidgets(
        'keeps rendered case list when syncError exists but data is present',
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

Future<void> _pumpCasesScreen(
  WidgetTester tester,
  AppSnapshot snapshot, {
  void Function(AppController c)? afterHydrate,
}) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupPlatformChannelMocks();

  final repository = FakeRepository(snapshot: snapshot);
  final controller = AppController(
    repository: repository,
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  afterHydrate?.call(controller);
  Get.put<AppController>(controller, permanent: true);

  // Use the real app theme: its FilledButtonThemeData (infinite-min-width
  // buttons) is exactly what blanked the Dossiers tab offline — the default
  // Material theme would mask that regression.
  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.buildTheme(),
      home: const Scaffold(body: CasesScreen()),
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
