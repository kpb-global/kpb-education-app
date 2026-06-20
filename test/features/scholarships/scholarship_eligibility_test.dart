import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/features/scholarships/scholarship_eligibility_screen.dart';

ScholarshipModel _scholarship({DateTime? deadlineAt}) => ScholarshipModel(
      id: 's',
      name: LocalizedText(fr: '', en: ''),
      countryId: 'uk',
      levelEligible: LocalizedText(fr: '', en: ''),
      typeOfFunding: LocalizedText(fr: '', en: ''),
      deadlineLabel: LocalizedText(fr: '', en: ''),
      keyRequirements: const [],
      relatedFieldIds: const [],
      baseMatch: 0,
      deadlineAt: deadlineAt,
    );

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

  group('ScholarshipModel.windowStatus', () {
    final now = DateTime(2026, 6, 20);

    test('deadline well in the future → open', () {
      expect(
        _scholarship(deadlineAt: DateTime(2026, 12, 1)).windowStatus(now: now),
        ScholarshipWindowStatus.open,
      );
    });

    test('deadline within the soon window → closingSoon', () {
      expect(
        _scholarship(deadlineAt: DateTime(2026, 7, 1)).windowStatus(now: now),
        ScholarshipWindowStatus.closingSoon,
      );
    });

    test('deadline in the past → closed', () {
      expect(
        _scholarship(deadlineAt: DateTime(2026, 6, 1)).windowStatus(now: now),
        ScholarshipWindowStatus.closed,
      );
    });

    test('no deadline → open (rolling)', () {
      expect(
        _scholarship().windowStatus(now: now),
        ScholarshipWindowStatus.open,
      );
    });
  });
}
