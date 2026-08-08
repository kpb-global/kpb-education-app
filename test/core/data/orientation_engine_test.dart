import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/orientation_engine.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';
import 'package:karatou/app/core/data/orientation_questions_m4.dart';
import 'package:karatou/app/core/models/app_models.dart';

UserProfile _profile({
  List<String>? fieldIds,
  String language = 'fr',
}) {
  return UserProfile(
    id: 'u1',
    accountType: AccountType.student,
    fullName: 'Test User',
    email: 'test@example.com',
    phone: '+22500000000',
    whatsApp: '+22500000000',
    countryOfResidence: 'CI',
    preferredLanguage: language,
    fieldIds: fieldIds ?? const <String>[],
    targetCountryIds: const <String>['france'],
    availableDocuments: const <String>['Passport'],
    wantsScholarshipSupport: true,
  );
}

void main() {
  group('OrientationEngine.evaluate', () {
    final mockScholarships = [
      const ScholarshipModel(
        id: 'brs_test_1',
        name: LocalizedText(fr: 'Bourse Test 1', en: 'Test Scholarship 1'),
        countryId: 'france',
        levelEligible: LocalizedText(fr: 'Master', en: 'Master'),
        typeOfFunding: LocalizedText(fr: 'Complet', en: 'Full'),
        deadlineLabel: LocalizedText(fr: 'Juin', en: 'June'),
        keyRequirements: [
          LocalizedText(fr: 'Critère 1', en: 'Requirement 1'),
        ],
        relatedFieldIds: ['d01'],
        baseMatch: 0,
      ),
    ];

    test('returns ranked recommendations when answers are provided', () {
      final profile = _profile(language: 'fr');
      final answers = <String, List<String>>{
        'interests': <String>['tech'],
        'strengths': <String>['analysis'],
        'goal': <String>['global_job'],
      };

      final result = OrientationEngine.evaluate(
        profile: profile,
        answers: answers,
        questions: MockCatalog.orientationQuestions,
        fields: MockCatalog.fields,
        scholarships: mockScholarships,
      );

      expect(result.recommendations, isNotEmpty);
      expect(result.recommendations.length, lessThanOrEqualTo(5));
      expect(result.recommendations.first.score, greaterThanOrEqualTo(55));
      expect(result.answers, equals(answers));
    });

    test('falls back to profile fieldIds when answers are empty', () {
      final profile = _profile(fieldIds: const <String>['d01']);

      final result = OrientationEngine.evaluate(
        profile: profile,
        answers: const <String, List<String>>{},
        questions: MockCatalog.orientationQuestions,
        fields: MockCatalog.fields,
        scholarships: mockScholarships,
      );

      expect(result.recommendations, isNotEmpty);
      expect(result.recommendations.first.fieldId, equals('d01'));
    });

    test('builds english explanation when profile language is en', () {
      final profile = _profile(language: 'en');
      final answers = <String, List<String>>{
        'interests': <String>['tech'],
      };

      final result = OrientationEngine.evaluate(
        profile: profile,
        answers: answers,
        questions: MockCatalog.orientationQuestions,
        fields: MockCatalog.fields,
        scholarships: mockScholarships,
      );

      expect(
        result.recommendations.first.explanation.en,
        contains('stands out strongly'),
      );
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  // A match score is a percentage. It has to stay in [0, 100] and it has to
  // actually tell fields apart — otherwise the "best match" badge is arbitrary.
  //
  // Regression: the engine used to publish `rawPoints * 10`, which shipped
  // result cards reading "160 %" with a saturated progress bar, and two
  // different fields landing on the same raw total displayed the identical
  // percentage.
  // ───────────────────────────────────────────────────────────────────────────
  group('OrientationEngine match percentage invariants', () {
    // The real questionnaire is the mock catalog's five questions plus the M4
    // extension — the same list AppController feeds the engine.
    final allQuestions = <OrientationQuestion>[
      ...MockCatalog.orientationQuestions,
      ...orientationQuestionsM4Extension,
    ];

    /// Answer set of a student whose answers all point at the same field, i.e.
    /// the worst case for an unnormalised cumulative score (raw total 24 for
    /// `d01`, which the old formula published as 240 %).
    const maxedOutAnswers = <String, List<String>>{
      'interests': ['tech'],
      'strengths': ['analysis'],
      'goal': ['global_job'],
      'environment': ['office'],
      'level': ['bac5'],
      'ai_concern': ['ai_yes'],
      'languages': ['lang_en'],
      'budget_band': ['budget_high'],
      'mobility': ['mobility_yes'],
    };

    /// Answer set that used to make two cards display the exact same "160 %"
    /// (`d01` and `d03` both totalled 16 raw points).
    const collidingAnswers = <String, List<String>>{
      'interests': ['tech'],
      'strengths': ['analysis'],
      'goal': ['global_job'],
      'environment': ['office'],
      'level': ['bac3'],
      'ai_concern': ['ai_yes'],
      'languages': ['lang_fr'],
      'avoid': ['avoid_desk'],
      'budget_band': ['budget_low'],
      'mobility': ['mobility_yes'],
    };

    const healthAnswers = <String, List<String>>{
      'interests': ['health'],
      'strengths': ['care'],
      'goal': ['impact'],
      'environment': ['hospital'],
      'level': ['bac8'],
      'ai_concern': ['ai_no'],
      'languages': ['lang_fr'],
      'avoid': ['avoid_sales'],
      'budget_band': ['budget_low'],
      'mobility': ['mobility_no'],
    };

    OrientationSession evaluateAnswers(Map<String, List<String>> answers) {
      return OrientationEngine.evaluate(
        profile: _profile(),
        answers: answers,
        questions: allQuestions,
        fields: MockCatalog.fields,
        scholarships: const <ScholarshipModel>[],
      );
    }

    test(
        'every score stays within [0, 100] — even when answers pile up on '
        'a single field', () {
      final result = evaluateAnswers(maxedOutAnswers);

      expect(result.recommendations, isNotEmpty);
      for (final rec in result.recommendations) {
        expect(rec.score, inInclusiveRange(0, 100),
            reason: '${rec.fieldId} scored ${rec.score}%');
      }
      // The old formula published 24 * 10 = 240 for the top field.
      expect(result.recommendations.first.score, lessThanOrEqualTo(100));
      expect(result.recommendations.first.fieldId, equals('d01'));
    });

    test('stays within [0, 100] across every question/option combination', () {
      final random = Random(1234);

      for (var i = 0; i < 400; i++) {
        final answers = <String, List<String>>{};
        for (final question in allQuestions) {
          final options = question.options;
          if (question.multiSelect) {
            final picks = <String>{};
            final count = 1 + random.nextInt(min(3, options.length));
            while (picks.length < count) {
              picks.add(options[random.nextInt(options.length)].id);
            }
            answers[question.id] = picks.toList();
          } else {
            answers[question.id] = [options[random.nextInt(options.length)].id];
          }
        }

        final percents = OrientationEngine.matchPercentByField(
          answers: answers,
          questions: allQuestions,
        );
        for (final entry in percents.entries) {
          expect(entry.value, inInclusiveRange(0, 100),
              reason: 'answers=$answers field=${entry.key}');
        }

        for (final rec in evaluateAnswers(answers).recommendations) {
          expect(rec.score, inInclusiveRange(0, 100),
              reason: 'answers=$answers field=${rec.fieldId}');
        }
      }
    });

    test('different answer profiles produce different scores', () {
      final tech = OrientationEngine.matchPercentByField(
        answers: collidingAnswers,
        questions: allQuestions,
      );
      final health = OrientationEngine.matchPercentByField(
        answers: healthAnswers,
        questions: allQuestions,
      );

      expect(tech, isNot(equals(health)));

      final techResult = evaluateAnswers(collidingAnswers);
      final healthResult = evaluateAnswers(healthAnswers);

      expect(techResult.recommendations.first.fieldId, equals('d01'));
      expect(healthResult.recommendations.first.fieldId, equals('d04'));
      expect(
        techResult.recommendations.first.score,
        isNot(equals(healthResult.recommendations.first.score)),
      );

      // Two answer sets that differ only on the practical questions must not
      // collapse onto the same percentage either.
      final maxed = evaluateAnswers(maxedOutAnswers);
      expect(
        techResult.recommendations.first.score,
        isNot(equals(maxed.recommendations.first.score)),
      );
    });

    test('tells fields apart inside a single result', () {
      final result = evaluateAnswers(collidingAnswers);
      final scores = result.recommendations.map((r) => r.score).toList();

      expect(scores.length, greaterThanOrEqualTo(2));
      // `d01` and `d03` used to tie at 160 % — the badge fell on whichever the
      // sort kept first.
      expect(scores.first, isNot(equals(scores[1])));
      expect(scores.toSet().length, equals(scores.length));
      // Ranked best first.
      final sorted = [...scores]..sort((a, b) => b.compareTo(a));
      expect(scores, equals(sorted));
    });

    test('does not recommend a field the answers pushed away', () {
      final result = evaluateAnswers(const <String, List<String>>{
        'avoid': ['avoid_sales'],
      });

      expect(
        result.recommendations.map((r) => r.fieldId),
        isNot(contains('d02')),
      );
    });
  });
}
