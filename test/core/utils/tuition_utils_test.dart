// LE CLIQUET DES PRIX — il garde à zéro ce que le lot 6 vient de corriger.
//
// Au lot 5, ce fichier chiffrait un défaut : 272 des 582 programmes de production
// affichaient un prix faux, répartis en quatre causes budgétées. Les budgets ne
// pouvaient que décroître, et le fichier disait explicitement quoi faire quand
// ils tomberaient à zéro.
//
// Ils y sont tombés. Ce fichier est donc devenu ce pour quoi il avait été écrit :
// non plus la mesure d'un mensonge, mais l'interdiction de son retour.
//
// Ce qu'il vérifie, sur les 146 étiquettes RÉELLES de la production :
//   1. la fixture décrit toujours bien la production ;
//   2. le formateur de référence est calibré, sinon les valeurs « interdites »
//      qu'il calcule seraient fausses et l'interdiction inoffensive ;
//   3. ZÉRO étiquette n'affiche le premier nombre multiplié par la parité de
//      l'euro — l'ancien défaut, exprimé de la seule façon qui le rende
//      détectable ;
//   4. les 305 programmes en euros gardent leur équivalent exact, parce qu'un
//      correctif qui les aurait emportés serait un recul déguisé en progrès ;
//   5. et les comptes par forme d'étiquette sont figés, pour que la fixture ne
//      puisse pas être régénérée en douce sur des données plus commodes.

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/currency_utils.dart';
import 'package:karatou/app/core/utils/tuition_utils.dart';

import 'tuition_fixture.dart';

/// Les comptes MESURÉS le 14/08/2026 sur les 582 programmes de production.
///
/// Ces nombres ne budgètent plus un défaut : ils décrivent la donnée. S'ils
/// changent, la fixture a été régénérée — ce qui est légitime, mais doit être un
/// geste conscient et non un effet de bord.
const _shapeLabelCount = <TuitionShape, int>{
  TuitionShape.euroSingleAmount: 49,
  TuitionShape.foreignCurrency: 66,
  TuitionShape.alreadyCfa: 18,
  TuitionShape.notASingleAmount: 9,
  TuitionShape.wholeProgrammeCost: 2,
  TuitionShape.noAmount: 2,
};

const _shapeProgramCount = <TuitionShape, int>{
  TuitionShape.euroSingleAmount: 305,
  TuitionShape.foreignCurrency: 177,
  TuitionShape.alreadyCfa: 48,
  TuitionShape.notASingleAmount: 45,
  TuitionShape.wholeProgrammeCost: 2,
  TuitionShape.noAmount: 5,
};

