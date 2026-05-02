import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/sync_conflict_merge.dart';

void main() {
  group('mergeCasesRemoteWithLocal', () {
    final t0 = DateTime.utc(2024, 1, 1);
    final t1 = DateTime.utc(2024, 6, 1);
    final t2 = DateTime.utc(2024, 12, 1);

    test('keeps newer version when ids match', () {
      final remote = [
        _case(id: 'a', updatedAt: t1),
      ];
      final local = [
        _case(id: 'a', updatedAt: t2),
      ];

      final (merged, stats) = mergeCasesRemoteWithLocal(remote, local);

      expect(merged.single.id, 'a');
      expect(merged.single.updatedAt, t2);
      expect(stats.localWinCount, 1);
      expect(stats.keptLocalOnlyCount, 0);
    });

    test('retains remote when it is newer', () {
      final remote = [
        _case(id: 'a', updatedAt: t2),
      ];
      final local = [
        _case(id: 'a', updatedAt: t1),
      ];

      final (merged, stats) = mergeCasesRemoteWithLocal(remote, local);

      expect(merged.single.updatedAt, t2);
      expect(stats.localWinCount, 0);
    });

    test('keeps local-only rows not present remotely', () {
      final remote = <StudentCase>[];
      final local = [
        _case(id: 'case-123', updatedAt: t0),
      ];

      final (merged, stats) = mergeCasesRemoteWithLocal(remote, local);

      expect(merged.single.id, 'case-123');
      expect(stats.keptLocalOnlyCount, 1);
    });
  });

  group('mergeSavedItemsUnion', () {
    test('adds local-only items to remote list', () {
      final remote = [
        const SavedItem(type: SavedItemType.field, itemId: 'f1'),
      ];
      final local = [
        const SavedItem(type: SavedItemType.field, itemId: 'f1'),
        const SavedItem(type: SavedItemType.country, itemId: 'c1'),
      ];

      final (merged, extra) = mergeSavedItemsUnion(remote, local);

      expect(merged.length, 2);
      expect(extra, 1);
    });
  });
}

StudentCase _case({required String id, required DateTime updatedAt}) {
  return StudentCase(
    id: id,
    referenceCode: 'x',
    type: CaseType.consultation,
    title: const LocalizedText(fr: 't', en: 't'),
    description: const LocalizedText(fr: 'd', en: 'd'),
    contextLabel: const LocalizedText(fr: 'c', en: 'c'),
    status: CaseStatus.submitted,
    preferredContactMethod: ContactMethod.inApp,
    createdAt: updatedAt,
    updatedAt: updatedAt,
    nextStepTitle: const LocalizedText(fr: 'n', en: 'n'),
    nextStepDescription: const LocalizedText(fr: 'n', en: 'n'),
    timeline: const [],
    messages: const [],
    documentRequests: const [],
  );
}
