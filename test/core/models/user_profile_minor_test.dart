import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

UserProfile _profile({DateTime? birthDate, DateTime? guardianConsentedAt}) {
  return UserProfile(
    id: 'u1',
    accountType: AccountType.student,
    fullName: 'Test User',
    email: 't@e.com',
    phone: '+22500000000',
    whatsApp: '+22500000000',
    countryOfResidence: 'CI',
    preferredLanguage: 'fr',
    birthDate: birthDate,
    guardianConsentedAt: guardianConsentedAt,
  );
}

void main() {
  group('UserProfile age gate', () {
    final now = DateTime.now();

    test('no birth date → age null and never treated as a minor', () {
      final p = _profile();
      expect(p.age, isNull);
      expect(p.isMinor, isFalse);
    });

    test('clearly under 18 → minor', () {
      final p = _profile(birthDate: DateTime(now.year - 10, now.month, now.day));
      expect(p.age, anyOf(9, 10));
      expect(p.isMinor, isTrue);
    });

    test('clearly over 18 → not a minor', () {
      final p = _profile(birthDate: DateTime(now.year - 25, now.month, now.day));
      expect(p.isMinor, isFalse);
    });

    test('birthday not yet reached this year decrements the age', () {
      // Born 17 years ago but birthday is tomorrow → still 16.
      final tomorrow = now.add(const Duration(days: 1));
      final p = _profile(
        birthDate: DateTime(now.year - 17, tomorrow.month, tomorrow.day),
      );
      // Guard against month/day rollover ambiguity at year boundaries.
      if (tomorrow.year == now.year) {
        expect(p.age, 16);
        expect(p.isMinor, isTrue);
      }
    });

    test('guardian consent flag reflects the timestamp', () {
      expect(_profile().hasGuardianConsent, isFalse);
      expect(
        _profile(guardianConsentedAt: now).hasGuardianConsent,
        isTrue,
      );
    });
  });
}
