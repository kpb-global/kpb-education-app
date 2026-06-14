import 'dart:io';
import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/repositories/local_app_repository.dart';
import 'package:karatou/app/core/services/catalog_cache_service.dart';

class _MockApiClient extends Mock implements AppApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp('hive_test');
    Hive.init(tempDir.path);
    await CatalogCacheService.init();
  });

  tearDownAll(() async {
    await Hive.deleteFromDisk();
  });

  test('fresh app state has onboarding not completed', () async {
    SharedPreferences.setMockInitialValues({});
    Get.reset();

    final mockApi = _MockApiClient();
    when(() => mockApi.getProfile()).thenAnswer((_) async => <String, dynamic>{});
    when(() => mockApi.listCases()).thenAnswer((_) async => []);
    when(() => mockApi.listSavedItems()).thenAnswer((_) async => []);
    when(() => mockApi.listCatalog(any())).thenAnswer((_) async => []);

    final repository = await LocalAppRepository.create();
    final controller = AppController(
      repository: repository,
      apiClient: mockApi,
    );
    await controller.hydrate();

    expect(controller.hasCompletedOnboarding, isFalse);

    Get.reset();
  });
}
