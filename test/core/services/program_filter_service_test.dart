// ProgramFilterService — première couverture. Aucun test du dépôt ne référençait
// ni `ProgramFilterService`, ni `ProgramFilterState`, ni `budgetMaxEur`.
//
// Pourquoi ça comptait : le filtre budget appelait le MÊME parseur que
// l'affichage. Le défaut de conversion n'était donc pas cosmétique — il DÉCIDAIT
// de ce que l'étudiant voit. Un programme sénégalais étiqueté « XOF 1 150 000/an »
// était lu comme 1 150 000 euros, donc écarté de tout budget raisonnable : le
// curseur « budget maximum » faisait DISPARAÎTRE des formations parmi les moins
// chères du catalogue, sans un mot.
//
// Il consomme maintenant `readTuition` et une table de taux INDICATIFS réservée à
// la comparaison, avec une tolérance de 20 % accordée dans le sens de
// l'utilisateur : la dérive d'un taux ne peut jamais RECACHER une formation
// abordable.
//
// LES DEUX CAS QUI PORTAIENT LE TAG `known-defect` SONT MAINTENANT VERTS, et le
// tag est retiré : le lot 6 a corrigé le filtre. C'est le mécanisme du cliquet
// qui fonctionne — un défaut chiffré, puis corrigé, puis dé-tagué dans le même
// mouvement. Ce qu'ils affirment est devenu une garde de non-régression.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/program_filter_service.dart';
import 'package:karatou/app/core/utils/tuition_utils.dart';

import '../../support/screen_harness.dart';

LocalizedText _t(String value) => LocalizedText(fr: value, en: value);

ProgramModel _program({
  required String id,
  String tuition = '9 000 €/an',
  String institutionId = 'inst-partner',
  String countryId = 'senegal',
  String fieldId = 'd01',
  String name = 'Master en gestion',
  String level = 'Master',
  String language = 'Français',
}) {
  return ProgramModel(
    id: id,
    institutionId: institutionId,
    countryId: countryId,
    fieldId: fieldId,
    name: _t(name),
    level: _t(level),
    duration: _t('2 ans'),
    tuition: _t(tuition),
    language: _t(language),
    requirements: <LocalizedText>[_t('Licence')],
  );
}

