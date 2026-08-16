import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/data/profile_api_codec.dart';

void main() {
  group('ProfileApiCodec.userProfileFromApi', () {
    test('parses a minimal payload with an id', () {
      final profile = ProfileApiCodec.userProfileFromApi(
        {'id': 'user-123', 'fullName': 'Aïcha'},
        fallbackLocale: 'fr',
      );
      expect(profile.id, 'user-123');
      expect(profile.fullName, 'Aïcha');
      expect(profile.preferredLanguage, 'fr');
    });

    test('throws FormatException when id is missing', () {
      expect(
        () => ProfileApiCodec.userProfileFromApi(
          {'fullName': 'Aïcha'},
          fallbackLocale: 'fr',
        ),
        throwsFormatException,
      );
    });

    test('throws FormatException when id is empty', () {
      expect(
        () => ProfileApiCodec.userProfileFromApi(
          {'id': '', 'fullName': 'Aïcha'},
          fallbackLocale: 'fr',
        ),
        throwsFormatException,
      );
    });

    test('une devise inconnue est refusée à la frontière (repli XOF)', () {
      final profile = ProfileApiCodec.userProfileFromApi(
        {'id': 'user-123', 'preferredCurrency': 'GBP'},
        fallbackLocale: 'fr',
      );
      expect(profile.preferredCurrency, 'XOF');
    });

    test('EUR et USD passent', () {
      expect(
        ProfileApiCodec.userProfileFromApi(
          {'id': 'user-123', 'preferredCurrency': 'eur'},
          fallbackLocale: 'fr',
        ).preferredCurrency,
        'EUR',
      );
      expect(
        ProfileApiCodec.userProfileFromApi(
          {'id': 'user-123', 'preferredCurrency': 'USD'},
          fallbackLocale: 'fr',
        ).preferredCurrency,
        'USD',
      );
    });
  });
}
