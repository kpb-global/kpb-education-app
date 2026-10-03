// Deux règles, et ce fichier n'existe que pour elles.
//
// 1. UNE RÉPONSE PÉRIMÉE N'ÉCRASE JAMAIS UNE RÉPONSE PLUS RÉCENTE. Avec un
//    anti-rebond, taper « droit » lance plusieurs requêtes ; sur un réseau
//    lent — celui du public visé — la réponse à « dro » peut arriver APRÈS
//    celle à « droit ». Le défaut est invisible en développement et permanent
//    en production.
//
// 2. UN ÉCHEC N'EST JAMAIS UN SUCCÈS. Une liste vide rendue sur une panne se
//    lit « aucune formation ne correspond ». Le dépôt a déjà payé ce prix avec
//    `documentUploadEnabled` (« fourni ✓ » coché avant l'appel réseau).

import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_controller.dart';

class _MockApiClient extends Mock implements AppApiClient {}

DioException _dio(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/search'),
      type: type,
    );

DioException _http(int status) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
        statusCode: status,
      ),
    );

/// La réponse de `GET /etudes-en-france/cities`, telle que le contrat la donne.
Map<String, dynamic> _cities(
  List<(String, int)> cities, {
  int? total,
  bool catalogPublished = true,
}) =>
    <String, dynamic>{
      'cities': [
        for (final (value, count) in cities)
          <String, dynamic>{'value': value, 'count': count},
      ],
      'total': total ?? cities.fold<int>(0, (sum, c) => sum + c.$2),
      'catalogPublished': catalogPublished,
      'source': 'database',
    };

Map<String, dynamic> _body({
  required List<String> ids,
  int total = 0,
  bool hasMore = false,
  String? nextCursor,
  Map<String, dynamic>? facets,
  bool? catalogPublished,
}) =>
    <String, dynamic>{
      'items': [
        for (final id in ids)
          <String, dynamic>{
            'id': id,
            'institutionId': 'eef-univ-x',
            'countryId': 'fra',
            'fieldId': 'd07',
            'nameFr': 'L1 - $id',
            'nameEn': 'L1 - $id',
            'levelFr': 'Bac+3',
            'levelEn': 'Bac+3',
            'durationFr': '3 ans',
            'durationEn': '3 years',
            'tuitionFr': 'x',
            'tuitionEn': 'x',
            'languageFr': 'Français',
            'languageEn': 'French',
            'requirementsFr': <String>[],
            'requirementsEn': <String>[],
          },
      ],
      'total': total == 0 ? ids.length : total,
      'page': <String, dynamic>{
        'limit': 20,
        'hasMore': hasMore,
        'nextCursor': nextCursor,
      },
      'facets': facets ?? <String, dynamic>{},
      'facetsTruncated': <String>[],
      if (catalogPublished != null) 'catalogPublished': catalogPublished,
    };

/// Une mesure notée, pour affirmer sur ce que le contrôleur envoie.
class _RecordingAnalytics implements EefCatalogAnalytics {
  final searches = <Map<String, Object>>[];
  final failures = <String>[];

  @override
  void searched({
    required bool hasQuery,
    required int filterCount,
    required int resultCount,
    required bool catalogPublished,
  }) =>
      searches.add(<String, Object>{
        'hasQuery': hasQuery,
        'filterCount': filterCount,
        'resultCount': resultCount,
        'catalogPublished': catalogPublished,
      });

  @override
  void failed(String reason) => failures.add(reason);
}

