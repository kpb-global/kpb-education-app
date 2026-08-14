// Cliquet des prix affichés — exécuté par la CI, VERT aujourd'hui.
//
// Il ne demande pas que les prix soient justes : ils ne le sont pas, et les
// corriger est le lot 6 (qui doit d'abord choisir une source de taux). Il demande
// que l'ampleur du défaut soit ÉCRITE, MESURÉE sur les vraies données, et
// incapable de bouger en silence — dans un sens comme dans l'autre.
//
// Le rouge, celui qui nomme chaque prix faux, vit dans tuition_defects_test.dart
// (tagué `known-defect`, hors portillon de fusion, exécuté par
// .github/workflows/catalog-freshness.yml et à la main).
//
// Les six assertions, dans l'ordre où elles se défendent :
//   1. la fixture décrit bien la production (7 devises, 146 étiquettes,
//      582 programmes, une seule devise par étiquette) — sinon tout le reste
//      mesure autre chose ;
//   2. le formateur de référence de ce test est calibré sur trois littéraux
//      figés — sinon la « valeur interdite » qu'il calcule serait fausse ;
//   3. aucune cause ne dépasse son budget ;
//   4. les budgets ne peuvent que décroître ;
//   5. les prix JUSTES d'aujourd'hui le restent (305 programmes en euros) ;
//   6. une étiquette sans chiffre n'affiche aucun montant.

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/currency_utils.dart';
import 'package:karatou/app/core/utils/tuition_utils.dart';

import 'tuition_defect_budget.dart';
import 'tuition_fixture.dart';

