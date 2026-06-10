import 'dart:math';

import 'package:collection/collection.dart';

import '../models/app_models.dart';

/// Evaluates a student's orientation answers against the catalog of fields,
/// producing ranked recommendations. All catalog data is injected to decouple
/// the engine from any static data source.
class OrientationEngine {
  static const _iaRank = {'high': 3, 'medium': 2, 'low': 1};

  static const _fieldIaResilience = <String, String>{
    'd01': 'high',
    'd02': 'medium',
    'd03': 'high',
    'd04': 'high',
    'd05': 'medium',
    'd06': 'medium',
    'd07': 'high',
    'd08': 'medium',
    'd09': 'medium',
    'd10': 'low',
    'd11': 'high',
    'd12': 'medium',
  };

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

    final prioritizeIaResilience =
        (answers['ai_concern'] ?? const []).contains('ai_yes');

    final recommendations = scores.entries.toList()
      ..sort((left, right) {
        if (prioritizeIaResilience) {
          final leftIa = _iaRank[_fieldIaResilience[left.key] ?? 'medium'] ?? 2;
          final rightIa =
              _iaRank[_fieldIaResilience[right.key] ?? 'medium'] ?? 2;
          final leftScore = left.value * 10 + leftIa;
          final rightScore = right.value * 10 + rightIa;
          return rightScore.compareTo(leftScore);
        }
        return right.value.compareTo(left.value);
      });

    final topFive = recommendations.take(5).map((entry) {
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

      final iaResilience = _fieldIaResilience[field.id] ?? 'medium';

      return OrientationRecommendation(
        fieldId: field.id,
        score: max(entry.value * 10, 55),
        explanation: _buildExplanation(profile.preferredLanguage, field),
        relatedCountryIds: countries,
        relatedScholarshipIds: scholarshipIds,
        jobs: profile.preferredLanguage.startsWith('en')
            ? field.careers.map((c) => c.en).take(3).toList()
            : field.careers.map((c) => c.fr).take(3).toList(),
        iaResilience: iaResilience,
      );
    }).whereType<OrientationRecommendation>().toList();

    return OrientationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      completedAt: DateTime.now(),
      answers: answers,
      recommendations: topFive,
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
