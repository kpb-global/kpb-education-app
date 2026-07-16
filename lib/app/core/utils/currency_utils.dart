/// Display currencies supported by KPB. Tuition and budget values are stored
/// canonically in EUR so matching remains stable across the app.
enum DisplayCurrency {
  eur('EUR'),
  xof('XOF'),
  usd('USD');

  const DisplayCurrency(this.code);

  final String code;

  static DisplayCurrency fromCode(String? value) {
    return DisplayCurrency.values.firstWhere(
      (currency) => currency.code == value?.toUpperCase(),
      orElse: () => DisplayCurrency.xof,
    );
  }
}

/// Offline, indicative display conversion for catalog prices that are stored
/// in EUR. XOF uses its fixed EUR parity. USD deliberately remains an
/// indicative offline conversion, not a payment or exchange-rate quote.
abstract final class CurrencyUtils {
  static const double xofPerEur = 655.957;
  static const double usdPerEur = 1.08;

  static String formatEur(
    num eur,
    String? currencyCode, {
    bool approximate = false,
    bool perYear = true,
  }) {
    final currency = DisplayCurrency.fromCode(currencyCode);
    final amount = switch (currency) {
      DisplayCurrency.eur => eur.round(),
      DisplayCurrency.xof => (eur * xofPerEur).round(),
      DisplayCurrency.usd => (eur * usdPerEur).round(),
    };
    final value = _group(amount);
    final prefix = approximate ? '~ ' : '';
    final unit = switch (currency) {
      DisplayCurrency.eur => '$value €',
      DisplayCurrency.xof => '$value FCFA',
      DisplayCurrency.usd => '\$$value',
    };
    return perYear ? '$prefix$unit/an' : '$prefix$unit';
  }

  static String formatXof(
    num xof,
    String? currencyCode, {
    bool approximate = false,
  }) {
    final currency = DisplayCurrency.fromCode(currencyCode);
    if (currency == DisplayCurrency.xof) {
      return '${approximate ? '~ ' : ''}${_group(xof.round())} FCFA';
    }
    return formatEur(
      xof / xofPerEur,
      currency.code,
      approximate: approximate,
      perYear: false,
    );
  }

  static String compactEur(num eur, String? currencyCode) {
    final currency = DisplayCurrency.fromCode(currencyCode);
    final amount = switch (currency) {
      DisplayCurrency.eur => eur,
      DisplayCurrency.xof => eur * xofPerEur,
      DisplayCurrency.usd => eur * usdPerEur,
    };
    if (currency == DisplayCurrency.xof) {
      return '${(amount / 1000000).toStringAsFixed(0)} M FCFA';
    }
    final roundedThousands = (amount / 1000).round();
    return currency == DisplayCurrency.usd
        ? '\$$roundedThousands K'
        : '$roundedThousands K €';
  }

  static String _group(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        );
  }
}
