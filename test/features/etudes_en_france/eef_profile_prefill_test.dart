// La table fermée qui préremplit la déclaration depuis le profil.
//
// Le profil stocke une ANNÉE d'étude (`bachelor_2`, « High school »), la
// déclaration un NIVEAU (`licence`). Les recopier tels quels enverrait
// « bachelor_2 » dans une colonne dont l'export commercial attend `licence`.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_profile_prefill.dart';

void main() {
  group('eefLevelSlugForProfileLevel', () {
    test('chaque année du profil tombe dans le vocabulaire de la déclaration',
        () {
      const expected = <String, String>{
        'terminale': 'terminale',
        'High school': 'terminale',
        'bachelor_1': 'licence',
        'Bachelor 2': 'licence',
        'L3': 'licence',
        'master_1': 'master',
        'M2': 'master',
        'doctorat': 'doctorat',
      };
      expected.forEach((raw, slug) {
        expect(eefLevelSlugForProfileLevel(raw), slug, reason: raw);
        // Et le résultat est TOUJOURS une valeur que la feuille sait afficher.
        expect(kEefLevelSlugs, contains(slug));
      });
    });

    test('une valeur inconnue ou vide laisse le champ vide', () {
      expect(eefLevelSlugForProfileLevel(null), isNull);
      expect(eefLevelSlugForProfileLevel(''), isNull);
      expect(eefLevelSlugForProfileLevel('   '), isNull);
      expect(eefLevelSlugForProfileLevel('quelque chose'), isNull);
    });
  });

  group('eefFieldIdsFromProfile', () {
    test('garde les domaines canoniques, dans l\'ordre, sans doublon', () {
      expect(
        eefFieldIdsFromProfile(['d07', 'd01', 'd07']),
        ['d07', 'd01'],
      );
    });

    test('écarte ce que la taxonomie ne connaît pas', () {
      expect(eefFieldIdsFromProfile(['d99', 'info', ' d03 ', '']), ['d03']);
      expect(eefFieldIdsFromProfile(null), isEmpty);
      expect(eefFieldIdsFromProfile(const <String>[]), isEmpty);
    });

    test('la taxonomie compte les douze domaines d01–d12', () {
      expect(kEefFieldIds,
          [for (var i = 1; i <= 12; i++) 'd${i.toString().padLeft(2, '0')}']);
    });
  });

  group('libellés', () {
    setUp(() {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
    });
    tearDown(Get.reset);

    test('un niveau connu a un libellé, un niveau inconnu aucun', () {
      expect(eefLevelLabel('licence'), 'Licence');
      expect(eefLevelLabel('inconnu'), isNull,
          reason: 'jamais la clé brute « eef_level_inconnu »');
      expect(eefLevelLabel(null), isNull);
      expect(eefLevelLabel(''), isNull);
    });

    test('un domaine a son libellé, un domaine inconnu son code', () {
      expect(eefFieldLabel('d01'), contains('Informatique'));
      expect(eefFieldLabel('d99'), 'd99');
    });
  });
}
