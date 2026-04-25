import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/data/orientation_engine.dart';
import 'package:karatou/app/core/data/mock_catalog.dart';
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
        scholarships: MockCatalog.scholarships,
      );

      expect(result.recommendations, isNotEmpty);
      expect(result.recommendations.length, lessThanOrEqualTo(3));
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
        scholarships: MockCatalog.scholarships,
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
        scholarships: MockCatalog.scholarships,
      );

      expect(
        result.recommendations.first.explanation.en,
        contains('stands out strongly'),
      );
    });
  });
}