void main() {
  late _MockApiClient api;
  late _RecordingAnalytics analytics;
  late EefCatalogController controller;

  setUp(() {
    api = _MockApiClient();
    analytics = _RecordingAnalytics();
    controller = EefCatalogController(
      apiClient: api,
      debounce: const Duration(milliseconds: 10),
      analytics: analytics,
    );
  });

  tearDown(() => controller.dispose());

  void stub(Future<Map<String, dynamic>> Function(Invocation) answer) {
    when(() => api.searchEefCatalog(
          query: any(named: 'query'),
          cycles: any(named: 'cycles'),
          procedureTypes: any(named: 'procedureTypes'),
          fieldIds: any(named: 'fieldIds'),
          campusCities: any(named: 'campusCities'),
          institutionIds: any(named: 'institutionIds'),
          selectivities: any(named: 'selectivities'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer(answer);
  }

  void stubCities(Future<Map<String, dynamic>> Function(Invocation) answer) {
    when(() => api.fetchEefCities(
          query: any(named: 'query'),
          cycles: any(named: 'cycles'),
          procedureTypes: any(named: 'procedureTypes'),
          fieldIds: any(named: 'fieldIds'),
          institutionIds: any(named: 'institutionIds'),
          selectivities: any(named: 'selectivities'),
        )).thenAnswer(answer);
  }

  group('règle n° 1 — la réponse périmée est jetée', () {
    test('une réponse lente arrivée après une rapide ne la remplace pas',
        () async {
      final gate = Completer<void>();
      stub((invocation) async {
        final query = invocation.namedArguments[#query] as String?;
        if (query == 'dro') {
          // La requête ancienne répond APRÈS la récente.
          await gate.future;
          return _body(ids: ['ancien']);
        }
        return _body(ids: ['recent']);
      });

      final slow = controller.search('dro');
      final fast = controller.search('droit');
      await fast;
      gate.complete();
      await slow;

      expect(controller.items.map((p) => p.id), ['recent']);
      expect(controller.phase, EefCatalogPhase.ready);
    });

    test('un échec périmé ne fait pas basculer un succès récent en panne',
        () async {
      final gate = Completer<void>();
      stub((invocation) async {
        final query = invocation.namedArguments[#query] as String?;
        if (query == 'dro') {
          await gate.future;
          throw _dio(DioExceptionType.connectionError);
        }
        return _body(ids: ['recent']);
      });

      final slow = controller.search('dro');
      await controller.search('droit');
      gate.complete();
      await slow;

      expect(controller.phase, EefCatalogPhase.ready);
      expect(controller.failure, isNull);
      expect(controller.items.map((p) => p.id), ['recent']);
    });
  });

  group('règle n° 2 — un échec n\'est jamais un succès', () {
    test('une panne réseau donne failed, pas une liste vide', () async {
      stub((_) async => throw _dio(DioExceptionType.connectionError));

      await controller.refresh();

      expect(controller.phase, EefCatalogPhase.failed);
      expect(controller.failure, EefCatalogFailure.network);
      // Et surtout : PAS « aucun résultat ».
      expect(controller.isEmptyResult, isFalse);
    });

    test('un serveur en erreur est distingué d\'une coupure réseau', () async {
      stub((_) async => throw _dio(DioExceptionType.badResponse));
      await controller.refresh();
      expect(controller.failure, EefCatalogFailure.server);
    });

    test('zéro résultat est un FAIT, pas une panne', () async {
      stub((_) async => _body(ids: <String>[]));

      await controller.refresh();

      expect(controller.phase, EefCatalogPhase.ready);
      expect(controller.failure, isNull);
      expect(controller.isEmptyResult, isTrue);
    });
  });

  group('pagination par curseur', () {
    test('la page suivante s\'ajoute, sans doublon', () async {
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _body(
              ids: ['a', 'b'], total: 4, hasMore: true, nextCursor: 'c1');
        }
        // Le serveur garantit l'unicité, mais un rejeu de page la casserait.
        return _body(ids: ['b', 'c'], total: 4);
      });

      await controller.refresh();
      expect(controller.items.map((p) => p.id), ['a', 'b']);
      expect(controller.hasMore, isTrue);

      await controller.loadMore();
      expect(controller.items.map((p) => p.id), ['a', 'b', 'c']);
      expect(controller.hasMore, isFalse);
      expect(controller.total, 4);
    });

    test('loadMore ne fait rien sans page suivante ni après un échec',
        () async {
      stub((_) async => _body(ids: ['a']));
      await controller.refresh();
      await controller.loadMore();
      verify(() => api.searchEefCatalog(
            query: any(named: 'query'),
            cycles: any(named: 'cycles'),
            procedureTypes: any(named: 'procedureTypes'),
            fieldIds: any(named: 'fieldIds'),
            campusCities: any(named: 'campusCities'),
            institutionIds: any(named: 'institutionIds'),
            selectivities: any(named: 'selectivities'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          )).called(1);
    });

    test('une nouvelle recherche repart de zéro, curseur compris', () async {
      final cursors = <String?>[];
      stub((invocation) async {
        cursors.add(invocation.namedArguments[#cursor] as String?);
        return _body(ids: ['a'], hasMore: true, nextCursor: 'c1');
      });

      await controller.refresh();
      await controller.loadMore();
      await controller.refresh();

      expect(cursors, [null, 'c1', null]);
      expect(controller.items.map((p) => p.id), ['a']);
    });
  });

  group('filtres et anti-rebond', () {
    test('les frappes rapprochées ne font qu\'UNE requête', () async {
      // Sur un réseau lent, dix frappes font dix allers-retours dont neuf sont
      // jetés — et c'est l'étudiant qui paie les octets.
      var calls = 0;
      stub((_) async {
        calls += 1;
        return _body(ids: ['a']);
      });

      controller.onQueryChanged('d');
      controller.onQueryChanged('dr');
      controller.onQueryChanged('dro');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(calls, 1);
    });

    test('un filtre part immédiatement et voyage vers le serveur', () async {
      final sent = <List<String>>[];
      stub((invocation) async {
        sent.add(invocation.namedArguments[#cycles] as List<String>);
        return _body(ids: ['a']);
      });

      controller.toggleFacet(kEefFacetCycle, 'master');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(sent.last, ['master']);
      expect(controller.isSelected(kEefFacetCycle, 'master'), isTrue);

      controller.toggleFacet(kEefFacetCycle, 'master');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(sent.last, isEmpty);
      expect(controller.isSelected(kEefFacetCycle, 'master'), isFalse);
    });

    test('les facettes de la première page survivent au chargement suivant',
        () async {
      // Elles décrivent l'ensemble du résultat, pas la page : les réécrire à
      // chaque page ferait clignoter les compteurs sans rien apprendre.
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _body(
            ids: ['a'],
            hasMore: true,
            nextCursor: 'c1',
            facets: <String, dynamic>{
              'cycle': [
                {'value': 'master', 'count': 3112},
              ],
            },
          );
        }
        return _body(ids: ['b'], facets: <String, dynamic>{});
      });

      await controller.refresh();
      await controller.loadMore();

      expect(controller.facets['cycle']!.single.value, 'master');
      expect(controller.facets['cycle']!.single.count, 3112);
    });
  });

  // EEF-UX-M02 — la page SUIVANTE qui échoue ne détruit pas la liste.
  group('échec de la page suivante', () {
    void stubTwoPages({required bool secondFails, void Function()? onSecond}) {
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _body(
              ids: ['a', 'b'], total: 4, hasMore: true, nextCursor: 'c1');
        }
        onSecond?.call();
        if (secondFails) throw _dio(DioExceptionType.connectionError);
        return _body(ids: ['c', 'd'], total: 4);
      });
    }

    test('garde les pages déjà lues et passe en loadMoreFailed', () async {
      stubTwoPages(secondFails: true);

      await controller.refresh();
      await controller.loadMore();

      expect(controller.items.map((p) => p.id), ['a', 'b']);
      expect(controller.loadMoreFailed, isTrue);
      // La liste reste LISIBLE : ni écran d'erreur, ni liste vide.
      expect(controller.phase, EefCatalogPhase.ready);
      expect(controller.isEmptyResult, isFalse);
    });

    // Le défilement rappelle `loadMore` à chaque image. Sans cette garde, un
    // réseau coupé ferait partir une requête par image.
    test('ne relance pas toute seule après un échec', () async {
      var secondCalls = 0;
      stubTwoPages(secondFails: true, onSecond: () => secondCalls += 1);

      await controller.refresh();
      await controller.loadMore();
      await controller.loadMore();
      await controller.loadMore();

      expect(secondCalls, 1);
    });

    test('retryLoadMore relance sur geste, et complète la liste', () async {
      var failing = true;
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _body(
              ids: ['a', 'b'], total: 4, hasMore: true, nextCursor: 'c1');
        }
        if (failing) throw _dio(DioExceptionType.connectionError);
        return _body(ids: ['c', 'd'], total: 4);
      });

      await controller.refresh();
      await controller.loadMore();
      expect(controller.loadMoreFailed, isTrue);

      failing = false;
      await controller.retryLoadMore();

      expect(controller.loadMoreFailed, isFalse);
      expect(controller.items.map((p) => p.id), ['a', 'b', 'c', 'd']);
    });

    test('retryLoadMore est sans effet quand rien n\'a échoué', () async {
      stub((_) async => _body(ids: ['a']));
      await controller.refresh();
      await controller.retryLoadMore();
      expect(controller.items.map((p) => p.id), ['a']);
    });

    test('une nouvelle recherche efface l\'échec de la page suivante',
        () async {
      stubTwoPages(secondFails: true);
      await controller.refresh();
      await controller.loadMore();
      expect(controller.loadMoreFailed, isTrue);

      await controller.refresh();

      expect(controller.loadMoreFailed, isFalse);
    });

    // Une PREMIÈRE page qui échoue, elle, n'a rien à garder : écran d'erreur.
    test('une première page qui échoue reste un écran d\'erreur', () async {
      stub((_) async => throw _dio(DioExceptionType.connectionError));
      await controller.refresh();
      expect(controller.phase, EefCatalogPhase.failed);
      expect(controller.loadMoreFailed, isFalse);
    });
  });

  // LIV-11 — « rien n'est publié » n'est pas « ta recherche est trop étroite ».
  group('catalogue non publié', () {
    test('catalogPublished: false avec zéro résultat', () async {
      stub((_) async => _body(ids: <String>[], catalogPublished: false));
      await controller.refresh();

      expect(controller.isCatalogNotPublished, isTrue);
      expect(controller.isEmptyResult, isTrue);
    });

    test(
        'catalogPublished: true avec zéro résultat — c\'est un filtre trop étroit',
        () async {
      stub((_) async => _body(ids: <String>[], catalogPublished: true));
      await controller.refresh();

      expect(controller.isCatalogNotPublished, isFalse);
      expect(controller.isEmptyResult, isTrue);
    });

    // Un serveur plus ancien n'envoie pas la clé : l'absence ne doit JAMAIS se
    // lire « rien de publié », sinon toute recherche vide annoncerait « le
    // catalogue arrive ».
    test('une clé absente se lit « publié »', () async {
      stub((_) async => _body(ids: <String>[]));
      await controller.refresh();

      expect(controller.catalogPublished, isTrue);
      expect(controller.isCatalogNotPublished, isFalse);
    });

    test('avec des résultats, ce n\'est jamais « non publié »', () async {
      stub((_) async => _body(ids: ['a'], catalogPublished: false));
      await controller.refresh();
      expect(controller.isCatalogNotPublished, isFalse);
    });
  });

  group('ce qui est mesuré', () {
    test('une recherche donne des comptes et des drapeaux', () async {
      stub((_) async => _body(ids: ['a', 'b'], total: 12));

      await controller.search('prénom nom ville secrète');

      expect(analytics.searches, hasLength(1));
      final event = analytics.searches.single;
      expect(event['hasQuery'], isTrue);
      expect(event['resultCount'], 12);
      expect(event['filterCount'], 0);
      expect(event['catalogPublished'], isTrue);
    });

    // L'interface `EefCatalogAnalytics` n'a aucun paramètre de texte : un test
    // d'exécution ne peut pas prouver l'ABSENCE d'un champ. Ce qui protège le
    // texte tapé est donc lu dans les SOURCES — le contrôleur ne passe à la
    // mesure que « y a-t-il une requête », et le service n'envoie que des comptes.
    test('SOURCES : le texte tapé ne part jamais dans la mesure', () {
      final controllerSource = File(
        'lib/app/features/etudes_en_france/eef_catalog_controller.dart',
      ).readAsStringSync();
      final call = RegExp(r'_analytics\.searched\(([\s\S]*?)\);')
          .firstMatch(controllerSource);
      expect(call, isNotNull, reason: 'l\'appel à la mesure a disparu');
      final args = call!.group(1)!;
      expect(args, contains('hasQuery: _query.trim().isNotEmpty'));
      expect(
        args.replaceAll('_query.trim().isNotEmpty', ''),
        isNot(contains('_query')),
        reason: 'le texte tapé ne doit pas atteindre la mesure',
      );

      final serviceSource = File('lib/app/core/services/analytics_service.dart')
          .readAsStringSync();
      final start = serviceSource.indexOf('Future<void> logEefCatalogSearched');
      final body = serviceSource.substring(
        start,
        serviceSource.indexOf('Future<void> logEefCatalogFailed'),
      );
      expect(body, isNot(contains('searchTerm')));
      expect(body.replaceAll('hasQuery', ''), isNot(contains('query')));
      // Les booléens partent en 1/0 : FirebaseAnalytics n'accepte que String/num.
      expect(body, contains('hasQuery ? 1 : 0'));
      expect(body, contains('catalogPublished ? 1 : 0'));
    });

    test('searchGeneration avance à chaque recherche, pas au défilement',
        () async {
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        return cursor == null
            ? _body(ids: ['a'], total: 2, hasMore: true, nextCursor: 'c1')
            : _body(ids: ['b'], total: 2);
      });

      expect(controller.searchGeneration, 0);
      await controller.refresh();
      expect(controller.searchGeneration, 1);
      await controller.loadMore();
      expect(controller.searchGeneration, 1);
      await controller.refresh();
      expect(controller.searchGeneration, 2);
    });

    test('compte les filtres posés, pas leur contenu', () async {
      stub((_) async => _body(ids: ['a']));
      controller.toggleFacet(kEefFacetCycle, 'master');
      controller.toggleFacet(kEefFacetProcedure, 'eef');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(analytics.searches.last['filterCount'], 2);
      expect(controller.activeFilterCount, 2);
    });

    test('mesure UNE recherche par requête, pas une par page', () async {
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        return cursor == null
            ? _body(ids: ['a'], total: 2, hasMore: true, nextCursor: 'c1')
            : _body(ids: ['b'], total: 2);
      });

      await controller.refresh();
      await controller.loadMore();

      expect(analytics.searches, hasLength(1));
    });

    test('une panne est mesurée, avec sa cause', () async {
      stub((_) async => throw _dio(DioExceptionType.connectionError));
      await controller.refresh();
      stub((_) async => throw _dio(DioExceptionType.badResponse));
      await controller.refresh();

      expect(analytics.failures, ['network', 'server']);
      // Et une panne n'est pas une recherche aboutie.
      expect(analytics.searches, isEmpty);
    });

    test('une réponse périmée n\'est pas mesurée', () async {
      final gate = Completer<void>();
      stub((invocation) async {
        final query = invocation.namedArguments[#query] as String?;
        if (query == 'dro') {
          await gate.future;
          return _body(ids: ['ancien']);
        }
        return _body(ids: ['recent']);
      });

      final slow = controller.search('dro');
      await controller.search('droit');
      gate.complete();
      await slow;

      expect(analytics.searches, hasLength(1));
    });
  });

  // ── Filtres par ville, par domaine, par niveau ─────────────────────────────

  group('ville et domaine voyagent vers le serveur', () {
    test('campusCity et fieldId arrivent dans la requête', () async {
      final sent = <Map<Symbol, Object?>>[];
      stub((invocation) async {
        sent.add(Map<Symbol, Object?>.of(invocation.namedArguments));
        return _body(ids: ['a']);
      });

      await controller.setFacetSelection(kEefFacetCity, {'Lyon', 'Paris'});
      await controller.setFacetSelection(kEefFacetField, {'d07'});

      expect(sent.last[#campusCities], unorderedEquals(['Lyon', 'Paris']));
      expect(sent.last[#fieldIds], ['d07']);
      // Les autres familles restent vides : rien n'est inventé.
      expect(sent.last[#cycles], isEmpty);
      expect(sent.last[#procedureTypes], isEmpty);
    });

    test('les constantes de famille sont les noms de colonne du serveur', () {
      expect(kEefFacetCycle, 'cycle');
      expect(kEefFacetProcedure, 'procedureType');
      expect(kEefFacetField, 'fieldId');
      expect(kEefFacetCity, 'campusCity');
    });

    test('toggleFacet porte aussi la ville (retrait d\'une puce active)',
        () async {
      final sent = <List<String>>[];
      stub((invocation) async {
        sent.add(invocation.namedArguments[#campusCities] as List<String>);
        return _body(ids: ['a']);
      });

      controller.toggleFacet(kEefFacetCity, 'Lyon');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(sent.last, ['Lyon']);

      controller.toggleFacet(kEefFacetCity, 'Lyon');
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(sent.last, isEmpty);
    });
  });

  group('setFacetSelection — remplacer une famille d\'un coup', () {
    late List<Map<Symbol, Object?>> sent;

    setUp(() {
      sent = <Map<Symbol, Object?>>[];
      stub((invocation) async {
        sent.add(Map<Symbol, Object?>.of(invocation.namedArguments));
        return _body(ids: ['a']);
      });
    });

    test('trois valeurs d\'un coup = UNE requête, pas trois', () async {
      // Réseaux lents : une requête par case cochée serait payée trois fois.
      await controller.refresh();
      final before = sent.length;

      await controller.setFacetSelection(
          kEefFacetCycle, {'licence1', 'licence2', 'master'});

      expect(sent.length, before + 1);
      expect(sent.last[#cycles],
          unorderedEquals(['licence1', 'licence2', 'master']));
    });

    test('REMPLACE la sélection : l\'ancienne valeur disparaît', () async {
      await controller
          .setFacetSelection(kEefFacetCycle, {'licence1', 'master'});
      await controller.setFacetSelection(kEefFacetCycle, {'but1'});

      expect(sent.last[#cycles], ['but1']);
      expect(controller.selectedValues(kEefFacetCycle), {'but1'});
      expect(controller.isSelected(kEefFacetCycle, 'master'), isFalse);
    });

    test('un ensemble vide vide la famille — et laisse les autres', () async {
      await controller.setFacetSelection(kEefFacetCycle, {'master'});
      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      await controller.setFacetSelection(kEefFacetCycle, <String>{});

      expect(sent.last[#cycles], isEmpty);
      expect(sent.last[#campusCities], ['Lyon']);
      expect(controller.selectedValues(kEefFacetCycle), isEmpty);
      expect(controller.activeFilterCount, 1);
    });

    test('la MÊME sélection ne repart pas en requête', () async {
      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      final before = sent.length;

      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      await controller.setFacetSelection(kEefFacetProcedure, <String>{});

      expect(sent.length, before);
    });

    test('une valeur vide ou d\'espaces n\'est pas un filtre', () async {
      await controller.setFacetSelection(kEefFacetCity, {'', '  ', 'Lyon'});

      expect(sent.last[#campusCities], ['Lyon']);
      expect(controller.activeFilterCount, 1);

      final before = sent.length;
      await controller.setFacetSelection(kEefFacetProcedure, {' '});
      expect(sent.length, before, reason: 'rien de réel à filtrer');
      expect(controller.activeFilterCount, 1);
    });

    test('n\'altère pas l\'ensemble passé par l\'appelant', () async {
      // La feuille garde son brouillon ; le contrôleur ne doit pas en tenir une
      // référence vivante, sinon cocher une case après coup filtrerait seul.
      final draft = <String>{'Lyon'};
      await controller.setFacetSelection(kEefFacetCity, draft);
      draft.add('Paris');

      expect(controller.selectedValues(kEefFacetCity), {'Lyon'});
    });

    test('rend une recherche neuve : curseur remis à zéro, génération avance',
        () async {
      final cursors = <String?>[];
      stub((invocation) async {
        cursors.add(invocation.namedArguments[#cursor] as String?);
        return _body(ids: ['a'], hasMore: true, nextCursor: 'c1');
      });
      await controller.refresh();
      await controller.loadMore();
      final generation = controller.searchGeneration;

      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});

      expect(cursors.last, isNull);
      expect(controller.searchGeneration, generation + 1);
    });

    test('une réponse périmée est jetée (règle n° 1 tient pour la feuille)',
        () async {
      final gate = Completer<void>();
      stub((invocation) async {
        final cities = invocation.namedArguments[#campusCities] as List<String>;
        if (cities.contains('Lyon')) {
          // La requête ancienne répond APRÈS la récente.
          await gate.future;
          return _body(ids: ['lyon']);
        }
        return _body(ids: ['paris']);
      });

      final slow = controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      final fast = controller.setFacetSelection(kEefFacetCity, {'Paris'});
      await fast;
      gate.complete();
      await slow;

      expect(controller.items.map((p) => p.id), ['paris']);
      expect(controller.phase, EefCatalogPhase.ready);
      expect(controller.selectedValues(kEefFacetCity), {'Paris'});
      expect(analytics.searches, hasLength(1),
          reason: 'la réponse périmée n\'est pas mesurée');
    });

    test('un échec périmé ne bascule pas un succès récent en panne', () async {
      final gate = Completer<void>();
      stub((invocation) async {
        final cities = invocation.namedArguments[#campusCities] as List<String>;
        if (cities.contains('Lyon')) {
          await gate.future;
          throw _dio(DioExceptionType.connectionError);
        }
        return _body(ids: ['paris']);
      });

      final slow = controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      await controller.setFacetSelection(kEefFacetCity, {'Paris'});
      gate.complete();
      await slow;

      expect(controller.phase, EefCatalogPhase.ready);
      expect(controller.failure, isNull);
    });

    test('annule une frappe en attente : une seule requête, texte compris',
        () async {
      controller.onQueryChanged('droit');
      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(sent, hasLength(1));
      expect(sent.single[#query], 'droit');
      expect(sent.single[#campusCities], ['Lyon']);
    });
  });

  group('tout effacer', () {
    test('vide TOUTES les familles et le texte, en une requête', () async {
      final sent = <Map<Symbol, Object?>>[];
      stub((invocation) async {
        sent.add(Map<Symbol, Object?>.of(invocation.namedArguments));
        return _body(ids: ['a']);
      });
      await controller.setFacetSelection(kEefFacetCycle, {'master'});
      await controller.setFacetSelection(kEefFacetField, {'d07'});
      await controller.setFacetSelection(kEefFacetCity, {'Lyon', 'Paris'});
      await controller.setFacetSelection(kEefFacetProcedure, {'eef'});
      await controller.search('droit');
      final before = sent.length;

      controller.clearFilters();
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(sent.length, before + 1);
      expect(sent.last[#cycles], isEmpty);
      expect(sent.last[#fieldIds], isEmpty);
      expect(sent.last[#campusCities], isEmpty);
      expect(sent.last[#procedureTypes], isEmpty);
      expect(sent.last[#query], '');
      expect(controller.activeFilterCount, 0);
      expect(controller.query, isEmpty);
    });
  });

  group('GET /etudes-en-france/cities — la feuille « Ville »', () {
    List<Map<Symbol, Object?>> trackCities(
        Future<Map<String, dynamic>> Function() answer) {
      final calls = <Map<Symbol, Object?>>[];
      stubCities((invocation) {
        calls.add(Map<Symbol, Object?>.of(invocation.namedArguments));
        return answer();
      });
      return calls;
    }

    test('envoie le texte et les filtres posés — jamais la ville elle-même',
        () async {
      stub((_) async => _body(ids: ['a']));
      final calls = trackCities(() async => _cities([('Paris', 727)]));
      await controller.setFacetSelection(kEefFacetCycle, {'master'});
      await controller.setFacetSelection(kEefFacetField, {'d07'});
      await controller.setFacetSelection(kEefFacetProcedure, {'eef'});
      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      await controller.search('droit');

      await controller.loadCities();

      expect(calls, hasLength(1));
      expect(calls.single[#query], 'droit');
      expect(calls.single[#cycles], ['master']);
      expect(calls.single[#fieldIds], ['d07']);
      expect(calls.single[#procedureTypes], ['eef']);
      // `campusCity` est IGNORÉ par le serveur, et la méthode n'a pas de
      // paramètre pour le porter : une ville déjà cochée ne réduit pas la liste
      // des villes (on veut pouvoir en cocher une autre).
      expect(calls.single.containsKey(#campusCities), isFalse);
    });

    test('rend la liste du serveur, son total, et le statut « chargé »',
        () async {
      stubCities((_) async => _cities(
            [('Paris', 727), ('Toulouse', 271), ('Évry', 12)],
            total: 1010,
          ));

      final outcome = await controller.loadCities();

      expect(outcome.status, EefCitiesStatus.loaded);
      expect(outcome.cities.map((c) => c.value), ['Paris', 'Toulouse', 'Évry']);
      expect(outcome.cities.first.count, 727);
      expect(outcome.total, 1010);
      expect(outcome.failure, isNull);
    });

    test('ne touche NI à la liste NI à la phase de la recherche', () async {
      stub((_) async => _body(ids: ['a', 'b']));
      stubCities((_) async => _cities([('Paris', 2)]));
      await controller.refresh();
      final generation = controller.searchGeneration;

      await controller.loadCities();

      expect(controller.items.map((p) => p.id), ['a', 'b']);
      expect(controller.phase, EefCatalogPhase.ready);
      expect(controller.searchGeneration, generation);
      expect(analytics.searches, hasLength(1),
          reason: 'la feuille n\'est pas une recherche');
    });

    test('une coupure réseau est un ÉCHEC — pas un repli, pas une liste vide',
        () async {
      stub((_) async => _body(ids: [
            'a'
          ], facets: {
            'campusCity': [
              {'value': 'Lyon', 'count': 3},
            ],
          }));
      await controller.refresh();
      stubCities((_) async => throw _dio(DioExceptionType.connectionError));

      final outcome = await controller.loadCities();

      expect(outcome.status, EefCitiesStatus.failed);
      expect(outcome.failure, EefCatalogFailure.network);
      expect(outcome.cities, isEmpty);
    });

    test('un délai dépassé est aussi un échec réseau', () async {
      stubCities((_) async => throw _dio(DioExceptionType.receiveTimeout));
      final outcome = await controller.loadCities();
      expect(outcome.status, EefCitiesStatus.failed);
      expect(outcome.failure, EefCatalogFailure.network);
    });

    test('un 400, un 401, un 403 ou un 429 sont des échecs, pas un repli',
        () async {
      for (final status in [400, 401, 403, 429]) {
        stubCities((_) async => throw _http(status));
        final outcome = await controller.loadCities();
        expect(outcome.status, EefCitiesStatus.failed, reason: '$status');
        expect(outcome.failure, EefCatalogFailure.server, reason: '$status');
      }
    });

    test('une erreur de décodage est un échec, pas un plantage', () async {
      stubCities((_) async => throw const FormatException('pas du JSON'));
      final outcome = await controller.loadCities();
      expect(outcome.status, EefCitiesStatus.failed);
    });

    test('l\'échec des villes n\'entre PAS dans eef_catalog_failed', () async {
      // Cet événement dit « le catalogue n'a pas pu répondre ». Une feuille
      // de villes en panne n'est pas cela, et son bruit fausserait la courbe.
      stubCities((_) async => throw _dio(DioExceptionType.connectionError));
      await controller.loadCities();
      expect(analytics.failures, isEmpty);
    });

    for (final status in [404, 405, 500, 502, 503]) {
      test(
          'REPLI sur $status : les villes de la facette de la dernière '
          'recherche', () async {
        stub((_) async => _body(ids: [
              'a'
            ], facets: {
              'campusCity': [
                {'value': 'Lyon', 'count': 190},
                {'value': 'Paris', 'count': 727},
              ],
              'cycle': [
                {'value': 'master', 'count': 9},
              ],
            }));
        await controller.refresh();
        stubCities((_) async => throw _http(status));

        final outcome = await controller.loadCities();

        expect(outcome.status, EefCitiesStatus.fallback);
        expect(outcome.cities.map((c) => c.value), ['Lyon', 'Paris']);
        expect(outcome.cities.last.count, 727);
        expect(outcome.failure, isNull);
        // Pas de total exact en repli : la facette est tronquée à 20 villes.
        expect(outcome.total, isNull);
      });
    }

    test('REPLI sans facette de ville : liste vide, jamais d\'exception',
        () async {
      stub((_) async => _body(ids: ['a']));
      await controller.refresh();
      stubCities((_) async => throw _http(404));

      final outcome = await controller.loadCities();

      expect(outcome.status, EefCitiesStatus.fallback);
      expect(outcome.cities, isEmpty);
    });

    test('REPLI avant toute recherche aboutie : facettes vides, pas de crash',
        () async {
      stubCities((_) async => throw _http(405));
      final outcome = await controller.loadCities();
      expect(outcome.status, EefCitiesStatus.fallback);
      expect(outcome.cities, isEmpty);
    });

    test('un 200 sans liste `cities` est lu comme un backend plus ancien',
        () async {
      stub((_) async => _body(ids: [
            'a'
          ], facets: {
            'campusCity': [
              {'value': 'Nice', 'count': 142},
            ],
          }));
      await controller.refresh();
      stubCities((_) async => <String, dynamic>{});

      final outcome = await controller.loadCities();

      expect(outcome.status, EefCitiesStatus.fallback);
      expect(outcome.cities.single.value, 'Nice');
    });

    test('ignore les villes sans valeur et garde l\'ordre du serveur',
        () async {
      stubCities((_) async => <String, dynamic>{
            'cities': [
              {'value': 'Paris', 'count': 727},
              {'value': '', 'count': 5},
              {'value': '   ', 'count': 4},
              {'count': 3},
              {'value': 'Lyon', 'count': 190},
            ],
            'total': 1000,
          });

      final outcome = await controller.loadCities();

      expect(outcome.cities.map((c) => c.value), ['Paris', 'Lyon']);
    });
  });

  group('ce qui est mesuré — les filtres', () {
    test(
        'filterCount compte les valeurs de TOUTES les familles, ville comprise',
        () async {
      stub((_) async => _body(ids: ['a']));

      await controller.setFacetSelection(kEefFacetCycle, {'master'});
      await controller.setFacetSelection(kEefFacetField, {'d07', 'd09'});
      await controller.setFacetSelection(kEefFacetCity, {'Lyon', 'Paris'});
      await controller.setFacetSelection(kEefFacetProcedure, {'eef'});

      expect(analytics.searches.last['filterCount'], 6);
      expect(controller.activeFilterCount, 6);
    });

    test('une ville seule compte : un filtre de ville n\'est pas invisible',
        () async {
      stub((_) async => _body(ids: ['a']));
      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});
      expect(analytics.searches.last['filterCount'], 1);
    });

    // L'interface de mesure n'a aucun paramètre de texte : un test d'exécution
    // ne prouve pas l'ABSENCE d'un champ. On le lit donc dans les SOURCES, comme
    // pour le texte tapé — la mesure ne reçoit que des comptes.
    test('SOURCES : ni ville ni libellé de filtre ne part dans la mesure', () {
      final controllerSource = File(
        'lib/app/features/etudes_en_france/eef_catalog_controller.dart',
      ).readAsStringSync();
      final call = RegExp(r'_analytics\.searched\(([\s\S]*?)\);')
          .firstMatch(controllerSource);
      expect(call, isNotNull);
      final args = call!.group(1)!;
      expect(args, contains('filterCount: activeFilterCount'));
      for (final forbidden in ['_selected', 'campus', 'city', 'Cit', 'label']) {
        expect(args, isNot(contains(forbidden)),
            reason: 'la mesure ne doit pas porter « $forbidden »');
      }

      final service = File('lib/app/core/services/analytics_service.dart')
          .readAsStringSync();
      final start = service.indexOf('Future<void> logEefCatalogSearched');
      final body = service.substring(
        start,
        service.indexOf('Future<void> logEefCatalogFailed'),
      );
      expect(body.toLowerCase(), isNot(contains('city')));
      expect(body.toLowerCase(), isNot(contains('campus')));
    });
  });

  // Le contrôleur est détruit avec l'écran. Une réponse encore en vol à ce
  // moment-là ne doit PAS réveiller un `ChangeNotifier` mort : Flutter lève alors
  // « used after being disposed », en production comme en test. Les feuilles de
  // filtre ajoutent deux chemins asynchrones (`setFacetSelection`, `loadCities`) :
  // ils sont éprouvés ici, parce que rien d'autre ne le fait.
  group('dispose pendant un chargement', () {
    late EefCatalogController mortal;

    setUp(() {
      mortal = EefCatalogController(
        apiClient: api,
        debounce: const Duration(milliseconds: 10),
        analytics: analytics,
      );
    });

    test('une recherche en vol : sa réponse arrive après dispose, sans bruit',
        () async {
      final gate = Completer<Map<String, dynamic>>();
      stub((_) => gate.future);
      final pending = mortal.refresh();

      mortal.dispose();
      gate.complete(_body(ids: ['a']));
      await pending;

      expect(analytics.searches, isEmpty,
          reason:
              'une réponse reçue par un contrôleur mort n\'est pas mesurée');
    });

    test('une recherche en vol qui ÉCHOUE après dispose : ni bruit ni mesure',
        () async {
      final gate = Completer<Map<String, dynamic>>();
      stub((_) => gate.future);
      final pending = mortal.refresh();

      mortal.dispose();
      gate.completeError(_dio(DioExceptionType.connectionError));
      await pending;

      expect(analytics.failures, isEmpty);
    });

    test('une sélection de feuille en vol, détruite avant la réponse',
        () async {
      final gate = Completer<Map<String, dynamic>>();
      stub((_) => gate.future);
      final pending =
          mortal.setFacetSelection(kEefFacetCity, {'Lyon', 'Paris'});

      mortal.dispose();
      gate.complete(_body(ids: ['a']));
      await pending;

      expect(analytics.searches, isEmpty);
    });

    test('la liste des villes en vol : la réponse arrive après dispose',
        () async {
      final gate = Completer<Map<String, dynamic>>();
      stubCities((_) => gate.future);
      final pending = mortal.loadCities();

      mortal.dispose();
      gate.complete(_cities([('Paris', 3)]));
      final outcome = await pending;

      expect(outcome.status, EefCitiesStatus.loaded);
    });

    test('l\'anti-rebond en attente est annulé par dispose', () async {
      stub((_) async => _body(ids: ['a']));
      mortal.onQueryChanged('droit');

      mortal.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 40));

      verifyNever(() => api.searchEefCatalog(
            query: any(named: 'query'),
            cycles: any(named: 'cycles'),
            procedureTypes: any(named: 'procedureTypes'),
            fieldIds: any(named: 'fieldIds'),
            campusCities: any(named: 'campusCities'),
            institutionIds: any(named: 'institutionIds'),
            selectivities: any(named: 'selectivities'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ));
    });
  });

  group('ce qui est mesuré — une panne avec une ville choisie', () {
    // `eef_catalog_failed` ne porte QUE sa cause. Une ville est une donnée de
    // profil : elle ne doit pas s'y glisser parce qu'un filtre de ville est posé.
    test('la raison est « network » ou « server », jamais la ville', () async {
      stub((_) async => _body(ids: ['a']));
      await controller.setFacetSelection(kEefFacetCity, {'Lyon'});

      stub((_) async => throw _dio(DioExceptionType.connectionError));
      await controller.refresh();
      stub((_) async => throw _dio(DioExceptionType.badResponse));
      await controller.refresh();

      expect(analytics.failures, ['network', 'server']);
    });
  });
}
