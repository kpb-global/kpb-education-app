// Lecture et classement de la fixture des 146 étiquettes de frais RÉELLES de la
// production (test/fixtures/prod_tuition_labels.txt).
//
// Ce fichier n'est PAS un test : il est partagé par le cliquet
// (tuition_utils_test.dart, vert, exécuté par la CI) et par l'inventaire des
// défauts (tuition_defects_test.dart, rouge, tagué `known-defect`). Même patron
// que color_budget.dart / color_audit_test.dart.
//
// Règle de conception : rien ici ne dépend d'un taux de change. Lot 5 ne décide
// PAS des taux — c'est le travail du lot 6, et il exige une source. Les
// invariants vérifiables sans taux suffisent à prouver que l'affichage
// d'aujourd'hui est faux :
//   · un montant en dirhams multiplié par la parité de l'EURO est faux, quel que
//     soit le vrai taux du dirham ;
//   · un montant déjà en francs CFA re-multiplié par 655,957 est faux ;
//   · une fourchette réduite à sa borne basse est fausse ;
//   · un coût TOTAL de programme suffixé « /an » est faux.

import 'dart:io';

/// Les espaces qui apparaissent RÉELLEMENT dans les étiquettes de production.
/// Nommées explicitement plutôt que via `\s` : la fidélité aux octets est tout
/// l'intérêt de la fixture, et `\s` diffère d'un moteur à l'autre.
/// U+202F = espace fine insécable (« 12 990 €/an »), U+00A0 = insécable,
/// U+2009 = fine.
const tuitionSpaces = ' \t   ';

final _spaceClass = RegExp('[$tuitionSpaces]');
final _numberish = RegExp('[0-9$tuitionSpaces]+');

/// Un enregistrement de la fixture : combien de programmes de production portent
/// cette étiquette, et l'étiquette telle quelle.
class TuitionRecord {
  const TuitionRecord({required this.programCount, required this.label});

  final int programCount;
  final String label;

  @override
  String toString() => '$programCount× ${label.isEmpty ? '(vide)' : label}';
}

/// Les causes racines, une par défaut d'affichage. Chaque étiquette en reçoit
/// EXACTEMENT une, dans l'ordre de priorité de [classifyTuition] — sinon les
/// budgets se chevaucheraient et ne voudraient plus rien dire.
enum TuitionCause {
  /// Aucun chiffre : « Sur demande », étiquette vide. Aucun montant attendu, et
  /// c'est bien ce que le code fait. Pas un défaut.
  noAmountExpected,

  /// L'étiquette est en euros, montant annuel unique et propre. Le seul cas que
  /// le code d'aujourd'hui traite juste — par accident, puisqu'il suppose l'euro
  /// partout. Protégé par une assertion positive : un futur correctif ne doit
  /// pas le casser.
  euroCorrect,

  /// Devise étrangère (MAD, AED, CAD, GBP, USD) multipliée par la parité de
  /// l'EURO. C'est le défaut de masse.
  foreignTreatedAsEuro,

  /// Étiquette déjà en francs CFA, re-multipliée par 655,957. Le pire cas : un
  /// facteur 656 sur des prix sénégalais.
  cfaReconverted,

  /// L'étiquette ne porte PAS un montant annuel unique, et le code en affiche
  /// un quand même. Trois formes réelles : une fourchette réduite à sa borne
  /// basse (« 11 490 € – 11 690 €/an selon le campus », « 8 000 - 18 500 AED »),
  /// une abréviation (« USD 15k–45k/an » lue comme 15), un point utilisé comme
  /// séparateur de milliers (« 9.850 EUR/an » lue comme 9).
  notASingleAmount,

  /// Coût TOTAL du programme (« 30 000 € (programme) ») suffixé « /an ».
  totalShownAsAnnual,
}

