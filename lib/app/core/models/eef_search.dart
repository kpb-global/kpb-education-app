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

/// L'établissement, en résumé : ce qu'il faut pour le nommer sur une carte et le
/// situer. La présentation et l'effectif restent sur la fiche (build 55).
///
/// « L1 - Droit » est proposée par une quarantaine d'universités : une carte qui
/// n'en nomme aucune est inutilisable pour choisir.
class EefInstitutionSummary {
  const EefInstitutionSummary({
    required this.id,
    required this.name,
    required this.location,
    this.acronym,
    this.institutionType,
    this.websiteUrl,
    this.logoUrl,
    this.logoSourceUrl,
    this.logoLicence,
  });

  final String id;
  final LocalizedText name;
  final LocalizedText location;
  final String? acronym;
  final String? institutionType;
  final String? websiteUrl;
  final String? logoUrl;

  /// La page qui atteste l'image, et sa licence. Elles voyagent avec le logo :
  /// afficher une image Wikimedia sans sa licence est une réutilisation sans
  /// attribution (dossier LIV-29).
  final String? logoSourceUrl;
  final String? logoLicence;

  /// `null` quand le serveur n'a pas servi d'établissement exploitable — la
  /// carte retombe alors sur la formation seule, jamais sur un nom inventé.
  static EefInstitutionSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = Map<String, dynamic>.from(raw);
    final id = _text(json['id']);
    final name = _localized(json['name']);
    if (id == null || name == null || (name.fr.isEmpty && name.en.isEmpty)) {
      return null;
    }
    return EefInstitutionSummary(
      id: id,
      name: name,
      location:
          _localized(json['location']) ?? const LocalizedText(fr: '', en: ''),
      acronym: _text(json['acronym']),
      institutionType: _text(json['institutionType']),
      websiteUrl: _text(json['websiteUrl']),
      logoUrl: _text(json['logoUrl']),
      logoSourceUrl: _text(json['logoSourceUrl']),
      logoLicence: _text(json['logoLicence']),
    );
  }
}

/// Une formation du catalogue « Études en France » : le modèle général, plus ce
/// que seul cet espace sait dire — la procédure d'admission, le cycle, la ville
/// du campus et l'établissement.
///
/// Un wrapper plutôt que de nouveaux champs sur [ProgramModel] : ce dernier est
/// partagé avec le catalogue général, qui n'a aucun usage de la procédure, et
/// toute zone de ce modèle partagé est une zone que les lignes « Études en
/// France » ne doivent pas atteindre par accident.
class EefProgram {
  const EefProgram({
    required this.program,
    this.procedureType,
    this.cycle,
    this.healthAccess = false,
    this.selectivity,
    this.campusCity,
    this.institution,
  });

  final ProgramModel program;

  /// `dap_blanche`, `dap_jaune`, `eef`, `parcoursup` ou `hors_eef`. Une valeur
  /// inconnue est conservée telle quelle : l'écran la traite comme absente
  /// plutôt que de lui inventer un libellé.
  final String? procedureType;
  final String? cycle;

  /// Un PASS ou une L.AS — une 1re année d'accès aux études de médecine,
  /// maïeutique, odontologie, pharmacie ou kinésithérapie. Décidé par le
  /// serveur, pas déduit du cycle : la famille `sante` compte aussi des diplômes
  /// paramédicaux qui n'en sont pas. Absent (serveur plus ancien) : faux.
  final bool healthAccess;
  final String? selectivity;
  final String? campusCity;
  final EefInstitutionSummary? institution;

  String get id => program.id;

  factory EefProgram.fromJson(Map<String, dynamic> json) => EefProgram(
        program: ProgramModel.fromJson(json),
        procedureType: _text(json['procedureType']),
        cycle: _text(json['cycle']),
        healthAccess: json['healthAccess'] == true,
        selectivity: _text(json['selectivity']),
        campusCity: _text(json['campusCity']),
        institution: EefInstitutionSummary.fromJson(json['institution']),
      );
}

String? _text(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

LocalizedText? _localized(Object? value) {
  if (value is! Map) return null;
  return LocalizedText.fromJson(Map<String, dynamic>.from(value));
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
    this.catalogPublished = true,
  });

  final List<EefProgram> items;

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

  /// Le catalogue publié contient-il AU MOINS une formation, quel que soit le
  /// filtre ? Faux ⇒ rien n'est encore publié : l'écran dit « le catalogue
  /// arrive », pas « ta recherche est trop étroite ».
  ///
  /// **Vrai quand le serveur ne le dit pas.** Un serveur plus ancien n'a pas
  /// cette clé ; la lire comme « faux » annoncerait « le catalogue arrive » à
  /// quiconque a simplement une recherche vide. Le seul affichage qu'une clé
  /// absente peut entraîner est le plus neutre : « aucune formation ne
  /// correspond ».
  final bool catalogPublished;

  static const EefSearchPage empty = EefSearchPage(
    items: <EefProgram>[],
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
            .map(EefProgram.fromJson)
            .toList()
        : <EefProgram>[];

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
      // Seul un `false` EXPLICITE signifie « rien de publié ».
      catalogPublished: json['catalogPublished'] != false,
    );
  }
}
