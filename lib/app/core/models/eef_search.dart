import 'app_models.dart';

/// Une valeur de facette et son compte, tels que le serveur les rend.
///
/// Le compte n'est pas décoratif : il est calculé SANS le filtre de sa propre
/// facette, donc il répond à « combien en aurais-je si je choisissais celle-ci
/// à la place ». Un sélecteur qui afficherait zéro partout dès le premier choix
/// obligerait l'étudiant à défaire son filtre pour explorer.
class EefFacetValue {
  const EefFacetValue({required this.value, required this.count});

  final String value;
  final int count;

  factory EefFacetValue.fromJson(Map<String, dynamic> json) => EefFacetValue(
        value: json['value'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

/// Une page de résultats de `GET /etudes-en-france/search`.
///
/// ## Pourquoi un curseur et pas un numéro de page
///
/// Le curseur porte la POSITION du dernier élément vu, pas un rang. Si un
/// administrateur publie une fiche pendant qu'un étudiant fait défiler, un
/// décalage de rang lui ferait sauter une formation sans qu'il le sache ; le
/// curseur, non. Le client n'a donc rien à compter : il repasse `nextCursor`
/// tel quel, sans jamais l'interpréter.
class EefSearchPage {
  const EefSearchPage({
    required this.items,
    required this.total,
    required this.hasMore,
    required this.nextCursor,
    required this.facets,
    required this.facetsTruncated,
  });

  final List<ProgramModel> items;

  /// Le nombre total de formations correspondant aux filtres — pas le nombre
  /// d'éléments de cette page.
  final int total;
  final bool hasMore;
  final String? nextCursor;

  /// Facettes par nom de colonne : `procedureType`, `cycle`, `fieldId`,
  /// `selectivity`, `campusCity`, `institutionId`.
  final Map<String, List<EefFacetValue>> facets;

  /// Facettes dont le serveur n'a rendu que les valeurs les plus fournies.
  /// L'écran doit le dire plutôt que de laisser croire à une liste complète.
  final List<String> facetsTruncated;

  static const EefSearchPage empty = EefSearchPage(
    items: <ProgramModel>[],
    total: 0,
    hasMore: false,
    nextCursor: null,
    facets: <String, List<EefFacetValue>>{},
    facetsTruncated: <String>[],
  );

  factory EefSearchPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map(ProgramModel.fromJson)
            .toList()
        : <ProgramModel>[];

    final page = json['page'];
    final pageMap = page is Map<String, dynamic> ? page : const {};

    final rawFacets = json['facets'];
    final facets = <String, List<EefFacetValue>>{};
    if (rawFacets is Map) {
      rawFacets.forEach((key, value) {
        if (value is! List) return;
        facets['$key'] = value
            .whereType<Map<String, dynamic>>()
            .map(EefFacetValue.fromJson)
            .where((entry) => entry.value.isNotEmpty)
            .toList();
      });
    }

    final rawTruncated = json['facetsTruncated'];

    return EefSearchPage(
      items: items,
      total: (json['total'] as num?)?.toInt() ?? items.length,
      hasMore: pageMap['hasMore'] == true,
      nextCursor: pageMap['nextCursor'] as String?,
      facets: facets,
      facetsTruncated: rawTruncated is List
          ? rawTruncated.whereType<String>().toList()
          : const <String>[],
    );
  }
}
