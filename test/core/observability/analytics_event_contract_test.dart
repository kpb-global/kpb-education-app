import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/observability/analytics_event_contract.dart';
import 'package:karatou/app/core/services/analytics_service.dart';

void main() {
  test('GA4 event names stay within typical length limits', () {
    const events = <String>[
      AnalyticsEventName.logout,
      AnalyticsEventName.orientationComplete,
      AnalyticsEventName.syncFullComplete,
      AnalyticsEventName.syncConflictResolved,
      AnalyticsEventName.syncCatalogHiveFallback,
      AnalyticsEventName.onboardingStepViewed,
      AnalyticsEventName.onboardingCompleted,
      AnalyticsEventName.onboardingSkipped,
      AnalyticsEventName.authFailed,
      AnalyticsEventName.dailyScholarshipViewed,
      AnalyticsEventName.dailyScholarshipOpened,
      AnalyticsEventName.eefHelpCardShown,
      AnalyticsEventName.eefHelpCtaTapped,
      AnalyticsEventName.eefBubbleOpened,
    ];
    for (final e in events) {
      expect(e.length, lessThanOrEqualTo(40), reason: e);
    }
  });

  // La carte d'aide de l'espace « Études en France » : deux événements, trois
  // identifiants fermés. Ce groupe est le cliquet de la règle « jamais de donnée
  // personnelle dans la mesure » — il rougit si quelqu'un ajoute une propriété.
  group('carte d\'aide Études en France', () {
    final snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

    test('les noms d\'événements sont ceux du contrat publié', () {
      expect(AnalyticsEventName.eefHelpCardShown, 'eef_help_card_shown');
      expect(AnalyticsEventName.eefHelpCtaTapped, 'eef_help_cta_tapped');
      for (final name in [
        AnalyticsEventName.eefHelpCardShown,
        AnalyticsEventName.eefHelpCtaTapped,
      ]) {
        expect(name, matches(snakeCase));
      }
    });

    test(
        'les clés de propriété sont en snake_case, et `step` n\'est pas '
        'réutilisée', () {
      expect(AnalyticsParamKey.helpStep, 'help_step');
      expect(AnalyticsParamKey.surface, 'surface');
      expect(AnalyticsParamKey.variant, 'variant');
      for (final key in [
        AnalyticsParamKey.helpStep,
        AnalyticsParamKey.surface,
        AnalyticsParamKey.variant,
      ]) {
        expect(key, matches(snakeCase));
      }
      // `step` est un entier (1-based) pour l'onboarding : deux types sous une
      // même clé de tableau de bord.
      expect(AnalyticsParamKey.helpStep, isNot(AnalyticsParamKey.step));
    });

    test('les propriétés envoyées sont EXACTEMENT ces trois clés', () {
      final params = AnalyticsService.eefHelpParams(
        step: 'hub',
        surface: 'hub',
        variant: 'card',
      );
      expect(
        params.keys.toSet(),
        {
          AnalyticsParamKey.helpStep,
          AnalyticsParamKey.surface,
          AnalyticsParamKey.variant,
        },
      );
      // `FirebaseAnalytics.logEvent` n'accepte que String ou num.
      for (final value in params.values) {
        expect(value, isA<String>());
      }
    });

    test('aucune clé de propriété ne désigne une donnée personnelle', () {
      final personal = RegExp(
        r'name|nom|mail|phone|tel|whatsapp|passport|passeport|country|pays|'
        r'user|uid|id$|profile|age|birth|address',
        caseSensitive: false,
      );
      final params = AnalyticsService.eefHelpParams(
        step: 'hub',
        surface: 'hub',
        variant: 'card',
      );
      for (final key in params.keys) {
        expect(personal.hasMatch(key), isFalse, reason: key);
      }
    });

    // Le contrat publié (docs/analytics-event-contract.md) doit citer les deux
    // événements et leurs propriétés : un événement sans ligne dans le contrat
    // est un événement que personne ne saura lire.
    test('docs/analytics-event-contract.md documente les deux événements', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_help_card_shown`',
        '`eef_help_cta_tapped`',
        '`help_step`',
        '`surface`',
        '`variant`',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });

  // La bulle d'aide (build 56) : elle réutilise les deux événements ci-dessus,
  // avec EXACTEMENT les mêmes trois propriétés, et n'ajoute qu'un événement —
  // l'ouverture du menu, qui n'est pas un envoi vers WhatsApp et ne doit donc
  // pas gonfler `eef_help_cta_tapped`.
  group('bulle d\'aide Études en France', () {
    final snakeCase = RegExp(r'^[a-z][a-z0-9]*(_[a-z0-9]+)*$');

    test('l\'événement neuf porte le nom du contrat publié', () {
      expect(AnalyticsEventName.eefBubbleOpened, 'eef_bubble_opened');
      expect(AnalyticsEventName.eefBubbleOpened, matches(snakeCase));
    });

    test('`eef_bubble_opened` ne porte QU\'une propriété : `surface`', () {
      final params = AnalyticsService.eefBubbleOpenedParams(surface: 'hub');
      expect(params.keys.toSet(), {AnalyticsParamKey.surface});
      for (final value in params.values) {
        expect(value, isA<String>());
      }
    });

    test(
        'les deux événements de la carte gardent EXACTEMENT leurs trois '
        'propriétés quand la bulle les utilise', () {
      final params = AnalyticsService.eefHelpParams(
        step: 'bubble_assistance',
        surface: 'catalog',
        variant: 'bubble',
      );
      expect(
        params.keys.toSet(),
        {
          AnalyticsParamKey.helpStep,
          AnalyticsParamKey.surface,
          AnalyticsParamKey.variant,
        },
      );
    });

    test('docs/analytics-event-contract.md documente la bulle', () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_bubble_opened`',
        '`bubble`',
        '`bubble_assistance`',
        '`bubble_dossier`',
        '`bubble_choose`',
        '`bubble_question`',
        'eef_help_bubble_',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });
  });
}