void main() {
  final records = loadTuitionFixture();

  final byShape = <TuitionShape, List<TuitionRecord>>{};
  for (final record in records) {
    byShape.putIfAbsent(classifyTuition(record.label), () => []).add(record);
  }
  int programs(TuitionShape shape) =>
      (byShape[shape] ?? const []).fold(0, (sum, r) => sum + r.programCount);

  group('la fixture décrit bien la production', () {
    test('146 étiquettes, 582 programmes, 7 familles de devises', () {
      expect(records.length, 146);
      expect(records.map((r) => r.label).toSet().length, records.length,
          reason: 'Étiquette dupliquée dans la fixture.');
      expect(records.fold(0, (sum, r) => sum + r.programCount), 582);
      final present = records
          .map((r) => declaredCurrency(r.label))
          .whereType<String>()
          .toSet();
      expect(present,
          containsAll(const ['EUR', 'USD', 'MAD', 'AED', 'CAD', 'GBP', 'XOF']));
    });

    test('les comptes par forme d\'étiquette sont ceux du 14/08/2026', () {
      for (final shape in TuitionShape.values) {
        expect((byShape[shape] ?? const []).length, _shapeLabelCount[shape],
            reason:
                'Forme ${shape.name} : le nombre d\'étiquettes a changé. Si '
                'la fixture a été régénérée, mettez _shapeLabelCount à jour dans '
                'le même commit — et relisez les assertions qui en dépendent.');
        expect(programs(shape), _shapeProgramCount[shape],
            reason: 'Forme ${shape.name} : le nombre de programmes a changé.');
      }
    });
  });

  group('le formateur de référence de ce test est calibré', () {
    test('groupThousands reproduit le regroupement de CurrencyUtils', () {
      // Trois littéraux figés : si `group` change d'espace (fine insécable au
      // lieu d'ordinaire), ce test le dit AVANT que les assertions « valeur
      // interdite » ne deviennent silencieusement inoffensives.
      expect(groupThousands(22958495), '22 958 495');
      expect(groupThousands(5904), '5 904');
      expect(groupThousands(754350550), '754 350 550');
      for (final eur in const [9, 12990, 1150000]) {
        expect(
          CurrencyUtils.group((eur * CurrencyUtils.xofPerEur).round()),
          groupThousands((eur * CurrencyUtils.xofPerEur).round()),
        );
      }
    });
  });

  group('le cliquet : aucun prix faux ne revient', () {
    test('zéro étiquette n\'affiche le premier nombre traité comme des euros',
        () {
      // L'ancien défaut, formulé de la seule façon qui le rende détectable : la
      // valeur mensongère est calculable pour CHAQUE étiquette, et aucune ne doit
      // l'afficher — sauf celles qui sont réellement en euros, où ce calcul EST
      // le bon.
      final leaks = <String>[];
      var checked = 0;
      for (final record in records) {
        // Sur une étiquette EN EUROS, « le premier nombre multiplié par la
        // parité de l'euro » n'est pas la valeur mensongère : c'est la valeur
        // JUSTE. L'interdiction n'a de sens que pour les autres devises — et
        // pour les étiquettes qui n'en déclarent aucune, où l'ancien code
        // supposait l'euro.
        if (declaredCurrency(record.label) == 'EUR') continue;
        final forbidden = euroTreatedFcfa(record.label);
        if (forbidden == null) continue;
        checked++;
        final shown = TuitionUtils.tuitionForDisplay(record.label, 'XOF');
        if (shown.contains(forbidden)) {
          leaks
              .add('  ${record.programCount}× « ${record.label} » → « $shown » '
                  '(contient $forbidden)');
        }
      }
      // Garde d'aveuglement. 146 étiquettes − 58 qui déclarent l'euro − 2 sans
      // aucun chiffre = 86 valeurs mensongères calculables, donc 86 vérifiées.
      // Si ce compte s'effondrait, l'assertion ci-dessous passerait au vert sans
      // rien regarder.
      expect(checked, 86,
          reason: 'Seules $checked étiquettes ont été vérifiées : la '
              'classification ou la fixture a changé sous ce test.');
      expect(
        leaks,
        isEmpty,
        reason: '${leaks.length} étiquette(s) affichent de nouveau le premier '
            'nombre multiplié par la parité de l\'EURO. C\'est le défaut du '
            '14/08/2026, revenu. Ne relevez aucun seuil : lisez la devise.\n'
            '${leaks.join('\n')}',
      );
    });

    test('aucun équivalent pour une devise sans parité fixe', () {
      final leaks = <String>[];
      var converted = 0;
      for (final record in records) {
        final equivalent = TuitionUtils.equivalentFor(record.label, 'XOF');
        if (expectsNoEquivalent(record.label)) {
          if (equivalent != null) {
            leaks.add('  « ${record.label} » → $equivalent');
          }
        } else if (equivalent != null) {
          converted++;
        }
      }
      expect(leaks, isEmpty,
          reason: 'Un taux a été inventé pour une devise que le dépôt ne sait '
              'pas convertir :\n${leaks.join('\n')}');
      // Garde d'aveuglement, dans l'autre sens : si le code cessait de convertir
      // QUOI QUE CE SOIT, l'assertion ci-dessus passerait vacuement au vert. Les
      // 58 étiquettes en euros doivent bel et bien produire leur équivalent.
      expect(converted, 58,
          reason: 'Seules $converted étiquettes produisent un équivalent : la '
              'conversion à parité fixe a disparu, et ce test ne prouve plus '
              'rien.');
    });

    test('l\'étiquette d\'origine survit toujours à l\'affichage', () {
      // La conversion COMPLÈTE, elle ne REMPLACE plus. C'est ce qui permet à un
      // étudiant de s'apercevoir qu'un montant est faux.
      for (final record in records) {
        expect(
          TuitionUtils.tuitionForDisplay(record.label, 'XOF'),
          contains(record.label.trim()),
          reason: '« ${record.label} » a été remplacée au lieu d\'être '
              'complétée.',
        );
      }
    });
  });

  group('ce qui était juste doit le rester', () {
    test('les 305 programmes en euros gardent la parité BCEAO exacte', () {
      final wrong = <String>[];
      for (final record in byShape[TuitionShape.euroSingleAmount] ?? const []) {
        final amount = naiveFirstAmount(record.label)!;
        final expected = '${record.label.trim()} · '
            '≈ ${groupThousands((amount * CurrencyUtils.xofPerEur).round())} '
            'FCFA';
        final actual = TuitionUtils.tuitionForDisplay(record.label, 'XOF');
        if (actual != expected) {
          wrong.add('  « ${record.label} » → « $actual » '
              '(attendu « $expected »)');
        }
      }
      expect(
        wrong,
        isEmpty,
        reason: 'Le cas que le code traitait DÉJÀ juste vient de casser : '
            '305 programmes, dont les 298 écoles partenaires françaises, la '
            'partie la plus consultée de l\'app.\n${wrong.join('\n')}',
      );
    });

    test('une étiquette sans chiffre n\'affiche toujours aucun montant', () {
      for (final record in byShape[TuitionShape.noAmount] ?? const []) {
        expect(TuitionUtils.equivalentFor(record.label, 'XOF'), isNull);
        expect(TuitionUtils.tuitionForDisplay(record.label, 'XOF'),
            record.label.trim());
      }
    });
  });
}
