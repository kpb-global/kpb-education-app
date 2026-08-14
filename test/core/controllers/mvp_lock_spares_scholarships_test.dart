import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/data/catalog_source.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/app_repository.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';

// Le verrou pays MVP filtre pays, établissements et formations — jamais les
// bourses. Mesuré le 14/08/2026 sur les 11 fiches vérifiées publiées en
// production : le filtre en cachait 6, dont l'Université de Pretoria (clôture au
// 30/09) et les deux UWC africaines. Personne ne l'a vu, parce qu'aucun test ne
// montait ce chemin avec des bourses hors périmètre.
//
// Ce test passe par `syncRemoteData`, c'est-à-dire le chemin qui a réellement
// écarté ces six fiches, et non par un appel direct à une fonction de filtrage.

class _FakeRepository implements AppRepository {
  AppSnapshot _snapshot = AppSnapshot.initial();

  @override
  Future<AppSnapshot> loadSnapshot() async => _snapshot;

  @override
  Future<void> saveSnapshot(AppSnapshot snapshot) async {
    _snapshot = snapshot;
  }

  @override
  Future<void> clear() async {
    _snapshot = AppSnapshot.initial();
  }
}

class _MockApiClient extends Mock implements AppApiClient {}

/// Le JSON minimal que `fromJson` accepte : tout le reste prend ses défauts.
Map<String, dynamic> _row(String id, String countryId) => <String, dynamic>{
      'id': id,
      'countryId': countryId,
      'name': <String, dynamic>{'fr': id, 'en': id},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async => null,
    );
    final tempDir = await Directory.systemTemp.createTemp('hive_mvp_lock');
    Hive.init(tempDir.path);
  });

  group('le verrou pays MVP', () {
    late _FakeRepository repository;
    late _MockApiClient api;
    late AppController controller;

    setUp(() async {
      Get.testMode = true;
      AppConfig.enableRemoteSyncOverride = true;
      CatalogCacheService.resetForTests();
      await Hive.deleteBoxFromDisk(CatalogCacheService.boxName);
      await CatalogCacheService.init();

      repository = _FakeRepository();
      api = _MockApiClient();
      when(() => api.hasAuthSession()).thenAnswer((_) async => false);
      when(() => api.listContent(any())).thenAnswer((_) async => <dynamic>[]);

      // Une réponse dont le pays est HORS périmètre pour chaque ressource.
      // `zaf` = Afrique du Sud (Université de Pretoria), `ken` et `bfa` = les
      // deux UWC africaines, `twn` = Taiwan ICDF.
      when(() => api.listCatalogEnvelope('scholarships')).thenAnswer(
        (_) async => CatalogListPayload(
          items: <dynamic>[
            _row('up_mastercard_scholars_2027', 'zaf'),
            _row('uwc_kenya_entry_2027', 'ken'),
            _row('uwc_burkina_faso_2027_forecast', 'bfa'),
            _row('taiwan_icdf_2027', 'twn'),
            _row('chevening_2027', 'gbr'),
          ],
          source: CatalogDataSource.database,
        ),
      );
      when(() => api.listCatalogEnvelope('programs')).thenAnswer(
        (_) async => CatalogListPayload(
          items: <dynamic>[
            _row('prog_hors_perimetre', 'zaf'),
            _row('prog_dans_perimetre', 'fra'),
          ],
          source: CatalogDataSource.database,
        ),
      );
      when(() => api.listCatalogEnvelope('institutions')).thenAnswer(
        (_) async => CatalogListPayload(
          items: <dynamic>[
            _row('etab_hors_perimetre', 'zaf'),
            _row('etab_dans_perimetre', 'fra'),
          ],
          source: CatalogDataSource.database,
        ),
      );
      when(() => api.listCatalogEnvelope('countries')).thenAnswer(
        (_) async => CatalogListPayload(
          items: <dynamic>[_row('zaf', 'zaf'), _row('fra', 'fra')],
          source: CatalogDataSource.database,
        ),
      );
      when(() => api.listCatalogEnvelope('fields')).thenAnswer(
        (_) async => const CatalogListPayload(
          items: <dynamic>[],
          source: CatalogDataSource.database,
        ),
      );

      controller = AppController(repository: repository, apiClient: api);
      await controller.syncRemoteData(force: true);
    });

    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      Get.testMode = false;
    });

    test('garde les bourses de TOUS les pays, périmètre de lancement ou non',
        () {
      final ids = controller.scholarships.map((s) => s.id).toSet();

      // C'est l'assertion qui casse si quelqu'un remet
      // `scholarships.retainWhere(... isMvpCountryId ...)`.
      expect(
        ids,
        containsAll(<String>[
          'up_mastercard_scholars_2027',
          'uwc_kenya_entry_2027',
          'uwc_burkina_faso_2027_forecast',
          'taiwan_icdf_2027',
          'chevening_2027',
        ]),
        reason: 'une bourse vérifiée ne doit jamais être masquée par le pays : '
            "c'est une information, pas une offre de service",
      );
      expect(controller.scholarships.length, 5);
    });

    test('continue de filtrer formations, établissements et pays', () {
      // Garde anti-sur-correction : exempter les bourses ne doit pas désarmer
      // le verrou là où il protège du contenu non revu.
      expect(
        controller.programs.map((p) => p.id),
        equals(<String>['prog_dans_perimetre']),
      );
      expect(
        controller.institutions.map((i) => i.id),
        equals(<String>['etab_dans_perimetre']),
      );
      expect(controller.countries.map((c) => c.id), equals(<String>['fra']));
    });
  });
}
