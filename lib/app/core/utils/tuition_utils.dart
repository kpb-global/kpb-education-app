import 'currency_utils.dart';

/// Parses annual tuition amounts from localized catalog strings.
abstract final class TuitionUtils {
  static const fcfaPerEur = CurrencyUtils.xofPerEur;

  /// Extracts the first integer amount from a tuition label (EUR assumed).
  static int? parseEurAnnual(String tuition) {
    final match = RegExp(r'([\d\s]+)').firstMatch(tuition.replaceAll(',', ''));
    if (match == null) return null;
    final digits = match.group(1)?.replaceAll(RegExp(r'\s'), '') ?? '';
    return int.tryParse(digits);
  }

  static String formatTuition(
    int eur,
    String? currencyCode, {
    bool approximate = true,
  }) {
    return CurrencyUtils.formatEur(
      eur,
      currencyCode,
      approximate: approximate,
    );
  }

  static String displayFromTuition(String tuition, String? currencyCode) {
    final amount = parseEurAnnual(tuition);
    if (amount == null) return '';
    return formatTuition(amount, currencyCode);
  }

  @Deprecated('Use displayFromTuition with the profile currency.')
  static String fcfaSuffixFromTuition(String tuition) =>
      displayFromTuition(tuition, DisplayCurrency.xof.code);
}
