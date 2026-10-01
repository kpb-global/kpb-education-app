// Régression — puce de ville sélectionnée sans libellé (Logement étudiant).
//
// Capture iPhone du 25/09/2026 : onglet France, la première puce (Paris)
// sélectionnée n'affichait que la coche. Cause : le chipTheme global définit
// `color` (actionPrimary à l'état sélectionné), et RawChip le fait passer
// AVANT le `selectedColor` de la puce. Le libellé actionPrimary était donc
// peint sur un fond actionPrimary. Le texte « Paris » existait bien dans
// l'arbre : seul un test sur les couleurs PEINTES, sous le vrai thème, le voit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/features/housing/housing_estimator_screen.dart';

import '../../support/screen_harness.dart';

/// WCAG relative-luminance contrast ratio.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await initializeDateFormatting('fr');
  });

  tearDown(Get.reset);

  testWidgets('la ville sélectionnée reste lisible sur sa puce',
      (tester) async {
    await seedKpbController();
    await pumpKpbScreen(
      tester,
      screen: const HousingEstimatorScreen(),
      viewport: iphone14,
    );

    final selectedChip = find.byWidgetPredicate(
      (w) => w is ChoiceChip && w.selected,
    );
    expect(selectedChip, findsOneWidget);

    final label = find.descendant(
      of: selectedChip,
      matching: find.text('Paris'),
    );
    expect(label, findsOneWidget);

    // Couleur effectivement appliquée au libellé (DefaultTextStyle posé par
    // RawChip) et fond effectivement peint (Ink de la puce).
    final labelColor = DefaultTextStyle.of(tester.element(label)).style.color!;
    final ink = tester.widget<Ink>(
      find.descendant(of: selectedChip, matching: find.byType(Ink)).first,
    );
    final bg = (ink.decoration! as ShapeDecoration).color!;

    expect(_contrast(labelColor, bg), greaterThanOrEqualTo(4.5),
        reason: 'Libellé $labelColor sur fond $bg : la ville sélectionnée '
            'redevient invisible (seule la coche reste).');
  });
}
