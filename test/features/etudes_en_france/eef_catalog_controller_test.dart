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
    test('une recherche donne des comptes — jamais le texte tapé', () async {
      stub((_) async => _body(ids: ['a', 'b'], total: 12));

      await controller.search('prénom nom ville secrète');

      expect(analytics.searches, hasLength(1));
      final event = analytics.searches.single;
      expect(event['hasQuery'], isTrue);
      expect(event['resultCount'], 12);
      expect(event['filterCount'], 0);
      // Aucune valeur ne contient ce que l'étudiant a tapé.
      expect(
        event.values.map((v) => '$v').join(' '),
        isNot(contains('secrète')),
      );
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
}
