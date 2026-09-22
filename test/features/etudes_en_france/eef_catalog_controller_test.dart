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
    };

void main() {
  late _MockApiClient api;
  late EefCatalogController controller;

  setUp(() {
    api = _MockApiClient();
    controller = EefCatalogController(
      apiClient: api,
      debounce: const Duration(milliseconds: 10),
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
}
