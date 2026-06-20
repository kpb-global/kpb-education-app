part of 'app_models.dart';


class ArticleModel {
  const ArticleModel({
    required this.id,
    required this.slug,
    required this.category,
    required this.title,
    required this.summary,
    required this.content,
    required this.tags,
    required this.authorName,
    required this.status,
    required this.publishedAt,
  });

  final String id;
  final String slug;
  final String category;
  final LocalizedText title;
  final LocalizedText summary;
  final LocalizedText content;
  final List<String> tags;
  final String authorName;
  final PublicationStatus status;
  final DateTime? publishedAt;
}
class ForumCategoryModel {
  const ForumCategoryModel({
    required this.id,
    required this.label,
    required this.description,
    required this.displayOrder,
    required this.status,
  });

  final String id;
  final LocalizedText label;
  final LocalizedText description;
  final int displayOrder;
  final PublicationStatus status;
}
class ForumTopicTagModel {
  const ForumTopicTagModel({
    required this.id,
    required this.label,
    required this.description,
    required this.displayOrder,
    required this.status,
  });

  final String id;
  final LocalizedText label;
  final LocalizedText description;
  final int displayOrder;
  final PublicationStatus status;
}
