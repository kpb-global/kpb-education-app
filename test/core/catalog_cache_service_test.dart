import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';

/// One of the fixture rows a degraded backend served to production and that the
/// old client pinned in Hive forever.
const _poisonedScholarships = [
  {
    'id': 'mccall_macbain',
    'name': {
      'fr': 'Bourse McCall MacBain (Université McGill)',
      'en': 'McCall MacBain Scholarship (McGill University)',
    },
  },
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_cache_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    CatalogCacheService.resetForTests();
    await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  group('poisoned-cache purge', () {
    test('bumping the format version evicts a v1 cache on first launch',
        () async {
      final legacy = await Hive.openBox<String>(CatalogCacheService.boxName);
      await legacy.put('__cache_format_version', '1');
      await legacy.put('scholarships', jsonEncode(_poisonedScholarships));

      await CatalogCacheService.init();

      expect(
        CatalogCacheService.instance.read('scholarships'),
        isEmpty,
        reason: 'v1 caches may hold backend fixtures and must be dropped',
      );
      expect(CatalogCacheService.instance.hasCached('scholarships'), isFalse);
      expect(CatalogCacheService.currentFormatVersion, greaterThan(1));
    });

    test('an unstamped legacy cache is dropped too', () async {
      final legacy = await Hive.openBox<String>(CatalogCacheService.boxName);
      await legacy.put('scholarships', jsonEncode(_poisonedScholarships));

      await CatalogCacheService.init();

      expect(CatalogCacheService.instance.read('scholarships'), isEmpty);
    });

    test('a cache already on the current version survives', () async {
      final box = await Hive.openBox<String>(CatalogCacheService.boxName);
      await box.put(
        '__cache_format_version',
        '${CatalogCacheService.currentFormatVersion}',
      );
      await box.put(
          'countries',
          jsonEncode([
            {'id': 'fra'}
          ]));
      await box.put('__source::countries', 'database');

      await CatalogCacheService.init();

      expect(CatalogCacheService.instance.read('countries'), hasLength(1));
    });
  });

  group('provenance marker', () {
    setUp(() async {
      await CatalogCacheService.init();
    });

    test('rows written as database are served back', () async {
      await CatalogCacheService.instance.write('fields', [
        {'id': 'd01'}
      ]);

      expect(CatalogCacheService.instance.sourceFor('fields'),
          CatalogDataSource.database);
      expect(CatalogCacheService.instance.read('fields'), hasLength(1));
      expect(CatalogCacheService.instance.hasCached('fields'), isTrue);
    });

    test('rows recorded as mock are refused, not served as real', () async {
      await CatalogCacheService.instance.write(
        'scholarships',
        _poisonedScholarships,
        source: CatalogDataSource.mock,
      );

      expect(CatalogCacheService.instance.read('scholarships'), isEmpty);
      expect(CatalogCacheService.instance.hasCached('scholarships'), isFalse);
    });

    test('an authoritatively empty snapshot is cached, not "never synced"',
        () async {
      await CatalogCacheService.instance.write('scholarships', const []);

      expect(CatalogCacheService.instance.read('scholarships'), isEmpty);
      expect(
        CatalogCacheService.instance.hasCached('scholarships'),
        isTrue,
        reason: '"the server has zero rows" must be distinguishable from '
            '"we never managed to sync"',
      );
    });
  });

  group('CatalogDataSource.parse', () {
    test('absent source is trusted (older backends send no field)', () {
      expect(CatalogDataSource.parse(null), CatalogDataSource.database);
      expect(CatalogDataSource.parse(''), CatalogDataSource.database);
    });

    test('mock and unknown values fail closed', () {
      expect(CatalogDataSource.parse('mock'), CatalogDataSource.mock);
      expect(CatalogDataSource.parse('MOCK'), CatalogDataSource.mock);
      expect(CatalogDataSource.parse('fixture'), CatalogDataSource.mock);
      expect(CatalogDataSource.parse('mock').isTrustworthy, isFalse);
    });
  });
}
