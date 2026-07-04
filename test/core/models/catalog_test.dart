import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';

void main() {
  group('LiveScholarshipModel.fromJson — application requirement & steps', () {
    Map<String, dynamic> baseJson({
      String? applicationRequirement,
      List<dynamic>? applicationSteps,
    }) {
      return {
        'id': 'sch-1',
        'title': 'Chevening Scholarship',
        'countryName': 'United Kingdom',
        'fundingType': 'fully_funded',
        if (applicationRequirement != null)
          'applicationRequirement': applicationRequirement,
        'description': 'Description',
        'advantages': <String>[],
        'eligibility': <String>[],
        'level': 'Master',
        'deadlineLabel': 'November',
        'applicationUrl': 'https://chevening.org',
        'tags': <String>[],
        'matchScore': 42,
        if (applicationSteps != null) 'applicationSteps': applicationSteps,
      };
    }

    test('defaults applicationRequirement to separate_application when absent',
        () {
      final model = LiveScholarshipModel.fromJson(baseJson());
      expect(model.applicationRequirement, 'separate_application');
      expect(model.isAutomaticAdmission, isFalse);
    });

    test('parses an explicit automatic applicationRequirement', () {
      final model = LiveScholarshipModel.fromJson(
        baseJson(applicationRequirement: 'automatic'),
      );
      expect(model.applicationRequirement, 'automatic');
      expect(model.isAutomaticAdmission, isTrue);
    });

    test('defaults applicationSteps to an empty list when absent', () {
      final model = LiveScholarshipModel.fromJson(baseJson());
      expect(model.applicationSteps, isEmpty);
    });

    test('parses applicationSteps into ScholarshipApplicationStepModel', () {
      final model = LiveScholarshipModel.fromJson(baseJson(
        applicationSteps: [
          {
            'id': 'step-1',
            'stepNumber': 1,
            'title': 'Online form',
            'description': 'Fill in the form',
            'estimatedDurationDays': 30,
          },
          {
            'id': 'step-2',
            'stepNumber': 2,
            'title': 'Interview',
            'description': '',
          },
        ],
      ));

      expect(model.applicationSteps, hasLength(2));
      expect(model.applicationSteps[0].id, 'step-1');
      expect(model.applicationSteps[0].stepNumber, 1);
      expect(model.applicationSteps[0].title, 'Online form');
      expect(model.applicationSteps[0].estimatedDurationDays, 30);
      expect(model.applicationSteps[1].estimatedDurationDays, isNull);
    });
  });
}
