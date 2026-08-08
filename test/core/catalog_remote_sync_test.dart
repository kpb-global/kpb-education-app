import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';
import 'package:karatou/app/core/services/catalog_remote_sync.dart';

class _MockApiClient extends Mock implements AppApiClient {}

String _id(Map<String, dynamic> json) => json['id'] as String;

const _row = {'id': 'real'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockApiClient api;

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_sync_test');
    Hive.init(tempDir.path);
  });

  setUp(() async {
    api = _MockApiClient();
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
    await CatalogCacheService.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  void answerWith(CatalogListPayload payload) {
    when(() => api.listCatalogEnvelope(any())).thenAnswer((_) async => payload);
  }

  group('three distinguishable situations', () {
    test('real catalog → live, rows displayed and cached', () async {
      answerWith(const CatalogListPayload(
        items: [_row],
        source: CatalogDataSource.database,
      ));
      final target = <String>['stale'];

      final outcome =
          await syncCatalogResource<String>(api, 'countries', target, _id);

      expect(outcome, CatalogSyncOutcome.live);
      expect(target, ['real']);
      expect(CatalogCacheService.instance.read('countries'), [_row]);
      expect(CatalogCacheService.instance.sourceFor('countries'),
          CatalogDataSource.database);
    });

    test('empty catalog → empty, target and cache both emptied', () async {
      // Seed a snapshot that must NOT survive an authoritative empty response.
      await CatalogCacheService.instance.write('countries', [_row]);
      answerWith(const CatalogListPayload(
        items: [],
        source: CatalogDataSource.database,
      ));
      final target = <String>['real'];

      final outcome =
          await syncCatalogResource<String>(api, 'countries', target, _id);

      expect(outcome, CatalogSyncOutcome.empty);
      expect(target, isEmpty,
          reason: '"the server has zero rows" is a fact, not a failure');
      expect(CatalogCacheService.instance.read('countries'), isEmpty,
          reason: 'the stale snapshot must not be pinned by an empty response');
      expect(CatalogCacheService.instance.hasCached('countries'), isTrue);
    });

    test('service unavailable with a snapshot → offlineCache, cache kept',
        () async {
      await CatalogCacheService.instance.write('countries', [_row]);
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('503 CATALOG_UNAVAILABLE'));
      final target = <String>[];
      final fallbacks = <String>[];

      final outcome = await syncCatalogResource<String>(
        api,
        'countries',
        target,
        _id,
        onHiveFallback: (resource, _) => fallbacks.add(resource),
      );

      expect(outcome, CatalogSyncOutcome.offlineCache);
      expect(target, ['real']);
      expect(fallbacks, ['countries']);
      expect(CatalogCacheService.instance.read('countries'), [_row]);
    });

    test('service unavailable with no snapshot → throws', () async {
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('503 CATALOG_UNAVAILABLE'));

      await expectLater(
        syncCatalogResource<String>(api, 'countries', <String>[], _id),
        throwsStateError,
      );
      verify(() => api.listCatalogEnvelope('countries')).called(3);
    });

    test('an authoritatively empty snapshot is replayed, not treated as absent',
        () async {
      await CatalogCacheService.instance.write('countries', const []);
      when(() => api.listCatalogEnvelope(any()))
          .thenThrow(StateError('offline'));
      final target = <String>['bundled-sample'];

      final outcome =
          await syncCatalogResource<String>(api, 'countries', target, _id);

      expect(outcome, CatalogSyncOutcome.offlineCache);
      expect(target, isEmpty,
          reason: 'the last known truth was "no rows"; do not resurrect '
              'bundled sample rows as if they were real');
    });
  });

  group('degraded payloads are never trusted', () {
    test('source="mock" is rejected: not displayed, not cached', () async {
      answerWith(const CatalogListPayload(
        items: [
          {
            'id': 'mccall_macbain',
            'name': {'fr': 'Bourse McCall MacBain (Université McGill)'},
          }
        ],
        source: CatalogDataSource.mock,
      ));
      final target = <String>[];

      await expectLater(
        syncCatalogResource<String>(api, 'scholarships', target, _id),
        throwsA(isA<StateError>()),
      );

      expect(target, isEmpty);
      expect(CatalogCacheService.instance.hasCached('scholarships'), isFalse,
          reason: 'backend fixtures must never reach the offline cache');
    });

    test('source="mock" falls back to the last real snapshot when it exists',
        () async {
      await CatalogCacheService.instance.write('scholarships', [_row]);
      answerWith(const CatalogListPayload(
        items: [
          {'id': 'mccall_macbain'}
        ],
        source: CatalogDataSource.mock,
      ));
      final target = <String>[];

      final outcome =
          await syncCatalogResource<String>(api, 'scholarships', target, _id);

      expect(outcome, CatalogSyncOutcome.offlineCache);
      expect(target, ['real']);
      expect(CatalogCacheService.instance.read('scholarships'), [_row]);
    });
  });

  group('injected fetch (/content/*) keeps the legacy empty no-op', () {
    test('empty content response does not wipe the bundled seed', () async {
      final target = <String>['bundled-offer'];

      final outcome = await syncCatalogResource<String>(
        api,
        'service-offers',
        target,
        _id,
        fetch: (_) async => <dynamic>[],
        cacheKey: 'content:service-offers',
      );

      expect(outcome, CatalogSyncOutcome.empty);
      expect(target, ['bundled-offer']);
      expect(
        CatalogCacheService.instance.hasCached('content:service-offers'),
        isFalse,
      );
      verifyNever(() => api.listCatalogEnvelope(any()));
    });

    test('the no-op can be opted out of explicitly', () async {
      final target = <String>['bundled-offer'];

      final outcome = await syncCatalogResource<String>(
        api,
        'service-offers',
        target,
        _id,
        fetch: (_) async => <dynamic>[],
        cacheKey: 'content:service-offers',
        emptyResponseIsAuthoritative: true,
      );

      expect(outcome, CatalogSyncOutcome.empty);
      expect(target, isEmpty);
    });

    test('non-empty content rows are cached under their own key', () async {
      final target = <String>[];

      final outcome = await syncCatalogResource<String>(
        api,
        'service-offers',
        target,
        _id,
        fetch: (_) async => [_row],
        cacheKey: 'content:service-offers',
      );

      expect(outcome, CatalogSyncOutcome.live);
      expect(target, ['real']);
      expect(
        CatalogCacheService.instance.read('content:service-offers'),
        [_row],
      );
    });
  });
}
