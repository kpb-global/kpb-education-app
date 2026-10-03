// L'ordre et les libellés des valeurs de filtre : la logique pure derrière les
// feuilles « Niveau », « Domaine », « Ville » et « Procédure ».
//
// Ce que ce fichier garantit, parce qu'un étudiant le lit sans le remarquer :
//  · le niveau suit l'ordre d'un parcours (L1, L2, L3, BUT…), pas celui du
//    nombre de formations ;
//  · un domaine sans nom n'est JAMAIS affiché sous son code (« d07 ») ;
//  · une ville se trie sans que « Évry » tombe après « Zoé » ;
//  · la recherche locale d'une ville ignore accents, casse et ponctuation.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/models/eef_search.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_filters.dart';
import 'package:karatou/app/features/etudes_en_france/eef_filter_options.dart';

EefFacetValue _f(String value, int count) =>
    EefFacetValue(value: value, count: count);

List<String> _values(List<EefFilterOption> options) =>
    options.map((o) => o.value).toList();

void main() {
  setUp(() {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
  });

  tearDown(Get.reset);

  group('niveau — ordre pédagogique fixe', () {
    test('licence1, licence2, licence3, but1, deust, sante, ingenieur, master',
        () {
      // Servi dans l'ordre du nombre de formations, donc mélangé.
      final options = eefCycleOptions([
        _f('master', 2771),
        _f('licence1', 2512),
        _f('licence3', 1637),
        _f('licence2', 1497),
        _f('but1', 834),
        _f('sante', 650),
        _f('ingenieur', 80),
        _f('deust', 48),
      ]);

      expect(_values(options), [
        'licence1',
        'licence2',
        'licence3',
        'but1',
        'deust',
        'sante',
        'ingenieur',
        'master',
      ]);
    });

    test('une valeur inconnue va À LA SUITE, par compte décroissant', () {
      final options = eefCycleOptions([
        _f('bts', 40),
        _f('master', 10),
        _f('doctorat', 90),
        _f('licence1', 5),
      ]);

      expect(_values(options), ['licence1', 'master', 'doctorat', 'bts']);
    });

    test('deux inconnues à égalité : ordre alphabétique, donc stable', () {
      final options = eefCycleOptions([_f('zeta', 7), _f('alpha', 7)]);
      expect(_values(options), ['alpha', 'zeta']);
    });

    test('les comptes servis sont conservés', () {
      final options = eefCycleOptions([_f('master', 2771), _f('but1', 834)]);
      expect(options.map((o) => o.count), [834, 2771]);
    });

    test('libellés localisés ; une valeur inconnue garde sa valeur brute', () {
      final options = eefCycleOptions([_f('master', 1), _f('bts', 1)]);
      expect(options.firstWhere((o) => o.value == 'master').label, 'Master');
      // Jamais la CLÉ de traduction (`eef_catalog_value_cycle_bts`).
      expect(options.firstWhere((o) => o.value == 'bts').label, 'bts');

      Get.locale = const Locale('en');
      final english = eefCycleOptions([_f('licence1', 1)]);
      expect(english.single.label, 'Bachelor, year 1');
    });

    test('un doublon servi n\'apparaît qu\'une fois', () {
      final options = eefCycleOptions([_f('master', 3), _f('master', 9)]);
      expect(_values(options), ['master']);
      expect(options.single.count, 3);
    });
  });

  group('procédure', () {
    test('garde l\'ordre du serveur et les libellés localisés', () {
      final options = eefProcedureOptions([
        _f('eef', 6804),
        _f('dap_blanche', 3076),
        _f('nouvelle_voie', 2),
      ]);

      expect(_values(options), ['eef', 'dap_blanche', 'nouvelle_voie']);
      expect(options[0].label, 'Études en France');
      expect(options[1].label, 'DAP dossier blanc');
      expect(options[2].label, 'nouvelle_voie');
    });
  });

  group('domaine — libellés du référentiel, triés par libellé', () {
    const names = <String, String>{
      'd01': 'Informatique & Intelligence Artificielle',
      'd09': 'Droit',
      'd07': 'Éducation',
      'd02': 'Agriculture',
    };

    test('triés par libellé, accents ignorés (Éducation entre Droit et Info)',
        () {
      final options = eefFieldOptions(
        [_f('d01', 638), _f('d09', 3343), _f('d07', 897), _f('d02', 1364)],
        nameOf: (id) => names[id],
      );

      expect(options.map((o) => o.label), [
        'Agriculture',
        'Droit',
        'Éducation',
        'Informatique & Intelligence Artificielle',
      ]);
      expect(_values(options), ['d02', 'd09', 'd07', 'd01']);
    });

    test('un domaine SANS NOM est ignoré — jamais affiché sous son code', () {
      final options = eefFieldOptions(
        [_f('d09', 10), _f('d99', 500), _f('d07', 4)],
        nameOf: (id) => names[id],
      );

      expect(_values(options), ['d09', 'd07']);
      expect(options.map((o) => o.label), isNot(contains('d99')));
    });

    test('un nom vide ou d\'espaces compte comme une absence de nom', () {
      final options = eefFieldOptions(
        [_f('d09', 10), _f('d07', 4)],
        nameOf: (id) => id == 'd07' ? '   ' : names[id],
      );
      expect(_values(options), ['d09']);
    });

    test('rend une liste vide quand AUCUN nom n\'est connu', () {
      final options = eefFieldOptions(
        [_f('d09', 10)],
        nameOf: (_) => null,
      );
      expect(options, isEmpty);
    });
  });

  group('ville — compte décroissant, puis alphabétique sans accents', () {
    test('trie par compte, puis par ordre alphabétique insensible aux accents',
        () {
      final options = eefCityOptions([
        _f('Zoé-sur-Mer', 12),
        _f('Évry', 12),
        _f('Paris', 727),
        _f('Albi', 12),
        _f('Aix-en-Provence', 151),
      ]);

      expect(_values(options),
          ['Paris', 'Aix-en-Provence', 'Albi', 'Évry', 'Zoé-sur-Mer']);
    });

    test('les libellés sont les valeurs brutes du serveur', () {
      final options = eefCityOptions([_f("Villeneuve-d'Ascq", 148)]);
      expect(options.single.label, "Villeneuve-d'Ascq");
      expect(options.single.value, "Villeneuve-d'Ascq");
    });

    test('ignore les villes sans valeur', () {
      final options = eefCityOptions([_f('', 5), _f('  ', 4), _f('Lyon', 1)]);
      expect(_values(options), ['Lyon']);
    });
  });

  group('valeurs choisies mais absentes de la liste servie', () {
    test('restent visibles — on doit pouvoir les décocher', () {
      final options = eefCityOptions(
        [_f('Paris', 727)],
        selected: {'Dijon'},
        missingCount: 0,
      );

      expect(_values(options), ['Paris', 'Dijon']);
      expect(options.last.count, 0);
    });

    test('compte inconnu quand la liste est tronquée (repli)', () {
      final options = eefCityOptions(
        [_f('Paris', 727)],
        selected: {'Dijon'},
        missingCount: null,
      );
      expect(options.last.count, isNull);
    });

    test('un niveau choisi mais absent reprend sa place pédagogique', () {
      final options = eefCycleOptions(
        [_f('master', 4), _f('licence1', 3)],
        selected: {'licence2'},
        missingCount: 0,
      );
      expect(_values(options), ['licence1', 'licence2', 'master']);
    });

    test('un domaine choisi sans nom reste ignoré', () {
      final options = eefFieldOptions(
        [_f('d09', 3)],
        nameOf: (id) => id == 'd09' ? 'Droit' : null,
        selected: {'d99'},
        missingCount: 0,
      );
      expect(_values(options), ['d09']);
    });
  });

  group('recherche locale d\'une ville', () {
    final options = eefCityOptions([
      _f('Paris', 727),
      _f('Évry-Courcouronnes', 90),
      _f('Saint-Étienne', 80),
      _f('Aix-en-Provence', 151),
      _f("Villeneuve-d'Ascq", 148),
      _f('Besançon', 60),
      _f('Lyon', 190),
    ]);

    test('sans accents : « evry » trouve « Évry-Courcouronnes »', () {
      expect(_values(eefFilterCityOptions(options, 'evry')),
          ['Évry-Courcouronnes']);
    });

    test('avec accents : « étienne » trouve « Saint-Étienne »', () {
      expect(
          _values(eefFilterCityOptions(options, 'étienne')), ['Saint-Étienne']);
    });

    test('insensible à la casse', () {
      expect(_values(eefFilterCityOptions(options, 'LYON')), ['Lyon']);
      expect(_values(eefFilterCityOptions(options, 'bEsAnCoN')), ['Besançon']);
    });

    test('la cédille et le trait d\'union ne gênent pas', () {
      expect(_values(eefFilterCityOptions(options, 'besancon')), ['Besançon']);
      expect(_values(eefFilterCityOptions(options, 'aix en provence')),
          ['Aix-en-Provence']);
      expect(_values(eefFilterCityOptions(options, 'saint etienne')),
          ['Saint-Étienne']);
    });

    test('l\'apostrophe droite ou typographique donne le même résultat', () {
      expect(_values(eefFilterCityOptions(options, "d'ascq")),
          ["Villeneuve-d'Ascq"]);
      expect(_values(eefFilterCityOptions(options, 'd’ascq')),
          ["Villeneuve-d'Ascq"]);
    });

    test('cherche à l\'intérieur du nom, pas seulement au début', () {
      expect(_values(eefFilterCityOptions(options, 'ris')), ['Paris']);
    });

    test('garde l\'ordre de la liste, et rend tout pour une requête vide', () {
      expect(_values(eefFilterCityOptions(options, '   ')), _values(options));
      // L'ordre de `options` (compte décroissant : Lyon 190, Évry 90, Besançon
      // 60) est conservé, pas celui de la recherche.
      expect(_values(eefFilterCityOptions(options, 'on')),
          ['Lyon', 'Évry-Courcouronnes', 'Besançon']);
    });

    test('rend une liste vide quand rien ne correspond', () {
      expect(eefFilterCityOptions(options, 'zzzz'), isEmpty);
    });
  });

  group('eefLocalizedName — le nom d\'un domaine dans la langue active', () {
    const both = LocalizedText(fr: 'Droit', en: 'Law');

    test('la langue active d\'abord', () {
      expect(eefLocalizedName(both, 'fr'), 'Droit');
      expect(eefLocalizedName(both, 'en'), 'Law');
      expect(eefLocalizedName(both, 'fr_FR'), 'Droit');
    });

    test('une langue sans nom retombe sur l\'autre : se lit, plutôt qu\'ignoré',
        () {
      expect(eefLocalizedName(const LocalizedText(fr: 'Droit', en: ''), 'en'),
          'Droit');
      expect(eefLocalizedName(const LocalizedText(fr: ' ', en: 'Law'), 'fr'),
          'Law');
    });

    test('aucun nom dans aucune langue : null (le domaine est ignoré)', () {
      expect(eefLocalizedName(null, 'fr'), isNull);
      expect(eefLocalizedName(const LocalizedText(fr: '', en: '  '), 'en'),
          isNull);
    });
  });

  group('eefFoldForSearch', () {
    test('minuscules, accents retirés, ponctuation et espaces unifiés', () {
      expect(eefFoldForSearch('  Évry–Courcouronnes '), 'evry courcouronnes');
      expect(eefFoldForSearch("L'Haÿ-les-Roses"), 'l hay les roses');
      expect(eefFoldForSearch('ÇA ÔTE'), 'ca ote');
      expect(eefFoldForSearch('Cœur'), 'coeur');
    });

    test('une lettre accentuée décomposée vaut la même lettre composée', () {
      // « É » écrit « E » + accent combinant (un clavier mobile peut le faire).
      expect(eefFoldForSearch('Évry'), 'evry');
      expect(eefFoldForSearch('Évry'), eefFoldForSearch('Évry'));
    });
  });
}
