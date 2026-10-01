import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/eef_search.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/services/analytics_service.dart';

/// Où en est la recherche, du point de vue de l'écran.
///
/// `ready` avec zéro résultat n'est PAS une erreur : c'est un fait, et l'écran
/// doit le dire autrement qu'une panne. `catalog_remote_sync.dart` fait déjà
/// cette distinction pour le catalogue hors ligne ; la perdre ici ferait
/// afficher « réessayez » à quelqu'un dont la recherche est simplement trop
/// étroite.
enum EefCatalogPhase { initial, loading, ready, loadingMore, failed }

/// Pourquoi une recherche a échoué — grossier, exprès : l'écran n'a que deux
/// choses différentes à dire, « vérifie ta connexion » et « réessaie plus
/// tard ». Un catalogue plus fin produirait des messages que personne ne sait
/// traduire en geste.
enum EefCatalogFailure { network, server }

/// Ce que le contrôleur mesure. Une interface plutôt que `AnalyticsService` en
/// direct : le service n'a pas de constructeur public, donc un test ne pouvait
/// rien affirmer sur ce qui est mesuré — et ce qui n'est pas testé ici est ce qui
/// finit par envoyer le texte tapé par l'étudiant.
abstract interface class EefCatalogAnalytics {
  void searched({
    required bool hasQuery,
    required int filterCount,
    required int resultCount,
    required bool catalogPublished,
  });

  void failed(String reason);
}

class _ServiceEefCatalogAnalytics implements EefCatalogAnalytics {
  const _ServiceEefCatalogAnalytics();

  @override
  void searched({
    required bool hasQuery,
    required int filterCount,
    required int resultCount,
    required bool catalogPublished,
  }) =>
      unawaited(AnalyticsService.instance.logEefCatalogSearched(
        hasQuery: hasQuery,
        filterCount: filterCount,
        resultCount: resultCount,
        catalogPublished: catalogPublished,
      ));

  @override
  void failed(String reason) =>
      unawaited(AnalyticsService.instance.logEefCatalogFailed(reason));
}

/// Les facettes que l'écran propose, dans l'ordre d'affichage.
const kEefFacetCycle = 'cycle';
const kEefFacetProcedure = 'procedureType';
const kEefFacetField = 'fieldId';

/// L'état de la recherche du catalogue, séparé de son rendu.
///
/// ## Les deux règles que ce contrôleur existe pour tenir
///
/// **1. Une réponse périmée ne doit jamais écraser une réponse plus récente.**
/// Avec un anti-rebond, taper « droit » lance potentiellement plusieurs
/// requêtes ; sur un réseau lent — celui du public visé — la réponse à « dro »
/// peut arriver APRÈS celle à « droit ». Sans numéro de séquence, l'étudiant
/// verrait les résultats d'un mot qu'il a fini d'effacer, sans rien pour le
/// lui dire. C'est le défaut le plus courant d'une recherche instantanée, et
/// il est invisible en développement.
///
/// **2. Un échec ne produit jamais un état de succès.** Le dépôt a déjà payé
/// ce prix ailleurs (`documentUploadEnabled` : « fourni ✓ » coché avant
/// l'appel réseau). Ici la faute serait de rendre une liste vide sur une
/// panne : « aucune formation ne correspond » alors que le serveur n'a pas
/// répondu. `failed` et `ready`-avec-zéro sont deux états distincts, et un
/// test le vérifie.
class EefCatalogController extends ChangeNotifier {
  EefCatalogController({
    required AppApiClient apiClient,
    Duration debounce = const Duration(milliseconds: 350),
    EefCatalogAnalytics? analytics,
  })  : _apiClient = apiClient,
        _debounce = debounce,
        _analytics = analytics ?? const _ServiceEefCatalogAnalytics();

  final AppApiClient _apiClient;
  final Duration _debounce;
  final EefCatalogAnalytics _analytics;

  Timer? _debounceTimer;

  /// Le numéro de la requête en vol. Toute réponse portant un numéro périmé est
  /// jetée — voir la règle n° 1 en tête de classe.
  int _sequence = 0;

  EefCatalogPhase _phase = EefCatalogPhase.initial;
  EefCatalogFailure? _failure;

