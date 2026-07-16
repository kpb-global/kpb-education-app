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

    test('parses and orders optional scholarship YouTube videos', () {
      final json = baseJson();
      json['videos'] = <dynamic>[
        <String, dynamic>{
          'id': 'video-2',
          'youtubeVideoId': 'abcdefghijk',
          'title': 'Second video',
          'displayOrder': 2,
          'languageCode': 'en',
        },
        <String, dynamic>{
          'id': 'video-1',
          'watchUrl': 'https://youtu.be/l_0UPSeH5sU',
          'title': 'Featured video',
          'displayOrder': 9,
          'isFeatured': true,
        },
        <String, dynamic>{
          'id': 'invalid',
          'youtubeVideoId': 'invalid',
        },
      ];

      final model = LiveScholarshipModel.fromJson(json);

      expect(model.videos, hasLength(2));
      expect(model.videos.first.id, 'video-1');
      expect(model.videos.first.youtubeVideoId, 'l_0UPSeH5sU');
      expect(model.videos.last.language, 'en');
    });

    test('parses Phase 1 list and detail alert/video requirement keys', () {
      final listJson = baseJson();
      listJson
        ..['isAlertEnabled'] = true
        ..['keyRequirements'] = <String>['Two references']
        ..['featuredVideo'] = <String, dynamic>{
          'id': 'featured-1',
          'youtubeVideoId': 'dQw4w9WgXcQ',
          'title': 'How to apply',
          'isFeatured': true,
          'displayOrder': 0,
        };

      final listModel = LiveScholarshipModel.fromJson(listJson);

      expect(listModel.isAlertEnabled, isTrue);
      expect(listModel.keyRequirements, ['Two references']);
      expect(listModel.videos.single.id, 'featured-1');

      final detailJson = baseJson();
      detailJson['alert'] = <String, dynamic>{
        'subscribed': false,
        'pushEnabled': false,
        'inAppEnabled': false,
      };

      final detailModel = LiveScholarshipModel.fromJson(detailJson);
      expect(detailModel.isAlertEnabled, isFalse);
    });
  });
}
