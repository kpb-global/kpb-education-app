import 'dart:math';

import 'package:collection/collection.dart';

import '../models/app_models.dart';

/// Evaluates a student's orientation answers against the catalog of fields,
/// producing ranked recommendations. All catalog data is injected to decouple
/// the engine from any static data source.
class OrientationEngine {
  static OrientationSession evaluate({
    required UserProfile profile,
    required Map<String, List<String>> answers,
    required List<OrientationQuestion> questions,
    required List<FieldModel> fields,
    required List<ScholarshipModel> scholarships,
  }) {
    final scores = <String, int>{};

    for (final question in questions) {
      final selectedOptionIds = answers[question.id] ?? <String>[];
      for (final option in question.options) {
        if (!selectedOptionIds.contains(option.id)) continue;
        option.weights.forEach((fieldId, weight) {
          scores[fieldId] = (scores[fieldId] ?? 0) + weight;
        });
      }
    }

    if (scores.isEmpty && profile.fieldIds.isNotEmpty) {
      for (final fieldId in profile.fieldIds) {
        scores[fieldId] = (scores[fieldId] ?? 0) + 3;
      }
    }

    final recommendations = scores.entries.toList()
      ..sort((left, right) => right.value.compareTo(left.value));

    final topThree = recommendations.take(3).map((entry) {
      final field = fields.firstWhereOrNull((item) => item.id == entry.key);
      if (field == null) return null;

      final countries = <String>{
        ...field.relatedCountryIds,
        ...profile.targetCountryIds,
      }.toList();
      final scholarshipIds = <String>{
        ...field.relatedScholarshipIds,
        ...scholarships
            .where((scholarship) => scholarship.relatedFieldIds.contains(field.id))
            .map((scholarship) => scholarship.id),
      }.toList();

      return OrientationRecommendation(
        fieldId: field.id,
        score: max(entry.value * 10, 55),
        explanation: _buildExplanation(profile.preferredLanguage, field),
        relatedCountryIds: countries,
        relatedScholarshipIds: scholarshipIds,
      );
    }).whereType<OrientationRecommendation>().toList();

    return OrientationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      completedAt: DateTime.now(),
      answers: answers,
      recommendations: topThree,
    );
  }

  static LocalizedText _buildExplanation(String locale, FieldModel field) {
    final leadingSkill = field.skills.firstOrNull;
    final leadingCareer = field.careers.firstOrNull;

    final skillFr = leadingSkill?.fr ?? 'ce domaine';
    final skillEn = leadingSkill?.en ?? 'this area';
    final careerFr = leadingCareer?.fr ?? 'ce secteur';
    final careerEn = leadingCareer?.en ?? 'this sector';

    return LocalizedText(
      fr:
          '${field.name.fr} ressort fortement car vos réponses montrent un intérêt pour ${skillFr.toLowerCase()} et un potentiel vers des parcours comme ${careerFr.toLowerCase()}. KPB peut maintenant vous guider vers les pays, les programmes et les bourses les plus adaptés.',
      en:
          '${field.name.en} stands out strongly because your answers show interest in ${skillEn.toLowerCase()} and real potential for careers such as ${careerEn.toLowerCase()}. KPB can now guide you toward the most relevant countries, programs, and scholarships.',
    );
  }
}
