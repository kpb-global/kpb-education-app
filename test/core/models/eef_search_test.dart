// Le modèle d'une page de recherche « Études en France ».
//
// Ce qui est éprouvé ici, c'est la TOLÉRANCE : le serveur évolue plus vite que
// les builds installées, donc le décodeur ne doit ni lever sur une charge
// incomplète, ni inventer ce qui manque.

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/eef_search.dart';

Map<String, dynamic> _item({
  Object? institution,
  Object? procedureType = 'eef',
  Object? campusCity = 'Lyon',
}) =>
    <String, dynamic>{
      'id': 'eef-prog-1',
      'institutionId': 'eef-univ-x',
      'countryId': 'fra',
      'fieldId': 'd07',
      'nameFr': 'Licence Droit',
      'nameEn': 'Law Bachelor',
      'levelFr': 'Bac+3',
      'levelEn': 'Bachelor',
      'durationFr': '3 ans',
      'durationEn': '3 years',
      'tuitionFr': 'x',
      'tuitionEn': 'x',
      'languageFr': 'Français',
      'languageEn': 'French',
      'requirementsFr': <String>[],
      'requirementsEn': <String>[],
      'procedureType': procedureType,
      'cycle': 'licence3',
      'selectivity': 'selective',
      'campusCity': campusCity,
      'institution': institution,
    };

Map<String, dynamic> _institution() => <String, dynamic>{
      'id': 'eef-univ-x',
      'name': {'fr': 'Université de Lyon', 'en': 'University of Lyon'},
      'acronym': 'UDL',
      'location': {'fr': 'Lyon, France', 'en': 'Lyon, France'},
      'institutionType': 'university',
      'websiteUrl': 'https://exemple.test',
      'logoUrl': 'https://upload.wikimedia.org/x.png',
      'logoSourceUrl': 'https://commons.wikimedia.org/wiki/File:x.png',
      'logoLicence': 'CC BY-SA 4.0',
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> items,
        {Object? catalogPublished}) =>
    <String, dynamic>{
      'items': items,
      'total': items.length,
      'page': <String, dynamic>{'hasMore': false, 'nextCursor': null},
      'facets': <String, dynamic>{},
      'facetsTruncated': <String>[],
      if (catalogPublished != null) 'catalogPublished': catalogPublished,
    };

void main() {
  group('EefProgram', () {
    test('lit la procédure, le cycle, la ville et l\'établissement', () {
      final page = EefSearchPage.fromJson(
        _page([_item(institution: _institution())]),
      );
      final item = page.items.single;

      expect(item.id, 'eef-prog-1');
      expect(item.procedureType, 'eef');
      expect(item.cycle, 'licence3');
      expect(item.selectivity, 'selective');
      expect(item.campusCity, 'Lyon');
      expect(item.institution!.name.fr, 'Université de Lyon');
      expect(item.institution!.acronym, 'UDL');
      expect(item.institution!.logoLicence, 'CC BY-SA 4.0');
      // Le modèle général reste lu tel quel.
      expect(item.program.name.fr, 'Licence Droit');
    });

    test('un serveur plus ancien (sans ces champs) ne fait pas lever', () {
      final raw = _item()
        ..remove('procedureType')
        ..remove('cycle')
        ..remove('selectivity')
        ..remove('campusCity')
        ..remove('institution');
      final item = EefSearchPage.fromJson(_page([raw])).items.single;

      expect(item.procedureType, isNull);
      expect(item.institution, isNull);
      expect(item.program.name.fr, 'Licence Droit');
    });

    // Une carte sans établissement doit rester honnête : jamais un nom inventé.
    test('un établissement incomplet devient null, pas un nom vide', () {
      final noName = _institution()..['name'] = {'fr': '', 'en': ''};
      final noId = _institution()..remove('id');

      expect(
        EefSearchPage.fromJson(_page([_item(institution: noName)]))
            .items
            .single
            .institution,
        isNull,
      );
      expect(
        EefSearchPage.fromJson(_page([_item(institution: noId)]))
            .items
            .single
            .institution,
        isNull,
      );
      expect(
        EefSearchPage.fromJson(_page([_item(institution: 'texte')]))
            .items
            .single
            .institution,
        isNull,
      );
    });

    test('des valeurs vides ou non textuelles sont lues comme absentes', () {
      final item = EefSearchPage.fromJson(
        _page([_item(procedureType: '  ', campusCity: 42)]),
      ).items.single;

      expect(item.procedureType, isNull);
      expect(item.campusCity, isNull);
    });
  });

  group('catalogPublished', () {
    test('une clé absente se lit « publié »', () {
      expect(EefSearchPage.fromJson(_page([])).catalogPublished, isTrue);
    });

    test('seul un false EXPLICITE signifie « rien de publié »', () {
      expect(
        EefSearchPage.fromJson(_page([], catalogPublished: false))
            .catalogPublished,
        isFalse,
      );
      for (final odd in <Object?>[null, 0, 'false', 'non']) {
        expect(
          EefSearchPage.fromJson(_page([], catalogPublished: odd))
              .catalogPublished,
          isTrue,
          reason: '$odd',
        );
      }
    });
  });
}
