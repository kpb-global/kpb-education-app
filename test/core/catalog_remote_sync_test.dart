import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/catalog_remote_sync.dart';

class _MockApiClient extends Mock implements AppApiClient {}

void main() {
  group('syncCatalogResource — empty-response guard', () {
    test('does not clear target when API returns empty list', () async {
      final api = _MockApiClient();
      when(() => api.listCatalog(any())).thenAnswer((_) async => []);

      final target = ['existing'];
      // The sync must be a no-op — it should not clear pre-loaded data.
      // (CatalogCacheService is never reached so no Hive init needed.)
      await syncCatalogResource<String>(
        api,
        'countries',
        target,
        (json) => json['id'] as String,
      );

      expect(target, ['existing'],
          reason: 'empty API response must not wipe the target list');
    });
  });
}
