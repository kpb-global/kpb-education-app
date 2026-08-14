import 'currency_utils.dart';
import 'tuition_reading.dart';

/// L'affichage des frais de scolarité : l'étiquette telle qu'elle est écrite,
/// plus un équivalent quand on sait le calculer SANS taux à entretenir.
///
/// ## La règle, et pourquoi elle est celle-là
///
/// Avant, la conversion REMPLAÇAIT l'étiquette : « MAD 40 000/an » devenait
/// « ~ 26 238 280 FCFA/an ». Deux dégâts distincts, pour le prix d'un :
///   · le montant était faux (les dirhams multipliés par la parité de l'euro) ;
///   · et l'information d'origine avait disparu, donc l'étudiant n'avait aucun
///     moyen de s'en apercevoir. Les 44 étiquettes « … – … €/an selon le
///     campus » perdaient de la même façon leur fourchette ET leur nuance.
///
/// Maintenant l'étiquette reste, et l'équivalent s'AJOUTE quand il est calculable
/// honnêtement. Ce que « honnêtement » veut dire ici, très précisément :
///
///   · **EUR ⇄ XOF** : la parité est FIXE (655,957, décidée par la BCEAO et
///     inchangée depuis 1999). La conversion est exacte, elle ne périme pas, on
///     la fait.
///   · **EUR/XOF → USD** : indicatif, via la constante `usdPerEur` déjà
///     présente. Le préfixe « ≈ » le dit.
///   · **MAD, AED, CAD, GBP, CNY** : AUCUN montant converti. Nous n'avons pas de
///     flux de taux, et un taux figé dans le code dérive en silence. Afficher
///     « MAD 40 000/an » est honnête, gratuit, et immédiatement compréhensible.
///
/// Une table de taux indicative existe bien dans le dépôt, mais uniquement pour
/// COMPARER (le filtre budget de `ProgramFilterService`) — jamais pour afficher,
/// et un test l'exige.
abstract final class TuitionUtils {
  /// La parité fixe EUR/XOF, exposée pour les appelants qui raisonnent en FCFA.
  static const fcfaPerEur = CurrencyUtils.xofPerEur;

  /// L'équivalent de ce que déclare [label] dans la devise d'affichage
  /// [preferredCurrencyCode], préfixé « ≈ » — ou `null` quand on ne sait pas le
  /// calculer sans taux à entretenir.
  ///
  /// Rend `null` aussi quand l'équivalent serait redondant (une étiquette en
  /// euros pour un utilisateur qui affiche en euros).
  static String? equivalentFor(String label, String? preferredCurrencyCode) {
    final reading = readTuition(label);
    if (reading == null) return null;

    final target = DisplayCurrency.fromCode(preferredCurrencyCode);
    final low = _convert(reading.amount, reading.currency, target);
    if (low == null) return null;

    if (!reading.isRange) return '≈ ${_formatIn(target, low)}';

    final high = _convert(reading.amountMax!, reading.currency, target);
    if (high == null) return '≈ ${_formatIn(target, low)}';
    // La borne basse ne répète pas la devise : « ≈ 7 536 946 – 7 668 138 FCFA ».
    return '≈ ${CurrencyUtils.group(low.round())} – ${_formatIn(target, high)}';
  }

  /// Ce qui va à l'écran : l'étiquette d'origine, et l'équivalent quand il
  /// existe.
  ///
  /// Exemples réels du catalogue de production :
  ///   « MAD 40 000/an »                        → « MAD 40 000/an »
  ///   « 12 990 €/an »                          → « 12 990 €/an · ≈ 8 520 881 FCFA »
  ///   « XOF 1 150 000/an (est.) »              → « XOF 1 150 000/an (est.) »
  ///   « 11 490 € – 11 690 €/an selon le campus »
  ///        → « … selon le campus · ≈ 7 536 946 – 7 668 138 FCFA »
  ///   « Sur demande »                          → « Sur demande »
  ///
  /// L'équivalent ne porte JAMAIS « /an » : la périodicité est déjà dans
  /// l'étiquette, et c'est en la recollant que l'ancien code présentait
  /// « 30 000 € (programme) » comme un tarif annuel.
  static String tuitionForDisplay(String label, String? preferredCurrencyCode) {
    final trimmed = label.trim();
    final equivalent = equivalentFor(label, preferredCurrencyCode);
    if (equivalent == null) return trimmed;
    return '$trimmed · $equivalent';
  }

  /// Les conversions qu'on s'autorise, et elles seules.
  static num? _convert(
    num amount,
    TuitionCurrency from,
    DisplayCurrency to,
  ) {
    return switch ((from, to)) {
      // Parité fixe, exacte, sans date de péremption.
      (TuitionCurrency.eur, DisplayCurrency.xof) =>
        amount * CurrencyUtils.xofPerEur,
      (TuitionCurrency.xof, DisplayCurrency.eur) =>
        amount / CurrencyUtils.xofPerEur,
      // Indicatif, et annoncé comme tel par le « ≈ ».
      (TuitionCurrency.eur, DisplayCurrency.usd) =>
        amount * CurrencyUtils.usdPerEur,
      (TuitionCurrency.xof, DisplayCurrency.usd) =>
        amount / CurrencyUtils.xofPerEur * CurrencyUtils.usdPerEur,
      // Tout le reste : on ne sait pas, donc on ne dit rien. Y compris le cas
      // où la devise de l'étiquette est déjà celle de l'affichage, où un
      // équivalent serait du bruit.
      _ => null,
    };
  }

  static String _formatIn(DisplayCurrency currency, num value) {
    final grouped = CurrencyUtils.group(value.round());
    return switch (currency) {
      DisplayCurrency.xof => '$grouped FCFA',
      DisplayCurrency.eur => '$grouped €',
      DisplayCurrency.usd => '\$$grouped',
    };
  }
}
