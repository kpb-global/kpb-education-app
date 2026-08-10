import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:flutter/material.dart';
import 'package:karatou/app/features/destinations/destinations_screen.dart';
import 'package:karatou/app/features/explore/country_detail_screen.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';
import 'package:karatou/app/features/universities/universities_screen.dart';

import '../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement restyle (PR2): the two detail screens are
// pushed via Get.to and therefore not covered by the shell navigation test.
// These verify they render real catalog data without layout/render errors.
// ─────────────────────────────────────────────────────────────────────────────

CountryModel _country() => const CountryModel(
      id: 'fra',
      name: LocalizedText(fr: 'France', en: 'France'),
      whyStudy: LocalizedText(
        fr: 'Une grande destination étudiante.',
        en: 'A leading student destination.',
      ),
      tuitionRange:
          LocalizedText(fr: '3 000–8 000 €/an', en: '3,000–8,000 €/yr'),
      livingCostRange: LocalizedText(fr: '600–900 €/mois', en: '600–900 €/mo'),
      visaOverview: LocalizedText(
        fr: 'Visa étudiant long séjour VLS-TS.',
        en: 'Long-stay VLS-TS student visa.',
      ),
      admissionDifficulty: LocalizedText(fr: 'Moyenne', en: 'Medium'),
      popularFieldIds: ['computer_science'],
      flagEmoji: '🇫🇷',
      nextIntakeLabel:
          LocalizedText(fr: 'Septembre 2025', en: 'September 2025'),
      marketingDescription: LocalizedText(
        fr: 'Étudier en France avec KPB.',
        en: 'Study in France with KPB.',
      ),
      whyStudyBulletsFr: ['Diplômes reconnus', 'Coût maîtrisé'],
      whyStudyBulletsEn: ['Recognized degrees', 'Affordable'],
      howItWorks: LocalizedText(
        fr: 'Choisir une école · Déposer le dossier · Obtenir le visa',
        en: 'Pick a school · Submit the file · Get the visa',
      ),
    );

InstitutionModel _institution() => const InstitutionModel(
      id: 'ece-paris',
      name: LocalizedText(fr: 'ECE Paris', en: 'ECE Paris'),
      countryId: 'fra',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(
        fr: 'École d\'ingénieurs du numérique.',
        en: 'Digital engineering school.',
      ),
      studyLevels: ['Bachelor', 'Master'],
      tuitionLabel: LocalizedText(fr: '8 850 €/an', en: '8,850 €/yr'),
      languageRequirements: LocalizedText(fr: 'B2', en: 'B2'),
      intakePeriods: ['Septembre'],
      programIds: ['fra-paris'],
      isPartner: true,
    );

ProgramModel _program() => const ProgramModel(
      id: 'fra-paris',
      institutionId: 'ece-paris',
      countryId: 'fra',
      fieldId: 'computer_science',
      name: LocalizedText(fr: 'Bachelor Informatique', en: 'CS Bachelor'),
      level: LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
      duration: LocalizedText(fr: '3 ans', en: '3 years'),
      tuition: LocalizedText(fr: '8 850 €/an', en: '8,850 €/yr'),
      language: LocalizedText(fr: 'Français', en: 'French'),
      requirements: [
        LocalizedText(fr: 'Baccalauréat', en: 'High-school diploma')
      ],
    );

Future<AppController> _seedController() async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();

  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    countries: [_country()],
    institutions: [_institution()],
    programs: [_program()],
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
    ..addAll(snapshot.institutions);
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
      'UniversitiesScreen renders the destinations carousel and a '
      'match-ranked school row', (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const UniversitiesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Universités'), findsWidgets);
    expect(find.text('Bachelor Informatique'), findsOneWidget);
    // Compare pill (>= 2 institutions is required, but 1 here → hidden).
    expect(tester.takeException(), isNull);
  });

  testWidgets('UniversitiesScreen applies the handoff quick filters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _seedController();
    await tester.pumpWidget(_wrap(const UniversitiesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Meilleurs matchs'), findsOneWidget);
    expect(find.text('🇫🇷 France'), findsOneWidget);

    await tester.drag(
      find.byKey(const ValueKey('university_quick_filters')),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    for (final label in const [
      '🇨🇦 Canada',
      '♥ Mes cibles',
      '< 3 M FCFA',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    await tester.tap(find.text('< 3 M FCFA'));
    await tester.pumpAndSettle();
    expect(find.text('Bachelor Informatique'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('university_quick_filters')),
      const Offset(500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Meilleurs matchs'));
    await tester.pumpAndSettle();
    expect(find.text('Bachelor Informatique'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ProgramDetailScreen renders the fiche with real tuition and the '
      'application CTA', (tester) async {
    await _seedController();
    await tester
        .pumpWidget(_wrap(const ProgramDetailScreen(programId: 'fra-paris')));
    await tester.pumpAndSettle();

    expect(find.text('Bachelor Informatique'), findsWidgets);
    expect(find.text('Créer un dossier'), findsOneWidget); // create_application
    expect(find.textContaining('5 805 219'), findsWidgets); // XOF tuition
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'CountryDetailScreen renders the 6-section guide and the KPB CTAs',
      (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const CountryDetailScreen(countryId: 'fra')));
    await tester.pumpAndSettle();

    expect(find.text('France'), findsWidgets); // big title
    expect(find.text('GUIDE PAYS'), findsOneWidget); // hero badge
    expect(find.textContaining('Aperçu'), findsOneWidget); // section 1 heading
    // No fabricated tuition figure is surfaced anywhere in the guide.
    expect(find.textContaining('3 000–8 000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // Owner video review: the back button must stay on screen while scrolling —
  // the audience does not reliably know the iOS back-swipe gesture.
  testWidgets(
      'CountryDetailScreen keeps the breadcrumb back button pinned while '
      'scrolling', (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const CountryDetailScreen(countryId: 'fra')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    final before = tester.getTopLeft(find.byIcon(Icons.arrow_back_rounded));
    // Structural: the back button must NOT be a child of the scroll view —
    // that is the actual bug being fixed, independent of any drag distance.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsNothing,
    );

    // Scroll deep into the guide (before the fix the breadcrumb was the first
    // ListView child and left the screen here).
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();

    // Guard against a vacuous pass: prove the list really scrolled by checking
    // that in-list content (the hero badge) has left the viewport.
    expect(find.text('GUIDE PAYS'), findsNothing);

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(
      tester.getTopLeft(find.byIcon(Icons.arrow_back_rounded)),
      before,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'DestinationsScreen, when pushed, shows a pinned back bar that pops',
      (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () => Get.to<void>(() => const DestinationsScreen()),
          child: const Text('ouvrir'),
        ),
      ),
    )));
    await tester.tap(find.text('ouvrir'));
    await tester.pumpAndSettle();

    // Back bar present (screen previously had no back affordance at all).
    expect(find.text('Accueil'), findsOneWidget); // nav_home crumb
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    // Pinned by construction: the back bar lives outside the country list, so
    // it cannot scroll away. Asserted structurally rather than by dragging —
    // this fixture seeds a single country, so the list does not overflow the
    // test viewport and a drag assertion would pass vacuously.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byIcon(Icons.arrow_back_rounded),
      ),
      findsNothing,
    );

    // And it actually navigates back.
    await tester.tap(find.text('Accueil'));
    await tester.pumpAndSettle();
    expect(find.text('ouvrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
