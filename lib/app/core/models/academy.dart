part of 'app_models.dart';


class AcademyCourseModel {
  const AcademyCourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.coverImageUrl,
    required this.priceXOF,
    required this.priceEUR,
    required this.lessonCount,
  });

  final String id;
  final LocalizedText title;
  final LocalizedText description;
  final String? coverImageUrl;
  final int priceXOF;
  final double priceEUR;
  final int lessonCount;

  factory AcademyCourseModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return AcademyCourseModel(
      id: json['id'] as String? ?? '',
      title: parseLoc('title'),
      description: parseLoc('description'),
      coverImageUrl: json['coverImageUrl'] as String?,
      priceXOF: json['priceXOF'] as int? ?? 0,
      priceEUR: (json['priceEUR'] as num?)?.toDouble() ?? 0.0,
      lessonCount: json['lessonCount'] as int? ?? 0,
    );
  }
}
class AcademyLessonModel {
  const AcademyLessonModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.durationSeconds,
    required this.order,
  });

  final String id;
  final LocalizedText title;
  final String videoUrl;
  final int durationSeconds;
  final int order;

  factory AcademyLessonModel.fromJson(Map<String, dynamic> json) {
    LocalizedText parseLoc(String key) {
      if (json[key] is Map) {
        return LocalizedText.fromJson(json[key] as Map<String, dynamic>);
      }
      return LocalizedText(
          fr: json['${key}Fr'] as String? ?? '',
          en: json['${key}En'] as String? ?? '');
    }

    return AcademyLessonModel(
      id: json['id'] as String? ?? '',
      title: parseLoc('title'),
      videoUrl: json['videoUrl'] as String? ?? '',
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      order: json['order'] as int? ?? 0,
    );
  }
}
