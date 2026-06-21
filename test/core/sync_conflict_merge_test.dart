import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/services/sync_conflict_merge.dart';

SavedItem _item(String itemId) =>
    SavedItem(type: SavedItemType.program, itemId: itemId);

void main() {
  group('mergeSavedItemsUnion — tombstone', () {
    test('tombstoned remote item is not resurrected in the merged list', () {
      final remote = [_item('p1'), _item('p2')];
      final local = <SavedItem>[];
      final tombstones = {'program:p1'};

      final (merged, _) = mergeSavedItemsUnion(
        remote,
        local,
        tombstones: tombstones,
      );

      expect(merged.any((s) => s.itemId == 'p1'), isFalse,
          reason: 'p1 is tombstoned and must not appear after merge');
      expect(merged.any((s) => s.itemId == 'p2'), isTrue);
    });

    test('non-tombstoned items are merged normally', () {
      final remote = [_item('p1')];
      final local = [_item('p2')];

      final (merged, extra) = mergeSavedItemsUnion(remote, local);
      expect(merged.length, 2);
      expect(extra, 1);
    });

    test('tombstoned local item is also excluded', () {
      final remote = <SavedItem>[];
      final local = [_item('p3')];
      final tombstones = {'program:p3'};

      final (merged, _) = mergeSavedItemsUnion(
        remote,
        local,
        tombstones: tombstones,
      );

      expect(merged, isEmpty);
    });
  });
}
