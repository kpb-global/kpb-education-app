import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed offline snapshot cache for the `/catalog/*` endpoints.
///
/// We keep this intentionally schema-less: each catalog resource is stored as
/// a single JSON-encoded string under its resource key (e.g. `fields`,
/// `countries`). The box also records a `last_synced_at` timestamp so the UI
/// can show "last updated …" for airtime-sensitive users.
///
/// Hive is preferred over SharedPreferences here because catalog payloads can
/// reach hundreds of KB and Hive reads without parsing the entire prefs blob.
class CatalogCacheService {
  CatalogCacheService._(this._box);

  static const _boxName = 'kpb.catalog.cache';
  static const _lastSyncKey = '__last_synced_at';
  static const _formatVersionKey = '__cache_format_version';

  /// Bumped when JSON shape or semantics under each resource key change materially.
  static const _currentFormatVersion = 1;
  static const _staleAfter = Duration(days: 14);

  final Box<String> _box;

  static CatalogCacheService? _instance;
  static bool get isInitialized => _instance != null;
  static CatalogCacheService get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('CatalogCacheService.init() was not called.');
    }
    return value;
  }

  static Future<CatalogCacheService> init() async {
    if (_instance != null) return _instance!;
    final box = await Hive.openBox<String>(_boxName);
    final stored = box.get(_formatVersionKey);
    if (stored == null) {
      // First app version with a format key: keep existing cache, stamp current.
      await box.put(_formatVersionKey, '$_currentFormatVersion');
    } else {
      final version = int.tryParse(stored) ?? 0;
      if (version != _currentFormatVersion) {
        await box.clear();
        await box.put(_formatVersionKey, '$_currentFormatVersion');
      }
    }
    return _instance = CatalogCacheService._(box);
  }

  Future<void> write(String resource, List<dynamic> items) async {
    await _box.put(resource, jsonEncode(items));
    await _box.put(_lastSyncKey, DateTime.now().toIso8601String());
  }

  List<dynamic> read(String resource) {
    final raw = _box.get(resource);
    if (raw == null || raw.isEmpty) return const <dynamic>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {
      // Corrupt cache — fall through to empty list.
    }
    return const <dynamic>[];
  }

  DateTime? get lastSyncedAt {
    final raw = _box.get(_lastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool get isStale {
    final at = lastSyncedAt;
    if (at == null) return true;
    return DateTime.now().difference(at) > _staleAfter;
  }

  Future<void> clear() => _box.clear();
}
