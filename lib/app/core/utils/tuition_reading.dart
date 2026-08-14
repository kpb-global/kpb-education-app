/// La lecture d'une étiquette de frais de scolarité : ce qu'elle dit vraiment,
/// devise comprise — ou un refus assumé.
///
/// ## Pourquoi ce fichier existe
///
/// Le parseur d'avant tenait en six lignes : il prenait le premier nombre de
/// l'étiquette et le déclarait « euros ». Sur les 582 programmes servis par la
/// production, 272 affichaient donc un prix faux, dont 48 faux d'un facteur 656
/// — des formations sénégalaises libellées en francs CFA, re-multipliées par la
/// parité de l'euro, et présentées à 754 millions de francs.
///
/// Le défaut n'était même pas seulement cosmétique : `ProgramFilterService`
/// appelait le même parseur, donc le curseur « budget maximum » comparait
/// 40 000 dirhams à 30 000 euros et faisait DISPARAÎTRE les formations parmi
/// les moins chères du catalogue.
///
/// ## La règle
///
/// **Lire la devise écrite, ne jamais la deviner, et refuser plutôt
/// qu'approximer.** Un refus est une information exploitable : l'appelant sait
/// qu'il doit afficher l'étiquette telle quelle et ne rien convertir. Une
/// approximation muette, elle, se propage jusqu'à l'écran d'un étudiant.
library;

/// Les sept familles de devises RÉELLEMENT présentes dans le catalogue de
/// production (relevé du 14/08/2026 sur les 582 programmes), plus CNY qui
/// n'existe que dans le catalogue de repli embarqué.
///
/// Ce n'est pas la liste des devises d'AFFICHAGE (`DisplayCurrency`) : c'est la
/// liste de ce qu'une étiquette peut déclarer. Les deux ne se recouvrent qu'en
/// partie, et confondre les deux est précisément le mécanisme du défaut.
enum TuitionCurrency {
  eur('EUR'),
  usd('USD'),
  mad('MAD'),
  aed('AED'),
  cad('CAD'),
  gbp('GBP'),
  xof('XOF'),
  cny('CNY');

  const TuitionCurrency(this.code);

  final String code;
}

/// Les espaces qui apparaissent réellement dans les étiquettes de production.
///
/// Nommées une par une plutôt que via `\s` : l'espace fine insécable U+202F
/// (« 12 990 €/an ») est celle que le back-office produit, et une classe
/// d'échappement dont le contenu varie d'un moteur à l'autre n'est pas une base
/// solide pour lire de l'argent.
const _spaceChars = ' \t   ';

final _spaces = RegExp('[$_spaceChars]');

/// Un nombre entier, éventuellement coupé par des espaces de groupement,
/// éventuellement suivi de l'abréviation « k » (× 1000).
final _amount = RegExp('([0-9][0-9$_spaceChars]*)(k)?', caseSensitive: false);

/// Un point suivi de trois chiffres : « 9.850 ». Irréductiblement ambigu — 9 850
/// ou 9,85 ? — donc motif de refus. C'est le format du catalogue de repli
/// français, et l'ancien parseur y lisait « 9 », soit 5 904 FCFA au lieu de
/// 6,5 millions.
final _dotThousands = RegExp(r'[0-9]\.[0-9]{3}');

/// Le séparateur d'une fourchette. Trois tirets circulent dans les données :
/// le trait d'union, le demi-cadratin U+2013 (« 11 490 € – 11 690 € ») et le
/// cadratin.
final _rangeDash = RegExp(r'[-–—]');

/// Ce qu'une étiquette de frais dit, une fois lue.
///
/// [amount] est le montant, ou la borne BASSE d'une fourchette. [amountMax] ne
/// vaut non-nul que pour une fourchette. Les deux sont dans [currency] — jamais
/// convertis : la conversion est une décision d'affichage, prise ailleurs et
/// seulement quand elle ne demande aucun taux à entretenir.
class TuitionReading {
  const TuitionReading({
    required this.amount,
    required this.currency,
    this.amountMax,
  });

  final int amount;
  final int? amountMax;
  final TuitionCurrency currency;

  bool get isRange => amountMax != null;

  @override
  String toString() => isRange
      ? '${currency.code} $amount–$amountMax'
      : '${currency.code} $amount';

  @override
  bool operator ==(Object other) =>
      other is TuitionReading &&
      other.amount == amount &&
      other.amountMax == amountMax &&
      other.currency == currency;

  @override
  int get hashCode => Object.hash(amount, amountMax, currency);
}

