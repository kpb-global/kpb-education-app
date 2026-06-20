part of '../app_controller.dart';

mixin _ParcoursMixin on _AppControllerBase {
  List<YoutubeVideo> get parcoursVideos => List.unmodifiable(_parcoursVideos);

  static const _parcoursCacheKey = 'parcours_videos';

  /// Hydrate the Parcours videos from the offline cache, then refresh from the
  /// backend YouTube proxy when online. Safe to call repeatedly.
  Future<void> fetchParcoursVideos({bool force = false}) async {
    // 1. Offline-first: hydrate from Hive cache if we have nothing yet.
    if (_parcoursVideos.isEmpty && CatalogCacheService.isInitialized) {
      final cached = CatalogCacheService.instance.read(_parcoursCacheKey);
      if (cached.isNotEmpty) {
        _parcoursVideos
          ..clear()
          ..addAll(cached
              .whereType<Map<String, dynamic>>()
              .map(YoutubeVideo.fromApi));
        update();
      }
    }

    if (!AppConfig.enableRemoteSync) return;
    if (isLoadingParcours) return;
    if (!force && _parcoursVideos.isNotEmpty && parcoursConfigured) {
      // Already populated this session; skip redundant network call.
      return;
    }

    isLoadingParcours = true;
    parcoursError = null;
    update();

    try {
      final result = await _apiClient.listParcoursVideos();
      parcoursConfigured = result.configured;
      if (result.items.isNotEmpty) {
        _parcoursVideos
          ..clear()
          ..addAll(result.items);
        if (CatalogCacheService.isInitialized) {
          await CatalogCacheService.instance.write(
            _parcoursCacheKey,
            result.items.map((v) => v.toJson()).toList(),
          );
        }
      }
    } catch (e, s) {
      if (_parcoursVideos.isEmpty) {
        parcoursError = userFacingSyncError(e, localeCode);
      }
      safeRecordError(
        e,
        s,
        reason: 'fetchParcoursVideos',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_parcours_videos',
      );
    } finally {
      isLoadingParcours = false;
      update();
    }
  }
}