void main() {
  final records = loadTuitionFixture();

  final byCause = <TuitionCause, List<TuitionRecord>>{};
  for (final record in records) {
    byCause.putIfAbsent(classifyTuition(record.label), () => []).add(record);
  }
  int programs(TuitionCause cause) =>
      (byCause[cause] ?? const []).fold(0, (sum, r) => sum + r.programCount);
  int labels(TuitionCause cause) => (byCause[cause] ?? const []).length;

  group('la fixture décrit bien la production', () {
    test('les 7 familles de devises sont présentes', () {
      final present = records
          .map((r) => declaredCurrency(r.label))
          .whereType<String>()
          .toSet();
      expect(
        present,
        containsAll(const ['EUR', 'USD', 'MAD', 'AED', 'CAD', 'GBP', 'XOF']),
        reason: 'Une famille disparue = un pan du défaut plus mesuré. '
            'Familles trouvées : $present',
      );
    });

    test('au moins 140 étiquettes distinctes', () {
      expect(records.length, greaterThanOrEqualTo(140));
      expect(records.length, tuitionFixtureLabelCount,
          reason: 'La fixture a été régénérée : recalculez les budgets de '
              'tuition_defect_budget.dart dans le même commit.');
      expect(records.map((r) => r.label).toSet().length, records.length,
          reason: 'Étiquette dupliquée dans la fixture.');
    });

    test('582 programmes de production couverts', () {
      final total = records.fold(0, (sum, r) => sum + r.programCount);
      expect(total, tuitionFixtureProgramCount);
    });

    test('au moins 40 % des étiquettes produisent un montant', () {
      // Sans cette garde, un parseur qui rendrait `null` partout ferait passer
      // toutes les assertions « le montant affiché est faux » : plus de montant,
      // plus de faute. Le harnais serait devenu aveugle en restant vert.
      final yielding = records
          .where(
              (r) => TuitionUtils.displayFromTuition(r.label, 'XOF').isNotEmpty)
          .length;
      expect(
        yielding / records.length,
        greaterThanOrEqualTo(0.40),
        reason: 'Seules $yielding/${records.length} étiquettes produisent un '
            'montant : le parseur rend du vide, donc ce test ne prouve plus '
            "rien. Ce n'est pas un progrès, c'est un aveuglement.",
      );
    });

    test('une seule devise déclarée par étiquette', () {
      // La classification par cause suppose cette propriété ; si une étiquette
      // portait « EUR » et « USD », son budget serait arbitraire.
      final ambiguous = <String>[];
      for (final record in records) {
        final hits = const ['EUR', 'MAD', 'AED', 'CAD', 'GBP', 'USD', 'XOF']
            .where(record.label.contains)
            .toList();
        if (record.label.contains('€') && !hits.contains('EUR')) {
          hits.add('EUR');
        }
        if (hits.length > 1) ambiguous.add('${record.label} → $hits');
      }
      expect(ambiguous, isEmpty);
    });
  });

  group('le formateur de référence de ce test est calibré', () {
    test('groupThousands reproduit le regroupement de CurrencyUtils', () {
      // Trois littéraux figés : si `_group` change d'espace (fine insécable au
      // lieu d'ordinaire), ce test le dit AVANT que les assertions « valeur
      // interdite » ne deviennent silencieusement inoffensives.
      expect(groupThousands(22958495), '22 958 495');
      expect(groupThousands(5904), '5 904');
      expect(groupThousands(754350550), '754 350 550');

      // Et la calibration croisée contre le vrai code, pour trois montants.
      for (final eur in const [9, 12990, 1150000]) {
        expect(
          CurrencyUtils.formatEur(eur, 'XOF', approximate: true),
          '~ ${groupThousands((eur * CurrencyUtils.xofPerEur).round())} FCFA/an',
        );
      }
    });
  });

  group('cliquet des prix faux', () {
    test('aucune cause ne dépasse son budget', () {
      final violations = <String>[];
      for (final cause in tuitionDefectCauses) {
        final labelBudget = tuitionLabelBudget[cause] ?? 0;
        final programBudget = tuitionProgramBudget[cause] ?? 0;
        if (labels(cause) > labelBudget) {
          violations.add('  ${cause.name} : ${labels(cause)} étiquettes '
              '(budget $labelBudget)');
        }
        if (programs(cause) > programBudget) {
          violations.add('  ${cause.name} : ${programs(cause)} programmes '
              '(budget $programBudget)');
        }
      }
      expect(
        violations,
        isEmpty,
        reason: 'De nouveaux prix faux sont apparus. Corrigez la donnée ou le '
            'code — ne relevez PAS le budget.\n${violations.join('\n')}',
      );
    });

    test('les budgets ne peuvent que décroître (cliquet honnête)', () {
      final stale = <String>[];
      tuitionLabelBudget.forEach((cause, budget) {
        final actual = labels(cause);
        if (actual < budget) {
          stale.add('  tuitionLabelBudget[${cause.name}] : $budget déclaré, '
              '$actual réel → abaissez-le à $actual');
        }
      });
      tuitionProgramBudget.forEach((cause, budget) {
        final actual = programs(cause);
        if (actual < budget) {
          stale.add('  tuitionProgramBudget[${cause.name}] : $budget déclaré, '
              '$actual réel → abaissez-le à $actual');
        }
      });
      expect(
        stale,
        isEmpty,
        reason:
            'Progrès détecté : verrouillez-le en abaissant les budgets dans '
            'test/core/utils/tuition_defect_budget.dart. Si un budget tombe à 0, '
            "retirez aussi le tag `known-defect` du cas correspondant dans "
            'tuition_defects_test.dart.\n${stale.join('\n')}',
      );
    });
  });

  group("ce qui est juste aujourd'hui doit le rester", () {
    test('les 305 programmes en euros affichent la parité BCEAO exacte', () {
      final wrong = <String>[];
      for (final record in byCause[TuitionCause.euroCorrect] ?? const []) {
        final amount = naiveFirstAmount(record.label)!;
        final expected =
            '~ ${groupThousands((amount * CurrencyUtils.xofPerEur).round())} '
            'FCFA/an';
        final actual = TuitionUtils.displayFromTuition(record.label, 'XOF');
        if (actual != expected) {
          wrong.add('  ${record.label} → « $actual » (attendu « $expected »)');
        }
      }
      expect(
        wrong,
        isEmpty,
        reason: 'Le seul cas que le code traite juste vient de casser. Un '
            'correctif de devises ne doit pas dégrader les euros.\n'
            '${wrong.join('\n')}',
      );
      expect(
          programs(TuitionCause.euroCorrect) +
              programs(TuitionCause.noAmountExpected),
          tuitionCorrectProgramCount);
    });

    test("une étiquette sans chiffre n'affiche aucun montant", () {
      for (final record in byCause[TuitionCause.noAmountExpected] ?? const []) {
        expect(
          TuitionUtils.displayFromTuition(record.label, 'XOF'),
          isEmpty,
          reason: '« ${record.label} » ne contient aucun montant : en inventer '
              'un serait pire que de ne rien afficher.',
        );
      }
      // « Sur demande » contient des espaces : `[\d\s]+` y trouve une
      // correspondance (l'espace), et seul le `int.tryParse('')` qui suit évite
      // d'afficher un montant. La garde est donc fragile par construction — d'où
      // ce test explicite.
      expect(TuitionUtils.displayFromTuition('Sur demande', 'XOF'), isEmpty);
      expect(TuitionUtils.displayFromTuition('', 'XOF'), isEmpty);
    });
  });
}
