// Ce qui va à l'écran : l'étiquette d'origine, plus un équivalent quand il est
// calculable sans taux à entretenir.
//
// Les valeurs INTERDITES de ce fichier sont celles que l'app affichait vraiment
// en production le 14/08/2026. Elles sont écrites en dur, exprès : si un futur
// refactor les fait revenir, ce test le dit avec le chiffre exact.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/utils/tuition_utils.dart';

import 'tuition_fixture.dart';

void main() {
  group('la devise étrangère n\'est plus convertie du tout', () {
    // Le cœur du correctif. Aucun taux MAD/AED/CAD/GBP n'existe dans le code,
    // donc aucun montant converti ne peut être affiché — ni juste, ni faux.
    const cases = <String, String>{
      'MAD 35,000/an': '22 958 495',
      'MAD 45,000/an': '29 518 065',
      '40 000 AED/an': '26 238 280',
      'CAD 12 000/an (indicatif)': '7 871 484',
      'GBP 12 000/an': '7 871 484',
      'USD 18,000/an (approx.)': '11 807 226',
    };

    cases.forEach((label, forbidden) {
      test('« $label » ne contient plus « $forbidden »', () {
        final shown = TuitionUtils.tuitionForDisplay(label, 'XOF');
        expect(shown, isNot(contains(forbidden)),
            reason:
                'Le premier nombre a de nouveau été traité comme des euros.');
        // Et l'étiquette d'origine est TOUJOURS là : c'est elle qui informe.
        expect(shown, contains(label));
      });
    });

    test('aucun montant FCFA n\'est ajouté à une devise sans parité connue',
        () {
      for (final label in const [
        'MAD 35,000/an',
        '40 000 AED/an',
        'CAD 12 000/an (indicatif)',
        'GBP 12 000/an',
        'USD 18,000/an (approx.)',
      ]) {
        expect(TuitionUtils.equivalentFor(label, 'XOF'), isNull);
        expect(TuitionUtils.tuitionForDisplay(label, 'XOF'), label);
      }
    });
  });

  group('les francs CFA ne sont plus re-convertis', () {
    test('« XOF 1 150 000/an (est.) » reste tel quel', () {
      final shown =
          TuitionUtils.tuitionForDisplay('XOF 1 150 000/an (est.)', 'XOF');
      // 754 350 550 : le montant que la production affichait — 656 fois le prix.
      expect(shown, isNot(contains('754 350 550')));
      expect(shown, 'XOF 1 150 000/an (est.)');
    });

    test('et se convertit en euros à la parité exacte si c\'est la préférence',
        () {
      // 1 150 000 / 655,957 = 1 753,17 → 1 753 €
      expect(
        TuitionUtils.tuitionForDisplay('XOF 1 150 000/an (est.)', 'EUR'),
        'XOF 1 150 000/an (est.) · ≈ 1 753 €',
      );
    });
  });

  group('les euros CONSERVENT leur équivalent — garde anti-sur-correction', () {
    // 350 des 582 programmes de production sont en euros, dont les 298 écoles
    // partenaires françaises : c'est la partie de l'app aujourd'hui juste, et la
    // plus consultée. Un correctif qui la ferait disparaître serait un recul.
    test('« 12 990 €/an » garde « 8 520 881 »', () {
      expect(
        TuitionUtils.tuitionForDisplay('12 990 €/an', 'XOF'),
        '12 990 €/an · ≈ 8 520 881 FCFA',
      );
    });

    test('« EUR 9 000/an » garde « 5 903 613 »', () {
      expect(
        TuitionUtils.tuitionForDisplay('EUR 9 000/an', 'XOF'),
        'EUR 9 000/an · ≈ 5 903 613 FCFA',
      );
    });

    test('pas d\'équivalent redondant quand la préférence est déjà l\'euro',
        () {
      expect(
          TuitionUtils.tuitionForDisplay('12 990 €/an', 'EUR'), '12 990 €/an');
    });
  });

  group('les fourchettes gardent leurs deux bornes', () {
    test('« 11 490 € – 11 690 €/an selon le campus »', () {
      final shown = TuitionUtils.tuitionForDisplay(
          '11 490 € – 11 690 €/an selon le campus', 'XOF');
      // L'ancien affichage écrasait la fourchette sur sa borne basse et perdait
      // « selon le campus » : 44 programmes concernés.
      expect(shown, contains('selon le campus'));
      expect(shown, contains('11 490'));
      expect(shown, contains('11 690'));
      expect(shown, endsWith('≈ 7 536 946 – 7 668 137 FCFA'));
    });

    test('une fourchette en dirhams n\'a aucun équivalent', () {
      expect(TuitionUtils.equivalentFor('8 000 - 18 500 AED', 'XOF'), isNull);
    });
  });

  group('un coût total de programme ne devient pas un tarif annuel', () {
    test('« 30 000 € (programme) » n\'ajoute pas « /an »', () {
      final shown =
          TuitionUtils.tuitionForDisplay('30 000 € (programme)', 'XOF');
      expect(shown, '30 000 € (programme) · ≈ 19 678 710 FCFA');
      // L'ancien code rendait « ~ 19 678 710 FCFA/an » : le « /an » était collé
      // par le formateur, sur un montant qui couvre toute la scolarité.
      expect(shown, isNot(contains('FCFA/an')));
    });
  });

  group('les étiquettes illisibles n\'inventent rien', () {
    test('« Sur demande » et la chaîne vide passent inchangées', () {
      expect(
          TuitionUtils.tuitionForDisplay('Sur demande', 'XOF'), 'Sur demande');
      expect(TuitionUtils.tuitionForDisplay('', 'XOF'), '');
      expect(TuitionUtils.equivalentFor('Sur demande', 'XOF'), isNull);
    });

    test('« 9.850 EUR/an » n\'affiche plus 5 904 FCFA', () {
      // Le point-millier du catalogue de repli : l'ancien parseur lisait « 9 ».
      final shown = TuitionUtils.tuitionForDisplay('9.850 EUR/an', 'XOF');
      expect(shown, isNot(contains('5 904')));
      expect(shown, '9.850 EUR/an');
    });

    test('un montant sans devise n\'est pas supposé en euros', () {
      expect(TuitionUtils.equivalentFor('12 000/an', 'XOF'), isNull);
    });
  });

  group('sur les 146 étiquettes de production', () {
    final records = loadTuitionFixture();

    test('aucun équivalent n\'est produit pour une devise sans parité connue',
        () {
      final leaks = <String>[];
      for (final record in records) {
        final declared = declaredCurrency(record.label);
        if (declared == null || declared == 'EUR' || declared == 'XOF') {
          continue;
        }
        final equivalent = TuitionUtils.equivalentFor(record.label, 'XOF');
        if (equivalent != null) {
          leaks.add('  ${record.programCount}× « ${record.label} » → '
              '$equivalent');
        }
      }
      expect(leaks, isEmpty,
          reason: 'Un taux a été inventé pour une devise sans parité fixe :\n'
              '${leaks.join('\n')}');
    });

    test('l\'étiquette d\'origine est toujours présente à l\'écran', () {
      for (final record in records) {
        final shown = TuitionUtils.tuitionForDisplay(record.label, 'XOF');
        expect(shown, contains(record.label.trim()),
            reason: '« ${record.label} » a été remplacée au lieu d\'être '
                'complétée.');
      }
    });

    test('232 programmes n\'affichent plus AUCUN montant faux', () {
      // Le compte : 582 − 350 en euros = 232 programmes dont le prix était
      // converti à tort (dirhams, dirhams des Émirats, dollars canadiens, livres,
      // dollars, francs CFA), plus les 5 sans étiquette lisible.
      var withoutEquivalent = 0;
      for (final record in records) {
        if (TuitionUtils.equivalentFor(record.label, 'XOF') == null) {
          withoutEquivalent += record.programCount;
        }
      }
      expect(withoutEquivalent, 232);
    });
  });
}
