import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../core/models/eef_search.dart';
import '../../core/repositories/app_api_client.dart';

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
  })  : _apiClient = apiClient,
        _debounce = debounce;

  final AppApiClient _apiClient;
  final Duration _debounce;

  Timer? _debounceTimer;

  /// Le numéro de la requête en vol. Toute réponse portant un numéro périmé est
  /// jetée — voir la règle n° 1 en tête de classe.
  int _sequence = 0;

  EefCatalogPhase _phase = EefCatalogPhase.initial;
  EefCatalogFailure? _failure;
  String _query = '';
  final Map<String, Set<String>> _selected = <String, Set<String>>{};

  List<ProgramModel> _items = <ProgramModel>[];
  final Set<String> _seenIds = <String>{};
  int _total = 0;
  bool _hasMore = false;
  String? _cursor;
  Map<String, List<EefFacetValue>> _facets = <String, List<EefFacetValue>>{};
  List<String> _facetsTruncated = <String>[];

  EefCatalogPhase get phase => _phase;
  EefCatalogFailure? get failure => _failure;
  String get query => _query;
  List<ProgramModel> get items => List.unmodifiable(_items);
  int get total => _total;
  bool get hasMore => _hasMore;
  Map<String, List<EefFacetValue>> get facets => _facets;
  List<String> get facetsTruncated => List.unmodifiable(_facetsTruncated);

  bool get busy =>
      _phase == EefCatalogPhase.loading ||
      _phase == EefCatalogPhase.loadingMore;

  /// `true` quand le serveur a répondu et que rien ne correspond. Distinct de
  /// `failed` : voir le commentaire de [EefCatalogPhase].
  bool get isEmptyResult => _phase == EefCatalogPhase.ready && _items.isEmpty;

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
  Future<void> loadMore() {
    if (!_hasMore || busy || _phase != EefCatalogPhase.ready) {
      return Future<void>.value();
    }
    return _load(append: true);
  }

  Future<void> _load({required bool append}) async {
    final sequence = ++_sequence;
    _phase = append ? EefCatalogPhase.loadingMore : EefCatalogPhase.loading;
    _failure = null;
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
        _items = <ProgramModel>[];
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
      }
      _phase = EefCatalogPhase.ready;
    } on DioException catch (error) {
      if (sequence != _sequence) return;
      _failure = _classify(error);
      _phase = EefCatalogPhase.failed;
    } catch (_) {
      if (sequence != _sequence) return;
      _failure = EefCatalogFailure.server;
      _phase = EefCatalogPhase.failed;
    }
    notifyListeners();
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
