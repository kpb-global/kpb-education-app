// ProgramFilterService — première couverture. Aucun test du dépôt ne référençait
// ni `ProgramFilterService`, ni `ProgramFilterState`, ni `budgetMaxEur`.
//
// Pourquoi ça compte maintenant : le filtre budget appelle le MÊME parseur que
// l'affichage (`TuitionUtils.parseEurAnnual`, program_filter_service.dart:116-120).
// Le défaut de conversion n'est donc pas seulement cosmétique — il DÉCIDE de ce
// que l'étudiant voit. Un programme sénégalais étiqueté « XOF 1 150 000/an » est
// lu comme 1 150 000 euros, donc écarté de tout budget raisonnable : le curseur
// « budget maximum » fait DISPARAÎTRE des formations parmi les moins chères du
// catalogue, sans un mot.
//
// Les cas qui décrivent ce défaut portent le tag `known-defect` : ils sont rouges
// aujourd'hui, hors portillon de fusion, et deviendront verts avec le lot 6. Le
// reste du fichier est du vert franc — la couverture qui manquait.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/program_filter_service.dart';

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
      tags: 'known-defect',
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
      tags: 'known-defect',
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
}
