// Lecture et classement de la fixture des 146 étiquettes de frais RÉELLES de la
// production (test/fixtures/prod_tuition_labels.txt).
//
// Ce fichier n'est PAS un test. Il est partagé par trois fichiers de test :
// tuition_reading_test.dart (le parseur), tuition_display_test.dart (ce qui va à
// l'écran) et tuition_utils_test.dart (le cliquet). Même patron que
// color_budget.dart / color_audit_test.dart.
//
// ## Ce qui a changé au lot 6, et pourquoi les noms ont changé avec
//
// Au lot 5, l'énumération ci-dessous s'appelait `TuitionCause` et ses valeurs
// nommaient des DÉFAUTS : `foreignTreatedAsEuro`, `cfaReconverted`. C'était juste
// à ce moment-là — le code traitait bien les dirhams comme des euros.
//
// Le lot 6 a corrigé le code. Ces noms décriraient maintenant un défaut qui
// n'existe plus, ce qui est la façon la plus sûre de rendre un test
// incompréhensible six mois plus tard. L'énumération décrit donc désormais des
// FORMES d'étiquette — des faits sur la donnée, qui ne changent pas quand le code
// change. Le cliquet, lui, mesure ce qui doit rester à zéro.

import 'dart:io';

/// Les espaces qui apparaissent RÉELLEMENT dans les étiquettes de production.
///
/// ÉCRITES EN ÉCHAPPEMENTS, jamais en caractères littéraux. Ce n'est pas une
/// coquetterie : la première version de ce fichier les portait en littéral, une
/// réécriture les a aplaties en trois espaces ordinaires, et `naiveFirstAmount`
/// s'est mis à lire « 12 » dans « 12 990 » — silencieusement, jusqu'à ce que le
/// cliquet le dise. Un caractère invisible qu'aucune relecture ne distingue n'a
/// rien à faire dans un littéral de code.
///
/// U+00A0 insécable · U+202F fine insécable (celle du back-office,
/// « 12 990 €/an ») · U+2009 fine.
const tuitionSpaces = ' \t\u00A0\u202F\u2009';

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

/// Les formes d'étiquette présentes dans le catalogue de production. Des FAITS
/// sur la donnée, pas des jugements sur le code. Chaque étiquette en reçoit
/// exactement une, dans l'ordre de priorité de [classifyTuition].
enum TuitionShape {
  /// Aucun chiffre : « Sur demande », étiquette vide. 2 étiquettes,
  /// 5 programmes.
  noAmount,

  /// Un montant annuel unique en euros. 49 étiquettes, 305 programmes — la
  /// majorité du catalogue, et la seule forme dont on sache produire un
  /// équivalent FCFA exact (parité fixe BCEAO).
  euroSingleAmount,

  /// Un montant unique dans une devise étrangère : MAD, AED, CAD, GBP, USD.
  /// 66 étiquettes, 177 programmes. Aucun taux fiable dans le dépôt, donc aucun
  /// équivalent affiché — l'étiquette parle d'elle-même.
  foreignCurrency,

  /// Déjà en francs CFA. 18 étiquettes, 48 programmes, essentiellement
  /// sénégalaises. C'est la forme qui souffrait le plus : re-multipliée par
  /// 655,957, elle s'affichait à 656 fois son prix.
  alreadyCfa,

  /// Pas UN montant annuel : une fourchette (« 11 490 € – 11 690 €/an selon le
  /// campus »), une abréviation (« 15k–45k »), ou un point-millier ambigu
  /// (« 9.850 »). 9 étiquettes, 45 programmes.
  notASingleAmount,

  /// Un coût TOTAL de programme (« 30 000 € (programme) »). 2 étiquettes,
  /// 2 programmes. Le piège : y coller « /an ».
  wholeProgrammeCost,
}

/// Les montants lisibles dans l'étiquette, virgules anglo-saxonnes retirées.
List<String> tuitionAmountsIn(String label) {
  final cleaned = label.replaceAll(',', '');
  return _numberish
      .allMatches(cleaned)
      .map((m) => m.group(0)!.replaceAll(_spaceClass, ''))
      .where((s) => s.isNotEmpty)
      .toList();
}

