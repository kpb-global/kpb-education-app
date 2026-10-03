// Le méta-test de `test/support/chip_paint.dart` : la mesure de puce sait-elle
// ÉCHOUER ?
//
// Un test de contraste qui ne peut pas rougir ne prouve rien. Les tests de
// catalogue et de feuille d'intérêt passent AU VERT une fois le défaut corrigé ;
// rien, dans leur vert, ne dit que la mesure aurait vu le défaut d'origine. Ici
// on le fabrique exprès — le `Text` à couleur fixe sur une puce cochée — et on
// exige que la mesure le voie, sous le vrai thème.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';

import '../../support/chip_paint.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget chip, {
  ThemeMode mode = ThemeMode.light,
  double? width,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.buildTheme(),
      darkTheme: AppTheme.buildDarkTheme(),
      themeMode: mode,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, child: chip),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('contrastRatio : noir sur blanc = 21, identique = 1', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.white, Colors.white), closeTo(1, 0.001));
  });

  testWidgets('VOIT un libellé à couleur fixe sur une puce cochée',
      (tester) async {
    await _pump(
      tester,
      FilterChip(
        selected: true,
        onSelected: (_) {},
        // Le défaut d'origine, à l'identique.
        label: Text('DAP dossier jaune · 29', style: KpbTextStyles.caption),
      ),
    );

    final chip = paintedChips(tester).single;
    expect(chip.selected, isTrue);
    expect(chip.contrast, lessThan(1.2), reason: chip.toString());
    expect(
      () => expectChipsReadable(tester, selected: 1),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('VOIT le même défaut au repos, en clair comme en sombre',
      (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await _pump(
        tester,
        FilterChip(
          selected: false,
          onSelected: (_) {},
          label: Text('Master · 4210', style: KpbTextStyles.caption),
        ),
        mode: mode,
      );
      expect(
        () => expectChipsReadable(tester, selected: 0),
        throwsA(isA<TestFailure>()),
        reason:
            'textMuted ne tient pas 4,5:1 sur le fond de repos (${mode.name})',
      );
    }
  });

  testWidgets('LAISSE PASSER une puce qui hérite du thème', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final selected in [false, true]) {
        await _pump(
          tester,
          FilterChip(
            selected: selected,
            onSelected: (_) {},
            // La correction : la taille seule, la couleur vient du chipTheme.
            label: const Text(
              'DAP dossier jaune · 29',
              style: TextStyle(fontSize: 12),
            ),
          ),
          mode: mode,
        );
        expectChipsReadable(tester, selected: selected ? 1 : 0);
      }
    }
  });

  testWidgets('exige que des puces soient cochées quand on le demande',
      (tester) async {
    await _pump(
      tester,
      FilterChip(
        selected: false,
        onSelected: (_) {},
        label: const Text('Master', style: TextStyle(fontSize: 12)),
      ),
    );
    // Aucune puce cochée alors que le test en attend une : c'est un test à
    // vide, et il doit rougir plutôt que mesurer le seul état de repos.
    expect(
      () => expectChipsReadable(tester, selected: 1),
      throwsA(isA<TestFailure>()),
    );
  });

  testWidgets('clippedChipLabels VOIT un libellé rogné', (tester) async {
    await _pump(
      tester,
      FilterChip(
        selected: true,
        onSelected: (_) {},
        label: const Text(
          'Informatique & Intelligence Artificielle · 1234',
          style: TextStyle(fontSize: 12),
        ),
      ),
      width: 90,
    );
    expect(clippedChipLabels(tester), isNotEmpty);
  });

  testWidgets('clippedChipLabels laisse passer un libellé entier',
      (tester) async {
    await _pump(
      tester,
      FilterChip(
        selected: true,
        onSelected: (_) {},
        label: const Text('Master · 4210', style: TextStyle(fontSize: 12)),
      ),
    );
    expect(clippedChipLabels(tester), isEmpty);
  });
}
