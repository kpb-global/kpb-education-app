part of '../app_controller.dart';

mixin _ParcoursMixin on _AppControllerBase {
  List<ParcoursStory> get parcoursStories =>
      List.unmodifiable(_parcoursStories);

  static const _parcoursCacheKey = 'parcours_stories';

  /// Distinct field domains (d01..d12) present in the loaded stories, in the
  /// catalog field order — used to render the theme filter chips. Only
  /// non-empty domains appear, so the filter never shows a dead chip.
  List<String> get parcoursFieldIds {
    final present =
        _parcoursStories.map((s) => s.fieldId).whereType<String>().toSet();
    return MockCatalog.fields
        .map((f) => f.id)
        .where(present.contains)
        .toList(growable: false);
  }

  /// The stories after applying the current theme filter + search query.
  List<ParcoursStory> get filteredParcoursStories {
    final q = parcoursQuery.trim().toLowerCase();
    return _parcoursStories.where((s) {
      if (parcoursFieldFilter != null && s.fieldId != parcoursFieldFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      bool has(String v) => v.toLowerCase().contains(q);
      return has(s.title.fr) ||
          has(s.title.en) ||
          has(s.personName) ||
          has(s.role.fr) ||
          has(s.role.en) ||
          has(s.summary.fr) ||
          has(s.summary.en) ||
          s.tags.any(has);
    }).toList(growable: false);
  }

  void setParcoursFieldFilter(String? fieldId) {
    if (parcoursFieldFilter == fieldId) return;
    parcoursFieldFilter = fieldId;
    update();
  }

  void setParcoursQuery(String query) {
    if (parcoursQuery == query) return;
    parcoursQuery = query;
    update();
  }

  /// Hydrate the Parcours stories from the offline cache, then refresh from the
  /// backend catalog when online. Safe to call repeatedly.
  Future<void> fetchParcoursStories({bool force = false}) async {
    // 1. Offline-first: hydrate from Hive cache if we have nothing yet.
    if (_parcoursStories.isEmpty && CatalogCacheService.isInitialized) {
      final cached = CatalogCacheService.instance.read(_parcoursCacheKey);
      if (cached.isNotEmpty) {
        _parcoursStories
          ..clear()
          ..addAll(cached
              .whereType<Map<String, dynamic>>()
              .map(ParcoursStory.fromApi));
        update();
      }
    }

    if (!AppConfig.enableRemoteSync) return;
    if (isLoadingParcours) return;
    if (!force && _parcoursStories.isNotEmpty) {
      // Already populated this session; skip redundant network call.
      return;
    }

    isLoadingParcours = true;
    parcoursError = null;
    update();

    try {
      final items = await _apiClient.listParcoursStories();
      if (items.isNotEmpty) {
        _parcoursStories
          ..clear()
          ..addAll(items);
        if (CatalogCacheService.isInitialized) {
          await CatalogCacheService.instance.write(
            _parcoursCacheKey,
            items.map((s) => s.toJson()).toList(),
          );
        }
      }
    } catch (e, s) {
      if (_parcoursStories.isEmpty) {
        parcoursError = userFacingSyncError(e, localeCode);
      }
      safeRecordError(
        e,
        s,
        reason: 'fetchParcoursStories',
        domain: CrashlyticsObsDomain.sync,
        operation: 'fetch_parcours_stories',
      );
    } finally {
      isLoadingParcours = false;
      update();
    }
  }
}
