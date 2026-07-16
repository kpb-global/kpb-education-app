import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/utils/currency_utils.dart';

void main() {
  group('CurrencyUtils', () {
    test('formats canonical EUR tuition in every supported display currency',
        () {
      expect(CurrencyUtils.formatEur(10000, 'EUR'), '10 000 €/an');
      expect(CurrencyUtils.formatEur(10000, 'XOF'), '6 559 570 FCFA/an');
      expect(CurrencyUtils.formatEur(10000, 'USD'), r'$10 800/an');
    });

    test('uses XOF as the safe default for unknown currency values', () {
      expect(CurrencyUtils.formatEur(5000, 'invalid'), '3 279 785 FCFA/an');
    });

    test('keeps filter labels compact in the selected currency', () {
      expect(CurrencyUtils.compactEur(4573, 'XOF'), '3 M FCFA');
      expect(CurrencyUtils.compactEur(4573, 'EUR'), '5 K €');
      expect(CurrencyUtils.compactEur(4573, 'USD'), r'$5 K');
    });
  });
}
