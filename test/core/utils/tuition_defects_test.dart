// L'INVENTAIRE DES PRIX FAUX — CE FICHIER EST ROUGE, ET C'EST SA RAISON D'ÊTRE.
//
// Il affirme le comportement CORRECT. Le code d'aujourd'hui ne l'a pas, donc il
// échoue, et chaque échec nomme une étiquette réelle de production, la valeur
// mensongère affichée, et le nombre d'étudiants concernés. C'est la preuve
// d'aptitude à échouer exigée par le lot 5 : un test de prix qui passerait du
// premier coup serait le test qu'il faut corriger, pas le code.
//
// Il porte le tag `known-defect` : il est donc HORS du portillon de fusion
// (flutter-ci.yml exclut `golden || known-defect`) mais exécuté juste après, dans
// une étape informative qui écrit son bilan dans le résumé du run sans bloquer.
// Le cliquet qui garde la CI honnête, lui, est dans tuition_utils_test.dart, et
// il est vert.
//
// Pour le lire :
//     flutter test --tags=known-defect test/core/utils/tuition_defects_test.dart
//
// QUAND LE LOT 6 AURA CORRIGÉ TUI-T1, CE FICHIER PASSE AU VERT. Retirez alors
// son tag et abaissez les budgets de tuition_defect_budget.dart à zéro — le
// second test de tuition_utils_test.dart refusera de vous laisser oublier.
//
// AUCUNE ASSERTION ICI NE DÉPEND D'UN TAUX DE CHANGE. Choisir les taux est le
// travail du lot 6 et exige une source datée. On se contente de ce qui est vrai
// sans taux : un dirham multiplié par la parité de l'EURO est faux quel que soit
// le vrai cours du dirham ; un franc CFA n'a pas à être converti en franc CFA ;
// une fourchette n'est pas un point ; un coût total n'est pas un coût annuel.
@Tags(['known-defect'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/tuition_utils.dart';

import 'tuition_defect_budget.dart';
import 'tuition_fixture.dart';

/// Un vecteur nommé : une étiquette réelle, d'où elle vient, et ce que le code
/// affiche aujourd'hui à sa place.
class _Vector {
  const _Vector(this.label, {required this.origin, required this.programs});

  final String label;

  /// `prod` = servie par l'API de production le 14/08/2026 ;
  /// `mock` = présente uniquement dans mock_catalog (le jeu de repli, qui reste
  /// du code atteignable — c'est lui qui s'affiche quand l'API ne répond pas).
  final String origin;

  /// Nombre de programmes de production portant cette étiquette (0 pour `mock`).
  final int programs;
}

/// Les treize étiquettes de production + les deux formes que seul mock_catalog
/// porte. Elles couvrent les quatre causes racines.
const _vectors = <_Vector>[
  _Vector('MAD 35,000/an', origin: 'prod', programs: 3),
  _Vector('MAD 45,000/an', origin: 'prod', programs: 7),
  _Vector('40 000 AED/an', origin: 'prod', programs: 7),
  _Vector('8 000 - 18 500 AED', origin: 'prod', programs: 1),
  _Vector('CAD 12 000/an (indicatif)', origin: 'prod', programs: 3),
  _Vector('GBP 12 000/an', origin: 'prod', programs: 4),
  _Vector('USD 18,000/an (approx.)', origin: 'prod', programs: 3),
  _Vector('XOF 1 150 000/an (est.)', origin: 'prod', programs: 1),
  _Vector('12 990 €/an', origin: 'prod', programs: 31),
  _Vector('EUR 9 000/an', origin: 'prod', programs: 8),
  _Vector('11 490 € – 11 690 €/an selon le campus',
      origin: 'prod', programs: 10),
  _Vector('30 000 € (programme)', origin: 'prod', programs: 1),
  _Vector('Sur demande', origin: 'prod', programs: 3),
  // lib/app/core/data/mock_catalog/programs/france.dart:794 — le point sert de
  // séparateur de milliers, le parseur lit « 9 ».
  _Vector('9.850 EUR/an', origin: 'mock', programs: 0),
  // lib/app/core/data/mock_catalog/countries_data.dart:51 — abréviation « k »,
  // le parseur lit « 15 ».
  _Vector('USD 15k–45k/an', origin: 'mock', programs: 0),
];

/// Ce que la devise déclarée impose, sans jamais avoir besoin de son cours.
void _expectHonest(_Vector vector) {
  final label = vector.label;
  final displayed = TuitionUtils.displayFromTuition(label, 'XOF');
  final cause = classifyTuition(label);
  final forbidden = euroTreatedFcfa(label);
  final where = vector.origin == 'prod'
      ? '${vector.programs} programme(s) de production'
      : 'mock_catalog (jeu de repli)';

  switch (cause) {
    case TuitionCause.noAmountExpected:
      expect(displayed, isEmpty,
          reason: '« $label » ne porte aucun montant : en afficher un serait '
              'inventer un prix.');

    case TuitionCause.euroCorrect:
      // Le cas sain : on le fige pour qu'un correctif de devises ne le casse pas.
      expect(displayed, '~ $forbidden FCFA/an',
          reason: '« $label » est en euros : la parité BCEAO 655,957 est la '
              'bonne opération. Ce cas doit rester juste. ($where)');

    case TuitionCause.cfaReconverted:
      final ownAmount = groupThousands(naiveFirstAmount(label)!);
      expect(displayed, isNot(contains(forbidden!)),
          reason: '« $label » est DÉJÀ en francs CFA. Affiché : « $displayed » '
              '— soit 656 fois le prix réel, sur $where. Un franc CFA ne se '
              'convertit pas en franc CFA.');
      expect(displayed, contains(ownAmount),
          reason: '« $label » doit afficher son propre montant '
              '($ownAmount FCFA), pas un produit.');

    case TuitionCause.foreignTreatedAsEuro:
      expect(displayed, isNot(contains(forbidden!)),
          reason: '« $label » est libellée en ${declaredCurrency(label)}, pas '
              'en euros. Affiché : « $displayed » — le premier nombre multiplié '
              'par la parité de l\'EURO (655,957), sur $where. Faux quel que '
              'soit le vrai cours de la devise.');

    case TuitionCause.notASingleAmount:
      final amounts = tuitionAmountsIn(label);
      expect(displayed, isNot(contains(forbidden!)),
          reason: '« $label » ne porte pas UN montant annuel mais '
              '${amounts.length} (${amounts.join(' / ')}). Affiché : '
              '« $displayed » — la borne basse présentée comme LE prix, sur '
              '$where. Attendu : aucun montant, ou la fourchette entière.');

    case TuitionCause.totalShownAsAnnual:
      expect(displayed, isNot(endsWith('/an')),
          reason: '« $label » est un coût TOTAL de programme. Affiché : '
              '« $displayed » — suffixé « /an », donc divisé par la durée dans '
              "la tête de l'étudiant, sur $where.");
  }
}

void main() {
  group('vecteurs nommés — étiquettes réelles, une par une', () {
    for (final vector in _vectors) {
      final cause = classifyTuition(vector.label);
      final tag = tuitionDefectCauses.contains(cause) ? 'FAUX' : 'juste';
      test(
          '[$tag/${cause.name}] ${vector.label.isEmpty ? '(vide)' : vector.label}',
          () => _expectHonest(vector));
    }
  });

  group('le catalogue de production entier, par cause racine', () {
    final records = loadTuitionFixture();
    final byCause = <TuitionCause, List<TuitionRecord>>{};
    for (final record in records) {
      byCause.putIfAbsent(classifyTuition(record.label), () => []).add(record);
    }

    for (final cause in tuitionDefectCauses) {
      final affected = byCause[cause] ?? const <TuitionRecord>[];
      final programs = affected.fold(0, (sum, r) => sum + r.programCount);
      test(
          '${cause.name} — ${affected.length} étiquettes, '
          '$programs programmes', () {
        final failures = <String>[];
        for (final record in affected) {
          final displayed =
              TuitionUtils.displayFromTuition(record.label, 'XOF');
          final forbidden = euroTreatedFcfa(record.label);
          if (forbidden != null && displayed.contains(forbidden)) {
            failures.add('  ${record.programCount}× « ${record.label} » '
                '→ « $displayed »');
          }
        }
        expect(
          failures,
          isEmpty,
          reason: '${failures.length} étiquettes affichent le premier nombre '
              'multiplié par la parité de l\'EURO ($programs programmes '
              'concernés).\n${failures.join('\n')}',
        );
      });
    }

    test('bilan : 272 des 582 programmes affichent un prix faux', () {
      final wrong = tuitionDefectCauses.fold<int>(
        0,
        (sum, cause) =>
            sum +
            (byCause[cause] ?? const <TuitionRecord>[])
                .fold(0, (s, r) => s + r.programCount),
      );
      expect(
        wrong,
        0,
        reason:
            '$wrong programmes sur $tuitionFixtureProgramCount affichent un '
            'coût faux. Répartition : '
            '${tuitionDefectCauses.map((c) => '${c.name}='
                '${(byCause[c] ?? const <TuitionRecord>[]).fold(0, (s, r) => s + r.programCount)}').join(', ')}.',
      );
    });
  });
}