/// Lit [label] et rend ce qu'il dit, ou `null` s'il refuse.
///
/// Les quatre motifs de refus, chacun préférable à une valeur inventée :
///
/// 1. **Aucune devise reconnue.** « 12 000 » tout court peut être n'importe
///    quoi. L'ancien parseur tranchait pour l'euro ; celui-ci ne tranche pas.
/// 2. **Un point suivi de trois chiffres.** « 9.850 » est ambigu. Le catalogue
///    de repli en contient une centaine ; TUI-T4 les normalise, mais le refus
///    reste, pour que le prochain format inconnu soit refusé et non deviné.
/// 3. **Deux familles de devises dans la même étiquette.** Jamais vu en
///    production (les 146 étiquettes n'en portent qu'une), mais une donnée
///    d'entrée n'a pas à être supposée propre.
/// 4. **Aucun entier lisible.** « Sur demande », une chaîne vide.
///
/// Ce qu'il sait lire, en revanche : la devise en préfixe (« MAD 35 000 ») comme
/// en suffixe (« 40 000 MAD »), le symbole (« 12 990 € », « $8 500 »), la
/// virgule anglo-saxonne de groupement (« MAD 35,000 »), l'espace fine
/// insécable, l'abréviation « k » (« 15k » = 15 000) et les fourchettes
/// (« 8 000 - 18 500 AED », « 11 490 € – 11 690 €/an selon le campus »).
TuitionReading? readTuition(String label) {
  if (label.trim().isEmpty) return null;

  // Motif de refus n°2, testé AVANT toute normalisation : retirer les virgules
  // ne rend pas « 9.850 » moins ambigu.
  if (_dotThousands.hasMatch(label)) return null;

  final currency = _detectCurrency(label);
  if (currency == null) return null;

  // La virgule anglo-saxonne est un séparateur de milliers dans ce catalogue
  // (« MAD 35,000/an », « USD 1,200/an »), jamais un séparateur décimal.
  final normalized = label.replaceAll(',', '');

  final amounts = <int>[];
  for (final match in _amount.allMatches(normalized)) {
    final digits = match.group(1)!.replaceAll(_spaces, '');
    final parsed = int.tryParse(digits);
    if (parsed == null) continue;
    final isThousands = match.group(2) != null;
    amounts.add(isThousands ? parsed * 1000 : parsed);
  }
  if (amounts.isEmpty) return null;

  // Une fourchette a besoin de DEUX montants ET d'un tiret entre eux. Le second
  // nombre d'une étiquette comme « 5 500 €/an (B1) » n'en est pas une.
  if (amounts.length >= 2 && _rangeDash.hasMatch(normalized)) {
    final low = amounts[0];
    final high = amounts[1];
    if (high > low) {
      return TuitionReading(amount: low, amountMax: high, currency: currency);
    }
  }

  return TuitionReading(amount: amounts.first, currency: currency);
}

/// Les codes alphabétiques, cherchés comme des MOTS ENTIERS.
///
/// La délimitation n'est pas un raffinement : « ACADÉMIQUE » contient « CAD » et
/// « EUROS » contient « EUR ». Sans elle, « Frais académiques : 12 000 € »
/// déclencherait deux familles et se ferait refuser — un refus injustifié reste
/// une perte d'information.
const _alphaMarkers = <String, TuitionCurrency>{
  'FCFA': TuitionCurrency.xof,
  'XOF': TuitionCurrency.xof,
  'EUR': TuitionCurrency.eur,
  'EUROS': TuitionCurrency.eur,
  'MAD': TuitionCurrency.mad,
  'AED': TuitionCurrency.aed,
  'CAD': TuitionCurrency.cad,
  'GBP': TuitionCurrency.gbp,
  'CNY': TuitionCurrency.cny,
  'USD': TuitionCurrency.usd,
};

/// Les symboles, qui n'ont pas de frontière de mot.
///
/// « $ » est ambigu entre plusieurs dollars ; on le rattache à l'USD parce que
/// c'est le seul dollar que ce catalogue écrit ainsi — le canadien y est
/// toujours « CAD ».
const _symbolMarkers = <String, TuitionCurrency>{
  '€': TuitionCurrency.eur,
  '\$': TuitionCurrency.usd,
};

/// La devise déclarée, ou `null` si aucune — ou si plusieurs, ce qui est un
/// refus et non un arbitrage.
TuitionCurrency? _detectCurrency(String label) {
  final upper = label.toUpperCase();
  final found = <TuitionCurrency>{};
  for (final entry in _alphaMarkers.entries) {
    // Mot entier : encadré par autre chose qu'une lettre latine.
    if (RegExp('(?<![A-Z])${entry.key}(?![A-Z])').hasMatch(upper)) {
      found.add(entry.value);
    }
  }
  for (final entry in _symbolMarkers.entries) {
    if (upper.contains(entry.key)) found.add(entry.value);
  }
  if (found.length != 1) return null;
  return found.first;
}
