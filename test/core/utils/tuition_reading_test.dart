// Le parseur d'étiquettes de frais, éprouvé sur les 146 étiquettes RÉELLES de la
// production avant d'être branché où que ce soit.
//
// Deux moitiés :
//   · des vecteurs nommés, un par forme réelle et un par motif de refus ;
//   · un balayage de la fixture entière, qui exige que CHAQUE étiquette soit soit
//     lue avec la devise qu'elle déclare, soit refusée — jamais lue avec une
//     autre devise. C'est cet invariant, et non un compte, qui dit que le
//     parseur ne devine plus.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/utils/tuition_reading.dart';

import 'tuition_fixture.dart';

void main() {
  group('ce qu\'il sait lire', () {
    void reads(
      String label,
      int amount,
      TuitionCurrency currency, {
      int? max,
    }) {
      test('« $label » → ${currency.code} $amount${max == null ? '' : '–$max'}',
          () {
        final reading = readTuition(label);
        expect(reading, isNotNull,
            reason: 'refusée alors qu\'elle est lisible');
        expect(reading!.amount, amount);
        expect(reading.amountMax, max);
        expect(reading.currency, currency);
      });
    }

    // Devise en préfixe, la forme du back-office pour le Maghreb et l'Afrique.
    reads('MAD 35,000/an', 35000, TuitionCurrency.mad);
    reads('XOF 1 150 000/an (est.)', 1150000, TuitionCurrency.xof);
    reads('CAD 12 000/an (indicatif)', 12000, TuitionCurrency.cad);
    reads('GBP 12 000/an', 12000, TuitionCurrency.gbp);
    reads('USD 18,000/an (approx.)', 18000, TuitionCurrency.usd);
    reads('EUR 9 000/an', 9000, TuitionCurrency.eur);

    // Devise en suffixe, la forme des écoles du Golfe et du Maroc.
    reads('40 000 AED/an', 40000, TuitionCurrency.aed);
    reads('45 000 MAD/an', 45000, TuitionCurrency.mad);
    reads('17 610 USD/an', 17610, TuitionCurrency.usd);

    // Symbole, avec l'espace fine insécable U+202F du back-office.
    reads('12 990 €/an', 12990, TuitionCurrency.eur);
    reads('15 420 €/an', 15420, TuitionCurrency.eur);

    // Fourchettes : les DEUX bornes, pas la plus basse déguisée en prix.
    reads('8 000 - 18 500 AED', 8000, TuitionCurrency.aed, max: 18500);
    reads('11 490 € – 11 690 €/an selon le campus', 11490, TuitionCurrency.eur,
        max: 11690);
    reads('USD 15k–45k/an', 15000, TuitionCurrency.usd, max: 45000);

    // Abréviation « k » seule : × 1000, sans ambiguïté.
    reads('MAD 15k–60k/an', 15000, TuitionCurrency.mad, max: 60000);

    // Un coût total de programme se lit comme un montant : c'est l'AFFICHAGE qui
    // doit cesser de lui coller « /an », pas la lecture.
    reads('30 000 € (programme)', 30000, TuitionCurrency.eur);
    reads('10 000 AED (programme)', 10000, TuitionCurrency.aed);

    // Un second nombre SANS tiret n'est pas une fourchette.
    reads('5 500 €/an (B1)', 5500, TuitionCurrency.eur);
  });

  group('ce qu\'il refuse, et pourquoi', () {
    void refuses(String label, String why) {
      test('« ${label.isEmpty ? '(vide)' : label} » — $why', () {
        expect(readTuition(label), isNull, reason: why);
      });
    }

    refuses('', 'chaîne vide');
    refuses('   ', 'espaces seulement');
    refuses('Sur demande', 'aucun chiffre, aucune devise');
    refuses(
        '12 000',
        'aucune devise déclarée : deviner l\'euro est le défaut '
            'entier');
    refuses('12 000/an', 'toujours aucune devise');
    // Le format du catalogue de repli français : 9 850 ou 9,85 ?
    refuses(
        '9.850 EUR/an',
        'point suivi de trois chiffres, irréductiblement '
            'ambigu');
    refuses('1.200 USD', 'même ambiguïté, autre devise');
    refuses(
        '12 000 EUR / 8 000 USD',
        'deux familles de devises : un arbitrage '
            'ne serait pas une lecture');
  });

  group('les pièges de délimitation', () {
    test('« académique » ne déclare pas le dollar canadien', () {
      // ACADÉMIQUE contient CAD. Sans frontière de mot, cette étiquette
      // déclencherait deux familles et serait refusée pour rien.
      final reading = readTuition('Frais académiques : 12 000 €');
      expect(reading?.currency, TuitionCurrency.eur);
      expect(reading?.amount, 12000);
    });

    test('« euros » écrit en mot est bien de l\'euro', () {
      expect(readTuition('12 000 euros/an')?.currency, TuitionCurrency.eur);
    });
  });

  group('les 146 étiquettes de production', () {
    final records = loadTuitionFixture();

    test('la fixture est bien celle des 146 étiquettes', () {
      expect(records.length, 146);
      expect(records.fold(0, (sum, r) => sum + r.programCount), 582);
    });

    test('aucune étiquette n\'est lue avec une devise qu\'elle ne déclare pas',
        () {
      // L'invariant central. Le parseur peut refuser — c'est permis et parfois
      // souhaitable. Ce qu'il ne peut pas faire, c'est rendre un montant assorti
      // d'une AUTRE devise que celle écrite dans l'étiquette.
      final mismatches = <String>[];
      for (final record in records) {
        final reading = readTuition(record.label);
        if (reading == null) continue;
        final declared = declaredCurrency(record.label);
        if (declared == null) {
          mismatches.add('  « ${record.label} » lue ${reading.currency.code} '
              'alors qu\'elle ne déclare AUCUNE devise');
          continue;
        }
        if (reading.currency.code != declared) {
          mismatches.add('  « ${record.label} » déclare $declared, lue '
              '${reading.currency.code}');
        }
      }
      expect(mismatches, isEmpty, reason: mismatches.join('\n'));
    });

    test('les seuls refus sont ceux sans chiffre', () {
      // Sur les données de production, tout le reste doit être lisible : si le
      // parseur refusait 40 étiquettes, il serait honnête mais inutile, et
      // l'app perdrait des équivalents FCFA qu'elle sait calculer.
      final refused = records
          .where((r) => readTuition(r.label) == null)
          .toList(growable: false);
      expect(
        refused.map((r) => r.label).toList(),
        ['Sur demande', ''],
        reason: 'Refus inattendu(s) : '
            '${refused.map((r) => '« ${r.label} » (${r.programCount} progr.)').join(', ')}',
      );
    });

    test('chaque famille de devise est effectivement reconnue', () {
      final read = <String, int>{};
      for (final record in records) {
        final reading = readTuition(record.label);
        if (reading == null) continue;
        read[reading.currency.code] =
            (read[reading.currency.code] ?? 0) + record.programCount;
      }
      // Les comptes de programmes par devise, mesurés le 14/08/2026 sur les
      // 582 lignes de production. Ils disent quelle part du catalogue chaque
      // famille représente — et donc combien d'étudiants un défaut touche.
      expect(read, {
        'EUR': 350,
        'USD': 55,
        'MAD': 50,
        'XOF': 48,
        'CAD': 32,
        'GBP': 32,
        'AED': 10,
      });
    });

    test('les fourchettes sont lues comme des fourchettes', () {
      final ranges = records
          .where((r) => readTuition(r.label)?.isRange ?? false)
          .toList(growable: false);
      // 9 étiquettes, 45 programmes : les 8 « … – … €/an selon le campus » des
      // écoles françaises multi-campus, plus « 8 000 - 18 500 AED ». L'ancien
      // parseur les écrasait toutes sur leur borne basse.
      expect(ranges.length, 9);
      expect(ranges.fold(0, (sum, r) => sum + r.programCount), 45);
    });
  });
}
