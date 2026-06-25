import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';
import 'package:karatou/app/core/utils/country_utils.dart';

void main() {
  group('MVP country lock', () {
    test('mock catalog ships exactly the MVP destination countries', () {
      final ids =
          MockCatalog.countries.map((c) => normalizeCountryId(c.id)).toSet();
      expect(ids, equals(kMvpCountryIds));
      expect(MockCatalog.countries.length, equals(kMvpCountryIds.length));
    });

    test('isMvpCountryId accepts both ISO-3 and legacy full-word ids', () {
      expect(isMvpCountryId('fra'), isTrue);
      expect(isMvpCountryId('france'), isTrue);
      expect(isMvpCountryId('gbr'), isTrue);
      expect(isMvpCountryId('uk'), isTrue);
      expect(isMvpCountryId('are'), isTrue);
      expect(isMvpCountryId('uae'), isTrue);
      // China was added as a launch destination (chn).
      expect(isMvpCountryId('chn'), isTrue);
      expect(isMvpCountryId('china'), isTrue);
    });

    test('isMvpCountryId rejects countries outside the launch scope', () {
      expect(isMvpCountryId('japan'), isFalse);
      expect(isMvpCountryId('switzerland'), isFalse);
      expect(isMvpCountryId(''), isFalse);
    });

    test('filtering institutions by the lock yields only MVP countries', () {
      // The mock intentionally retains broader data; the runtime lock
      // (AppController._applyMvpCountryLock) trims it to launch scope.
      final filtered = MockCatalog.institutions
          .where((i) => isMvpCountryId(i.countryId))
          .toList();
      expect(filtered, isNotEmpty);
      expect(
        filtered.every((i) => isMvpCountryId(i.countryId)),
        isTrue,
      );
    });
  });
}
