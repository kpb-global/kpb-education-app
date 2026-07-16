import 'package:flutter/foundation.dart';

import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';

/// Feature-scoped state for the live scholarship acquisition surface.
///
/// The current API uses offset pagination. The controller intentionally keeps
/// that contract while treating a short page as the fallback end-of-list
/// signal, so it also works with deployments that do not yet expose `total` or
/// cursor metadata.
class ScholarshipsController extends ChangeNotifier {
  ScholarshipsController({
    required AppApiClient apiClient,
    required this.lang,
    this.level,
    this.fieldIds,
    this.pageSize = 20,
  }) : _apiClient = apiClient;

  final AppApiClient _apiClient;
  final String lang;
  final String? level;
  final List<String>? fieldIds;
  final int pageSize;

  final List<LiveScholarshipModel> _items = <LiveScholarshipModel>[];
  final Set<String> _alertedScholarshipIds = <String>{};

  List<LiveScholarshipModel> get items => List.unmodifiable(_items);
  Set<String> get alertedScholarshipIds =>
      Set.unmodifiable(_alertedScholarshipIds);

  bool loading = true;
  bool loadingMore = false;
  bool hasMore = true;
  String? error;
  String fundingFilter = 'all';

  int _offset = 0;
  int _requestGeneration = 0;

  Future<void> loadInitial() async {
    final generation = ++_requestGeneration;
    loading = true;
    loadingMore = false;
    error = null;
    hasMore = true;
    _offset = 0;
    notifyListeners();

    try {
      // Keep the first request byte-for-byte compatible with the pre-pagination
      // client call. This matters for older servers and existing test doubles.
      final raw = await _apiClient.fetchLiveScholarships(
        lang: lang,
        level: level,
        fieldIds: fieldIds,
        fundingType: fundingFilter == 'all' ? null : fundingFilter,
      );
      if (generation != _requestGeneration) return;
      final parsed = _parse(raw);
      _items
        ..clear()
        ..addAll(parsed);
      _alertedScholarshipIds
        ..clear()
        ..addAll(
          parsed
              .where((item) => item.isAlertEnabled == true)
              .map((item) => item.id),
        );
      _offset = parsed.length;
      hasMore = raw.length >= pageSize;

      try {
        final alerts = await _apiClient.fetchScholarshipAlerts();
        if (generation == _requestGeneration) {
          _alertedScholarshipIds
            ..clear()
            ..addAll(alerts);
        }
      } catch (_) {
        // The scholarship catalog remains useful if alert state is temporarily
        // unavailable during a staged backend rollout.
      }
    } catch (exception) {
      if (generation == _requestGeneration) error = exception.toString();
    } finally {
      if (generation == _requestGeneration) {
        loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (loading || loadingMore || !hasMore || error != null) return;
    final generation = _requestGeneration;
    loadingMore = true;
    notifyListeners();
    try {
      final raw = await _apiClient.fetchLiveScholarships(
        lang: lang,
        level: level,
        fieldIds: fieldIds,
        fundingType: fundingFilter == 'all' ? null : fundingFilter,
        limit: pageSize,
        offset: _offset,
      );
      if (generation != _requestGeneration) return;
      final knownIds = _items.map((item) => item.id).toSet();
      final parsed = _parse(raw)
          .where((item) => knownIds.add(item.id))
          .toList(growable: false);
      _items.addAll(parsed);
      _alertedScholarshipIds.addAll(
        parsed
            .where((item) => item.isAlertEnabled == true)
            .map((item) => item.id),
      );
      // Advance by the server page size rather than only unique rows; otherwise
      // a duplicate page can cause a loop against a drifting result set.
      _offset += raw.length;
      hasMore = raw.length >= pageSize && raw.isNotEmpty;
    } catch (_) {
      // A failed incremental page must not replace already useful results with
      // the full-page connection error. A later scroll/refresh can retry.
      hasMore = false;
    } finally {
      if (generation == _requestGeneration) {
        loadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> changeFundingFilter(String value) async {
    if (value == fundingFilter) return;
    fundingFilter = value;
    await loadInitial();
  }

  void setAlertState(String scholarshipId, bool enabled) {
    final changed = enabled
        ? _alertedScholarshipIds.add(scholarshipId)
        : _alertedScholarshipIds.remove(scholarshipId);
    if (changed) notifyListeners();
  }

  List<LiveScholarshipModel> _parse(List<dynamic> raw) => raw
      .whereType<Map>()
      .map((item) =>
          LiveScholarshipModel.fromJson(Map<String, dynamic>.from(item)))
      .where((item) => item.id.isNotEmpty)
      .toList(growable: false);
}
