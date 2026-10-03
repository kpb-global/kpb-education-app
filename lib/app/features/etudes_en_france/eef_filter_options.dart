import 'package:get/get.dart';

import '../../core/models/eef_search.dart';
import 'eef_catalog_controller.dart';

/// Les familles de filtre, dans l'ordre où l'écran les montre : « Niveau »,
/// « Domaine », « Ville », « Procédure ».
///
/// La procédure vient en dernier parce que c'est la seule que l'étudiant a déjà
/// vue avant cette refonte, et la moins discriminante pour qui cherche « du droit
/// à Lyon » : on pose d'abord ce qu'on veut étudier, puis où.
enum EefFilterFamily {
  cycle(kEefFacetCycle, 'eef_catalog_facet_cycle'),
  field(kEefFacetField, 'eef_catalog_facet_field'),
  city(kEefFacetCity, 'eef_catalog_facet_city'),
  procedure(kEefFacetProcedure, 'eef_catalog_facet_procedure');

  const EefFilterFamily(this.facetKey, this.labelKey);

  /// Le nom de colonne côté serveur (`kEefFacet*`).
  final String facetKey;

  /// La clé de traduction du nom de la famille — bouton ET titre de la feuille.
  final String labelKey;
}

/// L'ordre d'un parcours d'études : de la 1re année de licence au master. C'est
/// celui qu'un étudiant lit sans y penser ; trier par nombre de formations ferait
/// passer « Master » devant « Licence 1re année » parce qu'il y a plus de masters.
const kEefCycleOrder = <String>[
  'licence1',
  'licence2',
  'licence3',
  'but1',
  'deust',
  'sante',
  'ingenieur',
  'master',
];

/// Une valeur proposée dans une feuille : ce qu'on envoie au serveur, ce qu'on
/// affiche, et combien de formations elle donnerait.
class EefFilterOption {
  EefFilterOption({required this.value, required this.label, this.count})
      : folded = eefFoldForSearch(label);

  /// Ce qui part dans la requête (`master`, `d07`, `Lyon`…).
  final String value;

  /// Ce que l'étudiant lit, dans la langue active.
  final String label;

  /// Le nombre de formations que ce choix donnerait — `null` quand on ne sait
  /// pas : une valeur choisie mais absente d'une liste tronquée (repli de la
  /// feuille « Ville »). Afficher 0 serait un chiffre inventé.
  final int? count;

  /// Le libellé plié pour la recherche locale ([eefFoldForSearch]).
  final String folded;
}

// ── Pliage pour la recherche locale ──────────────────────────────────────────

const _foldTable = <String, String>{
  'à': 'a', 'á': 'a', 'â': 'a', 'ã': 'a', 'ä': 'a', 'å': 'a', 'ā': 'a', //
  'ă': 'a', 'ą': 'a', 'æ': 'ae', //
  'ç': 'c', 'ć': 'c', 'č': 'c', //
  'ď': 'd', 'đ': 'd', //
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e', 'ė': 'e', 'ę': 'e', //
  'ě': 'e', //
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i', 'ı': 'i', //
  'ł': 'l', //
  'ñ': 'n', 'ń': 'n', 'ň': 'n', //
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'õ': 'o', 'ö': 'o', 'ø': 'o', 'ō': 'o', //
  'ő': 'o', 'œ': 'oe', //
  'ř': 'r', //
  'ś': 's', 'š': 's', 'ş': 's', 'ß': 'ss', //
  'ť': 't', //
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u', 'ů': 'u', 'ű': 'u', //
  'ý': 'y', 'ÿ': 'y', //
  'ź': 'z', 'ż': 'z', 'ž': 'z', //
};

/// Ce qui sépare deux mots dans un nom de ville — « Aix-en-Provence »,
/// « Villeneuve-d'Ascq », « L'Haÿ-les-Roses » : traits d'union, tirets,
/// apostrophes droite et typographique, points, virgules.
const _separators = <String>{
  '-', '–', '—', '‐', '‑', '_', "'", '’', '‘', '`', '´', '.', ',', '/', //
};

/// Minuscules, accents retirés, ponctuation de nom propre ramenée à une
/// espace, espaces réduites. C'est la forme sous laquelle on COMPARE — jamais
/// celle qu'on affiche.
///
/// Écrite ici plutôt que tirée d'un paquet : l'app n'a pas de dépendance de
/// translittération, et ce pliage est celui d'un seul usage — chercher une ville
/// dans une liste de quelques centaines. Les marques combinantes (U+0300–036F)
/// sont retirées : un clavier mobile peut produire « é » en deux points de code,
/// et la recherche ne doit pas le voir.
String eefFoldForSearch(String input) {
  final buffer = StringBuffer();
  for (final rune in input.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036F) continue;
    final char = String.fromCharCode(rune);
    if (_separators.contains(char)) {
      buffer.write(' ');
      continue;
    }
    buffer.write(_foldTable[char] ?? char);
  }
  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

int _compareLabels(String a, String b) {
  final folded = eefFoldForSearch(a).compareTo(eefFoldForSearch(b));
  // Départage stable : deux libellés qui se plient pareil (« Évry » et « Evry »)
  // ne doivent pas changer de place d'un affichage à l'autre.
  return folded != 0 ? folded : a.compareTo(b);
}

// ── Construction des listes ──────────────────────────────────────────────────

typedef _Row = ({String value, int? count});

