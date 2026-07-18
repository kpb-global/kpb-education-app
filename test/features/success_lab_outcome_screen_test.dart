import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/controllers/success_lab_outcome_controller.dart';
import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/repositories/success_lab_repository.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/kpb_button.dart';
import 'package:karatou/app/features/success_lab/success_lab_outcome_screen.dart';

class _MockRepository extends Mock implements SuccessLabRepository {}

void main() {
  testWidgets('admission CTA reacts to issuer input at 200% text',
      (tester) async {
    final repository = _MockRepository();
    final controller = SuccessLabOutcomeController(
      repository: repository,
      workspaceId: 'workspace-1',
    )
      ..phase = SuccessLabOutcomePhase.ready
      ..history = const SuccessLabDecisionHistory(
        admissions: <SuccessLabAdmissionDecisionRecord>[],
        funding: <SuccessLabFundingDecisionRecord>[],
        workspaceVersion: 3,
      )
      ..consentNotice = const SuccessLabAiNotice(
        version: 'outcome-evidence-v1',
        languageCode: 'fr',
        title: 'Preuves privées',
        body: 'Notice',
        contentHash: 'hash',
      );
    controller
      ..setConsentAccepted(true)
      ..selectAdmissionEvidence(
        path: '/tmp/decision.pdf',
        name: 'decision.pdf',
      );
    addTearDown(controller.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SuccessLabOutcomeScreen(
            workspaceId: 'workspace-1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final issuer = find.byKey(
      const ValueKey<String>('success-lab-admission-issuer'),
    );
    await tester.scrollUntilVisible(
      issuer,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(issuer, 'Example University');
    await tester.pump();

    final action = find.byKey(
      const ValueKey<String>('success-lab-declare-admission'),
    );
    await tester.scrollUntilVisible(
      action,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.widget<KpbButton>(action).onPressed, isNotNull);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
  });
}