void main() {
  late AppController controller;

  setUp(() async {
    controller = await seedKpbController();
  });
  tearDown(Get.reset);

  group('ProgramFilterState', () {
    test('hasActiveFilters ignore un budget au maximum', () {
      // 30 000 est la valeur par défaut : la garde `budgetMaxEur < 30000`
      // (program_filter_service.dart:52) évite d'annoncer un filtre actif quand
      // l'utilisateur n'a rien touché.
      expect(const ProgramFilterState().hasActiveFilters, isFalse);
      expect(
        const ProgramFilterState(budgetMaxEur: 29999).hasActiveFilters,
        isTrue,
      );
    });

    test('copyWith sait EFFACER un filtre, pas seulement le remplacer', () {
      const base = ProgramFilterState(countryId: 'france', levelKey: 'master');
      expect(base.copyWith(clearCountryId: true).countryId, isNull);
      expect(base.copyWith(clearLevelKey: true).levelKey, isNull);
      // Sans les drapeaux `clear`, passer `null` ne fait rien — comportement
      // volontaire de copyWith, et le piège classique de ce patron.
      expect(base.copyWith().countryId, 'france');
    });
  });

  group('apply — le filtre budget', () {
    test('écarte un programme en euros au-dessus du budget', () {
      final programs = [
        _program(id: 'p-cher', tuition: '45 000 €/an'),
        _program(id: 'p-abordable', tuition: '9 000 €/an'),
      ];
      final kept = ProgramFilterService.apply(
        programs,
        const ProgramFilterState(partnerOnly: false, budgetMaxEur: 30000),
        controller,
      ).map((p) => p.id);

      expect(kept, contains('p-abordable'));
      expect(kept, isNot(contains('p-cher')));
    });

    test('garde un programme sans montant lisible plutôt que de le cacher', () {
      // « Sur demande » ne donne aucun nombre : le filtre laisse passer
      // (`tuitionEur != null` en garde). Cacher serait pire — on ne sait pas.
      final kept = ProgramFilterService.apply(
        [_program(id: 'p-demande', tuition: 'Sur demande')],
        const ProgramFilterState(partnerOnly: false, budgetMaxEur: 5000),
        controller,
      ).map((p) => p.id);
      expect(kept, contains('p-demande'));
    });

    test(
      'un programme en francs CFA reste visible sous un budget de 30 000 €',
      () {
        // « XOF 1 150 000/an » vaut ~1 750 €. Aucun budget réaliste ne doit
        // l'écarter. Aujourd'hui le parseur lit 1 150 000 « euros » et le filtre
        // le supprime — donc le curseur budget cache les formations les MOINS
        // chères du catalogue. 48 programmes sénégalais sont dans ce cas en
        // production.
        final kept = ProgramFilterService.apply(
          [_program(id: 'p-dakar', tuition: 'XOF 1 150 000/an')],
          const ProgramFilterState(partnerOnly: false, budgetMaxEur: 30000),
          controller,
        ).map((p) => p.id);

        expect(
          kept,
          contains('p-dakar'),
          reason: 'Le filtre budget a écarté un programme à ~1 750 € parce '
              "qu'il a lu ses francs CFA comme des euros "
              '(program_filter_service.dart:116-120).',
        );
      },
    );

    test(
      'un programme en dirhams reste visible sous un budget de 10 000 €',
      () {
        // « MAD 35 000/an » vaut ~3 300 €.
        final kept = ProgramFilterService.apply(
          [_program(id: 'p-rabat', tuition: 'MAD 35,000/an')],
          const ProgramFilterState(partnerOnly: false, budgetMaxEur: 10000),
          controller,
        ).map((p) => p.id);

        expect(kept, contains('p-rabat'),
            reason: 'Un programme marocain à ~3 300 € a été écarté par un '
                'budget de 10 000 € : ses dirhams ont été comptés comme des '
                'euros. 50 programmes marocains sont dans ce cas en production.');
      },
    );
  });

  group('apply — les autres critères', () {
    test('partnerOnly écarte les institutions non partenaires', () {
      // Aucune institution `inst-inconnue` n'existe : `institutionByIdOrNull`
      // rend null, donc `isPartner` vaut false.
      final kept = ProgramFilterService.apply(
        [_program(id: 'p1', institutionId: 'inst-inconnue')],
        const ProgramFilterState(),
        controller,
      );
      expect(kept, isEmpty);
    });

    test('countryId compare sans tenir compte de la casse', () {
      final programs = [
        _program(id: 'p-sn', countryId: 'senegal'),
        _program(id: 'p-fr', countryId: 'france'),
      ];
      final kept = ProgramFilterService.apply(
        programs,
        const ProgramFilterState(partnerOnly: false, countryId: 'SENEGAL'),
        controller,
      ).map((p) => p.id);
      expect(kept, ['p-sn']);
    });

    test('fieldId est une égalité stricte', () {
      final kept = ProgramFilterService.apply(
        [
          _program(id: 'p1', fieldId: 'd01'),
          _program(id: 'p2', fieldId: 'd02')
        ],
        const ProgramFilterState(partnerOnly: false, fieldId: 'd02'),
        controller,
      ).map((p) => p.id);
      expect(kept, ['p2']);
    });

    test('query cherche dans le nom, le niveau, le domaine et le pays', () {
      final programs = [
        _program(id: 'p-gestion', name: 'Master en gestion'),
        _program(id: 'p-info', name: 'Master en informatique'),
      ];
      List<String> search(String q) => ProgramFilterService.apply(
            programs,
            ProgramFilterState(partnerOnly: false, query: q),
            controller,
          ).map((p) => p.id).toList();

      expect(search('informatique'), ['p-info']);
      // Casse et espaces indifférents.
      expect(search('  GESTION '), ['p-gestion']);
      // Le pays fait partie du foin cherché.
      expect(search('senegal').length, 2);
      expect(search('introuvable'), isEmpty);
    });

    test('le tri place les moins chers devant, à statut partenaire égal', () {
      final programs = [
        _program(id: 'p-20k', tuition: '20 000 €/an'),
        _program(id: 'p-5k', tuition: '5 000 €/an'),
        _program(id: 'p-inconnu', tuition: 'Sur demande'),
      ];
      final order = ProgramFilterService.apply(
        programs,
        const ProgramFilterState(partnerOnly: false),
        controller,
      ).map((p) => p.id).toList();

      // Le sentinel `?? 999999` (program_filter_service.dart:140-147) renvoie
      // les prix inconnus en fin de liste — comportement voulu, figé ici.
      expect(order, ['p-5k', 'p-20k', 'p-inconnu']);
    });
  });

  group('la porte de sortie du lot 6 — quatre programmes, deux budgets', () {
    // Les quatre cas du plan, avec leurs équivalents estimés :
    //   A  MAD 40 000/an   ≈ 3 720 €
    //   B  MAD 150,000/an  ≈ 13 950 €
    //   C  12 990 €/an     = 12 990 €
    //   D  Sur demande     illisible → toujours gardé
    List<ProgramModel> abcd() => [
          _program(id: 'A', tuition: 'MAD 40 000/an', countryId: 'mar'),
          _program(id: 'B', tuition: 'MAD 150,000/an', countryId: 'mar'),
          _program(id: 'C', tuition: '12 990 €/an', countryId: 'france'),
          _program(id: 'D', tuition: 'Sur demande', countryId: 'france'),
        ];

    List<String> keptWith(ProgramFilterState filters) =>
        ProgramFilterService.apply(abcd(), filters, controller)
            .map((p) => p.id)
            .toList();

    test('état par défaut : les quatre sont présents', () {
      // Avant, A et B disparaissaient — 40 000 et 150 000 dirhams comparés à
      // 30 000 euros.
      expect(
        keptWith(const ProgramFilterState(partnerOnly: false))..sort(),
        ['A', 'B', 'C', 'D'],
      );
    });

    test('puce « < 3 M FCFA » : A et D seulement', () {
      // 3 000 000 FCFA / 655,957 = 4 573 € de plafond, tolérance ×1,2 = 5 488 €.
      // A (3 720 €) passe ; B (13 950 €) non ; C (12 990 €) non — exclusion
      // LÉGITIME, pas un bug ; D reste faute de savoir lire son prix.
      const chip = ProgramFilterState(
        partnerOnly: false,
        budgetMaxEur: 3000000 / 655.957,
      );
      expect(keptWith(chip)..sort(), ['A', 'D']);
    });

    test('le tri place le programme marocain avant le français', () {
      // 3 720 € contre 12 990 € : à statut partenaire égal, le moins cher devant.
      final order = keptWith(const ProgramFilterState(partnerOnly: false));
      expect(order.indexOf('A'), lessThan(order.indexOf('C')));
    });

    test('aucun taux indicatif ne peut apparaître dans un libellé', () {
      // La promesse structurante du lot : la table de taux sert à COMPARER, jamais
      // à afficher. `TuitionUtils` n'y a pas accès, et voici l'assertion qui le
      // dit — sur les quatre programmes, aucun montant converti en euros ne
      // ressort côté affichage pour une devise sans parité fixe.
      for (final program in abcd()) {
        final label = controller.resolve(program.tuition);
        if (declaredCurrencyOf(label) == 'MAD') {
          expect(TuitionUtils.equivalentFor(label, 'XOF'), isNull,
              reason:
                  '« $label » a produit un équivalent : un taux MAD a fui de '
                  "la table de comparaison vers l'affichage.");
        }
      }
    });
  });
}

/// La devise déclarée, lue ici de façon volontairement naïve : ce test ne doit pas
/// dépendre du parseur qu'il surveille.
String? declaredCurrencyOf(String label) {
  for (final code in const ['MAD', 'AED', 'CAD', 'GBP', 'USD', 'XOF', 'EUR']) {
    if (label.contains(code)) return code;
  }
  if (label.contains('€')) return 'EUR';
  return null;
}
