import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/community/community_screen.dart';
import 'package:karatou/app/features/community/forum_category_screen.dart';
import 'package:karatou/app/features/explore/program_detail_screen.dart';

import '../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement Community restyle (PR7):
//   • the net-new shareable match card presents real match% + school + student
//   • Community + ForumCategory render the honest article/topic surfaces.
// ─────────────────────────────────────────────────────────────────────────────

CountryModel _country() => const CountryModel(
      id: 'fra',
      name: LocalizedText(fr: 'France', en: 'France'),
      whyStudy: LocalizedText(fr: 'Destination.', en: 'Destination.'),
      tuitionRange: LocalizedText(fr: '3 000 €/an', en: '3,000 €/yr'),
      livingCostRange: LocalizedText(fr: '700 €/mois', en: '700 €/mo'),
      visaOverview: LocalizedText(fr: 'VLS-TS.', en: 'VLS-TS.'),
      admissionDifficulty: LocalizedText(fr: 'Moyenne', en: 'Medium'),
      popularFieldIds: ['computer_science'],
      flagEmoji: '🇫🇷',
      nextIntakeLabel: LocalizedText(fr: 'Sept. 2025', en: 'Sept 2025'),
      marketingDescription: LocalizedText(fr: 'Étudier.', en: 'Study.'),
      whyStudyBulletsFr: ['Diplômes'],
      whyStudyBulletsEn: ['Degrees'],
      howItWorks: LocalizedText(fr: 'Choisir.', en: 'Pick.'),
    );

InstitutionModel _institution() => const InstitutionModel(
      id: 'ece-paris',
      name: LocalizedText(fr: 'ECE Paris', en: 'ECE Paris'),
      countryId: 'fra',
      location: LocalizedText(fr: 'Paris', en: 'Paris'),
      overview: LocalizedText(fr: 'École.', en: 'School.'),
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
      requirements: [LocalizedText(fr: 'Bac', en: 'Diploma')],
    );

ArticleModel _article() => ArticleModel(
      id: 'art-1',
      slug: 'visa-france',
      category: 'visa',
      title: LocalizedText(fr: 'Obtenir le visa', en: 'Getting the visa'),
      summary: LocalizedText(fr: 'Résumé visa.', en: 'Visa summary.'),
      content: LocalizedText(fr: 'Contenu complet.', en: 'Full content.'),
      tags: const ['visa', 'france'],
      authorName: 'KPB',
      status: PublicationStatus.published,
      publishedAt: DateTime(2025, 1, 15),
    );

ForumCategoryModel _category() => const ForumCategoryModel(
      id: 'visa',
      label: LocalizedText(fr: 'Visa & démarches', en: 'Visa & process'),
      description:
          LocalizedText(fr: 'Tout sur le visa.', en: 'All about visa.'),
      displayOrder: 0,
      status: PublicationStatus.published,
    );

ForumTopicTagModel _tag() => const ForumTopicTagModel(
      id: 'visa',
      label: LocalizedText(fr: 'Visa', en: 'Visa'),
      description: LocalizedText(fr: 'Visa', en: 'Visa'),
      displayOrder: 0,
      status: PublicationStatus.published,
    );

Future<AppController> _seedController() async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();

  final snapshot = AppSnapshot(
    localeCode: 'fr',
    hasCompletedOnboarding: true,
    profile: createTestProfile(fullName: 'Awa Diallo'),
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
  // Deterministic community content.
  controller.articles
    ..clear()
    ..add(_article());
  controller.forumCategories
    ..clear()
    ..add(_category());
  controller.forumTopicTags
    ..clear()
    ..add(_tag());

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
      'share action presents the shareable match card with real match%, '
      'school and student — plus WhatsApp + Download', (tester) async {
    await _seedController();
    await tester
        .pumpWidget(_wrap(const ProgramDetailScreen(programId: 'fra-paris')));
    await tester.pumpAndSettle();

    // Trigger the school-detail share action.
    await tester.tap(find.byIcon(Icons.ios_share_rounded));
    await tester.pumpAndSettle();

    // Real, correctly-labelled card content.
    expect(find.text('match_card_eyebrow'.tr), findsOneWidget);
    expect(find.text('ECE Paris'), findsWidgets); // real institution name
    expect(find.textContaining('Awa'), findsOneWidget); // real first name
    expect(find.textContaining('%'), findsWidgets); // real match figure
    // Both share affordances are present.
    expect(find.text('match_card_share_whatsapp'.tr), findsOneWidget);
    expect(find.text('match_card_download'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CommunityScreen renders real articles + the static safety note',
      (tester) async {
    await _seedController();
    await tester.pumpWidget(_wrap(const CommunityScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Obtenir le visa'), findsWidgets); // real article title
    // No fabricated social-forum affordances anywhere.
    expect(find.text('Report'), findsNothing);
    expect(find.textContaining('members'), findsNothing);

    // The static safety note lives below the fold — scroll the (single)
    // vertical scrollable into view (the chip strip is a second, horizontal
    // Scrollable, so target by axis to stay unambiguous).
    final verticalScrollable = find.byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          (w.axisDirection == AxisDirection.down ||
              w.axisDirection == AxisDirection.up),
    );
    await tester.scrollUntilVisible(
      find.text('community_safety_note'.tr),
      300,
      scrollable: verticalScrollable,
    );
    expect(find.text('community_safety_note'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ForumCategoryScreen shows related articles + honest launching-soon CTA',
      (tester) async {
    await _seedController();
    await tester.pumpWidget(
      _wrap(
        ForumCategoryScreen(
          category: _category(),
          accentColor: const Color(0xFF2563EB),
          accentBg: const Color(0xFFEFF6FF),
          icon: Icons.school_outlined,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Visa & démarches'), findsWidgets); // category label
    expect(find.text('Obtenir le visa'), findsWidgets); // related article
    // Honest "forum launching soon" copy (no fake post/reply composer).
    expect(find.textContaining('arrive bientôt'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
