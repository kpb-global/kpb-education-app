import '../data/catalog_source.dart';
import '../repositories/app_api_client.dart';
import 'catalog_cache_service.dart';

const _maxCatalogSyncAttempts = 3;

typedef CatalogHiveFallbackFn = void Function(String resource, int attempts);

/// What one resource sync actually resolved to.
///
/// These are the three situations the client used to be unable to tell apart —
/// they all ended up looking like "we have some rows, carry on":
///  * [live] — the server answered with real rows from its database;
///  * [empty] — the server answered successfully with **zero** rows. That is a
///    fact about the catalog, not a failure: the target list and the cache are
///    both emptied so the app stops showing rows the backend no longer has;
///  * [offlineCache] — every attempt failed (or the server admitted its rows
///    were degraded fixtures), and the last real snapshot was replayed.
///
/// A fourth case has no value because it throws: fetching failed and there is
/// no usable snapshot. Callers treat that as "catalog unavailable" (the app
/// keeps its bundled sample data behind the sample-data banner).
enum CatalogSyncOutcome { live, empty, offlineCache }

/// Loads catalog lists from API with bounded retries, then Hive fallback (offline cache).
///
/// [onHiveFallback] is invoked when API retries are exhausted but a cached
/// snapshot exists.
///
/// KPB-166: [fetch] lets other list endpoints reuse this exact machinery — the
/// retries, the Hive write and the offline fallback. Editorial content
/// (`/content/…`) passes `api.listContent`. [cacheKey] keeps those rows in their
/// own cache slot, so a content resource can never collide with a catalog one.
///
/// Two rules matter for data integrity, and both used to be broken:
///
///  1. **A successful empty response is authoritative.** It used to be treated
///     exactly like a network failure (`if (raw.isEmpty) return;`), which pinned
///     the existing Hive snapshot forever: fixture rows served once by a
///     degraded backend survived every later refresh, and publishing the real
///     catalog could not dislodge them. Only a *failed* fetch preserves cache.
///  2. **Degraded rows are never trusted.** If the envelope says
///     `source: "mock"`, the payload is the backend's demo fixtures. It is
///     rejected like a failed attempt: not displayed as real, never cached.
///     (Production backends answer 503 instead, so this is the belt to that
///     braces — it also protects dev/staging builds pointed at a broken API.)
///
/// [emptyResponseIsAuthoritative] carries rule 1. It defaults to `true` for the
/// `/catalog/*` endpoints, where an empty list is now unambiguous (a broken
/// backend answers 503 and a degraded one tags itself `source: "mock"`), and to
/// `false` for resources reached through [fetch]: `/content/*` has neither
/// signal yet — it silently substitutes in-memory records and returns `[]` for
/// an unpopulated table — so treating its emptiness as truth would wipe the
/// bundled service offers, prices included. Flip it once `/content/*` gains the
/// same envelope contract.
Future<CatalogSyncOutcome> syncCatalogResource<T>(
  AppApiClient api,
  String resource,
  List<T> target,
  T Function(Map<String, dynamic>) fromJson, {
  CatalogHiveFallbackFn? onHiveFallback,
  Future<List<dynamic>> Function(String resource)? fetch,
  String? cacheKey,
  bool? emptyResponseIsAuthoritative,
}) async {
  final key = cacheKey ?? resource;
  final emptyIsTruth = emptyResponseIsAuthoritative ?? (fetch == null);
  Object? lastError;
  for (var attempt = 0; attempt < _maxCatalogSyncAttempts; attempt++) {
    try {
      // Endpoints reached through [fetch] (`/content/…`) carry no `source`
      // field; they are read as trusted, exactly as before.
      final payload = fetch != null
          ? CatalogListPayload.trusted(await fetch(resource))
          : await api.listCatalogEnvelope(resource);

      if (!payload.isTrustworthy) {
        lastError = StateError(
          'catalog "$resource" answered with degraded '
          '${payload.source.wireValue} data',
        );
        await _backoff(attempt);
        continue;
      }

      final raw = payload.items;
      if (raw.isEmpty && !emptyIsTruth) {
        // Legacy no-op, kept only where emptiness carries no information.
        return CatalogSyncOutcome.empty;
      }
      target
        ..clear()
        ..addAll(raw.whereType<Map<String, dynamic>>().map(fromJson));
      // Cache the empty list too: it records that the server said "no rows",
      // which is different from "never synced" (see [CatalogCacheService.hasCached]).
      await CatalogCacheService.instance.write(key, raw);
      return raw.isEmpty ? CatalogSyncOutcome.empty : CatalogSyncOutcome.live;
    } catch (error) {
      lastError = error;
      await _backoff(attempt);
    }
  }

  // Fetching failed — and only now may we keep serving the previous snapshot.
  final cache = CatalogCacheService.instance;
  if (!cache.hasCached(key)) {
    throw lastError ?? StateError('catalog sync failed for $resource');
  }
  final cached = cache.read(key);
  onHiveFallback?.call(resource, _maxCatalogSyncAttempts);
  target
    ..clear()
    ..addAll(cached.whereType<Map<String, dynamic>>().map(fromJson));
  return CatalogSyncOutcome.offlineCache;
}

Future<void> _backoff(int attempt) async {
  if (attempt >= _maxCatalogSyncAttempts - 1) return;
  await Future<void>.delayed(Duration(milliseconds: 120 * (1 << attempt)));
}
