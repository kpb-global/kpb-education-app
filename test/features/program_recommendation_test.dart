import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';

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

void main() {
  // The old France/ECE-Lyon-only stub (ProgramRecommendationUtils) was replaced
  // by AppController.topProgramForCountry, which ranks via the shared search
  // scorer and works for every destination — verified here.
  group('AppController.topProgramForCountry', () {
    late AppController controller;

    setUp(() async {
      resetGetxSingleton();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(),
        programs: [
          _program(
            id: 'fra-paris',
            institutionId: 'ece-paris',
            countryId: 'fra',
            nameFr: 'ECE Paris — Bachelor',
          ),
          _program(
            id: 'fra-lyon',
            institutionId: 'ece-lyon',
            countryId: 'fra',
            nameFr: 'ECE Lyon — Bachelor IA',
          ),
          _program(
            id: 'can-mcgill',
            institutionId: 'mcgill',
            countryId: 'can',
            nameFr: 'McGill — CS',
          ),
        ],
      );
      controller = AppController(
        repository: FakeRepository(snapshot: snapshot),
        apiClient: MockApiClient(),
      );
      await controller.hydrate();
      controller.programs
        ..clear()
        ..addAll(snapshot.programs);
    });

    tearDown(resetGetxSingleton);

    test('recommends a France program for the conversion CTA', () {
      final program = controller.topProgramForCountry('fra');
      expect(program, isNotNull);
      expect(program!.countryId, 'fra');
    });

    test('also recommends for a non-France country (no longer France-only)',
        () {
      final program = controller.topProgramForCountry('can');
      expect(program, isNotNull);
      expect(program!.id, 'can-mcgill');
    });

    test('returns null when the catalog has no program for that country', () {
      expect(controller.topProgramForCountry('deu'), isNull);
    });
  });
}
