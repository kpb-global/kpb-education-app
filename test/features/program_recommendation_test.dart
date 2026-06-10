import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/utils/program_recommendation_utils.dart';

import '../widget_test_helpers.dart';

ProgramModel _program({
  required String id,
  required String institutionId,
  String countryId = 'fra',
  String nameFr = 'Programme test',
}) {
  return ProgramModel(
    id: id,
    institutionId: institutionId,
    countryId: countryId,
    fieldId: 'computer_science',
    name: LocalizedText(fr: nameFr, en: nameFr),
    level: const LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
    duration: const LocalizedText(fr: '3 ans', en: '3 years'),
    tuition: const LocalizedText(fr: '8 850 €/an', en: '8,850 EUR/year'),
    language: const LocalizedText(fr: 'Français', en: 'French'),
    requirements: const [],
  );
}

InstitutionModel _institution({
  required String id,
  required String nameFr,
  String countryId = 'fra',
}) {
  return InstitutionModel(
    id: id,
    name: LocalizedText(fr: nameFr, en: nameFr),
    countryId: countryId,
    location: const LocalizedText(fr: 'Lyon', en: 'Lyon'),
    overview: const LocalizedText(fr: 'Campus', en: 'Campus'),
    studyLevels: const ['Bachelor'],
    tuitionLabel: const LocalizedText(fr: 'Voir programme', en: 'See program'),
    languageRequirements:
        const LocalizedText(fr: 'Français', en: 'French'),
    intakePeriods: const ['Septembre'],
    programIds: const [],
    isPartner: true,
  );
}

void main() {
  group('ProgramRecommendationUtils', () {
    late AppController controller;

    setUp(() async {
      resetGetxSingleton();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        institutions: [
          _institution(
            id: 'omnes-ece-lyon',
            nameFr: 'ECE — Lyon',
          ),
          _institution(
            id: 'omnes-ece-paris',
            nameFr: 'ECE — Paris',
          ),
        ],
        programs: [
          _program(
            id: 'omnes-p-paris',
            institutionId: 'omnes-ece-paris',
            nameFr: 'ECE Paris — Bachelor',
          ),
          _program(
            id: 'omnes-p-lyon',
            institutionId: 'omnes-ece-lyon',
            nameFr: 'ECE Lyon — Bachelor IA',
          ),
        ],
      );
      controller = AppController(
        repository: FakeRepository(snapshot: snapshot),
        apiClient: MockApiClient(),
      );
      await controller.hydrate();
      controller.institutions
        ..clear()
        ..addAll(snapshot.institutions);
      controller.programs
        ..clear()
        ..addAll(snapshot.programs);
    });

    tearDown(resetGetxSingleton);

    test('returns ECE Lyon program for France conversion CTA', () {
      final program =
          ProgramRecommendationUtils.recommendedEceLyonProgram(controller);

      expect(program, isNotNull);
      expect(program!.id, 'omnes-p-lyon');
      expect(program.institutionId, 'omnes-ece-lyon');
    });

    test('returns null for non-France countries', () {
      final program = ProgramRecommendationUtils.recommendedProgramForCountry(
        controller,
        'can',
        schoolHint: 'ece',
        campusHint: 'lyon',
      );

      expect(program, isNull);
    });
  });
}
