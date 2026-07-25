import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/content_api_codec.dart';
import 'package:karatou/app/core/models/app_models.dart';

/// Guards KPB-166: editorial content now comes from the API, so the codec must
/// survive whatever the endpoint sends — including the two parallel-array shape
/// used for benefits/conditions — without ever throwing inside the sync.
void main() {
  group('serviceOffersFromApi', () {
    test('maps a full offer, zipping the parallel benefit arrays', () {
      final offers = ContentApiCodec.serviceOffersFromApi([
        {
          'id': 'off-1',
          'name': {'fr': 'Dossier prêt', 'en': 'Ready file'},
          'offerType': 'dossier',
          'destinationIds': ['fra', 'can'],
          'studyLevels': ['master'],
          'priceLabel': {'fr': '25 000 FCFA', 'en': 'XOF 25,000'},
          'benefits': {
            'fr': ['Relecture CV', 'Lettre'],
            'en': ['CV review', 'Letter'],
          },
          'ctaLabel': {'fr': 'Choisir', 'en': 'Choose'},
          'status': 'published',
        },
      ]);

      expect(offers, hasLength(1));
      final o = offers.single;
      expect(o.id, 'off-1');
      // The price is the whole point of the ticket: it must round-trip.
      expect(o.priceLabel.fr, '25 000 FCFA');
      expect(o.destinationIds, ['fra', 'can']);
      expect(o.status, PublicationStatus.published);
      expect(o.benefits, hasLength(2));
      expect(o.benefits.first.fr, 'Relecture CV');
      expect(o.benefits.first.en, 'CV review');
    });

    test('drops rows without an id rather than rendering a nameless offer', () {
      final offers = ContentApiCodec.serviceOffersFromApi([
        {
          'id': '',
          'name': {'fr': 'x', 'en': 'x'}
        },
        {
          'name': {'fr': 'y', 'en': 'y'}
        },
        {'id': 'ok'},
        'not-a-map',
      ]);
      expect(offers.map((o) => o.id), ['ok']);
    });

    test('falls back to the other locale when one side is missing', () {
      final o = ContentApiCodec.serviceOfferFromApi({
        'id': 'off-2',
        'name': {'fr': 'Seulement FR'},
        'priceKabel': 'typo-ignored',
      });
      expect(o.name.fr, 'Seulement FR');
      expect(o.name.en, 'Seulement FR');
      // Unknown status ⇒ draft, never a crash.
      expect(o.status, PublicationStatus.draft);
    });

    test('never throws on a malformed row (it must not break the sync)', () {
      expect(
        () => ContentApiCodec.serviceOfferFromApi({
          'id': 'off-3',
          'benefits': 'not-a-map',
          'destinationIds': 'not-a-list',
          'status': 42,
        }),
        returnsNormally,
      );
    });

    test('uses the longer side so no benefit line is silently truncated', () {
      final o = ContentApiCodec.serviceOfferFromApi({
        'id': 'off-4',
        'benefits': {
          'fr': ['un', 'deux', 'trois'],
          'en': ['one'],
        },
      });
      expect(o.benefits, hasLength(3));
      expect(o.benefits.last.fr, 'trois');
      expect(o.benefits.last.en, 'trois'); // missing EN falls back to FR
    });
  });

  group('supportDestinationsFromApi', () {
    test('maps a destination, conditions being a localized list', () {
      final list = ContentApiCodec.supportDestinationsFromApi([
        {
          'id': 'sup-1',
          'countryId': 'fra',
          'supportLanguages': ['fr'],
          'availableServiceTypes': ['visa'],
          'conditions': {
            'fr': ['Dossier complet'],
            'en': ['Complete file'],
          },
          'counselorNames': ['Awa'],
          'isVisible': false,
          'status': 'archived',
        },
      ]);

      expect(list, hasLength(1));
      final d = list.single;
      expect(d.countryId, 'fra');
      expect(d.conditions.single.fr, 'Dossier complet');
      expect(d.counselorNames, ['Awa']);
      expect(d.isVisible, isFalse);
      expect(d.status, PublicationStatus.archived);
    });

    test('defaults isVisible to true when the field is absent', () {
      final d = ContentApiCodec.supportDestinationFromApi({'id': 'sup-2'});
      expect(d.isVisible, isTrue);
      expect(d.conditions, isEmpty);
    });
  });
}
