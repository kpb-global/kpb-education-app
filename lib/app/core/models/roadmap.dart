part of 'app_models.dart';

enum RoadmapStepType { audit, language, writing, review, submission }

class RoadmapStepModel {
  const RoadmapStepModel({
    required this.type,
    required this.title,
    required this.description,
    required this.daysBeforeDeadline,
    this.actionRoute,
  });

  final RoadmapStepType type;
  final LocalizedText title;
  final LocalizedText description;
  final int daysBeforeDeadline;
  final String? actionRoute;
}
