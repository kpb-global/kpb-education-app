import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';

const _maxCatalogSyncAttempts = 3;

typedef CatalogHiveFallbackFn = void Function(String resource, int attempts);

/// Loads catalog lists from API with bounded retries, then Hive fallback (offline cache).
///
/// [onHiveFallback] is invoked when API retries are exhausted but cached rows exist.
Future<void> syncCatalogResource<T>(
  AppApiClient api,
  String resource,
  List<T> target,
  T Function(Map<String, dynamic>) fromJson, {
  CatalogHiveFallbackFn? onHiveFallback,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < _maxCatalogSyncAttempts; attempt++) {
    try {
      final raw = await api.listCatalog(resource);
      // An empty response is treated as a no-op: don't clear existing catalog
      // data (seeded from MockCatalog or a prior cache) and don't overwrite the
      // Hive cache, which would poison future offline sessions.
      if (raw.isEmpty) return;
      target
        ..clear()
        ..addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
      await CatalogCacheService.instance.write(resource, raw);
      return;
    } catch (error) {
      lastError = error;
      if (attempt < _maxCatalogSyncAttempts - 1) {
        await Future<void>.delayed(
          Duration(milliseconds: 120 * (1 << attempt)),
        );
      }
    }
  }
  final cached = CatalogCacheService.instance.read(resource);
  if (cached.isEmpty) {
    throw lastError ?? StateError('catalog sync failed for $resource');
  }
  onHiveFallback?.call(resource, _maxCatalogSyncAttempts);
  target
    ..clear()
    ..addAll(cached.whereType<Map<String, dynamic>>().map(fromJson));
}
