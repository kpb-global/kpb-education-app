// Les étiquettes OneSignal alimentent des segments filtrés par égalité
// stricte : chaque valeur doit être une clé stable, et une valeur absente doit
// être envoyée vide (le service la retire alors côté OneSignal).

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/onesignal_tags.dart';

UserProfile _profile({
  String? currentLevel,
  List<String> targetCountryIds = const [],
  String countryOfResidence = 'GN',
  AccountType accountType = AccountType.student,
}) {
  return UserProfile(
    id: 'usr-42',
    accountType: accountType,
    fullName: 'Aminata Diallo',
    email: 'aminata.diallo@student.example',
    phone: '',
    whatsApp: '',
    countryOfResidence: countryOfResidence,
    preferredLanguage: 'fr',
    currentLevel: currentLevel,
    targetCountryIds: targetCountryIds,
  );
}

void main() {
  test('envoie exactement les quatre étiquettes déclarées', () {
    final tags = oneSignalTargetingTags(_profile(), localeCode: 'fr');
    expect(
      tags.keys,
      unorderedEquals(['account_type', 'level', 'target_country', 'locale']),
    );
  });

  group('level', () {
    test('normalise le jeton de l\'onboarding et le libellé du profil', () {
      String level(String raw) => oneSignalTargetingTags(
            _profile(currentLevel: raw),
            localeCode: 'fr',
          )['level']!;

      // Même niveau, deux écritures en base : une seule valeur de segment.
      expect(level('High school'), 'terminale');
      expect(level('Terminale'), 'terminale');
      expect(level('Bachelor 1'), 'bachelor_1');
      expect(level('Master 2'), 'master_2');
      expect(level('PhD'), 'doctorat');
    });

    test('vide quand le niveau est absent ou inconnu', () {
      expect(
        oneSignalTargetingTags(_profile(), localeCode: 'fr')['level'],
        isEmpty,
      );
      expect(
        oneSignalTargetingTags(
          _profile(currentLevel: '???'),
          localeCode: 'fr',
        )['level'],
        isEmpty,
      );
    });
  });

  group('target_country', () {
    test('premier pays visé', () {
      final tags = oneSignalTargetingTags(
        _profile(targetCountryIds: ['canada', 'france']),
        localeCode: 'fr',
      );
      expect(tags['target_country'], 'canada');
    });

    test('ne retombe jamais sur le pays de résidence', () {
      final tags = oneSignalTargetingTags(
        _profile(countryOfResidence: 'GN'),
        localeCode: 'fr',
      );
      expect(tags['target_country'], isEmpty);
    });
  });

  test('account_type et locale', () {
    final tags = oneSignalTargetingTags(
      _profile(accountType: AccountType.parent),
      localeCode: 'en',
    );
    expect(tags['account_type'], 'parent');
    expect(tags['locale'], 'en');
  });
}
