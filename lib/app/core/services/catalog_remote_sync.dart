import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';

/// Loads catalog lists from API with Hive fallback (offline cache).
Future<void> syncCatalogResource<T>(
  AppApiClient api,
  String resource,
  List<T> target,
  T Function(Map<String, dynamic>) fromJson,
) async {
  try {
    final raw = await api.listCatalog(resource);
    target
      ..clear()
      ..addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
    await CatalogCacheService.instance.write(resource, raw);
  } catch (error) {
    final cached = CatalogCacheService.instance.read(resource);
    if (cached.isEmpty) rethrow;
    target
      ..clear()
      ..addAll(cached.whereType<Map<String, dynamic>>().map(fromJson));
  }
}
