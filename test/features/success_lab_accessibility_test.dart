import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_controller.dart';
import 'package:karatou/app/core/controllers/success_lab_diagnostic_controller.dart';
import 'package:karatou/app/core/controllers/success_lab_list_controller.dart';
import 'package:karatou/app/core/controllers/success_lab_submission_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/success_lab/success_lab_diagnostic_screen.dart';
import 'package:karatou/app/features/success_lab/success_lab_list_screen.dart';
import 'package:karatou/app/features/success_lab/success_lab_submission_screen.dart';
import 'package:karatou/app/features/success_lab/success_lab_workspace_screen.dart';
import 'package:karatou/app/features/success_lab/widgets/success_lab_accessibility.dart';

class _MockRepository extends Mock implements SuccessLabRepository {}

void main() {
  tearDown(Get.reset);

  test('Success Lab translations have complete non-empty FR/EN parity', () {
    final translations = AppTranslations().keys;
    final french = translations['fr']!;
    final english = translations['en']!;
    final frenchKeys =
        french.keys.where((key) => key.startsWith('success_lab_')).toSet();
    final englishKeys =
        english.keys.where((key) => key.startsWith('success_lab_')).toSet();

    expect(englishKeys, frenchKeys);
    for (final key in frenchKeys) {
      expect(french[key]?.trim(), isNotEmpty, reason: 'French: $key');
      expect(english[key]?.trim(), isNotEmpty, reason: 'English: $key');
    }
  });

  testWidgets(
      'accessible body scrolls at 200% and announces offline then recovery',
      (tester) async {
    await _setSmallSurface(tester, const Size(320, 480));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _testApp(
        SuccessLabAccessibleBody(
          networkState: SuccessLabNetworkUiState.offline,
          busyLabel: 'Chargement',
          ensureScrollable: true,
          child: const SizedBox(height: 900),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('success-lab-state-scroll')),
      findsOneWidget,
    );
    var announcement = tester.getSemantics(
      find.byKey(
        const ValueKey<String>('success-lab-network-announcement'),
      ),
    );
    expect(announcement.label, contains('Hors ligne'));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      _testApp(
        SuccessLabAccessibleBody(
          networkState: SuccessLabNetworkUiState.busy,
          busyLabel: 'Chargement',
          ensureScrollable: true,
          child: const SizedBox(height: 900),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(
      _testApp(
        SuccessLabAccessibleBody(
          networkState: SuccessLabNetworkUiState.stable,
          busyLabel: 'Chargement',
          ensureScrollable: true,
          child: const SizedBox(height: 900),
        ),
      ),
    );
    await tester.pump();

    announcement = tester.getSemantics(
      find.byKey(
        const ValueKey<String>('success-lab-network-announcement'),
      ),
    );
    expect(announcement.label, contains('Connexion rétablie'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('workspace list card remains readable at 200% on 320px',
      (tester) async {
    final repository = _MockRepository();
    when(repository.readCachedAccess).thenAnswer((_) async => null);
    when(() => repository.readCachedPage(status: null))
        .thenAnswer((_) async => null);
    when(() => repository.canUseNetwork).thenReturn(true);
    when(repository.fetchAccess).thenAnswer(
      (_) async => const SuccessLabAccess(enabled: true),
    );
    when(() => repository.fetchPage(status: null, limit: 20)).thenAnswer(
      (_) async => SuccessLabWorkspacePage(items: <SuccessLabWorkspace>[
        _workspace(),
      ]),
    );
    final controller = SuccessLabListController(repository: repository);
    await controller.loadInitial();
    addTearDown(controller.dispose);
    await _setSmallSurface(tester, const Size(320, 640));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _testApp(
        SuccessLabListScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('UWC Afrique'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('UWC Afrique.*42%')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('workspace progress stacks without overflow at 200% text',
      (tester) async {
    final controller = SuccessLabController(
      repository: _MockRepository(),
      workspaceId: 'workspace-1',
    )
      ..phase = LabLoadPhase.ready
      ..workspace = _workspace()
      ..access = const SuccessLabAccess(enabled: true);
    addTearDown(controller.dispose);
    await _setSmallSurface(tester, const Size(320, 640));

    await tester.pumpWidget(
      _testApp(
        SuccessLabWorkspaceScreen(
          workspaceId: 'workspace-1',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('success-lab-progress')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('diagnostic CTA is at least 48px and usable at 200% text',
      (tester) async {
    final controller = SuccessLabDiagnosticController(
      repository: _MockRepository(),
      workspaceId: 'workspace-1',
      language: 'fr',
    )..phase = SuccessLabDiagnosticPhase.ready;
    addTearDown(controller.dispose);
    await _setSmallSurface(tester, const Size(320, 640));

    await tester.pumpWidget(
      _testApp(
        SuccessLabDiagnosticScreen(
          workspaceId: 'workspace-1',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(
      const ValueKey<String>('success-lab-run-diagnostic'),
    );
    await tester.scrollUntilVisible(
      action,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('submission CTA is at least 48px at 200% on a small screen',
      (tester) async {
    final controller = SuccessLabSubmissionController(
      repository: _MockRepository(),
      workspaceId: 'workspace-1',
    )
      ..phase = SuccessLabSubmissionPhase.ready
      ..consentNotice = const SuccessLabAiNotice(
        version: 'outcome-evidence-v1',
        languageCode: 'fr',
        title: 'Preuves privées',
        body: 'Notice de confidentialité',
        contentHash: 'notice-hash',
      );
    addTearDown(controller.dispose);
    await _setSmallSurface(tester, const Size(320, 640));

    await tester.pumpWidget(
      _testApp(
        SuccessLabSubmissionScreen(
          workspaceId: 'workspace-1',
          controller: controller,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byKey(
      const ValueKey<String>('success-lab-declare-submission'),
    );
    await tester.scrollUntilVisible(
      action,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget child) {
  return GetMaterialApp(
    translations: AppTranslations(),
    locale: const Locale('fr'),
    home: MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(2)),
      child: Scaffold(body: child),
    ),
  );
}

Future<void> _setSmallSurface(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

SuccessLabWorkspace _workspace() => SuccessLabWorkspace(
      schemaVersion: successLabWorkspaceSchemaVersionV1,
      id: 'workspace-1',
      scholarshipId: 'scholarship-1',
      scholarshipCycleId: 'cycle-1',
      status: SuccessLabWorkspaceStatus.preparing,
      statusWireValue: 'preparing',
      version: 2,
      readinessPercent: 42,
      scholarship: const SuccessLabScholarshipSummary(
        id: 'scholarship-1',
        name: 'UWC Afrique — programme international',
        countryName: 'Plusieurs pays africains',
      ),
      cycle: SuccessLabCycleSummary(
        id: 'cycle-1',
        status: SuccessLabCycleStatus.open,
        statusWireValue: 'open',
        dateConfidence: SuccessLabDateConfidence.confirmed,
        dateConfidenceWireValue: 'confirmed',
        closesAt: DateTime.utc(2026, 10, 31),
      ),
      nextAction: const SuccessLabNextAction(
        code: 'complete_profile',
        label: 'Compléter les critères du profil et vérifier les documents',
      ),
      steps: const <SuccessLabWorkspaceStep>[
        SuccessLabWorkspaceStep(
          id: 'step-1',
          code: 'profile',
          titleFr: 'Vérifier les critères d’éligibilité du profil',
          titleEn: 'Check profile eligibility criteria',
          category: SuccessLabWorkspaceStepCategory.profileEligibility,
          categoryWireValue: 'profile_eligibility',
          weight: 25,
          isRequired: true,
          templateVersion: 'v1',
          status: SuccessLabWorkspaceStepStatus.inProgress,
          statusWireValue: 'in_progress',
        ),
      ],
    );
