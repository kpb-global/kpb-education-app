part of 'app_models.dart';

enum SavedItemType { field, country, institution, program, scholarship }

class SavedItem {
  const SavedItem({
    required this.type,
    required this.itemId,
  });

  final SavedItemType type;
  final String itemId;
}
