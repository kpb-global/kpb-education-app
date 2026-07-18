import 'package:flutter/foundation.dart';

import '../models/success_lab.dart';
import '../repositories/success_lab_repository.dart';

class SuccessLabListController extends ChangeNotifier {
  SuccessLabListController({
    required SuccessLabRepository repository,
    this.statusFilter,
    this.pageSize = 20,
  }) : _repository = repository;

  final SuccessLabRepository _repository;
  final String? statusFilter;
  final int pageSize;

  LabLoadPhase phase = LabLoadPhase.initial;
  SuccessLabAccess? access;
  SuccessLabFailure? failure;
  DateTime? cachedAt;
  String? nextCursor;
  bool loadingMore = false;

  final List<SuccessLabWorkspace> _items = <SuccessLabWorkspace>[];
  List<SuccessLabWorkspace> get items => List.unmodifiable(_items);

  Future<void> loadInitial() async {
    phase = LabLoadPhase.loading;
    failure = null;
    notifyListeners();

    final cachedAccess = await _repository.readCachedAccess();
    final cachedPage = await _repository.readCachedPage(status: statusFilter);
    access = cachedAccess?.value;
    if (cachedPage != null) {
      _items
        ..clear()
        ..addAll(cachedPage.value.items);
      nextCursor = cachedPage.value.nextCursor;
      cachedAt = cachedPage.syncedAt;
      phase = _items.isEmpty ? LabLoadPhase.loading : LabLoadPhase.cached;
      notifyListeners();
    }

    if (!_repository.canUseNetwork) {
      phase = LabLoadPhase.offline;
      notifyListeners();
      return;
    }

    if (_items.isNotEmpty) {
      phase = LabLoadPhase.syncing;
      notifyListeners();
    }

    try {
      final decision = await _repository.fetchAccess();
      access = decision;
      if (!decision.enabled) {
        _items.clear();
        nextCursor = null;
        phase = LabLoadPhase.featureDisabled;
        notifyListeners();
        return;
      }
      final page = await _repository.fetchPage(
        status: statusFilter,
        limit: pageSize,
      );
      _items
        ..clear()
        ..addAll(page.items);
      nextCursor = page.nextCursor;
      cachedAt = DateTime.now().toUtc();
      phase = _items.isEmpty ? LabLoadPhase.empty : LabLoadPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      phase =
          _items.isNotEmpty && failure!.kind == SuccessLabFailureKind.offline
              ? LabLoadPhase.offline
              : _phaseForFailure(failure!);
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    final cursor = nextCursor;
    if (loadingMore || cursor == null || cursor.isEmpty) return;
    if (!_repository.canUseNetwork) {
      phase = LabLoadPhase.offline;
      notifyListeners();
      return;
    }
    loadingMore = true;
    notifyListeners();
    try {
      final page = await _repository.fetchPage(
        status: statusFilter,
        cursor: cursor,
        limit: pageSize,
      );
      final knownIds = _items.map((item) => item.id).toSet();
      _items.addAll(page.items.where((item) => knownIds.add(item.id)));
      nextCursor = page.nextCursor;
      phase = LabLoadPhase.ready;
    } catch (error) {
      failure = SuccessLabRepository.normalizeFailure(error);
      if (failure!.kind == SuccessLabFailureKind.offline) {
        phase = LabLoadPhase.offline;
      }
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  LabLoadPhase _phaseForFailure(SuccessLabFailure value) {
    switch (value.kind) {
      case SuccessLabFailureKind.offline:
        return LabLoadPhase.offline;
      case SuccessLabFailureKind.forbidden:
        return LabLoadPhase.forbidden;
      case SuccessLabFailureKind.featureDisabled:
        return LabLoadPhase.featureDisabled;
      case SuccessLabFailureKind.conflict:
      case SuccessLabFailureKind.notFound:
      case SuccessLabFailureKind.invalidPayload:
      case SuccessLabFailureKind.server:
      case SuccessLabFailureKind.unknown:
        return LabLoadPhase.error;
    }
  }
}
