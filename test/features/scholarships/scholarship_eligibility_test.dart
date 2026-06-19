import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/features/scholarships/scholarship_eligibility_screen.dart';

void main() {
  group('computeScholarshipEligibility', () {
    test('all yes → eligible', () {
      expect(
        computeScholarshipEligibility(
            [CriterionAnswer.yes, CriterionAnswer.yes, CriterionAnswer.yes]),
        ScholarshipEligibilityVerdict.eligible,
      );
    });

    test('any no → unlikely (a stated criterion is not met)', () {
      expect(
        computeScholarshipEligibility(
            [CriterionAnswer.yes, CriterionAnswer.no, CriterionAnswer.yes]),
        ScholarshipEligibilityVerdict.unlikely,
      );
    });

    test('some maybe but no "no" → conditional', () {
      expect(
        computeScholarshipEligibility(
            [CriterionAnswer.yes, CriterionAnswer.maybe]),
        ScholarshipEligibilityVerdict.conditional,
      );
    });

    test('a "no" overrides any "maybe" → unlikely', () {
      expect(
        computeScholarshipEligibility(
            [CriterionAnswer.maybe, CriterionAnswer.no]),
        ScholarshipEligibilityVerdict.unlikely,
      );
    });

    test('empty answers → conditional (cannot confirm)', () {
      expect(
        computeScholarshipEligibility(const []),
        ScholarshipEligibilityVerdict.conditional,
      );
    });
  });
}
