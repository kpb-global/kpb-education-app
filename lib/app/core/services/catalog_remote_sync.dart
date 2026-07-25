import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';

const _maxCatalogSyncAttempts = 3;

typedef CatalogHiveFallbackFn = void Function(String resource, int attempts);

/// Loads catalog lists from API with bounded retries, then Hive fallback (offline cache).
///
/// [onHiveFallback] is invoked when API retries are exhausted but cached rows exist.
///
/// KPB-166: [fetch] lets other list endpoints reuse this exact machinery — the
/// retries, the "empty response is a no-op" rule, the Hive write and the offline
/// fallback. Editorial content (`/content/…`) passes `api.listContent`.
/// [cacheKey] keeps those rows in their own cache slot, so a content resource can
/// never collide with a catalog one.
Future<void> syncCatalogResource<T>(
  AppApiClient api,
  String resource,
  List<T> target,
  T Function(Map<String, dynamic>) fromJson, {
  CatalogHiveFallbackFn? onHiveFallback,
  Future<List<dynamic>> Function(String resource)? fetch,
  String? cacheKey,
}) async {
  final fetcher = fetch ?? api.listCatalog;
  final key = cacheKey ?? resource;
  Object? lastError;
  for (var attempt = 0; attempt < _maxCatalogSyncAttempts; attempt++) {
    try {
      final raw = await fetcher(resource);
      // An empty response is treated as a no-op: don't clear existing catalog
      // data (seeded from MockCatalog or a prior cache) and don't overwrite the
      // Hive cache, which would poison future offline sessions.
      if (raw.isEmpty) return;
      target
        ..clear()
        ..addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
      await CatalogCacheService.instance.write(key, raw);
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
  final cached = CatalogCacheService.instance.read(key);
  if (cached.isEmpty) {
    throw lastError ?? StateError('catalog sync failed for $resource');
  }
  onHiveFallback?.call(resource, _maxCatalogSyncAttempts);
  target
    ..clear()
    ..addAll(cached.whereType<Map<String, dynamic>>().map(fromJson));
}
