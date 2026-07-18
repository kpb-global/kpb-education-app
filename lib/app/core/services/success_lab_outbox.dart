import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../data/success_lab_api_codec.dart';
import '../models/success_lab.dart';

enum SuccessLabMutationAction { updateStep }

class SuccessLabPendingMutation {
  const SuccessLabPendingMutation({
    required this.clientMutationId,
    required this.userId,
    required this.action,
    required this.workspaceId,
    required this.stepId,
    required this.status,
    required this.baseVersion,
    required this.createdAt,
    this.notApplicableReason,
    this.attempts = 0,
    this.lastAttemptAt,
    this.lastErrorCode,
    this.permanentlyFailed = false,
  });

  final String clientMutationId;
  final String userId;
  final SuccessLabMutationAction action;
  final String workspaceId;
  final String stepId;
  final SuccessLabWorkspaceStepStatus status;
  final int baseVersion;
  final String? notApplicableReason;
  final DateTime createdAt;
  final int attempts;
  final DateTime? lastAttemptAt;
  final String? lastErrorCode;
  final bool permanentlyFailed;

  SuccessLabPendingMutation copyWith({
    int? baseVersion,
    int? attempts,
    DateTime? lastAttemptAt,
    String? lastErrorCode,
    bool? permanentlyFailed,
  }) {
    return SuccessLabPendingMutation(
      clientMutationId: clientMutationId,
      userId: userId,
      action: action,
      workspaceId: workspaceId,
      stepId: stepId,
      status: status,
      baseVersion: baseVersion ?? this.baseVersion,
      notApplicableReason: notApplicableReason,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      permanentlyFailed: permanentlyFailed ?? this.permanentlyFailed,
    );
  }
}

abstract interface class SuccessLabOutboxStore {
  Future<void> enqueue(SuccessLabPendingMutation mutation);
  Future<List<SuccessLabPendingMutation>> pending({String? workspaceId});
  Future<void> remove(String clientMutationId);

  Future<void> markAttempt(
    SuccessLabPendingMutation mutation, {
    required String? errorCode,
    int? rebasedVersion,
    bool permanentlyFailed,
  });

  Future<void> clearUser();
}

/// Persistent, user-scoped outbox for small idempotent workspace mutations.
///
/// It never stores document content, uploads, consent data or AI inputs.
class SuccessLabOutbox implements SuccessLabOutboxStore {
  SuccessLabOutbox({required this.userId});

  static const boxName = 'kpb.success_lab.outbox.v1';
  static const _schemaVersion = 1;
  static const maxAttempts = 5;

  final String userId;

  Future<Box<String>> _box() async {
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  String _key(String clientMutationId) => '$userId:$clientMutationId';

  @override
  Future<void> enqueue(SuccessLabPendingMutation mutation) async {
    if (mutation.userId != userId) {
      throw ArgumentError.value(
        mutation.userId,
        'mutation.userId',
        'Mutation belongs to another local account.',
      );
    }
    final box = await _box();
    await box.put(_key(mutation.clientMutationId), _encode(mutation));
  }

  @override
  Future<List<SuccessLabPendingMutation>> pending({String? workspaceId}) async {
    final box = await _box();
    final result = box
        .toMap()
        .entries
        .where((entry) => entry.key is String)
        .where((entry) => (entry.key as String).startsWith('$userId:'))
        .map((entry) => _decode(entry.value))
        .whereType<SuccessLabPendingMutation>()
        .where(
            (entry) => workspaceId == null || entry.workspaceId == workspaceId)
        .toList(growable: false)
      ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
    return List<SuccessLabPendingMutation>.unmodifiable(result);
  }

  @override
  Future<void> remove(String clientMutationId) async {
    final box = await _box();
    await box.delete(_key(clientMutationId));
  }

  @override
  Future<void> markAttempt(
    SuccessLabPendingMutation mutation, {
    required String? errorCode,
    int? rebasedVersion,
    bool permanentlyFailed = false,
  }) {
    final attempts = mutation.attempts + 1;
    return enqueue(
      mutation.copyWith(
        baseVersion: rebasedVersion,
        attempts: attempts,
        lastAttemptAt: DateTime.now().toUtc(),
        lastErrorCode: errorCode,
        permanentlyFailed:
            permanentlyFailed || attempts >= SuccessLabOutbox.maxAttempts,
      ),
    );
  }

  String _encode(SuccessLabPendingMutation mutation) {
    return jsonEncode(<String, dynamic>{
      'schemaVersion': _schemaVersion,
      'clientMutationId': mutation.clientMutationId,
      'userId': mutation.userId,
      'action': 'update_step',
      'workspaceId': mutation.workspaceId,
      'stepId': mutation.stepId,
      'status': SuccessLabApiCodec.encodeWorkspaceStepStatus(mutation.status),
      'baseVersion': mutation.baseVersion,
      'notApplicableReason': mutation.notApplicableReason,
      'createdAt': mutation.createdAt.toUtc().toIso8601String(),
      'attempts': mutation.attempts,
      'lastAttemptAt': mutation.lastAttemptAt?.toUtc().toIso8601String(),
      'lastErrorCode': mutation.lastErrorCode,
      'permanentlyFailed': mutation.permanentlyFailed,
    });
  }

  SuccessLabPendingMutation? _decode(String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic> ||
          json['schemaVersion'] != _schemaVersion ||
          json['userId'] != userId ||
          json['action'] != 'update_step') {
        return null;
      }
      final status = SuccessLabApiCodec.decodeWorkspaceStepStatus(
        json['status'],
      );
      final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
      final clientMutationId = json['clientMutationId'] as String? ?? '';
      final workspaceId = json['workspaceId'] as String? ?? '';
      final stepId = json['stepId'] as String? ?? '';
      if (status == SuccessLabWorkspaceStepStatus.unknown ||
          createdAt == null ||
          clientMutationId.isEmpty ||
          workspaceId.isEmpty ||
          stepId.isEmpty) {
        return null;
      }
      return SuccessLabPendingMutation(
        clientMutationId: clientMutationId,
        userId: userId,
        action: SuccessLabMutationAction.updateStep,
        workspaceId: workspaceId,
        stepId: stepId,
        status: status,
        baseVersion: json['baseVersion'] as int? ?? 0,
        notApplicableReason: json['notApplicableReason'] as String?,
        createdAt: createdAt.toUtc(),
        attempts: json['attempts'] as int? ?? 0,
        lastAttemptAt: DateTime.tryParse(
          json['lastAttemptAt'] as String? ?? '',
        )?.toUtc(),
        lastErrorCode: json['lastErrorCode'] as String?,
        permanentlyFailed: json['permanentlyFailed'] as bool? ?? false,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> clearUser() async {
    final box = await _box();
    final keys = box.keys
        .whereType<String>()
        .where((key) => key.startsWith('$userId:'))
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