  /// Incrémenté à chaque NOUVELLE recherche (première page), jamais au
  /// défilement. L'écran s'en sert pour remonter en haut de la liste : sans cela,
  /// un filtre posé après avoir défilé laissait l'étudiant en bas d'une liste
  /// plus courte, sans le compteur ni le premier résultat à l'écran.
  int _searchGeneration = 0;
  String _query = '';
  final Map<String, Set<String>> _selected = <String, Set<String>>{};

  List<EefProgram> _items = <EefProgram>[];
  final Set<String> _seenIds = <String>{};
  int _total = 0;
  bool _hasMore = false;
  bool _catalogPublished = true;

  /// La page SUIVANTE a échoué alors que la liste, elle, est intacte.
  ///
  /// Distinct de [EefCatalogPhase.failed], qui remplace tout l'écran : perdre
  /// trois pages déjà lues parce que la quatrième n'a pas répondu — sur un
  /// réseau de pays où c'est courant — ferait recommencer l'étudiant de zéro.
  bool _loadMoreFailed = false;
  String? _cursor;
  Map<String, List<EefFacetValue>> _facets = <String, List<EefFacetValue>>{};
  List<String> _facetsTruncated = <String>[];

  EefCatalogPhase get phase => _phase;
  int get searchGeneration => _searchGeneration;
  EefCatalogFailure? get failure => _failure;
  String get query => _query;
  List<EefProgram> get items => List.unmodifiable(_items);
  int get total => _total;
  bool get hasMore => _hasMore;

  /// Le catalogue publié contient-il au moins une formation ? Voir
  /// [EefSearchPage.catalogPublished].
  bool get catalogPublished => _catalogPublished;

  /// La page suivante a échoué ; la liste déjà lue reste affichée.
  bool get loadMoreFailed => _loadMoreFailed;

  /// Le nombre de filtres de facette posés (le texte libre n'en fait pas partie).
  int get activeFilterCount =>
      _selected.values.fold(0, (sum, values) => sum + values.length);
  Map<String, List<EefFacetValue>> get facets => _facets;
  List<String> get facetsTruncated => List.unmodifiable(_facetsTruncated);

  bool get busy =>
      _phase == EefCatalogPhase.loading ||
      _phase == EefCatalogPhase.loadingMore;

  /// `true` quand le serveur a répondu et que rien ne correspond. Distinct de
  /// `failed` : voir le commentaire de [EefCatalogPhase].
  bool get isEmptyResult => _phase == EefCatalogPhase.ready && _items.isEmpty;

  /// `true` quand le serveur a répondu, que la liste est vide ET que rien n'est
  /// publié du tout. L'écran dit « le catalogue arrive », pas « ta recherche est
  /// trop étroite » : retirer des filtres sur un catalogue vide ne mène nulle
  /// part, et le suggérer est un faux conseil.
  bool get isCatalogNotPublished => isEmptyResult && !_catalogPublished;

  Set<String> selectedValues(String facet) =>
      Set.unmodifiable(_selected[facet] ?? const <String>{});

  bool isSelected(String facet, String value) =>
      _selected[facet]?.contains(value) ?? false;

