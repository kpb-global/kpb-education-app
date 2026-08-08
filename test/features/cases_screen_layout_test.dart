// Layout regressions reported on a real TestFlight build (iPhone with Dynamic
// Island):
//   • the Dossiers header was drawn under the Dynamic Island (no SafeArea);
//   • the floating "KPB Intelligence" pill covered the last card of the list.
//
// Widget tests call `AppController.hydrate()`, which runs remote sync when
// `KPB_ENABLE_REMOTE_SYNC` is true (compile-time default). Run locally with:
//   flutter test --dart-define=KPB_ENABLE_REMOTE_SYNC=false
// (matches CI) to avoid sync/network side effects.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/shell_chrome.dart';
import 'package:karatou/app/features/cases/cases_screen.dart';

import '../widget_test_helpers.dart';

const double _topInset = 59; // Dynamic Island status-bar inset
const double _bottomInset = 34; // home indicator

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  group('CasesScreen layout', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    testWidgets('header stays below the status-bar / Dynamic Island inset',
        (tester) async {
      await _pumpCasesScreen(tester);

      final title = find.text('nav_cases'.tr);
      expect(title, findsOneWidget);

      final topLeft = tester.getTopLeft(title);
      expect(topLeft.dy, greaterThanOrEqualTo(_topInset),
          reason: 'the Dossiers title must not be drawn under the notch');
      // The shell paints its floating hamburger (48px + 4px margin) over the
      // top-left corner of every tab.
      expect(topLeft.dx, greaterThanOrEqualTo(52),
          reason: 'the title must stay clear of the shell hamburger');
    });

    testWidgets('list reserves the floating chrome band at the bottom',
        (tester) async {
      await _pumpCasesScreen(tester);

      final spacer = find.byType(KpbShellBottomSpacer);
      expect(spacer, findsOneWidget);

      final height = tester.getSize(spacer).height;
      expect(
        height,
        greaterThanOrEqualTo(KpbShellChrome.coachPillBottom +
            KpbShellChrome.coachPillHeight +
            _bottomInset),
        reason: 'the last card must clear the nav bar AND the copilot pill',
      );
    });
  });

  group('KpbShellChrome', () {
    testWidgets('bottomReserve grows with the device safe-area inset',
        (tester) async {
      late double reserve;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            padding: EdgeInsets.only(bottom: _bottomInset),
          ),
          child: Builder(
            builder: (context) {
              reserve = KpbShellChrome.bottomReserve(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(
        reserve,
        KpbShellChrome.coachPillBottom +
            KpbShellChrome.coachPillHeight +
            KpbShellChrome.contentGap +
            _bottomInset,
      );
    });
  });
}

Future<void> _pumpCasesScreen(WidgetTester tester) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupPlatformChannelMocks();

  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    cases: <StudentCase>[_buildCase()],
  );

  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  controller
    ..isSyncing = false
    ..syncError = null;
  Get.put<AppController>(controller, permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.buildTheme(),
      debugShowCheckedModeBanner: false,
      // Simulate a notched device: the shell keeps the system insets for its
      // tabs (its Scaffold has neither appBar nor bottomNavigationBar), so the
      // screen itself has to honour them.
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: const EdgeInsets.only(
              top: _topInset,
              bottom: _bottomInset,
            ),
          ),
          child: const Scaffold(body: CasesScreen()),
        ),
      ),
    ),
  );
  await tester.pump();
}

StudentCase _buildCase() {
  final now = DateTime(2026, 1, 20);
  return StudentCase(
    id: 'case-1',
    referenceCode: 'KPB-001',
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
