part of 'app_models.dart';


class OrientationOption {
  const OrientationOption({
    required this.id,
    required this.label,
    required this.weights,
  });

  final String id;
  final LocalizedText label;
  final Map<String, int> weights;
}
class OrientationQuestion {
  const OrientationQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    this.multiSelect = false,
  });

  final String id;
  final LocalizedText prompt;
  final List<OrientationOption> options;
  final bool multiSelect;
}
class OrientationRecommendation {
  const OrientationRecommendation({
    required this.fieldId,
    required this.score,
    required this.explanation,
    required this.relatedCountryIds,
    required this.relatedScholarshipIds,
    this.jobs = const [],
    this.iaResilience = 'medium',
  });

  final String fieldId;
  final int score;
  final LocalizedText explanation;
  final List<String> relatedCountryIds;
  final List<String> relatedScholarshipIds;
  final List<String> jobs;
  final String iaResilience;
}
class OrientationSession {
  const OrientationSession({
    required this.id,
    required this.completedAt,
    required this.answers,
    required this.recommendations,
  });

  final String id;
  final DateTime completedAt;
  final Map<String, List<String>> answers;
  final List<OrientationRecommendation> recommendations;
}
