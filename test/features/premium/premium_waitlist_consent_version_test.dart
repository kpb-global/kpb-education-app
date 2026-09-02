// Cliquet : `kPremiumWaitlistConsentVersion` doit désigner le texte RÉELLEMENT
// affiché à l'écran.
//
// Même mécanique — et même raison — que `eef_consent_version_test.dart`. Chaque
// inscription enregistre `consentVersion` en base ; cette colonne répond à la
// seule question qu'un horodatage laisse ouverte : le jour où un étudiant
// demande à quoi il s'est inscrit, il faut pouvoir produire LA PHRASE, pas
// seulement l'instant du tap.
//
// Le défaut interdit ici est une version qui ne bouge pas quand le texte change.
// La base porterait « premium-waitlist-v1 » pour deux textes différents, donc on
// croirait pouvoir produire la phrase acceptée alors qu'on ne le pourrait pas.
// Une colonne qui ment est plus dangereuse qu'une colonne absente, parce qu'on
// s'y fie.
//
// Le texte décrit un service qui n'existe pas encore : il changera. C'est
// précisément pourquoi le cliquet est posé dès maintenant.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/premium/premium_waitlist_controller.dart';

/// Version → empreinte des textes affichés (FR puis EN).
///
/// Une nouvelle version s'AJOUTE, elle ne remplace pas : garder les anciennes
/// permet de retrouver ce qu'une ligne portant « premium-waitlist-v1 »
/// désignait, des mois après que le texte a changé. C'est l'usage même de la
/// colonne.
const _fingerprints = <String, String>{
  'premium-waitlist-v1':
      'b62c4c63ff534702ee97561674de4fad3f60ba197359d35128d7b912fef4a575',
};

/// Les clés qui composent l'acte de consentement.
///
/// `premium_waitlist_notice` porte l'engagement. `premium_waitlist_body` est
/// inclus parce qu'il dit à quoi sert l'inscription, juste au-dessus du bouton :
/// c'est du même acte.
const _consentKeys = <String>[
  'premium_waitlist_notice',
  'premium_waitlist_body',
];

String _fingerprint(Map<String, Map<String, String>> keys) {
  final buffer = StringBuffer();
  for (final locale in const ['fr', 'en']) {
    for (final key in _consentKeys) {
      final value = keys[locale]?[key];
      expect(value, isNotNull,
          reason: 'Clé de consentement « $key » absente de $locale.');
      buffer
        ..write(locale)
        ..write(' ')
        ..write(key)
        ..write(' ')
        ..write(value);
    }
  }
  return sha256.convert(utf8.encode(buffer.toString())).toString();
}

void main() {
  final keys = AppTranslations().keys;

  test('la version courante est enregistrée dans le registre', () {
    expect(
      _fingerprints.containsKey(kPremiumWaitlistConsentVersion),
      isTrue,
      reason:
          'kPremiumWaitlistConsentVersion vaut « $kPremiumWaitlistConsentVersion », '
          'absente du registre de ce fichier.',
    );
  });

  test('la version courante désigne bien le texte actuellement affiché', () {
    final actual = _fingerprint(keys);
    expect(
      actual,
      _fingerprints[kPremiumWaitlistConsentVersion],
      reason: 'Le texte affiché a changé sans que '
          'kPremiumWaitlistConsentVersion bouge.\n\n'
          'Les lignes déjà en base portent « $kPremiumWaitlistConsentVersion » et '
          'désignaient l\'ANCIEN texte : laisser la constante inchangée ferait '
          'croire que ces inscriptions ont accepté le nouveau.\n\n'
          'Trois gestes : incrémenter la constante, ajouter son entrée au '
          'registre avec l\'empreinte ci-dessous, garder l\'ancienne.\n\n'
          'Empreinte actuelle : $actual',
    );
  });

  test('les deux langues portent un texte non vide et substantiel', () {
    // Un consentement affiché dans une seule langue laisserait l'autre moitié du
    // public valider un bouton sans savoir ce qu'elle accepte.
    for (final locale in const ['fr', 'en']) {
      for (final key in _consentKeys) {
        final value = keys[locale]?[key] ?? '';
        expect(value.trim(), isNotEmpty, reason: '$locale/$key est vide.');
        expect(value.length, greaterThan(40),
            reason: '$locale/$key est trop court pour être un consentement.');
      }
    }
  });

  test('le texte promet le retrait, et le retrait existe', () {
    // La promesse et le mécanisme ont été livrés ensemble ; ce test empêche
    // qu'une réécriture fasse disparaître l'une en gardant l'autre.
    expect(keys['fr']!['premium_waitlist_notice'], contains('retirer'));
    expect(keys['en']!['premium_waitlist_notice'], contains('leave'));
  });

  test('l\'écran n\'annonce ni prix ni paiement', () {
    // Règle App Store 3.1.1 : aucun achat intégré, et donc aucun montant ni
    // verbe d'abonnement sur une surface qui ne peut rien encaisser. La note
    // d'honnêteté de `premium_screen.dart` dit la même chose en prose ; ce test
    // la rend exécutable.
    const forbidden = <String>[
      'FCFA',
      'CFA',
      '€',
      'EUR',
      'USD',
      '\$',
      'abonn',
      'subscrib',
      'paiement',
      'payment',
      'checkout',
      'carte bancaire',
    ];
    for (final locale in const ['fr', 'en']) {
      for (final entry in keys[locale]!.entries) {
        if (!entry.key.startsWith('premium_pitch') &&
            !entry.key.startsWith('premium_waitlist')) {
          continue;
        }
        for (final needle in forbidden) {
          expect(
            entry.value.toLowerCase().contains(needle.toLowerCase()),
            isFalse,
            reason: '$locale/${entry.key} contient « $needle » : '
                'la liste d\'attente ne doit annoncer ni prix ni paiement.',
          );
        }
      }
    }
  });
}
