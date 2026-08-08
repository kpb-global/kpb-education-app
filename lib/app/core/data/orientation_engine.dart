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

  /// Relative importance of each question in the match score. What a student is
  /// drawn to (interests, strengths, goal) weighs more than the practical
  /// constraints (budget, mobility).
  ///
  /// The non-uniform, fractional importances are also what give the score real
  /// resolution. The previous flat sum of integer weights landed two *different*
  /// fields on the exact same total for ~15% of answer sets, so two cards
  /// displayed the same percentage and the "best match" badge fell on whichever
  /// field the sort happened to keep first. Weighting each question differently
  /// drops that collision rate to ~4%.
  static const _questionImportance = <String, double>{
    'interests': 1.5,
    'strengths': 1.4,
    'goal': 1.3,
    'avoid': 1.2,
    'environment': 1.1,
    'ai_concern': 1.0,
    'level': 0.8,
    'languages': 0.7,
    'budget_band': 0.6,
    'mobility': 0.6,
  };

  /// Importance applied to any question missing from [_questionImportance]
  /// (a catalog-driven question added after this build, for instance).
  static const _defaultImportance = 1.0;

  /// Share of the attainable weight that counts as a perfect (100%) match.
  ///
  /// The attainable weight computed by [_weigh] is what an imaginary field
  /// would score if it were the top-weighted answer to *every* question the
  /// student answered. No real field can be, so normalising on that raw ceiling
  /// would keep even excellent matches near 60%. A field that captures 80% of
  /// the ceiling is treated as a perfect match.
  static const _perfectMatchRatio = 0.8;

  /// Highest percentage ever surfaced. Mirrors the 98 ceiling the program and
  /// institution match scores already use, so no card claims a flawless 100%.
  static const _maxPercent = 98;

  /// Percentage used when there is nothing to score and the recommendation
  /// falls back to the fields the student declared in their profile.
  static const _declaredInterestPercent = 55;

  static OrientationSession evaluate({
    required UserProfile profile,
    required Map<String, List<String>> answers,
    required List<OrientationQuestion> questions,
    required List<FieldModel> fields,
    required List<ScholarshipModel> scholarships,
  }) {
    var scores = matchPercentByField(answers: answers, questions: questions)
        .entries
        .toList();

    if (scores.isEmpty && profile.fieldIds.isNotEmpty) {
      scores = profile.fieldIds
          .toSet()
          .map((fieldId) => MapEntry(fieldId, _declaredInterestPercent))
          .toList();
    }

    final prioritizeIaResilience =
        (answers['ai_concern'] ?? const []).contains('ai_yes');

    final recommendations = scores
      ..sort((left, right) {
        // The percentage is the ranking key; AI resilience (and then the field
        // id, for determinism) only breaks exact ties. Ranking on resilience
        // first would surface a weaker match above a stronger one.
        final byScore = right.value.compareTo(left.value);
        if (byScore != 0) return byScore;
        if (prioritizeIaResilience) {
          final byResilience =
              _iaRankOf(right.key).compareTo(_iaRankOf(left.key));
          if (byResilience != 0) return byResilience;
        }
        return left.key.compareTo(right.key);
      });

    final topFive = recommendations
        .take(5)
        .map((entry) {
          final field = fields.firstWhereOrNull((item) => item.id == entry.key);
          if (field == null) return null;

          final countries = <String>{
            ...field.relatedCountryIds,
            ...profile.targetCountryIds,
          }.toList();
          final scholarshipIds = <String>{
            ...field.relatedScholarshipIds,
            ...scholarships
                .where((scholarship) =>
                    scholarship.relatedFieldIds.contains(field.id))
                .map((scholarship) => scholarship.id),
          }.toList();

          final iaResilience = _fieldIaResilience[field.id] ?? 'medium';

          return OrientationRecommendation(
            fieldId: field.id,
            score: entry.value,
            explanation: _buildExplanation(profile.preferredLanguage, field),
            relatedCountryIds: countries,
            relatedScholarshipIds: scholarshipIds,
            jobs: profile.preferredLanguage.startsWith('en')
                ? field.careers.map((c) => c.en).take(3).toList()
                : field.careers.map((c) => c.fr).take(3).toList(),
            iaResilience: iaResilience,
          );
        })
        .whereType<OrientationRecommendation>()
        .toList();

    return OrientationSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      completedAt: DateTime.now(),
      answers: answers,
      recommendations: topFive,
    );
  }

  static int _iaRankOf(String fieldId) =>
      _iaRank[_fieldIaResilience[fieldId] ?? 'medium'] ?? 2;

  /// Weighted alignment per field for [answers], plus the ceiling a single
  /// field could reach on the very same answers.
  static ({Map<String, double> weights, double attainable}) _weigh({
    required Map<String, List<String>> answers,
    required List<OrientationQuestion> questions,
  }) {
    final weights = <String, double>{};
    var attainable = 0.0;

    for (final question in questions) {
      final selectedOptionIds = answers[question.id] ?? const <String>[];
      if (selectedOptionIds.isEmpty) continue;
      final importance = _questionImportance[question.id] ?? _defaultImportance;

      for (final option in question.options) {
        if (!selectedOptionIds.contains(option.id)) continue;
        option.weights.forEach((fieldId, weight) {
          weights[fieldId] = (weights[fieldId] ?? 0) + importance * weight;
        });
        // Best a single field could score on this option. Options that only
        // subtract (the "what would you NOT do" question) raise nobody's score,
        // so they add nothing to the ceiling either.
        final best = option.weights.values
            .fold<int>(0, (acc, weight) => weight > acc ? weight : acc);
        attainable += importance * best;
      }
    }

    return (weights: weights, attainable: attainable);
  }

  static int _percent(double weighted, double attainable) {
    if (weighted <= 0 || attainable <= 0) return 0;
    final ratio = weighted / (attainable * _perfectMatchRatio);
    return (ratio * 100).round().clamp(0, _maxPercent);
  }

  /// Match percentage in `[0, _maxPercent]` for every field the answers give
  /// positive evidence for.
  ///
  /// This is the single source of truth for the percentage a result card shows.
  /// The results screen calls it directly so that a session scored somewhere
  /// else — by the REST backend, or persisted by an older build — is presented
  /// on this same normalised scale instead of leaking raw points.
  static Map<String, int> matchPercentByField({
    required Map<String, List<String>> answers,
    required List<OrientationQuestion> questions,
  }) {
    final weighed = _weigh(answers: answers, questions: questions);
    final percents = <String, int>{};
    weighed.weights.forEach((fieldId, weight) {
      // A field the answers actively pushed away (negative weight only, e.g.
      // "I would never do sales") is not a recommendation.
      if (weight <= 0) return;
      percents[fieldId] = _percent(weight, weighed.attainable);
    });
    return percents;
  }

  static LocalizedText _buildExplanation(String locale, FieldModel field) {
    final leadingSkill = field.skills.firstOrNull;
    final leadingCareer = field.careers.firstOrNull;

    final skillFr = leadingSkill?.fr ?? 'ce domaine';
    final skillEn = leadingSkill?.en ?? 'this area';
    final careerFr = leadingCareer?.fr ?? 'ce secteur';
    final careerEn = leadingCareer?.en ?? 'this sector';

    return LocalizedText(
      fr: '${field.name.fr} ressort fortement car vos réponses montrent un intérêt pour ${skillFr.toLowerCase()} et un potentiel vers des parcours comme ${careerFr.toLowerCase()}. KPB peut maintenant vous guider vers les pays, les programmes et les bourses les plus adaptés.',
      en: '${field.name.en} stands out strongly because your answers show interest in ${skillEn.toLowerCase()} and real potential for careers such as ${careerEn.toLowerCase()}. KPB can now guide you toward the most relevant countries, programs, and scholarships.',
    );
  }
}
