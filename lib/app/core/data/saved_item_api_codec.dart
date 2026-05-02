import 'package:collection/collection.dart';

import '../models/app_models.dart';

abstract final class SavedItemApiCodec {
  static SavedItemType? parseType(String? value) {
    return SavedItemType.values.firstWhereOrNull((e) => e.name == value);
  }

  static SavedItem fromApi(dynamic raw) {
    final json = raw as Map<String, dynamic>;
    return SavedItem(
      type: SavedItemType.values.firstWhereOrNull(
            (item) => item.name == json['type'],
          ) ??
          SavedItemType.field,
      itemId: json['itemId'] as String? ?? '',
    );
  }
}