/// Les montants lisibles dans l'étiquette, virgules anglo-saxonnes retirées
/// comme le fait le code de production.
List<String> tuitionAmountsIn(String label) {
  final cleaned = label.replaceAll(',', '');
  return _numberish
      .allMatches(cleaned)
      .map((m) => m.group(0)!.replaceAll(_spaceClass, ''))
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Le PREMIER nombre de l'étiquette — ce que voit `TuitionUtils.parseEurAnnual`.
/// Reproduit ici pour pouvoir calculer la valeur INTERDITE sans appeler le code
/// sous test (un oracle qui appellerait le code testé ne prouverait rien).
int? naiveFirstAmount(String label) {
  final amounts = tuitionAmountsIn(label);
  if (amounts.isEmpty) return null;
  return int.tryParse(amounts.first);
}

/// La devise DÉCLARÉE dans l'étiquette, ou `null` si aucune. Aucune étiquette de
/// production n'en porte deux (vérifié sur les 146 : voir la garde d'intégrité
/// `une seule devise par étiquette`).
String? declaredCurrency(String label) {
  for (final code in const ['EUR', 'MAD', 'AED', 'CAD', 'GBP', 'USD', 'XOF']) {
    if (label.contains(code)) return code;
  }
  if (label.contains('€')) return 'EUR';
  if (label.contains('FCFA')) return 'XOF';
  return null;
}

final _hasDigit = RegExp('[0-9]');
final _kAbbrev = RegExp('[0-9][$tuitionSpaces]*k', caseSensitive: false);
final _dotThousands = RegExp(r'[0-9]\.[0-9]{3}');
final _dash = RegExp('[-–—]');
final _wholeProgramme = RegExp(r'\(programme\)', caseSensitive: false);

/// Ordre de priorité, du plus spécifique au plus général. Cet ordre est la
/// définition des budgets : le changer redistribue les compteurs.
TuitionCause classifyTuition(String label) {
  if (!_hasDigit.hasMatch(label)) return TuitionCause.noAmountExpected;
  // « 15k–45k » : le parseur lit 15 et affiche 9 839 FCFA/an.
  if (_kAbbrev.hasMatch(label)) return TuitionCause.notASingleAmount;
  // « 9.850 EUR/an » : le point n'est pas retiré, le parseur lit 9.
  if (_dotThousands.hasMatch(label)) return TuitionCause.notASingleAmount;
  if (tuitionAmountsIn(label).length > 1 && _dash.hasMatch(label)) {
    return TuitionCause.notASingleAmount;
  }
  if (_wholeProgramme.hasMatch(label)) return TuitionCause.totalShownAsAnnual;
  final currency = declaredCurrency(label);
  if (currency == 'XOF') return TuitionCause.cfaReconverted;
  if (currency == 'MAD' ||
      currency == 'AED' ||
      currency == 'CAD' ||
      currency == 'GBP' ||
      currency == 'USD') {
    return TuitionCause.foreignTreatedAsEuro;
  }
  return TuitionCause.euroCorrect;
}

/// Les causes qui sont des DÉFAUTS (les deux autres décrivent un comportement
/// correct qu'il faut protéger).
const tuitionDefectCauses = <TuitionCause>{
  TuitionCause.foreignTreatedAsEuro,
  TuitionCause.cfaReconverted,
  TuitionCause.notASingleAmount,
  TuitionCause.totalShownAsAnnual,
};

const tuitionFixturePath = 'test/fixtures/prod_tuition_labels.txt';

/// Lit la fixture. Échoue fort si elle est absente : un test qui se contenterait
/// d'une liste vide passerait au vert en ne mesurant rien — le motif exact que
/// ce lot existe pour supprimer.
List<TuitionRecord> loadTuitionFixture() {
  final file = File(tuitionFixturePath);
  if (!file.existsSync()) {
    throw StateError(
      'Fixture introuvable : $tuitionFixturePath (depuis '
      '${Directory.current.path}). Sans elle ce test ne mesure rien et '
      "passerait au vert : c'est pour ça qu'il refuse de démarrer.",
    );
  }
  final records = <TuitionRecord>[];
  var lineNumber = 0;
  for (final line in file.readAsLinesSync()) {
    lineNumber++;
    if (line.isEmpty || line.startsWith('#')) continue;
    final tab = line.indexOf('\t');
    if (tab < 0) {
      throw StateError(
        '$tuitionFixturePath:$lineNumber — format attendu '
        '« <nombre de programmes><TAB><étiquette> », lu : ${line.trim()}',
      );
    }
    final count = int.tryParse(line.substring(0, tab));
    if (count == null) {
      throw StateError(
        '$tuitionFixturePath:$lineNumber — nombre de programmes illisible.',
      );
    }
    records.add(
      TuitionRecord(programCount: count, label: line.substring(tab + 1)),
    );
  }
  return records;
}

/// Le regroupement par milliers de `CurrencyUtils._group`, reproduit pour
/// pouvoir écrire la chaîne INTERDITE sans appeler le code sous test.
/// L'espace inséré est une espace ORDINAIRE (U+0020) — vérifié par une garde
/// dans tuition_utils_test.dart contre trois littéraux figés.
String groupThousands(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$out';
}

/// Le montant FCFA que le code d'aujourd'hui affiche pour [label] : le premier
/// nombre traité comme des euros. C'est la valeur qui doit DISPARAÎTRE.
String? euroTreatedFcfa(String label, {double xofPerEur = 655.957}) {
  final amount = naiveFirstAmount(label);
  if (amount == null) return null;
  return groupThousands((amount * xofPerEur).round());
}
