import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/compare/institution_compare_screen.dart';

import '../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement restyle (PR3): the university Comparateur
// and its net-new "Sélecteur d'université" picker modal. Verify the compact
// table renders real catalog data, the picker exposes a search field, and
// choosing a row swaps the compared column.
// ─────────────────────────────────────────────────────────────────────────────

CountryModel _france() => const CountryModel(
      id: 'fra',
      name: LocalizedText(fr: 'France', en: 'France'),
      whyStudy:
          LocalizedText(fr: 'Grande destination.', en: 'Top destination.'),
      tuitionRange: LocalizedText(fr: '3 000–8 000 €', en: '3,000–8,000 €'),
      livingCostRange: LocalizedText(fr: '600–900 €', en: '600–900 €'),
      visaOverview: LocalizedText(fr: 'VLS-TS.', en: 'VLS-TS.'),
      admissionDifficulty: LocalizedText(fr: 'Moyenne', en: 'Medium'),
      popularFieldIds: ['d01'],
      flagEmoji: '🇫🇷',
      nextIntakeLabel: LocalizedText(fr: 'Septembre', en: 'September'),
      marketingDescription: LocalizedText(fr: 'KPB.', en: 'KPB.'),
      whyStudyBulletsFr: ['Diplômes reconnus'],
      whyStudyBulletsEn: ['Recognized degrees'],
      howItWorks: LocalizedText(fr: 'Choisir · Déposer', en: 'Pick · Submit'),
    );

InstitutionModel _inst({
  required String id,
  required String name,
  required String city,
  required String tuition,
  required List<String> programIds,
  bool isPartner = false,
}) =>
    InstitutionModel(
      id: id,
      name: LocalizedText(fr: name, en: name),
      countryId: 'fra',
      location: LocalizedText(fr: city, en: city),
      overview: const LocalizedText(fr: 'École.', en: 'School.'),
      studyLevels: const ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: tuition, en: tuition),
      languageRequirements: const LocalizedText(fr: 'B2', en: 'B2'),
      intakePeriods: const ['Septembre'],
      programIds: programIds,
      isPartner: isPartner,
    );

ProgramModel _program(String id, String institutionId) => ProgramModel(
      id: id,
      institutionId: institutionId,
      countryId: 'fra',
      fieldId: 'd01',
      name: const LocalizedText(fr: 'Programme', en: 'Program'),
      level: const LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
      duration: const LocalizedText(fr: '3 ans', en: '3 years'),
      tuition: const LocalizedText(fr: '8 850 €/an', en: '8,850 €/yr'),
      language: const LocalizedText(fr: 'Français', en: 'French'),
      requirements: const [LocalizedText(fr: 'Bac', en: 'Diploma')],
    );

Future<AppController> _seedController() async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();

  final institutions = [
    _inst(
      id: 'ece-paris',
      name: 'ECE Paris',
      city: 'Paris',
      tuition: '8 850 €/an',
      programIds: const ['fra-paris'],
      isPartner: true,
    ),
    _inst(
      id: 'epita-lyon',
      name: 'EPITA Lyon',
      city: 'Lyon',
      tuition: '7 200 €/an',
      programIds: const ['fra-lyon'],
    ),
    _inst(
      id: 'esme-nice',
      name: 'ESME Nice',
      city: 'Nice',
      tuition: '6 500 €/an',
      programIds: const [],
    ),
  ];

  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    countries: [_france()],
    institutions: institutions,
    programs: [
      _program('fra-paris', 'ece-paris'),
      _program('fra-lyon', 'epita-lyon'),
    ],
  );

  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();
  controller.countries
    ..clear()
    ..addAll(snapshot.countries);
  controller.institutions
    ..clear()
    ..addAll(institutions);
  controller.programs
    ..clear()
    ..addAll(snapshot.programs);

  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('fr'),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(resetGetxSingleton);

  testWidgets(
      'Comparator renders the compact table with two real universities '
      'and a per-column PICK affordance', (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const InstitutionCompareScreen(
      institutionId1: 'ece-paris',
      institutionId2: 'epita-lyon',
    )));
    await tester.pumpAndSettle();

    expect(find.text('Comparaison'), findsOneWidget); // compare_title
    expect(find.text('ECE Paris'), findsWidgets);
    expect(find.text('EPITA Lyon'), findsWidgets);
    expect(find.textContaining('8 850'), findsWidgets); // real tuition row
    expect(find.text('CHOISIR'), findsNWidgets(2)); // one PICK per column
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tapping a column opens the picker with a search field',
      (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const InstitutionCompareScreen(
      institutionId1: 'ece-paris',
      institutionId2: 'epita-lyon',
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('CHOISIR').first);
    await tester.pumpAndSettle();

    expect(find.text('Choisir une université'), findsOneWidget); // sheet title
    expect(find.byType(TextField), findsOneWidget); // search field
    expect(tester.takeException(), isNull);
  });

  testWidgets('Picking a university swaps the compared column', (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const InstitutionCompareScreen(
      institutionId1: 'ece-paris',
      institutionId2: 'epita-lyon',
    )));
    await tester.pumpAndSettle();

    // Edit the first column; the opposite column (EPITA Lyon) is excluded, so
    // the list offers ESME Nice.
    await tester.tap(find.text('CHOISIR').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ESME Nice'));
    await tester.pumpAndSettle();

    // First column is now ESME Nice; ECE Paris is gone from the comparison.
    expect(find.text('ESME Nice'), findsWidgets);
    expect(find.text('ECE Paris'), findsNothing);
    expect(find.text('EPITA Lyon'), findsWidgets); // untouched column
    expect(tester.takeException(), isNull);
  });
}
