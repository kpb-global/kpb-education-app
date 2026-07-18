import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../data/success_lab_api_codec.dart';
import '../models/success_lab.dart';

class SuccessLabCachedValue<T> {
  const SuccessLabCachedValue({
    required this.value,
    required this.syncedAt,
  });

  final T value;
  final DateTime syncedAt;
}

abstract interface class SuccessLabCacheStore {
  Future<SuccessLabCachedValue<SuccessLabAccess>?> readAccess();

  Future<void> writeAccess(
    SuccessLabAccess access, {
    DateTime? syncedAt,
  });

  Future<SuccessLabCachedValue<SuccessLabWorkspacePage>?> readPage({
    String? status,
  });

  Future<void> writePage(
    SuccessLabWorkspacePage page, {
    String? status,
    DateTime? syncedAt,
  });

  Future<SuccessLabCachedValue<SuccessLabWorkspace>?> readWorkspace(
    String workspaceId,
  );

  Future<void> writeWorkspace(
    SuccessLabWorkspace workspace, {
    DateTime? syncedAt,
  });

  Future<void> clearUser();
}

/// User-scoped, versioned JSON cache for Success Lab snapshots.
///
/// No document bytes or diagnostic text are persisted here. Every envelope is
/// bound to [userId], preventing one signed-out account from reading another
/// account's preparation workspace on a shared phone.
class SuccessLabCacheService implements SuccessLabCacheStore {
  SuccessLabCacheService({required this.userId});

  static const boxName = 'kpb.success_lab.cache.v1';
  static const _cacheSchemaVersion = 1;

  final String userId;

  String get _userPrefix => 'user:$userId:';
  String get _accessKey => '${_userPrefix}access';
  String _pageKey(String? status) =>
      '${_userPrefix}page:${status?.trim().isNotEmpty == true ? status : 'all'}';
  String _workspaceKey(String workspaceId) =>
      '${_userPrefix}workspace:$workspaceId';

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  @override
  Future<SuccessLabCachedValue<SuccessLabAccess>?> readAccess() async {
    return _read(
      _accessKey,
      SuccessLabApiCodec.accessFromApi,
    );
  }

  @override
  Future<void> writeAccess(
    SuccessLabAccess access, {
    DateTime? syncedAt,
  }) {
    return _write(
      _accessKey,
      SuccessLabApiCodec.accessToJson(access),
      syncedAt: syncedAt,
    );
  }

  @override
  Future<SuccessLabCachedValue<SuccessLabWorkspacePage>?> readPage({
    String? status,
  }) {
    return _read(
      _pageKey(status),
      SuccessLabApiCodec.workspacePageFromApi,
    );
  }

  @override
  Future<void> writePage(
    SuccessLabWorkspacePage page, {
    String? status,
    DateTime? syncedAt,
  }) {
    return _write(
      _pageKey(status),
      SuccessLabApiCodec.workspacePageToJson(page),
      syncedAt: syncedAt,
    );
  }

  @override
  Future<SuccessLabCachedValue<SuccessLabWorkspace>?> readWorkspace(
    String workspaceId,
  ) {
    return _read(
      _workspaceKey(workspaceId),
      SuccessLabApiCodec.workspaceFromApi,
    );
  }

  @override
  Future<void> writeWorkspace(
    SuccessLabWorkspace workspace, {
    DateTime? syncedAt,
  }) {
    return _write(
      _workspaceKey(workspace.id),
      SuccessLabApiCodec.workspaceToJson(workspace),
      syncedAt: syncedAt,
    );
  }

  Future<SuccessLabCachedValue<T>?> _read<T>(
    String key,
    T Function(Object? raw) decode,
  ) async {
    final box = await _box();
    final raw = box.get(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map<String, dynamic> ||
          envelope['cacheSchemaVersion'] != _cacheSchemaVersion ||
          envelope['userId'] != userId) {
        await box.delete(key);
        return null;
      }
      final syncedAt = DateTime.tryParse(
        envelope['syncedAt'] as String? ?? '',
      );
      if (syncedAt == null) {
        await box.delete(key);
        return null;
      }
      return SuccessLabCachedValue<T>(
        value: decode(envelope['payload']),
        syncedAt: syncedAt.toUtc(),
      );
    } catch (_) {
      await box.delete(key);
      return null;
    }
  }

  Future<void> _write(
    String key,
    Map<String, dynamic> payload, {
    DateTime? syncedAt,
  }) async {
    final box = await _box();
    final envelope = <String, dynamic>{
      'cacheSchemaVersion': _cacheSchemaVersion,
      'payloadSchemaVersion': successLabWorkspaceSchemaVersionV1,
      'userId': userId,
      'syncedAt': (syncedAt ?? DateTime.now()).toUtc().toIso8601String(),
      'payload': payload,
    };
    await box.put(key, jsonEncode(envelope));
  }

  @override
  Future<void> clearUser() async {
    final box = await _box();
    final keys = box.keys
        .whereType<String>()
        .where((key) => key.startsWith(_userPrefix))
        .toList(growable: false);
    await box.deleteAll(keys);
  }

  static Future<void> clearAll() async {
    if (!Hive.isBoxOpen(boxName)) {
      final box = await Hive.openBox<String>(boxName);
      await box.clear();
      return;
    }
    await Hive.box<String>(boxName).clear();
  }
}
