import 'dart:async';
import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Hive-backed outbox for case messages typed while offline. Drained by
/// [AppController.flushPendingCaseMessages] on reconnect.
class CaseMessageOutbox {
  CaseMessageOutbox._(this._box);

  static const _boxName = 'kpb.cases.outbox';
  static const _maxRetries = 5;

  final Box<String> _box;

  static CaseMessageOutbox? _instance;
  static CaseMessageOutbox get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('CaseMessageOutbox.init() was not called.');
    }
    return value;
  }

  static Future<CaseMessageOutbox> init() async {
    if (_instance != null) return _instance!;
    final box = await Hive.openBox<String>(_boxName);
    return _instance = CaseMessageOutbox._(box);
  }

  Future<void> enqueue({
    required String caseId,
    required String body,
    required String senderName,
  }) async {
    final entry = OutboxEntry(
      key: null,
      caseId: caseId,
      body: body,
      senderName: senderName,
      createdAt: DateTime.now(),
      retries: 0,
    );
    await _box.add(entry.encode());
  }

  Iterable<OutboxEntry> get pending => _box
      .toMap()
      .entries
      .map((e) => OutboxEntry.decode(e.key, e.value))
      .whereType<OutboxEntry>()
      .where((e) => e.retries < _maxRetries);

  int get pendingCount => _box.length;

  bool hasPendingFor(String caseId) =>
      pending.any((e) => e.caseId == caseId);

  Future<void> remove(dynamic key) => _box.delete(key);

  /// Drop every queued message (used by account deletion — these entries hold
  /// personal data: case bodies + sender names typed offline).
  Future<void> clear() => _box.clear();

  Future<void> markFailure(dynamic key, OutboxEntry entry) async {
    final next = entry.withRetries(entry.retries + 1);
    // On max retries, mark as permanently failed instead of silently deleting.
    // Permanently-failed entries are surfaced in the UI so the user can resend.
    await _box.put(key, next.encode());
  }

  Iterable<OutboxEntry> get permanentlyFailed => _box
      .toMap()
      .entries
      .map((e) => OutboxEntry.decode(e.key, e.value))
      .whereType<OutboxEntry>()
      .where((e) => e.retries >= _maxRetries);
}

class OutboxEntry {
  OutboxEntry({
    required this.key,
    required this.caseId,
    required this.body,
    required this.senderName,
    required this.createdAt,
    required this.retries,
  });

  final dynamic key;
  final String caseId;
  final String body;
  final String senderName;
  final DateTime createdAt;
  final int retries;

  static OutboxEntry? decode(dynamic key, String raw) {
    try {
      final json = jsonDecode(raw);
      if (json is! Map) return null;
      return OutboxEntry(
        key: key,
        caseId: json['caseId'] as String? ?? '',
        body: json['body'] as String? ?? '',
        senderName: json['senderName'] as String? ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
        retries: json['retries'] as int? ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode(<String, dynamic>{
        'caseId': caseId,
        'body': body,
        'senderName': senderName,
        'createdAt': createdAt.toIso8601String(),
        'retries': retries,
      });

  OutboxEntry withRetries(int retries) => OutboxEntry(
        key: key,
        caseId: caseId,
        body: body,
        senderName: senderName,
        createdAt: createdAt,
        retries: retries,
      );
}
