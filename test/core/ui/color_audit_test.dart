// Ratchet des couleurs en dur (docs/fable-global-theme-architecture.md §11.1).
//
// Règle : app_tokens.dart est le SEUL fichier autorisé à définir des
// hexadécimaux. Chaque fichier existant a un budget figé dans
// color_budget.dart ; les lots de migration ABAISSENT les budgets (jamais
// l'inverse) jusqu'à 0. Un fichier hors budget ne peut pas introduire de
// `Color(0x…)`.
//
// Échappatoire documentée : suffixer la ligne d'un commentaire
// `// kpb-allow-color: <raison>` ET inscrire le cas dans l'allowlist
// (docs/theme-color-allowlist.md). Réservé aux exceptions du §10.4
// (marques externes, surfaces immersives).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'color_budget.dart';

final _colorHex = RegExp(r'Color\(0x');

Map<String, int> _scanLib() {
  final counts = <String, int>{};
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final rel = file.path.replaceAll('\\', '/');
    var count = 0;
    for (final line in file.readAsLinesSync()) {
      if (line.contains('kpb-allow-color')) continue;
      count += _colorHex.allMatches(line).length;
    }
    if (count > 0) counts[rel] = count;
  }
  return counts;
}

void main() {
  final actual = _scanLib();

  test('aucune nouvelle couleur en dur au-dessus du budget', () {
    final violations = <String>[];
    actual.forEach((file, count) {
      final budget = colorBudget[file] ?? 0;
      if (count > budget) {
        violations.add('  $file : $count hex (budget $budget)');
      }
    });
    expect(
      violations,
      isEmpty,
      reason: 'Couleur(s) en dur introduite(s) hors budget — utilise un rôle '
          'de KpbColors (docs/fable-global-theme-architecture.md §6) ou, cas '
          'exceptionnel documenté, `// kpb-allow-color: raison` + allowlist.\n'
          '${violations.join('\n')}',
    );
  });

  test('les budgets ne peuvent que décroître (ratchet honnête)', () {
    final stale = <String>[];
    colorBudget.forEach((file, budget) {
      final count = actual[file] ?? 0;
      if (count < budget) {
        stale.add('  $file : budget $budget mais $count hex réels '
            '→ abaisse le budget à $count');
      }
    });
    expect(
      stale,
      isEmpty,
      reason: 'Migration détectée : verrouille le progrès en abaissant les '
          'budgets dans test/core/ui/color_budget.dart.\n${stale.join('\n')}',
    );
  });

  test('L1/L2 (app_theme, kpb_theme_ext) : zéro hexadécimal', () {
    expect(actual['lib/app/core/ui/app_theme.dart'], isNull,
        reason: 'app_theme.dart doit dériver intégralement des tokens.');
    expect(actual['lib/app/core/ui/kpb_theme_ext.dart'], isNull,
        reason: 'kpb_theme_ext.dart doit lire les tokens, jamais en définir.');
  });
}