/// Le PREMIER nombre de l'étiquette — ce que voyait l'ancien parseur.
///
/// Conservé APRÈS le correctif, et c'est volontaire : c'est ce nombre, multiplié
/// par la parité de l'euro, qui donne la valeur mensongère que le cliquet
/// interdit désormais d'afficher. Sans lui, on ne pourrait plus formuler
/// l'interdiction.
int? naiveFirstAmount(String label) {
  final amounts = tuitionAmountsIn(label);
  if (amounts.isEmpty) return null;
  return int.tryParse(amounts.first);
}

/// La devise DÉCLARÉE dans l'étiquette, ou `null` si aucune.
///
/// Oracle INDÉPENDANT du parseur de production (`readTuition`) : les deux se
/// vérifient l'un contre l'autre dans tuition_reading_test.dart. Un oracle qui
/// appellerait le code testé ne prouverait rien.
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

/// Ordre de priorité, du plus spécifique au plus général.
TuitionShape classifyTuition(String label) {
  if (!_hasDigit.hasMatch(label)) return TuitionShape.noAmount;
  if (_kAbbrev.hasMatch(label)) return TuitionShape.notASingleAmount;
  if (_dotThousands.hasMatch(label)) return TuitionShape.notASingleAmount;
  if (tuitionAmountsIn(label).length > 1 && _dash.hasMatch(label)) {
    return TuitionShape.notASingleAmount;
  }
  if (_wholeProgramme.hasMatch(label)) return TuitionShape.wholeProgrammeCost;
  final currency = declaredCurrency(label);
  if (currency == 'XOF') return TuitionShape.alreadyCfa;
  if (currency == 'MAD' ||
      currency == 'AED' ||
      currency == 'CAD' ||
      currency == 'GBP' ||
      currency == 'USD') {
    return TuitionShape.foreignCurrency;
  }
  return TuitionShape.euroSingleAmount;
}

/// Les deux seules devises que le dépôt sache relier : la parité EUR/XOF est
/// FIXE (655,957, BCEAO) et n'a pas de date de péremption. Tout le reste
/// demanderait un taux à entretenir.
const tuitionPeggedCurrencies = <String>{'EUR', 'XOF'};

/// `true` quand AUCUN équivalent ne doit être affiché pour [label] à un
/// utilisateur qui lit en [displayCurrency].
///
/// C'est la DEVISE qui décide, pas la forme de l'étiquette. Une fourchette en
/// euros a un équivalent parfaitement calculable (« ≈ 7 536 946 – 7 668 137
/// FCFA ») ; une fourchette en dirhams n'en a aucun. Confondre les deux — ce que
/// faisait la première version de ce fichier, en classant par forme — donne un
/// test qui accuse le code d'inventer un taux là où il applique une parité fixe.
bool expectsNoEquivalent(String label, {String displayCurrency = 'XOF'}) {
  final declared = declaredCurrency(label);
  if (declared == null) return true;
  if (!tuitionPeggedCurrencies.contains(declared)) return true;
  // Même devise de part et d'autre : un équivalent serait du bruit.
  return declared == displayCurrency;
}

const tuitionFixturePath = 'test/fixtures/prod_tuition_labels.txt';

/// Lit la fixture. Échoue fort si elle est absente : un test qui se contenterait
/// d'une liste vide passerait au vert en ne mesurant rien.
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

/// Le regroupement par milliers de `CurrencyUtils.group`, reproduit pour pouvoir
/// écrire la chaîne INTERDITE sans appeler le code sous test. L'espace insérée
/// est une espace ORDINAIRE (U+0020) — vérifié contre trois littéraux figés dans
/// tuition_utils_test.dart.
String groupThousands(int value) {
  final digits = value.abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
    out.write(digits[i]);
  }
  return '${value < 0 ? '-' : ''}$out';
}

/// Le montant FCFA que l'ANCIEN code affichait pour [label] : le premier nombre
/// traité comme des euros. C'est la valeur qui ne doit plus jamais apparaître.
String? euroTreatedFcfa(String label, {double xofPerEur = 655.957}) {
  final amount = naiveFirstAmount(label);
  if (amount == null) return null;
  return groupThousands((amount * xofPerEur).round());
}
