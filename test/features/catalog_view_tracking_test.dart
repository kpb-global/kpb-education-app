// Garde : ouvrir une fiche programme ou un guide pays émet UN `view_item`
// vers PostHog, avec l'identifiant de la fiche.
//
// Sans cet événement, PostHog ne voyait que « ProgramDetailScreen : 906 vues »
// — impossible de savoir QUELS programmes ou pays intéressent, donc sur quoi
// produire du contenu.
//
// Pourquoi passer par `posthogCapture` et non par le SDK : sans clé PostHog en
// test, l'appel réel est inobservable ; un test écrit contre le SDK resterait
// vert pendant qu'aucun événement ne part. Le premier test vérifie en plus que
// la couture pointe, en production, sur le vrai envoi — sinon elle masquerait
// le défaut au lieu de le détecter.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/explore/country_detail_screen.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../widget_test_helpers.dart';

const _country = CountryModel(
  id: 'fra',
  name: LocalizedText(fr: 'France', en: 'France'),
  whyStudy: LocalizedText(fr: 'Destination.', en: 'Destination.'),
  tuitionRange: LocalizedText(fr: '—', en: '—'),
  livingCostRange: LocalizedText(fr: '—', en: '—'),
  visaOverview: LocalizedText(fr: 'VLS-TS.', en: 'VLS-TS.'),
  admissionDifficulty: LocalizedText(fr: 'Moyenne', en: 'Medium'),
  popularFieldIds: ['computer_science'],
  flagEmoji: '🇫🇷',
  nextIntakeLabel: LocalizedText(fr: 'Septembre', en: 'September'),
);

const _institution = InstitutionModel(
  id: 'ece-paris',
  name: LocalizedText(fr: 'ECE Paris', en: 'ECE Paris'),
  countryId: 'fra',
  location: LocalizedText(fr: 'Paris', en: 'Paris'),
  overview: LocalizedText(fr: 'École.', en: 'School.'),
  studyLevels: ['Bachelor'],
  tuitionLabel: LocalizedText(fr: '8 850 €/an', en: '8,850 €/yr'),
  languageRequirements: LocalizedText(fr: 'B2', en: 'B2'),
  intakePeriods: ['Septembre'],
  programIds: ['fra-paris'],
  isPartner: true,
);

// Nom FR ≠ nom EN : le test prouve que c'est le nom FR qui part, quelle que
// soit la langue d'affichage.
const _program = ProgramModel(
  id: 'fra-paris',
  institutionId: 'ece-paris',
  countryId: 'France', // alias hérité : doit partir normalisé en `fra`
  fieldId: 'computer_science',
  name: LocalizedText(fr: 'Bachelor Informatique', en: 'CS Bachelor'),
  level: LocalizedText(fr: 'Bachelor', en: 'Bachelor'),
  duration: LocalizedText(fr: '3 ans', en: '3 years'),
  tuition: LocalizedText(fr: '8 850 €/an', en: '8,850 €/yr'),
  language: LocalizedText(fr: 'Français', en: 'French'),
  requirements: [LocalizedText(fr: 'Baccalauréat', en: 'High-school diploma')],
);

Future<void> _seedController({String localeCode = 'fr'}) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();
  final snapshot = AppSnapshot(
    localeCode: localeCode,
    hasCompletedOnboarding: true,
    profile: createTestProfile(),
    countries: const [_country],
    institutions: const [_institution],
    programs: const [_program],
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
}

Widget _wrap(Widget home, {String locale = 'fr'}) => GetMaterialApp(
      translations: AppTranslations(),
      locale: Locale(locale),
      fallbackLocale: const Locale('fr'),
      home: home,
    );

void main() {
  final service = AnalyticsService.instance;

  // Capturés AVANT toute substitution : ce sont les branchements livrés.
  final defaultCapture = service.posthogCapture;
  final defaultWired = service.posthogWired;

  late List<(String, Map<String, Object>?)> captured;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
    captured = [];
    service.posthogCapture = (event, props) => captured.add((event, props));
    service.posthogWired = true;
  });

  tearDown(() {
    // Singleton : sans restauration, la substitution fuirait vers les autres
    // tests du même binaire.
    service.posthogCapture = defaultCapture;
    service.posthogWired = defaultWired;
    resetGetxSingleton();
  });

  List<Map<String, Object>?> viewItems() =>
      captured.where((e) => e.$1 == 'view_item').map((e) => e.$2).toList();

  test('en production, la couture pointe sur un vrai envoi PostHog', () {
    expect(defaultCapture, isNot(same(service.posthogCapture)));
    expect(defaultCapture.toString(), contains('_capturePosthog'));
  });

  testWidgets(
      'fiche programme : un view_item avec id, nom FR, pays normalisé et '
      'école — une seule fois malgré les rebuilds', (tester) async {
    await _seedController(localeCode: 'en');
    const screen = ProgramDetailScreen(programId: 'fra-paris');
    await tester.pumpWidget(_wrap(screen, locale: 'en'));
    await tester.pumpAndSettle();
    // Même widget re-pompé : build() rejoue, initState() non.
    await tester.pumpWidget(_wrap(screen, locale: 'en'));
    await tester.pumpAndSettle();

    expect(viewItems(), [
      {
        'item_id': 'fra-paris',
        'item_category': 'program',
        'item_name': 'Bachelor Informatique',
        'country_id': 'fra',
        'institution_id': 'ece-paris',
      },
    ]);
  });

  testWidgets('programme introuvable : le view_item part quand même, sans nom',
      (tester) async {
    await _seedController();
    await tester
        .pumpWidget(_wrap(const ProgramDetailScreen(programId: 'inconnu')));
    await tester.pumpAndSettle();

    // Un lien profond cassé doit rester visible dans PostHog.
    expect(viewItems(), [
      {'item_id': 'inconnu', 'item_category': 'program'},
    ]);
  });

  testWidgets('guide pays : un view_item avec l\'id normalisé', (tester) async {
    await _seedController();
    await tester
        .pumpWidget(_wrap(const CountryDetailScreen(countryId: 'France')));
    await tester.pumpAndSettle();

    expect(viewItems(), [
      {'item_id': 'fra', 'item_category': 'country'},
    ]);
  });
}
