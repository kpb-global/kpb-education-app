import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/models/success_lab.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/success_lab/widgets/success_lab_outcome_widgets.dart';

void main() {
  testWidgets('outcome consent remains usable at 200% text', (tester) async {
    var accepted = false;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => SuccessLabOutcomeConsentCard(
                  notice: const SuccessLabAiNotice(
                    version: 'outcome-evidence-v1',
                    languageCode: 'fr',
                    title: 'Preuves privées',
                    body: 'J’accepte le stockage privé et la vérification KPB.',
                    contentHash: 'notice-hash',
                  ),
                  accepted: accepted,
                  onChanged: (value) => setState(() => accepted = value),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final checkbox = find.byKey(
      const ValueKey<String>('success-lab-outcome-consent'),
    );
    expect(checkbox, findsOneWidget);
    expect(tester.getSize(checkbox).height, greaterThanOrEqualTo(48));
    expect(find.textContaining('ni publication'), findsOneWidget);
    await tester.tap(checkbox);
    await tester.pump();
    expect(accepted, isTrue);
    semantics.dispose();
  });

  testWidgets('verification status is explicit and separate', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en'),
        home: const Scaffold(
          body: Center(
            child: SuccessLabVerificationBadge(
              status: SuccessLabEvidenceVerificationStatus.needsInformation,
            ),
          ),
        ),
      ),
    );

    expect(find.text('More information requested by KPB'), findsOneWidget);
    expect(find.textContaining('admitted'), findsNothing);
    expect(find.textContaining('funding'), findsNothing);
  });
}
