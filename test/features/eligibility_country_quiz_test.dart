import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/eligibility/eligibility_simulator_data.dart';

/// KPB-62: the per-country quiz is now scored by the single client-side
/// [EligibilityEngine] (ported verbatim from the former backend scorer). These
/// cases lock that logic so the explore quiz and the simulator can never give
/// contradictory verdicts from two divergent engines.
void main() {
  const engine = EligibilityEngine();
  EligibilityVerdict score(String country, Map<String, String> a) =>
      engine.scoreCountryQuiz(country, a);

  group('scoreCountryQuiz — single engine, per-country trees', () {
    test('France', () {
      expect(
          score('fra', {'q2_diploma': 'no'}), EligibilityVerdict.notEligible);
      expect(
        score('fra', {
          'q2_diploma': 'yes_obtained',
          'q5_french_level': 'fluent',
          'q7_financial_proof': 'yes',
          'q6_visa_history': 'none',
        }),
        EligibilityVerdict.eligible,
      );
      expect(
        score(
            'fra', {'q2_diploma': 'yes_obtained', 'q5_french_level': 'basic'}),
        EligibilityVerdict.eligibleWithConditions,
      );
      // basic French + no funds → hard fail.
      expect(
        score('fra', {'q5_french_level': 'basic', 'q7_financial_proof': 'no'}),
        EligibilityVerdict.notEligible,
      );
    });

    test('Germany', () {
      expect(score('deu', {'q5_blocked_account': 'no'}),
          EligibilityVerdict.notEligible);
      expect(score('deu', {'q2_german_level': 'advanced'}),
          EligibilityVerdict.eligible);
      expect(
        score('deu', {
          'q4_language_track': 'yes_partial',
          'q5_blocked_account': 'yes_difficult'
        }),
        EligibilityVerdict.eligibleWithConditions,
      );
    });

    test('USA', () {
      expect(
          score('usa', {'q4_budget': 'low'}), EligibilityVerdict.notEligible);
      expect(
        score('usa', {'q3_english_level': 'advanced', 'q4_budget': 'high'}),
        EligibilityVerdict.eligible,
      );
      expect(score('usa', {'q3_english_level': 'intermediate'}),
          EligibilityVerdict.eligibleWithConditions);
    });

    test('Canada / UK / UAE require funds', () {
      expect(
          score('can', {'q4_budget': 'low'}), EligibilityVerdict.notEligible);
      expect(
        score('can', {
          'q2_diploma': 'yes_obtained',
          'q3_english_level': 'advanced',
          'q4_budget': 'high',
        }),
        EligibilityVerdict.eligible,
      );
      expect(score('gbr', {'q4_budget': 'low', 'q2_diploma': 'yes_obtained'}),
          EligibilityVerdict.notEligible);
      expect(
        score('gbr', {
          'q3_english_level': 'advanced',
          'q4_budget': 'high',
          'q2_diploma': 'yes_obtained'
        }),
        EligibilityVerdict.eligible,
      );
      expect(
          score('are', {'q4_budget': 'low'}), EligibilityVerdict.notEligible);
      expect(
          score('are', {'q3_english_level': 'advanced', 'q4_budget': 'high'}),
          EligibilityVerdict.eligible);
    });

    test('Morocco / Turkey / Spain', () {
      expect(score('mar', {'q2_diploma': 'no', 'q4_budget': 'low'}),
          EligibilityVerdict.notEligible);
      expect(
          score('mar',
              {'q2_diploma': 'yes_obtained', 'q3_french_level': 'fluent'}),
          EligibilityVerdict.eligible);
      expect(
          score('tur', {'q2_diploma': 'no'}), EligibilityVerdict.notEligible);
      expect(score('tur', {'q4_budget': 'low', 'q2_diploma': 'yes_obtained'}),
          EligibilityVerdict.eligibleWithConditions);
      expect(
          score('esp', {'q2_diploma': 'no'}), EligibilityVerdict.notEligible);
      expect(
        score('esp', {
          'q3_english_level': 'advanced',
          'q4_budget': 'high',
          'q2_diploma': 'yes_obtained'
        }),
        EligibilityVerdict.eligible,
      );
    });

    test('unknown country / empty answers default to "with conditions"', () {
      expect(score('zzz', const {}), EligibilityVerdict.eligibleWithConditions);
      expect(score('fra', const {}), EligibilityVerdict.eligibleWithConditions);
    });

    test('deterministic — identical answers always yield the same verdict', () {
      final a = {'q2_diploma': 'yes_obtained', 'q5_french_level': 'fluent'};
      expect(score('fra', a), score('fra', Map<String, String>.from(a)));
    });
  });
}