/// Les valeurs servies, dédoublonnées (la première gagne), plus celles que
/// l'étudiant a CHOISIES et que la liste servie ne contient pas.
///
/// Ces dernières doivent rester visibles : une sélection qu'on ne voit pas, on
/// ne peut pas la décocher. [missingCount] dit leur compte — `0` quand la liste
/// servie est complète (une valeur absente n'a plus de formation sous les autres
/// filtres), `null` quand elle est tronquée (on ne sait pas).
List<_Row> _rows(
  List<EefFacetValue> facet,
  Set<String> selected,
  int? missingCount,
) {
  final seen = <String>{};
  final rows = <_Row>[];
  for (final entry in facet) {
    if (entry.value.trim().isEmpty || !seen.add(entry.value)) continue;
    rows.add((value: entry.value, count: entry.count));
  }
  for (final value in selected) {
    if (value.trim().isEmpty || !seen.add(value)) continue;
    rows.add((value: value, count: missingCount));
  }
  return rows;
}

/// Le libellé d'une valeur de facette, ou la valeur brute si l'app ne la connaît
/// pas. `.tr` rend la CLÉ quand elle manque : servir « eef_catalog_value_cycle_x »
/// à un étudiant serait pire que servir la valeur du serveur.
String eefFacetValueLabel(String facet, String value) {
  final key = 'eef_catalog_value_${facet}_$value';
  final translated = key.tr;
  return translated == key ? value : translated;
}

/// Niveau : l'ordre pédagogique de [kEefCycleOrder] ; une valeur que l'app ne
/// connaît pas va À LA SUITE, par compte décroissant (puis ordre alphabétique,
/// pour que l'ordre soit le même d'un affichage à l'autre).
List<EefFilterOption> eefCycleOptions(
  List<EefFacetValue> facet, {
  Set<String> selected = const <String>{},
  int? missingCount,
}) {
  final rows = _rows(facet, selected, missingCount);
  int rank(_Row row) {
    final index = kEefCycleOrder.indexOf(row.value);
    return index == -1 ? kEefCycleOrder.length : index;
  }

  rows.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    // Même rang ⇒ les deux sont inconnus (les connus ont un rang unique).
    final byCount = (b.count ?? -1).compareTo(a.count ?? -1);
    return byCount != 0 ? byCount : a.value.compareTo(b.value);
  });
  return [
    for (final row in rows)
      EefFilterOption(
        value: row.value,
        label: eefFacetValueLabel(kEefFacetCycle, row.value),
        count: row.count,
      ),
  ];
}

/// Procédure : l'ordre du serveur (le plus fourni d'abord), libellés localisés.
List<EefFilterOption> eefProcedureOptions(
  List<EefFacetValue> facet, {
  Set<String> selected = const <String>{},
  int? missingCount,
}) {
  return [
    for (final row in _rows(facet, selected, missingCount))
      EefFilterOption(
        value: row.value,
        label: eefFacetValueLabel(kEefFacetProcedure, row.value),
        count: row.count,
      ),
  ];
}

/// Domaine : les libellés du référentiel que l'app charge déjà, triés par
/// libellé. [nameOf] rend le nom localisé d'un identifiant (`d07`), ou `null`.
///
/// Un domaine SANS NOM est ignoré plutôt qu'affiché sous son code : « d07 »
/// n'apprend rien à un étudiant, et un code qui s'affiche est le signe d'un
/// référentiel qu'on n'a pas fini de charger.
List<EefFilterOption> eefFieldOptions(
  List<EefFacetValue> facet, {
  required String? Function(String id) nameOf,
  Set<String> selected = const <String>{},
  int? missingCount,
}) {
  final options = <EefFilterOption>[];
  for (final row in _rows(facet, selected, missingCount)) {
    final name = nameOf(row.value)?.trim();
    if (name == null || name.isEmpty) continue;
    options
        .add(EefFilterOption(value: row.value, label: name, count: row.count));
  }
  options.sort((a, b) => _compareLabels(a.label, b.label));
  return options;
}

/// Ville : les libellés bruts du serveur — `value` est la chaîne exacte à
/// renvoyer —, triés par compte décroissant, puis par ordre alphabétique sans
/// accents (« Évry » avant « Zoé », pas après).
List<EefFilterOption> eefCityOptions(
  List<EefFacetValue> facet, {
  Set<String> selected = const <String>{},
  int? missingCount,
}) {
  final rows = _rows(facet, selected, missingCount)
    ..sort((a, b) {
      final byCount = (b.count ?? -1).compareTo(a.count ?? -1);
      return byCount != 0 ? byCount : _compareLabels(a.value, b.value);
    });
  return [
    for (final row in rows)
      EefFilterOption(value: row.value, label: row.value, count: row.count),
  ];
}

/// La recherche locale de la feuille « Ville » : insensible aux accents, à la
/// casse et à la ponctuation (« aix en provence » trouve « Aix-en-Provence »).
/// Chaque mot tapé doit figurer dans le nom ; l'ordre de [options] est gardé.
List<EefFilterOption> eefFilterCityOptions(
  List<EefFilterOption> options,
  String query,
) {
  final terms = eefFoldForSearch(query).split(' ').where((t) => t.isNotEmpty);
  if (terms.isEmpty) return options;
  return [
    for (final option in options)
      if (terms.every(option.folded.contains)) option,
  ];
}