  /// Le texte a changé. On ne part PAS en requête à chaque frappe : sur un
  /// réseau lent, dix frappes font dix allers-retours dont neuf sont jetés, et
  /// c'est l'étudiant qui paie les octets.
  void onQueryChanged(String value) {
    _query = value;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, refresh);
  }

  /// Bascule une valeur de facette. Un filtre est un geste délibéré : il part
  /// tout de suite, sans anti-rebond.
  void toggleFacet(String facet, String value) {
    final current = _selected.putIfAbsent(facet, () => <String>{});
    if (!current.remove(value)) current.add(value);
    if (current.isEmpty) _selected.remove(facet);
    _debounceTimer?.cancel();
    refresh();
  }

  void clearFilters() {
    _selected.clear();
    _query = '';
    _debounceTimer?.cancel();
    refresh();
  }

  /// Lance la recherche MAINTENANT, sans attendre l'anti-rebond. C'est ce que
  /// fait la touche « rechercher » du clavier : l'étudiant a fini de taper, le
  /// faire patienter 350 ms de plus serait gratuit.
  Future<void> search(String value) {
    _query = value;
    _debounceTimer?.cancel();
    return refresh();
  }

  /// Première page : remet la liste à zéro et repart sans curseur.
  Future<void> refresh() => _load(append: false);

  /// Page suivante. Sans effet s'il n'y a plus rien, si une requête est déjà en
  /// vol, ou si la précédente a échoué — réessayer une page suivante sur un
  /// état cassé empilerait des résultats sur une liste qu'on ne sait plus lire.
  ///
  /// Sans effet non plus après un échec de page suivante : le défilement
  /// rappelle `loadMore` à chaque image, et sans cette garde un réseau coupé
  /// ferait partir une requête par image. Seul [retryLoadMore] relance, sur un
  /// geste de l'étudiant.
  Future<void> loadMore() {
    if (!_hasMore ||
        busy ||
        _loadMoreFailed ||
        _phase != EefCatalogPhase.ready) {
      return Future<void>.value();
    }
    return _load(append: true);
  }

  /// Relance la page suivante après un échec, sur un geste de l'étudiant.
  Future<void> retryLoadMore() {
    if (!_loadMoreFailed || busy || !_hasMore) return Future<void>.value();
    _loadMoreFailed = false;
    return _load(append: true);
  }

  Future<void> _load({required bool append}) async {
    final sequence = ++_sequence;
    _phase = append ? EefCatalogPhase.loadingMore : EefCatalogPhase.loading;
    _failure = null;
    // Une nouvelle recherche repart de zéro, y compris de l'échec de page
    // suivante de la précédente.
    if (!append) {
      _loadMoreFailed = false;
      _searchGeneration += 1;
    }
    notifyListeners();

    try {
      final body = await _apiClient.searchEefCatalog(
        query: _query,
        cycles: _selected[kEefFacetCycle]?.toList() ?? const <String>[],
        procedureTypes:
            _selected[kEefFacetProcedure]?.toList() ?? const <String>[],
        fieldIds: _selected[kEefFacetField]?.toList() ?? const <String>[],
        cursor: append ? _cursor : null,
      );
      // La garde de la règle n° 1. Elle est ici et pas dans l'appelant : une
      // vérification qu'on peut oublier au point d'appel n'est pas une garde.
      if (sequence != _sequence) return;

      final page = EefSearchPage.fromJson(body);
      if (!append) {
        _items = <EefProgram>[];
        _seenIds.clear();
      }
      for (final program in page.items) {
        // Le serveur garantit déjà l'unicité, mais un rejeu de page — un
        // curseur repassé après une reprise réseau — la casserait, et une
        // liste Flutter avec deux fois la même clé se remarque tout de suite.
        if (_seenIds.add(program.id)) _items.add(program);
      }
      _total = page.total;
      _hasMore = page.hasMore;
      _cursor = page.nextCursor;
      // Les facettes décrivent l'ensemble du résultat, pas la page : celles de
      // la première réponse valent pour toutes les suivantes, et les réécrire à
      // chaque page ferait clignoter les compteurs sans rien apprendre.
      if (!append) {
        _facets = page.facets;
        _facetsTruncated = page.facetsTruncated;
        _catalogPublished = page.catalogPublished;
        // Une mesure par RECHERCHE, pas par page : le défilement n'est pas une
        // nouvelle recherche. Des comptes seulement — jamais le texte tapé.
        _analytics.searched(
          hasQuery: _query.trim().isNotEmpty,
          filterCount: activeFilterCount,
          resultCount: page.total,
          catalogPublished: page.catalogPublished,
        );
      }
      _phase = EefCatalogPhase.ready;
    } on DioException catch (error) {
      if (sequence != _sequence) return;
      _fail(_classify(error), append: append);
    } catch (_) {
      if (sequence != _sequence) return;
      _fail(EefCatalogFailure.server, append: append);
    }
    notifyListeners();
  }

  /// Consigne un échec. Une page SUIVANTE qui échoue laisse la liste lisible ;
  /// une première page qui échoue remplace l'écran, faute de rien à montrer.
  void _fail(EefCatalogFailure failure, {required bool append}) {
    _analytics.failed(failure.name);
    if (append) {
      _loadMoreFailed = true;
      _phase = EefCatalogPhase.ready;
      return;
    }
    _failure = failure;
    _phase = EefCatalogPhase.failed;
  }

  static EefCatalogFailure _classify(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return EefCatalogFailure.network;
      default:
        return EefCatalogFailure.server;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    // Le compteur avance une dernière fois : une réponse encore en vol au
    // moment du `dispose` ne doit pas appeler `notifyListeners` sur un
    // contrôleur mort.
    _sequence += 1;
    super.dispose();
  }
}
