import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/country_utils.dart';
import 'package:karatou/app/features/budget/data/budget_data.dart';

void main() {
  group('Budget simulator data (MVP lock)', () {
    test('ships a budget profile for every MVP destination', () {
      expect(mockBudgetProfiles.length, equals(kMvpCountryIds.length));
      final ids =
          mockBudgetProfiles.map((p) => normalizeCountryId(p.country)).toSet();
      expect(ids, equals(kMvpCountryIds));
    });

    test('every profile exposes the same nine spending categories', () {
      for (final p in mockBudgetProfiles) {
        expect(
          p.categories.length,
          equals(9),
          reason: '${p.country} should have 9 categories',
        );
      }
    });

    test('category order is canonical across all profiles', () {
      final reference =
          mockBudgetProfiles.first.categories.map((c) => c.name).toList();
      // Category names are now i18n keys (.tr); in tests .tr returns the key.
      expect(reference.first, equals('budget_category_rent'));
      expect(reference.last, equals('budget_category_leisure'));
      for (final p in mockBudgetProfiles) {
        expect(
          p.categories.map((c) => c.name).toList(),
          equals(reference),
          reason: '${p.country} category order diverges',
        );
      }
    });

    test('typical total stays within the min/max lifestyle band', () {
      for (final p in mockBudgetProfiles) {
        expect(
          p.totalTypical >= p.monthlyMin && p.totalTypical <= p.monthlyMax,
          isTrue,
          reason:
              '${p.country}: typical ${p.totalTypical} outside [${p.monthlyMin}, ${p.monthlyMax}]',
        );
      }
    });

    test('all category amounts are positive', () {
      for (final p in mockBudgetProfiles) {
        for (final c in p.categories) {
          expect(c.typical, greaterThan(0), reason: '${p.country} · ${c.name}');
        }
      }
    });
  });
}
