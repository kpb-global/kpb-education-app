/// Parses annual tuition amounts from localized catalog strings.
abstract final class TuitionUtils {
  static const fcfaPerEur = 655;

  /// Extracts the first integer amount from a tuition label (EUR assumed).
  static int? parseEurAnnual(String tuition) {
    final match =
        RegExp(r'([\d\s]+)').firstMatch(tuition.replaceAll(',', ''));
    if (match == null) return null;
    final digits = match.group(1)?.replaceAll(RegExp(r'\s'), '') ?? '';
    return int.tryParse(digits);
  }

  static String formatFcfaEstimate(int eur) {
    final fcfa = (eur * fcfaPerEur).toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
    return '~ $fcfa FCFA/an';
  }

  static String fcfaSuffixFromTuition(String tuition) {
    final amount = parseEurAnnual(tuition);
    if (amount == null) return '';
    return formatFcfaEstimate(amount);
  }
}
