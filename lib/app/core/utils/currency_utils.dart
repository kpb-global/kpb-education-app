/// Display currencies supported by KPB. Tuition and budget values are stored
/// canonically in EUR so matching remains stable across the app.
enum DisplayCurrency {
  eur('EUR'),
  xof('XOF'),
  usd('USD');

  const DisplayCurrency(this.code);

  final String code;

  /// Devise reconnue, ou `null`. C'est la frontière d'entrée : le codec
  /// refuse (en repliant sur XOF) ce que cette méthode ne connaît pas.
  static DisplayCurrency? tryParse(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final upper = value.toUpperCase();
    for (final currency in values) {
      if (currency.code == upper) return currency;
    }
    return null;
  }

  /// Repli d'affichage. Ne JAMAIS `assert` ici : le serveur peut envoyer une
  /// devise inconnue, et un assert planterait les builds debug. La validation
  /// d'entrée est dans `ProfileApiCodec`.
  static DisplayCurrency fromCode(String? value) {
    return tryParse(value) ?? DisplayCurrency.xof;
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
    final value = group(amount);
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
      return '${approximate ? '~ ' : ''}${group(xof.round())} FCFA';
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

  /// Groupement par milliers avec une espace ORDINAIRE (U+0020).
  ///
  /// Public parce que l'affichage des équivalents de frais (`TuitionUtils`) doit
  /// produire exactement le même groupement : deux formateurs concurrents
  /// finiraient par diverger d'une espace, et une assertion de test comparant
  /// des chaînes deviendrait silencieusement inoffensive.
  static String group(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (match) => '${match[1]} ',
        );
  }
}
