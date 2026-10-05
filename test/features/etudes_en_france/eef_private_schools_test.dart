// Les écoles privées dans l'espace « Études en France » (build 56, PR 3) : une
// feuille d'information « Service KPB », une ligne secondaire dans l'état « aucun
// résultat » du catalogue, et une option dans le menu de la bulle.
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · RIEN n'existe tant que le serveur n'a pas ouvert `features.eefPrivateSchools`
//     (fermé par défaut) : ni ligne, ni option, ni feuille ;
//   · un compte dont le pays est suspendu ne lit jamais « école privée » : ni
//     ligne (la carte d'aide neutre reste seule), ni option (menu à deux lignes) ;
//   · la ligne n'est que dans l'état « aucun résultat » du catalogue — ni dans
//     « rien n'est publié », ni dans une liste non vide, ni dans le hub ;
//   · la feuille ne s'ouvre JAMAIS seule ; elle dit les limites (frais, démarches)
//     et la provenance (service privé, rémunération) AVANT qu'on écrive ;
//   · « En parler à un conseiller » ferme la feuille PUIS ouvre WhatsApp avec le
//     message exact montré sous le bouton ; « Pas maintenant » ne mesure rien et
//     n'ouvre rien ;
//   · aucun texte ne chiffre, ne nomme une école, un pays ou l'opérateur de l'État ;
//   · la phrase de rémunération vit dans SA clé, retirable sans toucher aux autres.
//
// Le lanceur d'URL est intercepté à `UrlLauncherPlatform`, comme partout dans ce
// dossier ; la mesure passe par la couture `EefHelpCard.analytics` et, pour le
// chemin réel, par `AnalyticsService.logEventSink`.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_data_notice.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_bubble.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_private_schools_sheet.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

// ── Les textes attendus, ÉCRITS EN DUR ────────────────────────────────────────
//
// Un test qui relirait la clé que le code lit ne verrait pas qu'on l'a vidée ou
// retouchée : tout ce que lit l'étudiant est recopié ici.

class _Copy {
  const _Copy({
    required this.chip,
    required this.title,
    required this.terms,
    required this.fees,
    required this.steps,
    required this.status,
    required this.disclosure,
    required this.cta,
    required this.dismiss,
    required this.messageLabel,
    required this.messageHub,
    required this.messageCatalog,
    required this.optionLabel,
    required this.noteText,
    required this.noteLink,
    required this.feesFallback,
  });

  final String chip;
  final String title;
  final String terms;
  final String fees;
  final String steps;
  final String status;
  final String disclosure;
  final String cta;
  final String dismiss;
  final String messageLabel;
  final String messageHub;
  final String messageCatalog;
  final String optionLabel;
  final String noteText;
  final String noteLink;
  final String feesFallback;

  String get fourth => '$status $disclosure';

  String message({required bool catalog}) =>
      catalog ? messageCatalog : messageHub;
}

const _fr = _Copy(
  chip: 'Service KPB',
  title: "Les écoles privées : ce qu'il faut savoir",
  terms:
      "Chaque école privée fixe ses propres conditions d'admission, ses frais et son calendrier.",
  fees:
      "Les frais sont en général plus élevés que dans le public. Demande-les par écrit avant de t'engager.",
  steps:
      "Les démarches officielles (admission, visa) dépendent de ton pays et de l'école. Vérifie-les sur les sites officiels.",
  status:
      "KPB Education est un service privé d'accompagnement, pas un service de l'État.",
  disclosure: 'KPB peut être rémunéré par certaines écoles.',
  cta: 'En parler à un conseiller',
  dismiss: 'Pas maintenant',
  messageLabel: 'Message qui sera écrit :',
  messageHub:
      "Bonjour KPB Education, je suis dans l'espace Études en France de l'app. J'aimerais en savoir plus sur les écoles privées : conditions d'admission, frais et calendrier.",
  messageCatalog:
      "Bonjour KPB Education, je suis dans le catalogue de l'espace Études en France de l'app. J'aimerais en savoir plus sur les écoles privées : conditions d'admission, frais et calendrier.",
  optionLabel: 'Je veux en savoir plus sur les écoles privées',
  noteText:
      "Les écoles privées ont d'autres conditions et un autre calendrier.",
  noteLink: "Les écoles privées : ce qu'il faut savoir",
  feesFallback:
      "Les frais varient beaucoup d'une école à l'autre. Demande-les par écrit avant de t'engager.",
);

const _en = _Copy(
  chip: 'KPB service',
  title: 'Private schools: what to know',
  terms:
      'Each private school sets its own admission requirements, fees and calendar.',
  fees:
      'Fees are generally higher than at public universities. Ask for them in writing before you commit.',
  steps:
      'Official steps (admission, visa) depend on your country and the school. Check them on the official websites.',
  status:
      'KPB Education is a private support service, not a government service.',
  disclosure: 'KPB may be paid by some schools.',
  cta: 'Talk to an advisor',
  dismiss: 'Not now',
  messageLabel: 'Message that will be written:',
  messageHub:
      "Hello KPB Education, I'm in the Études en France space of the app. I'd like to know more about private schools: admission requirements, fees and calendar.",
  messageCatalog:
      "Hello KPB Education, I'm in the catalogue of the Études en France space of the app. I'd like to know more about private schools: admission requirements, fees and calendar.",
  optionLabel: 'I want to know more about private schools',
  noteText: 'Private schools have different requirements and calendars.',
  noteLink: 'Private schools: what to know',
  feesFallback:
      'Fees vary a lot from one school to another. Ask for them in writing before you commit.',
);

_Copy _copyFor(Locale locale) => locale.languageCode == 'fr' ? _fr : _en;

/// Toutes les clés NOUVELLES de cette livraison : le préfixe `eef_help_private_`
/// les fait hériter des balayages de `eef_help_line_test.dart`.
const _disclosureKey = 'eef_help_private_disclosure';

const _privateKeys = <String>[
  'eef_help_private_chip',
  'eef_help_private_title',
  'eef_help_private_point_terms',
  'eef_help_private_point_fees',
  'eef_help_private_point_fees_fallback',
  'eef_help_private_point_steps',
  'eef_help_private_point_status',
  _disclosureKey,
  'eef_help_private_cta',
  'eef_help_private_dismiss',
  'eef_help_private_message_label',
  'eef_help_private_message',
  'eef_help_private_option_label',
  'eef_help_private_note_text',
  'eef_help_private_note_link',
];

/// Ce que ce chantier s'interdit de dire, FR et EN. « officiel » au singulier,
/// dit de KPB, est un faux : le pluriel « démarches officielles » / « sites
/// officiels » désigne les services de l'État, comme le plan l'écrit.
final _forbiddenClaims = RegExp(
  r'partenaire|sponsoris|agr[ée]{1,2}\b|s[ée]r[ée]nit[ée]|garanti|'
  r'faites? pour [çc]a|moyens clairement connus|sans stress|tranquillit|'
  r'\bpartner|sponsored|approved|accredited|serenity|guarantee|made for this|'
  r'clearly known means|stress[- ]free|campus[\s_-]*france|'
  r'kpb[^.]*\bofficiel\b|kpb[^.]*\bofficial\b',
  caseSensitive: false,
);

/// Des écoles qu'aucun texte ne doit nommer.
final _schoolNames = RegExp(
  r'\bHEC\b|ESSEC|\bESCP\b|EDHEC|Sciences?\s*Po|\bSKEMA\b|Kedge|Neoma|'
  r'Audencia|EM\s*Lyon|emlyon|Epitech|\bISEG\b|\bINSEEC\b|\bIPAG\b|'
  r'Sorbonne|Polytechnique|Centrale|\bEPF\b|\bESIEE\b|\bIESEG\b',
  caseSensitive: false,
);

/// Un pays, le sien ou un de remplacement. « France » n'y figure pas : c'est le
/// nom de l'espace (« Études en France »).
final _countryWording = RegExp(
  r'togo|s[ée]n[ée]gal|c[ôo]te d.ivoire|cameroun|cameroon|maroc|morocco|'
  r'niger\b|mali\b|burkina|guin[ée]e|b[ée]nin|gabon|congo|tunisi|alg[ée]ri|'
  r'autre pays pour|another country',
  caseSensitive: false,
);

/// Le prix, la devise, le gratuit : le garde de `eef_help_line_test.dart`.
final _priceWording = RegExp(
  r'€|\bfcfa\b|\bxof\b|\bfrancs?\b|\bprix\b|\bprice\b|gratuit|\bfree\b|'
  r'\beuros?\b|\btarif',
  caseSensitive: false,
);

// ── La géométrie : les écrans éprouvés ───────────────────────────────────────

const _se = KpbViewport(
  id: 'phone320',
  name: 'Petit téléphone 320×568',
  size: Size(320, 568),
  padding: EdgeInsets.only(top: 20),
);

const _phone360 = KpbViewport(
  id: 'phone360x640',
  name: 'Android 360×640',
  size: Size(360, 640),
  padding: EdgeInsets.only(top: 24),
);

const _ipad = KpbViewport(
  id: 'ipad768',
  name: 'iPad 768×1024',
  size: Size(768, 1024),
  padding: EdgeInsets.only(top: 24, bottom: 20),
);

const _matrixViewports = <KpbViewport>[_se, _phone360, iphone14, _ipad];

const _bubbleKey = ValueKey('eef-help-bubble');
const _sheetKey = ValueKey('eef-private-sheet');
const _ctaKey = ValueKey('eef-private-sheet-cta');
const _dismissKey = ValueKey('eef-private-sheet-dismiss');
const _noteKey = ValueKey('eef-private-note');
const _linkKey = ValueKey('eef-private-note-link');
const _menuKey = ValueKey('eef-help-bubble-sheet');

Finder _option(EefBubbleOption option) =>
    find.byKey(ValueKey('eef-help-bubble-option-${option.id}'));

Finder _inSheet(Finder inner) =>
    find.descendant(of: find.byKey(_sheetKey), matching: inner);

// ── Un lanceur qui regarde si la feuille est encore là ───────────────────────

class _ProbingLauncher extends RecordingUrlLauncher {
  _ProbingLauncher(this.sheetIsOpen, this.tappedCount);

  final bool Function() sheetIsOpen;
  final int Function() tappedCount;
  final List<bool> sheetOpenAtLaunch = <bool>[];
  final List<int> tappedAtLaunch = <int>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    sheetOpenAtLaunch.add(sheetIsOpen());
    tappedAtLaunch.add(tappedCount());
    return super.launchUrl(url, options);
  }
}

class _Emitted {
  const _Emitted(this.name, this.params);

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => '$name$params';
}

Map<String, dynamic> _program(String id, {String name = 'Licence Droit'}) =>
    <String, dynamic>{
      'id': id,
      'institutionId': 'eef-univ-x',
      'countryId': 'fra',
      'fieldId': 'd07',
      'nameFr': name,
      'nameEn': name,
      'levelFr': 'Bac+3',
      'levelEn': 'Bachelor',
      'durationFr': '3 ans',
      'durationEn': '3 years',
      'tuitionFr': 'x',
      'tuitionEn': 'x',
      'languageFr': 'Français',
      'languageEn': 'French',
      'requirementsFr': <String>[],
      'requirementsEn': <String>[],
      'procedureType': 'eef',
      'cycle': 'licence3',
      'campusCity': 'Lyon',
      'institution': null,
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  bool? catalogPublished,
}) =>
    <String, dynamic>{
      'items': items,
      'total': items.length,
      'page': <String, dynamic>{
        'limit': 20,
        'hasMore': false,
        'nextCursor': null,
      },
      'facets': <String, dynamic>{},
      'facetsTruncated': <String>[],
      if (catalogPublished != null) 'catalogPublished': catalogPublished,
    };

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics analytics;
  late List<_Emitted> emitted;

  void stubCatalog(Future<Map<String, dynamic>> Function(Invocation) answer) {
    when(() => api.searchEefCatalog(
          query: any(named: 'query'),
          cycles: any(named: 'cycles'),
          procedureTypes: any(named: 'procedureTypes'),
          fieldIds: any(named: 'fieldIds'),
          campusCities: any(named: 'campusCities'),
          institutionIds: any(named: 'institutionIds'),
          selectivities: any(named: 'selectivities'),
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        )).thenAnswer(answer);
  }

  void stubEmpty() =>
      stubCatalog((_) async => _page([], catalogPublished: true));

  void stubUnpublished() =>
      stubCatalog((_) async => _page([], catalogPublished: false));

  void stubThreePrograms() => stubCatalog((_) async => _page(
      [_program('a'), _program('b', name: 'Licence Lettres'), _program('c')]));

  void stubHubInterest() {
    when(() => api.getEefInterest())
        .thenAnswer((_) async => <String, dynamic>{'declared': false});
  }

  void setSuspendedCountries(List<String> countries) {
    EefCalendar.windowSource = () => EefCampaignWindow(
          opensAt: DateTime(2026, 10, 1),
          platformUrl: 'https://www.campusfrance.org/fr',
          suspendedCountries: countries,
          suspendedSources: const {
            'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
          },
        );
  }

  setUp(() {
    api = MockApiClient();
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    analytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = analytics;
    emitted = <_Emitted>[];
    AnalyticsService.instance.logEventSink =
        (name, params) async => emitted.add(_Emitted(name, params));
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = null;
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    // Dans CE fichier : l'espace, la bulle ET les écoles privées sont ouverts par
    // défaut. Chaque test « fermé » les referme explicitement.
    AppConfig.eefSpaceEnabledOverride = true;
    AppConfig.eefHelpBubbleEnabledOverride = true;
    AppConfig.eefPrivateSchoolsEnabledOverride = true;
    Get.locale = const Locale('fr');
    EefCalendar.clock = () => DateTime(2026, 9, 28);
    setSuspendedCountries(const ['Niger']);
    stubHubInterest();
    stubEmpty();
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = null;
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = null;
    AppConfig.eefHelpBubbleEnabledOverride = null;
    AppConfig.eefPrivateSchoolsEnabledOverride = null;
    Get.reset();
  });

  Future<KpbScreenReport> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    String country = 'Sénégal',
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: locale.languageCode,
        hasCompletedOnboarding: true,
        isGuestMode: guest,
        profile: guest
            ? null
            : createTestProfile(
                countryOfResidence: country,
                preferredLanguage: locale.languageCode,
              ),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: screen,
      viewport: viewport,
      textScale: textScale,
      locale: locale,
      routesShareMediaQuery: true,
    );
  }

  /// Parcourt la liste du haut vers le bas, par petits pas, et s'arrête dès que
  /// [target] est monté — ou au bout de la liste.
  ///
  /// La liste est PARESSEUSE : ce qui est loin sous l'écran n'est pas monté, et
  /// un `findsNothing` posé sans ce parcours ne prouverait rien (la ligne
  /// pourrait exister plus bas). Après cet appel, soit [target] est trouvé, soit
  /// toute la liste a été parcourue sans qu'il apparaisse.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isEmpty) return;
    final position = tester.state<ScrollableState>(scrollables.last).position;
    position.jumpTo(0);
    await tester.pump();
    while (target.evaluate().isEmpty &&
        position.pixels < position.maxScrollExtent) {
      position
          .jumpTo((position.pixels + 120).clamp(0.0, position.maxScrollExtent));
      await tester.pump();
    }
  }

  /// [reveal] pour la ligne des écoles privées.
  Future<void> revealNote(WidgetTester tester) =>
      reveal(tester, find.byKey(_noteKey));

  Future<KpbScreenReport> pumpCatalog(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
  }) async {
    final report = await pumpScreen(
      tester,
      const EefCatalogScreen(),
      country: country,
      guest: guest,
      viewport: viewport,
      textScale: textScale,
      locale: locale,
    );
    // Le parcours de la liste : c'est en bas que vivent la ligne et la mention
    // des données, et la liste est paresseuse.
    await revealNote(tester);
    return report;
  }

  Future<KpbScreenReport> pumpHub(
    WidgetTester tester, {
    String country = 'Sénégal',
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
  }) =>
      pumpScreen(
        tester,
        const EefHomeScreen(),
        country: country,
        viewport: viewport,
        textScale: textScale,
        locale: locale,
      );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byKey(_bubbleKey));
    await settleBounded(tester);
  }

  /// Ouvre la feuille par le lien de la ligne du catalogue vide.
  Future<void> openSheetFromNote(WidgetTester tester) async {
    await revealNote(tester);
    await tester.ensureVisible(find.byKey(_linkKey));
    await tester.pump();
    await tester.tap(find.byKey(_linkKey));
    await settleBounded(tester);
  }

  /// Ouvre la feuille par l'option du menu de la bulle.
  Future<void> openSheetFromBubble(WidgetTester tester) async {
    await openMenu(tester);
    final tile = _option(EefBubbleOption.private);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await settleBounded(tester);
  }

  /// Tape l'option « écoles privées » d'un menu DÉJÀ ouvert (sans le rouvrir ni
  /// le reconstruire).
  Future<void> tapPrivateTile(WidgetTester tester) async {
    final tile = _option(EefBubbleOption.private);
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await settleBounded(tester);
  }

  Future<void> tapCta(WidgetTester tester) async {
    final cta = find.byKey(_ctaKey);
    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    // La feuille se ferme (animation), PUIS WhatsApp s'ouvre.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> tapDismiss(WidgetTester tester) async {
    final dismiss = find.byKey(_dismissKey);
    await tester.ensureVisible(dismiss);
    await tester.pump();
    await tester.tap(dismiss);
    await settleBounded(tester);
  }

  int menuOptionCount() => find
      .byWidgetPredicate((w) {
        final key = w.key;
        return key is ValueKey<String> &&
            key.value.startsWith('eef-help-bubble-option-');
      })
      .evaluate()
      .length;

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. OÙ ÇA APPARAÎT, OÙ ÇA N'APPARAÎT PAS
  // ═══════════════════════════════════════════════════════════════════════════

  group('l\'interrupteur fermé : rien', () {
    setUp(() => AppConfig.eefPrivateSchoolsEnabledOverride = null);

    testWidgets('catalogue vide : ni ligne ni lien', (tester) async {
      await pumpCatalog(tester);
      // Contre-épreuve : l'état « aucun résultat » est bien à l'écran.
      await reveal(tester, find.byType(EefHelpCard));
      expect(find.byType(EefHelpCard), findsOneWidget);
      await reveal(tester, find.byType(EefDataNotice));
      expect(find.byType(EefDataNotice), findsOneWidget);
      expect(find.byKey(_noteKey), findsNothing);
      expect(find.byKey(_linkKey), findsNothing);
      expect(find.textContaining('écoles privées'), findsNothing);
      expect(analytics.shownSteps, isNot(contains('private_note')));
    });

    testWidgets('menu de la bulle : quatre sujets, aucune école privée',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
      expect(menuOptionCount(), 4);
      expect(_option(EefBubbleOption.private), findsNothing);
      expect(find.textContaining('écoles privées'), findsNothing);
    });

    testWidgets('menu de la bulle du catalogue : idem', (tester) async {
      await pumpCatalog(tester);
      await openMenu(tester);
      expect(menuOptionCount(), 4);
      expect(_option(EefBubbleOption.private), findsNothing);
    });

    testWidgets('absente, la ligne ne laisse AUCUNE marge', (tester) async {
      await pumpCatalog(tester);
      await reveal(tester, find.byType(EefDataNotice));
      expect(find.byType(EefPrivateSchoolsNote), findsOneWidget);
      expect(tester.getSize(find.byType(EefPrivateSchoolsNote)).height, 0);
    });

    test('l\'interrupteur est fermé par défaut, côté client', () {
      AppConfig.eefPrivateSchoolsEnabledOverride = null;
      expect(RemoteFeatureFlags.instance.eefPrivateSchoolsEnabled, isFalse);
    });
  });

  group('l\'interrupteur ouvert, compte suspendu : rien', () {
    testWidgets('catalogue vide : la carte neutre reste SEULE, aucune ligne',
        (tester) async {
      await pumpCatalog(tester, country: 'Niger');
      await reveal(tester, find.byType(EefHelpCard));
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.text("Besoin d'y voir plus clair ?"), findsOneWidget);
      expect(find.byKey(_noteKey), findsNothing);
      expect(find.byKey(_linkKey), findsNothing);
      expect(find.textContaining('écoles privées'), findsNothing);
      await reveal(tester, find.byType(EefDataNotice));
      expect(find.byType(EefDataNotice), findsOneWidget);
      expect(analytics.shownSteps, isNot(contains('private_note')));
    });

    testWidgets('absente, la ligne ne laisse AUCUNE marge (compte suspendu)',
        (tester) async {
      await pumpCatalog(tester, country: 'Niger');
      await reveal(tester, find.byType(EefDataNotice));
      expect(find.byType(EefPrivateSchoolsNote), findsOneWidget);
      expect(tester.getSize(find.byType(EefPrivateSchoolsNote)).height, 0);
    });

    testWidgets('menu à DEUX lignes neutres, sans école privée (hub)',
        (tester) async {
      await pumpHub(tester, country: 'Niger');
      await openMenu(tester);
      expect(menuOptionCount(), 2);
      expect(_option(EefBubbleOption.private), findsNothing);
      expect(find.textContaining('écoles privées'), findsNothing);
      expect(find.text(_fr.chip), findsNothing);
    });

    testWidgets('menu à DEUX lignes neutres, sans école privée (catalogue)',
        (tester) async {
      await pumpCatalog(tester, country: 'Niger');
      await openMenu(tester);
      expect(menuOptionCount(), 2);
      expect(_option(EefBubbleOption.private), findsNothing);
    });
  });

  group('l\'interrupteur ouvert, compte normal', () {
    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final copy = _copyFor(locale);
      testWidgets(
          'catalogue VIDE (${locale.languageCode}) : UNE ligne, pastille, '
          'texte et lien', (tester) async {
        await pumpCatalog(tester, locale: locale);

        expect(find.byKey(_noteKey), findsOneWidget);
        expect(find.byKey(_linkKey), findsOneWidget);
        expect(_inNote(copy.chip), findsOneWidget);
        expect(_inNote(copy.noteText), findsOneWidget);
        expect(_inNote(copy.noteLink), findsOneWidget);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets(
        'la ligne est SOUS la carte d\'aide, AVANT la mention des '
        'données', (tester) async {
      // Un iPad : la carte, la ligne et la mention tiennent ensemble à l'écran.
      await pumpCatalog(tester, viewport: _ipad);
      final card = tester.getRect(find.byType(EefHelpCard));
      final note = tester.getRect(find.byKey(_noteKey));
      final data = tester.getRect(find.byType(EefDataNotice));
      expect(note.top, greaterThanOrEqualTo(card.bottom));
      expect(data.top, greaterThanOrEqualTo(note.bottom));
    });

    testWidgets(
        'une ligne secondaire : ni seconde carte, ni second bouton '
        'WhatsApp', (tester) async {
      await pumpCatalog(tester, viewport: _ipad);
      expect(find.byType(EefHelpCard), findsOneWidget);
      // La carte d'aide garde son unique bouton plein ; la ligne n'en a aucun.
      expect(
          find.descendant(
              of: find.byKey(_noteKey), matching: find.byType(FilledButton)),
          findsNothing);
      expect(
        find.descendant(
            of: find.byKey(_noteKey),
            matching: find.byIcon(Icons.chat_rounded)),
        findsNothing,
      );
      // Et elle est plus basse qu'une carte.
      expect(tester.getSize(find.byKey(_noteKey)).height,
          lessThan(tester.getSize(find.byType(EefHelpCard)).height));
    });

    testWidgets('catalogue « rien n\'est publié » : PAS de ligne',
        (tester) async {
      stubUnpublished();
      await pumpCatalog(tester);
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.text('Le catalogue arrive bientôt'), findsNothing,
          reason: 'le libellé exact n\'importe pas ici');
      expect(find.byKey(_noteKey), findsNothing);
      expect(analytics.shownSteps, isNot(contains('private_note')));
    });

    testWidgets('catalogue NON VIDE : PAS de ligne', (tester) async {
      stubThreePrograms();
      await pumpCatalog(tester);
      expect(find.text('Licence Droit'), findsWidgets);
      await tester.drag(find.byType(ListView).last, const Offset(0, -9000));
      await tester.pumpAndSettle();
      expect(find.byKey(_noteKey), findsNothing);
    });

    testWidgets('hub : PAS de ligne, PAS de tuile, rien sur l\'accueil',
        (tester) async {
      await pumpHub(tester);
      expect(find.byKey(_noteKey), findsNothing);
      expect(find.byKey(_linkKey), findsNothing);
      for (var i = 0; i < 4; i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -700));
        await tester.pump();
      }
      expect(find.textContaining('écoles privées'), findsNothing);
      expect(find.byKey(_noteKey), findsNothing);
    });

    testWidgets(
        'le menu de la bulle propose CINQ sujets, l\'école privée en '
        '4e position', (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(menuOptionCount(), 5);
      final order = [
        EefBubbleOption.assistance,
        EefBubbleOption.dossier,
        EefBubbleOption.choose,
        EefBubbleOption.private,
        EefBubbleOption.question,
      ];
      for (final option in order) {
        final tile = _option(option);
        await tester.ensureVisible(tile);
        await tester.pump();
        expect(tile, findsOneWidget, reason: option.id);
      }
      // Les tuiles se suivent dans CET ordre dans l'arbre.
      final tiles = tester
          .widgetList(find.byWidgetPredicate((w) {
            final key = w.key;
            return key is ValueKey<String> &&
                key.value.startsWith('eef-help-bubble-option-');
          }))
          .map((w) => (w.key! as ValueKey<String>).value)
          .toList();
      expect(tiles, [
        for (final option in order) 'eef-help-bubble-option-${option.id}',
      ]);
    });

    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final copy = _copyFor(locale);
      testWidgets(
          'l\'option du menu (${locale.languageCode}) : libellé + pastille, '
          'et PAS de message dessous', (tester) async {
        await pumpHub(tester, locale: locale);
        await openMenu(tester);
        final tile = _option(EefBubbleOption.private);
        await tester.ensureVisible(tile);
        await tester.pump();
        expect(find.descendant(of: tile, matching: find.text(copy.optionLabel)),
            findsOneWidget);
        expect(find.descendant(of: tile, matching: find.text(copy.chip)),
            findsOneWidget);
        // Elle OUVRE une feuille : aucun message de WhatsApp n'est annoncé dessous.
        expect(find.descendant(of: tile, matching: find.text(copy.messageHub)),
            findsNothing);
        expect(tester.getSize(tile).height, greaterThanOrEqualTo(56));
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });
    }

    testWidgets(
        'les flags du SERVEUR (sans aucun override) commandent la '
        'ligne et l\'option', (tester) async {
      AppConfig.eefSpaceEnabledOverride = null;
      AppConfig.eefHelpBubbleEnabledOverride = null;
      AppConfig.eefPrivateSchoolsEnabledOverride = null;

      Future<void> serve(Map<String, dynamic> features) async {
        when(api.getAppConfig)
            .thenAnswer((_) async => <String, dynamic>{'features': features});
        await RemoteFeatureFlags.instance.refresh(api);
        await settleBounded(tester);
        await revealNote(tester);
      }

      await pumpCatalog(tester);
      // Rien de servi, rien de compilé : fermé (le catalogue dit « bientôt »).
      expect(find.byKey(_noteKey), findsNothing);

      await serve({'eefSpace': true});
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.byKey(_noteKey), findsNothing, reason: 'clé absente = fermé');

      await serve({'eefSpace': true, 'eefPrivateSchools': true});
      expect(find.byKey(_noteKey), findsOneWidget);

      await serve({'eefSpace': true, 'eefPrivateSchools': false});
      expect(find.byKey(_noteKey), findsNothing);

      await serve({'eefSpace': true, 'eefPrivateSchools': true});
      expect(find.byKey(_noteKey), findsOneWidget);

      // L'option de la bulle suit : bulle ET école privée ouvertes.
      await serve({
        'eefSpace': true,
        'eefPrivateSchools': true,
        'eefHelpBubble': true,
      });
      await openMenu(tester);
      expect(_option(EefBubbleOption.private), findsOneWidget);
      expect(menuOptionCount(), 5);
    });

    testWidgets(
        'l\'option de la bulle ne dépend PAS de la ligne du catalogue '
        'et inversement', (tester) async {
      // Bulle fermée, école privée ouverte : la ligne seule.
      AppConfig.eefHelpBubbleEnabledOverride = null;
      await pumpCatalog(tester);
      expect(find.byKey(_bubbleKey), findsNothing);
      expect(find.byKey(_noteKey), findsOneWidget);
    });

    testWidgets(
        'la suspension arrive APRÈS le premier cadre : la ligne '
        'disparaît', (tester) async {
      await pumpCatalog(tester);
      expect(find.byKey(_noteKey), findsOneWidget);

      setSuspendedCountries(const ['Sénégal']);
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(_noteKey), findsNothing);
      expect(find.byType(EefHelpCard), findsOneWidget);
    });

    testWidgets('invité : la version standard (ligne et option)',
        (tester) async {
      await pumpCatalog(tester, guest: true);
      expect(find.byKey(_noteKey), findsOneWidget);
      await openMenu(tester);
      expect(menuOptionCount(), 5);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. LA FEUILLE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la feuille', () {
    testWidgets('ne s\'ouvre JAMAIS toute seule', (tester) async {
      await pumpCatalog(tester);
      await settleBounded(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
      expect(analytics.privateInfoEntries, isEmpty);

      await pumpHub(tester);
      await openMenu(tester);
      // Le menu seul n'ouvre pas la feuille des écoles privées.
      expect(find.byKey(_sheetKey), findsNothing);
      expect(analytics.privateInfoEntries, isEmpty);
    });

    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final copy = _copyFor(locale);
      for (final viaBubble in [false, true]) {
        testWidgets(
            '${locale.languageCode} / ${viaBubble ? 'bulle' : 'ligne du '
                'catalogue'} : pastille, titre, points 1 à 4, mention, boutons',
            (tester) async {
          await pumpCatalog(tester, locale: locale);
          if (viaBubble) {
            await openSheetFromBubble(tester);
          } else {
            await openSheetFromNote(tester);
          }

          expect(find.byKey(_sheetKey), findsOneWidget);
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(_inSheet(find.text(copy.chip)), findsOneWidget);
          expect(_inSheet(find.text(copy.title)), findsOneWidget);
          expect(_inSheet(find.text(copy.terms)), findsOneWidget);
          expect(_inSheet(find.text(copy.fees)), findsOneWidget);
          expect(_inSheet(find.text(copy.steps)), findsOneWidget);
          // Le point 4 se cherche par son début : la phrase de rémunération a son
          // propre test, plus bas, pour pouvoir être retirée en une ligne.
          expect(_inSheet(find.textContaining(copy.status)), findsOneWidget);
          // La mention qui existe déjà dans l'app, mot pour mot.
          expect(_inSheet(find.text('eef_help_fineprint'.tr)), findsOneWidget);
          expect(_inSheet(find.text(copy.cta)), findsOneWidget);
          expect(_inSheet(find.text(copy.dismiss)), findsOneWidget);
          expect(_inSheet(find.text(copy.messageLabel)), findsOneWidget);
          expect(_inSheet(find.text(copy.messageCatalog)), findsOneWidget);
          // Le repli sur les frais n'est PAS affiché.
          expect(_inSheet(find.text(copy.feesFallback)), findsNothing);
          expect(rawTranslationKeysOnScreen(tester), isEmpty);
          expect(tester.takeException(), isNull);
        });
      }
    }

    // La phrase de rémunération : SA clé, SON test. Pour la retirer, supprimer la
    // clé (FR et EN), l'élément du `join` dans la feuille, et ce test.
    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final copy = _copyFor(locale);
      testWidgets(
          '(${locale.languageCode}) le point 4 dit ce qu\'est KPB, puis la '
          'rémunération, dans UN seul paragraphe', (tester) async {
        await pumpCatalog(tester, locale: locale);
        await openSheetFromNote(tester);
        expect(_inSheet(find.text(copy.fourth)), findsOneWidget);
        expect(_inSheet(find.textContaining(copy.disclosure)), findsOneWidget);
      });
    }

    testWidgets(
        'le message exact est SOUS le bouton, l\'autre bouton '
        'dessous', (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      await tester.ensureVisible(find.byKey(_dismissKey));
      await tester.pump();
      final cta = tester.getRect(find.byKey(_ctaKey));
      final label = tester.getRect(_inSheet(find.text(_fr.messageLabel)));
      final message = tester.getRect(_inSheet(find.text(_fr.messageCatalog)));
      final dismiss = tester.getRect(find.byKey(_dismissKey));
      final fineprint =
          tester.getRect(_inSheet(find.text('eef_help_fineprint'.tr)));
      expect(fineprint.bottom, lessThanOrEqualTo(cta.top));
      expect(label.top, greaterThanOrEqualTo(cta.bottom));
      expect(message.top, greaterThanOrEqualTo(label.bottom - 1));
      expect(dismiss.top, greaterThanOrEqualTo(message.bottom));
    });

    testWidgets('deux boutons seulement : WhatsApp et « Pas maintenant »',
        (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      expect(_inSheet(find.byType(FilledButton)), findsOneWidget);
      expect(_inSheet(find.byType(TextButton)), findsOneWidget);
      expect(_inSheet(find.byType(OutlinedButton)), findsNothing);
    });

    testWidgets(
        'ouverte depuis le menu : le menu est FERMÉ, la feuille '
        'l\'a remplacé', (tester) async {
      await pumpHub(tester);
      await openSheetFromBubble(tester);
      expect(find.byKey(_menuKey), findsNothing);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(find.byType(BottomSheet), findsOneWidget);
      // Choisir « écoles privées » n'envoie RIEN : on lit d'abord.
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
    });

    testWidgets('l\'iPad : bornée à 560 dp', (tester) async {
      await pumpCatalog(tester, viewport: _ipad);
      await openSheetFromNote(tester);
      expect(
          tester.getSize(find.byKey(_sheetKey)).width, lessThanOrEqualTo(560));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. CE QUI PART VERS WHATSAPP, ET CE QUI NE PART PAS
  // ═══════════════════════════════════════════════════════════════════════════

  group('« En parler à un conseiller »', () {
    for (final locale in [const Locale('fr'), const Locale('en')]) {
      final copy = _copyFor(locale);
      testWidgets(
          '(${locale.languageCode}) depuis la ligne du catalogue : le message '
          'exact part, vers le numéro officiel, surface `catalog`',
          (tester) async {
        await pumpCatalog(tester, locale: locale);
        await openSheetFromNote(tester);
        await tapCta(tester);

        expect(launcher.launched, hasLength(1));
        expect(launcher.lastText, copy.messageCatalog);
        final uri = Uri.parse(launcher.launched.single);
        expect(uri.host, 'wa.me');
        expect(
          uri.path,
          '/${AppConfig.whatsappNumber.replaceAll(RegExp(r'[^\d]'), '')}',
        );
        expect(analytics.tappedCalls, [
          const RecordedHelpEvent('private_sheet', 'catalog', 'sheet'),
        ]);
        expect(find.byKey(_sheetKey), findsNothing);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });

      testWidgets(
          '(${locale.languageCode}) depuis la bulle du hub : le message nomme '
          'le hub, surface `hub`', (tester) async {
        await pumpHub(tester, locale: locale);
        await openSheetFromBubble(tester);
        // Le message montré est celui du HUB.
        expect(_inSheet(find.text(copy.messageHub)), findsOneWidget);
        await tapCta(tester);

        expect(launcher.launched, hasLength(1));
        expect(launcher.lastText, copy.messageHub);
        expect(analytics.tappedCalls, [
          const RecordedHelpEvent('private_sheet', 'hub', 'sheet'),
        ]);
      });

      testWidgets(
          '(${locale.languageCode}) depuis la bulle du catalogue : le message '
          'nomme le catalogue', (tester) async {
        await pumpCatalog(tester, locale: locale);
        await openSheetFromBubble(tester);
        await tapCta(tester);
        expect(launcher.lastText, copy.messageCatalog);
        expect(analytics.tappedCalls, [
          const RecordedHelpEvent('private_sheet', 'catalog', 'sheet'),
        ]);
      });
    }

    testWidgets(
        'la feuille est fermée AVANT que WhatsApp s\'ouvre, et la '
        'mesure part AVANT le lancement', (tester) async {
      final probing = _ProbingLauncher(
        () => find.byKey(_sheetKey).evaluate().isNotEmpty,
        () => analytics.tappedCalls.length,
      );
      UrlLauncherPlatform.instance = probing;
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);

      await tapCta(tester);

      expect(probing.launched, hasLength(1));
      expect(probing.sheetOpenAtLaunch, [false],
          reason: 'le lancement ne doit pas partir sous une feuille encore là');
      expect(probing.tappedAtLaunch, [1]);
      expect(find.byKey(_sheetKey), findsNothing);
    });

    testWidgets(
        'même chose quand la feuille vient de la bulle (menu puis '
        'feuille, puis WhatsApp)', (tester) async {
      final probing = _ProbingLauncher(
        () =>
            find.byKey(_sheetKey).evaluate().isNotEmpty ||
            find.byKey(_menuKey).evaluate().isNotEmpty,
        () => analytics.tappedCalls.length,
      );
      UrlLauncherPlatform.instance = probing;
      await pumpHub(tester);
      await openSheetFromBubble(tester);
      await tapCta(tester);
      expect(probing.sheetOpenAtLaunch, [false]);
      expect(probing.launched, hasLength(1));
    });

    testWidgets(
        'sans WhatsApp, l\'étudiant lit le toast (le lancement est '
        'TENTÉ)', (tester) async {
      final failing = FailingUrlLauncher();
      UrlLauncherPlatform.instance = failing;
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      await tapCta(tester);

      expect(failing.launched, hasLength(1));
      expect(find.text('whatsapp_open_failed'.tr), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('deux activations d\'affilée n\'envoient QU\'UN message',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester);
      await openSheetFromNote(tester);

      tester.semantics.tap(find.semantics.byLabel(RegExp('^${_fr.cta}')));
      tester.semantics.tap(find.semantics.byLabel(RegExp('^${_fr.cta}')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      expect(launcher.launched, hasLength(1));
      expect(analytics.tappedCalls, hasLength(1));
      expect(find.byType(EefCatalogScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      handle.dispose();
    });

    testWidgets(
        'WhatsApp SEUL : le suivi attribue `eef_help_private_sheet` '
        'et le type `eef_help`', (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      await tapCta(tester);
      final handoffs =
          emitted.where((e) => e.name == 'whatsapp_handoff').toList();
      expect(handoffs, hasLength(1));
      expect(handoffs.single.params['source'], 'eef_help_private_sheet');
      expect(handoffs.single.params['context_type'], 'eef_help');
      expect(handoffs.single.params['success'], 1);
    });

    testWidgets(
        'la suspension arrive feuille ouverte : « En parler » ne '
        'part pas', (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      setSuspendedCountries(const ['Sénégal']);
      await tapCta(tester);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
      expect(find.byKey(_sheetKey), findsNothing);
    });

    testWidgets(
        'le serveur ferme l\'interrupteur feuille ouverte : « En '
        'parler » ne part pas', (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      AppConfig.eefPrivateSchoolsEnabledOverride = false;
      await tapCta(tester);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
    });

    // La garde d'OUVERTURE (avant la feuille), distincte de la garde relue après
    // la fermeture : le menu de la bulle a été construit quand tout était ouvert,
    // puis la suspension (ou la fermeture serveur) arrive sans le reconstruire.
    // Ces deux tests tuent aussi la branche `opensInfoSheet` de la bulle : sans
    // elle, l'option « effective » d'un compte suspendu devient l'assistance et un
    // message part vers WhatsApp alors que l'étudiant voulait LIRE une feuille.
    testWidgets(
        'la suspension arrive menu ouvert : le tap sur « écoles '
        'privées » n\'ouvre rien, ne mesure rien, n\'envoie rien',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(_option(EefBubbleOption.private), findsOneWidget);
      // Le menu n'est PAS reconstruit.
      setSuspendedCountries(const ['Sénégal']);
      await tapPrivateTile(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
      expect(analytics.privateInfoEntries, isEmpty);
    });

    testWidgets(
        'le serveur ferme l\'interrupteur menu ouvert : le tap sur '
        '« écoles privées » n\'ouvre rien, ne mesure rien, n\'envoie rien',
        (tester) async {
      await pumpHub(tester);
      await openMenu(tester);
      expect(_option(EefBubbleOption.private), findsOneWidget);
      AppConfig.eefPrivateSchoolsEnabledOverride = false;
      await tapPrivateTile(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
      expect(analytics.privateInfoEntries, isEmpty);
    });
  });

  group('« Pas maintenant » et la fermeture', () {
    testWidgets('ferme la feuille sans rien enregistrer ni lancer',
        (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      expect(analytics.privateInfoEntries, ['catalog_empty']);

      await tapDismiss(tester);

      expect(find.byKey(_sheetKey), findsNothing);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
      // Seule l'ouverture a été mesurée, et rien d'autre n'a été émis par elle.
      expect(analytics.privateInfoEntries, ['catalog_empty']);
      expect(emitted.where((e) => e.name == 'whatsapp_handoff'), isEmpty);
      expect(emitted.where((e) => e.name == 'eef_help_cta_tapped'), isEmpty);
      // On peut la rouvrir.
      await openSheetFromNote(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
    });

    testWidgets('le voile : mêmes garanties', (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      await tester.tapAt(const Offset(10, 20));
      await settleBounded(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
    });

    testWidgets('depuis la bulle : « Pas maintenant » ne lance rien non plus',
        (tester) async {
      await pumpHub(tester);
      await openSheetFromBubble(tester);
      await tapDismiss(tester);
      expect(find.byKey(_sheetKey), findsNothing);
      expect(find.byKey(_menuKey), findsNothing);
      expect(launcher.launched, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
      // La bulle, elle, est toujours là et se rouvre.
      await openMenu(tester);
      expect(find.byKey(_menuKey), findsOneWidget);
    });

    testWidgets(
        'deux activations du lien d\'affilée n\'ouvrent QU\'UNE '
        'feuille', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester);
      await tester.ensureVisible(find.byKey(_linkKey));
      await tester.pump();
      tester.semantics.tap(find.semantics.byLabel(_fr.noteLink));
      tester.semantics.tap(find.semantics.byLabel(_fr.noteLink));
      await settleBounded(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(analytics.privateInfoEntries, ['catalog_empty']);
      handle.dispose();
    });

    testWidgets(
        'deux activations de l\'option d\'affilée n\'ouvrent QU\'UNE '
        'feuille', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);
      await openMenu(tester);
      final tile = _option(EefBubbleOption.private);
      await tester.ensureVisible(tile);
      await tester.pump();
      final label = RegExp('^${RegExp.escape(_fr.optionLabel)}\\. ');
      tester.semantics.tap(find.semantics.byLabel(label));
      tester.semantics.tap(find.semantics.byLabel(label));
      await settleBounded(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(analytics.privateInfoEntries, ['bubble']);
      expect(launcher.launched, isEmpty);
      handle.dispose();
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. LA MESURE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la mesure', () {
    testWidgets(
        'la ligne est « vue » UNE fois par visite, avec ses trois '
        'propriétés', (tester) async {
      await pumpCatalog(tester);
      List<RecordedHelpEvent> noteShown() =>
          analytics.shownCalls.where((e) => e.step == 'private_note').toList();
      expect(noteShown(),
          [const RecordedHelpEvent('private_note', 'catalog', 'note')]);

      // Reconstruire sur l'arrivée de drapeaux : pas une 2e « vue ».
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await tester.pump();
      await tester.pump();
      expect(noteShown(), hasLength(1));

      // Retirée puis revenue dans la MÊME visite : toujours une seule vue.
      AppConfig.eefPrivateSchoolsEnabledOverride = false;
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await settleBounded(tester);
      expect(find.byKey(_noteKey), findsNothing);
      AppConfig.eefPrivateSchoolsEnabledOverride = true;
      RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(null);
      await settleBounded(tester);
      await revealNote(tester);
      expect(find.byKey(_noteKey), findsOneWidget);
      expect(noteShown(), hasLength(1));
    });

    testWidgets(
        'démontée puis remontée dans la même visite (défilement) : pas une '
        '2e « vue »', (tester) async {
      await pumpCatalog(tester, viewport: _se);
      List<RecordedHelpEvent> noteShown() =>
          analytics.shownCalls.where((e) => e.step == 'private_note').toList();
      expect(find.byKey(_noteKey), findsOneWidget);
      expect(noteShown(), hasLength(1));

      // Tout en haut : la liste est paresseuse, la ligne est démontée.
      final position =
          tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      position.jumpTo(0);
      await tester.pump();
      await tester.pump();
      expect(find.byKey(_noteKey), findsNothing,
          reason: 'la ligne doit avoir été démontée pour que ce test serve');

      await revealNote(tester);
      expect(find.byKey(_noteKey), findsOneWidget);
      expect(noteShown(), hasLength(1));
    });

    testWidgets('rien n\'est « vu » quand la ligne est absente',
        (tester) async {
      AppConfig.eefPrivateSchoolsEnabledOverride = false;
      await pumpCatalog(tester);
      expect(analytics.shownSteps, isNot(contains('private_note')));
    });

    testWidgets('le lien : `eef_private_info_opened` {entry: catalog_empty}',
        (tester) async {
      await pumpCatalog(tester);
      await openSheetFromNote(tester);
      expect(analytics.privateInfoEntries, ['catalog_empty']);
      // Ouvrir n'est pas envoyer.
      expect(analytics.tappedCalls, isEmpty);
    });

    testWidgets(
        'l\'option : `eef_private_info_opened` {entry: bubble}, après '
        '`eef_bubble_opened`', (tester) async {
      await pumpHub(tester);
      await openSheetFromBubble(tester);
      expect(analytics.openedSurfaces, ['hub']);
      expect(analytics.privateInfoEntries, ['bubble']);
      expect(analytics.tappedCalls, isEmpty);
    });

    group('l\'événement émis par le vrai service', () {
      testWidgets('de bout en bout, depuis la ligne du catalogue',
          (tester) async {
        EefHelpCard.resetForTest();
        await pumpCatalog(tester);
        await openSheetFromNote(tester);
        await tapCta(tester);

        final mine = emitted
            .where((e) =>
                const {
                  'eef_private_info_opened',
                  'eef_help_cta_tapped',
                  'whatsapp_handoff',
                }.contains(e.name) ||
                (e.name == 'eef_help_card_shown' &&
                    e.params['help_step'] == 'private_note'))
            .toList();
        expect(mine.map((e) => e.name), [
          'eef_help_card_shown',
          'eef_private_info_opened',
          'eef_help_cta_tapped',
          'whatsapp_handoff',
        ]);
        expect(mine[0].params, {
          'help_step': 'private_note',
          'surface': 'catalog',
          'variant': 'note',
        });
        // UNE propriété fermée, `entry`.
        expect(mine[1].params, {'entry': 'catalog_empty'});
        expect(mine[2].params, {
          'help_step': 'private_sheet',
          'surface': 'catalog',
          'variant': 'sheet',
        });
        expect(mine[3].params['source'], 'eef_help_private_sheet');
        expect(mine[3].params['context_type'], 'eef_help');
        // Jamais le texte du message.
        expect(mine.map((e) => e.toString()).join(' '),
            isNot(contains('Bonjour')));
      });

      testWidgets('de bout en bout, depuis la bulle', (tester) async {
        EefHelpCard.resetForTest();
        await pumpHub(tester);
        await openSheetFromBubble(tester);
        await tapCta(tester);

        final mine = emitted
            .where((e) => const {
                  'eef_bubble_opened',
                  'eef_private_info_opened',
                  'eef_help_cta_tapped',
                  'whatsapp_handoff',
                }.contains(e.name))
            .toList();
        expect(mine.map((e) => e.name), [
          'eef_bubble_opened',
          'eef_private_info_opened',
          'eef_help_cta_tapped',
          'whatsapp_handoff',
        ]);
        expect(mine[1].params, {'entry': 'bubble'});
        expect(mine[2].params, {
          'help_step': 'private_sheet',
          'surface': 'hub',
          'variant': 'sheet',
        });
        // Le sujet de la bulle n'a PAS produit de `bubble_private` mesuré comme
        // un envoi : choisir l'option est lire, pas écrire.
        expect(
            emitted
                .where((e) => e.name == 'eef_help_cta_tapped')
                .map((e) => e.params['help_step']),
            ['private_sheet']);
      });

      test('`eef_private_info_opened` : ce nom et la seule clé `entry`', () {
        EefHelpCard.resetForTest();
        EefHelp.analytics.privateInfoOpened(entry: 'catalog_empty');
        expect(emitted.map((e) => e.name), ['eef_private_info_opened']);
        expect(emitted.single.params, {'entry': 'catalog_empty'});
      });
    });

    test('le contrat publié documente l\'événement et les nouvelles valeurs',
        () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final needle in [
        '`eef_private_info_opened`',
        '`entry`',
        '`catalog_empty`',
        '`private_sheet`',
        '`private_note`',
        '`sheet`',
        '`note`',
        'eef_help_private_sheet',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });

    test('les seules valeurs de `entry` écrites dans le code', () {
      final source = File(
              'lib/app/features/etudes_en_france/eef_private_schools_sheet.dart')
          .readAsStringSync();
      expect(source, contains("bubble('bubble')"));
      expect(source, contains("catalogEmpty('catalog_empty')"));
      // Aucune autre valeur de `entry` n'est écrite, ni ici ni dans la bulle.
      final bubble =
          File('lib/app/features/etudes_en_france/eef_help_bubble.dart')
              .readAsStringSync();
      for (final file in [source, bubble]) {
        expect(RegExp(r"entry: '").hasMatch(file), isFalse,
            reason: 'un identifiant libre passé en chaîne');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. LES TEXTES
  // ═══════════════════════════════════════════════════════════════════════════

  group('les textes', () {
    final keys = AppTranslations().keys;
    Iterable<String> privateKeys(String locale) =>
        keys[locale]!.keys.where((k) => k.startsWith('eef_help_private_'));

    // Les clés balayées par les gardes de contenu : toutes celles qui existent.
    // La liste du contrat (`_privateKeys`) est vérifiée à part, par « chaque clé
    // existe » et « parité » : retirer la phrase de rémunération (sa clé et le
    // test qui la nomme) ne fait donc rougir QUE les tests qui la nomment.
    Iterable<String> sweep() => _privateKeys.where(keys['fr']!.containsKey);

    test('chaque clé existe en français ET en anglais, non vide', () {
      for (final locale in ['fr', 'en']) {
        for (final key in _privateKeys) {
          expect(keys[locale]![key], isNotNull, reason: '$key ($locale)');
          expect(keys[locale]![key]!.trim(), isNotEmpty, reason: key);
        }
      }
    });

    test(
        'parité : exactement les mêmes clés `eef_help_private_*` en FR et EN '
        'et rien d\'autre que la liste', () {
      expect(privateKeys('fr').toSet(), privateKeys('en').toSet());
      expect(privateKeys('fr').toSet(), _privateKeys.toSet());
    });

    test('FR et EN diffèrent (aucune traduction oubliée)', () {
      for (final key in sweep()) {
        expect(keys['en']![key], isNot(keys['fr']![key]), reason: key);
      }
    });

    test('les textes sont ceux du plan, mot pour mot', () {
      for (final entry in {'fr': _fr, 'en': _en}.entries) {
        final k = keys[entry.key]!;
        final c = entry.value;
        expect(k['eef_help_private_chip'], c.chip);
        expect(k['eef_help_private_title'], c.title);
        expect(k['eef_help_private_point_terms'], c.terms);
        expect(k['eef_help_private_point_fees'], c.fees);
        expect(k['eef_help_private_point_fees_fallback'], c.feesFallback);
        expect(k['eef_help_private_point_steps'], c.steps);
        expect(k['eef_help_private_point_status'], c.status);
        expect(k['eef_help_private_cta'], c.cta);
        expect(k['eef_help_private_dismiss'], c.dismiss);
        expect(k['eef_help_private_message_label'], c.messageLabel);
        expect(k['eef_help_private_option_label'], c.optionLabel);
        expect(k['eef_help_private_note_text'], c.noteText);
        expect(k['eef_help_private_note_link'], c.noteLink);
      }
    });

    test('la phrase de rémunération : le texte du plan, accentué', () {
      expect(keys['fr']![_disclosureKey], _fr.disclosure);
      expect(keys['en']![_disclosureKey], _en.disclosure);
      expect(keys['fr']![_disclosureKey], contains('rémunéré'));
    });

    // La phrase de rémunération a SA clé : retirable en une ligne sans toucher
    // aux autres points.
    test('la phrase de rémunération est dans SA clé, nulle part ailleurs', () {
      for (final locale in ['fr', 'en']) {
        final remuneration = RegExp(
          locale == 'fr' ? r'r[ée]mun[ée]r' : r'\bpaid\b',
          caseSensitive: false,
        );
        for (final key in _privateKeys) {
          final has = remuneration.hasMatch(keys[locale]![key]!);
          expect(has, key == 'eef_help_private_disclosure',
              reason: '$key ($locale) : ${keys[locale]![key]}');
        }
        // Les autres points, retranchés de la phrase, se lisent seuls.
        expect(keys[locale]!['eef_help_private_point_status'],
            isNot(contains(keys[locale]!['eef_help_private_disclosure']!)));
      }
    });

    test(
        'le widget compose le point 4 de DEUX clés, la rémunération en '
        'dernier', () {
      final source = File(
              'lib/app/features/etudes_en_france/eef_private_schools_sheet.dart')
          .readAsStringSync();
      expect(source, contains("'eef_help_private_point_status'.tr"));
      expect(source, contains("'eef_help_private_disclosure'.tr"));
      expect(
        source.indexOf("'eef_help_private_point_status'.tr"),
        lessThan(source.indexOf("'eef_help_private_disclosure'.tr")),
      );
    });

    test(
        'le repli sur les frais existe en FR et EN mais n\'est PAS affiché '
        'par défaut', () {
      final source = File(
              'lib/app/features/etudes_en_france/eef_private_schools_sheet.dart')
          .readAsStringSync();
      expect(source, contains('const bool _useFeesFallback = false;'));
      expect(source, contains("'eef_help_private_point_fees_fallback'"));
      // Seul le booléen choisit : le repli n'est référencé qu'une fois.
      expect(
          RegExp("'eef_help_private_point_fees_fallback'")
              .allMatches(source)
              .length,
          1);
      expect(
          RegExp('_useFeesFallback').allMatches(source).length, greaterThan(1));
    });

    test(
        'aucune clé ne chiffre, ne nomme une école, un pays, ni l\'opérateur '
        'de l\'État', () {
      for (final locale in ['fr', 'en']) {
        for (final key in sweep()) {
          final value = keys[locale]![key]!;
          final reason = '$key ($locale) : $value';
          expect(RegExp(r'\d').hasMatch(value), isFalse,
              reason: 'chiffre — $reason');
          expect(_priceWording.hasMatch(value), isFalse,
              reason: 'prix — $reason');
          expect(_schoolNames.hasMatch(value), isFalse,
              reason: 'école — $reason');
          expect(_countryWording.hasMatch(value), isFalse,
              reason: 'pays — $reason');
          expect(_forbiddenClaims.hasMatch(value), isFalse,
              reason: 'promesse ou enseigne — $reason');
          expect(
              RegExp(r'campus[\s_-]*france', caseSensitive: false)
                  .hasMatch(value),
              isFalse,
              reason: reason);
          // Ni le nom d'une devise, ni un montant, ni un symbole.
          expect(RegExp(r'[€$£]').hasMatch(value), isFalse, reason: reason);
        }
      }
    });

    test('aucun texte ne promet un résultat', () {
      final promise = RegExp(
        r'(admission|visa|bourse|scholarship)s?\s+(garanti|assur|certain|'
        r'guaranteed|assured|certain)|vous obtiendrez|tu obtiendras|'
        r'you will (get|obtain)|100\s?%|\bfacile|\brapide|\bmeilleur|\bid[ée]al|'
        r'\beasy\b|\bfast\b|\bbest\b|\bideal\b',
        caseSensitive: false,
      );
      for (final locale in ['fr', 'en']) {
        for (final key in sweep()) {
          expect(promise.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale) : ${keys[locale]![key]}');
        }
      }
    });

    test('le français est accentué : aucun mot sans ses accents', () {
      // Les mots qui DOIVENT porter un accent en français, écrits sans.
      final mustAccent = RegExp(
        r'\b(ecoles?|remunere|remuneres|demarches?|verifie|verifier|etat|'
        r'etudes?|prives?|privee|ecrit|ecrire|specifique)\b',
        caseSensitive: false,
      );
      for (final key in sweep()) {
        final value = keys['fr']![key]!;
        expect(mustAccent.hasMatch(value), isFalse, reason: '$key : $value');
      }
      expect(keys['fr']!['eef_help_private_title'], contains('écoles'));
      expect(
          keys['fr']!['eef_help_private_message'], contains('écoles privées'));
    });

    test('la pastille dit « Service KPB » / « KPB service »', () {
      expect(keys['fr']!['eef_help_private_chip'], 'Service KPB');
      expect(keys['en']!['eef_help_private_chip'], 'KPB service');
    });

    test('tutoiement dans les phrases en français (pas de « vous »)', () {
      for (final key in sweep()) {
        expect(
            RegExp(r'\b(vous|votre|vos)\b', caseSensitive: false)
                .hasMatch(keys['fr']![key]!),
            isFalse,
            reason: key);
      }
    });

    group('le message prérempli', () {
      for (final locale in ['fr', 'en']) {
        for (final surface in EefBubbleSurface.values) {
          test(
              '$locale / ${surface.key} : exact, borné, sans @, sans donnée '
              'personnelle', () {
            Get.addTranslations(AppTranslations().keys);
            Get.locale = Locale(locale);
            Get.fallbackLocale = const Locale('fr');
            final copy = _copyFor(Locale(locale));
            final message = EefBubbleMessages.messageFor(
              EefBubbleOption.private,
              surface,
              suspended: false,
            );
            expect(message, copy.message(catalog: surface.key == 'catalog'));
            expect(message.runes.length, lessThanOrEqualTo(520));
            expect(
                Uri.encodeComponent(message).length, lessThanOrEqualTo(1800));
            expect(message, isNot(contains('@')));
            expect(message, message.trim());
            expect(message, isNot(contains('\n')));
            expect(looksLikeRawTranslationKey(message), isFalse);
            for (final personal in ['Mouhamadou', 'Diallo', 'example.com']) {
              expect(message, isNot(contains(personal)));
            }
            // Aucun champ à compléter, aucun pays.
            expect(message, isNot(contains('…')));
            expect(message, isNot(contains(': .')));
            expect(_countryWording.hasMatch(message), isFalse);
            expect(_priceWording.hasMatch(message), isFalse);
          });
        }
      }

      test('la clé porte `@place` et RIEN d\'autre à remplacer', () {
        for (final locale in ['fr', 'en']) {
          final value = keys[locale]!['eef_help_private_message']!;
          expect(value, contains('@place'));
          expect(value.replaceAll('@place', ''), isNot(contains('@')));
        }
      });
    });

    test('rien n\'est écrit en dur dans le widget', () {
      // Le code, sans ses commentaires (qui parlent naturellement d'écoles).
      final source = File(
              'lib/app/features/etudes_en_france/eef_private_schools_sheet.dart')
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      for (final hardcoded in [
        'Bonjour',
        'Hello',
        'Service KPB',
        'KPB service',
        'écoles',
        'schools',
        'conseiller',
        'advisor',
        'Pas maintenant',
        'Not now',
      ]) {
        expect(source, isNot(contains(hardcoded)),
            reason: '« $hardcoded » écrit en dur');
      }
      expect(source, isNot(contains('canLaunchUrl')));
      expect(source, isNot(contains('FrancePrivateAdmission')));
      expect(source, isNot(contains('france_private_admission')));
      expect(source, contains("source: 'eef_help_private_sheet'"));
      expect(source, contains("contextType: 'eef_help'"));
    });

    test('aucune dépendance native ni Flutter n\'a été ajoutée', () {
      final source = File(
              'lib/app/features/etudes_en_france/eef_private_schools_sheet.dart')
          .readAsStringSync();
      final imports = RegExp(r"^import '([^']+)';", multiLine: true)
          .allMatches(source)
          .map((m) => m.group(1)!)
          .toList();
      expect(imports, isNotEmpty);
      for (final import in imports) {
        expect(
          import.startsWith('dart:') ||
              import.startsWith('package:flutter/') ||
              import.startsWith('package:get/') ||
              import.startsWith('../') ||
              import.startsWith('eef_'),
          isTrue,
          reason: 'import inattendu : $import',
        );
      }
    });

    test(
        'la ligne et la feuille ne sont écrites que dans les endroits '
        'prévus', () {
      String read(String name) =>
          File('lib/app/features/etudes_en_france/$name').readAsStringSync();
      // Ni dans la mention des données, ni dans les sources, ni dans le hub.
      for (final untouched in [
        'eef_data_notice.dart',
        'eef_sources_row.dart',
        'eef_home_screen.dart',
        'eef_official_links.dart',
      ]) {
        final file = File('lib/app/features/etudes_en_france/$untouched');
        if (!file.existsSync()) continue;
        final source = read(untouched);
        expect(source, isNot(contains('PrivateSchools')), reason: untouched);
        expect(source, isNot(contains('eef_help_private')), reason: untouched);
      }
      expect(
          read('eef_catalog_screen.dart'), contains('EefPrivateSchoolsNote'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. LA GÉOMÉTRIE ET LA SÉMANTIQUE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la feuille et la ligne tiennent sur tous les écrans', () {
    for (final viewport in _matrixViewports) {
      for (final scale in [1.0, 1.3]) {
        for (final locale in [const Locale('fr'), const Locale('en')]) {
          final copy = _copyFor(locale);
          testWidgets(
              '${viewport.id} ×$scale ${locale.languageCode} : ligne et '
              'feuille sans débordement, sans troncature', (tester) async {
            final report = await pumpCatalog(
              tester,
              viewport: viewport,
              textScale: scale,
              locale: locale,
            );
            expect(report.overflows, isEmpty, reason: '$report');
            expect(find.byKey(_noteKey), findsOneWidget);
            await tester.ensureVisible(find.byKey(_linkKey));
            await tester.pump();
            expect(truncatedTexts(tester), isEmpty);
            // Le lien est une cible tactile d'au moins 48 dp (comme le bouton
            // principal et « Pas maintenant »).
            expect(tester.getSize(find.byKey(_linkKey)).height,
                greaterThanOrEqualTo(48));
            final noteRect = tester.getRect(find.byKey(_noteKey));
            expect(noteRect.left, greaterThanOrEqualTo(0));
            expect(noteRect.right, lessThanOrEqualTo(viewport.size.width));

            await tester.tap(find.byKey(_linkKey));
            await settleBounded(tester);
            expect(find.byKey(_sheetKey), findsOneWidget);
            expect(tester.takeException(), isNull);
            expect(tester.getSize(find.byKey(_sheetKey)).width,
                lessThanOrEqualTo(560));

            // Tout est atteignable par le défilement ; rien n'est tronqué.
            for (final point in [
              _inSheet(find.text(copy.terms)),
              _inSheet(find.text(copy.fees)),
              _inSheet(find.text(copy.steps)),
              // Le point 4 se cherche par son début : la phrase de rémunération
              // (sa propre clé) peut être retirée sans toucher cette matrice.
              _inSheet(find.textContaining(copy.status)),
              _inSheet(find.text(copy.messageCatalog)),
            ]) {
              await tester.ensureVisible(point);
              await tester.pump();
            }
            await tester.ensureVisible(find.byKey(_ctaKey));
            await tester.pump();
            expect(tester.getSize(find.byKey(_ctaKey)).height,
                greaterThanOrEqualTo(48));
            await tester.ensureVisible(find.byKey(_dismissKey));
            await tester.pump();
            expect(tester.getSize(find.byKey(_dismissKey)).height,
                greaterThanOrEqualTo(48));
            expect(tester.takeException(), isNull);
            expect(truncatedTexts(tester), isEmpty);
            for (final key in [_ctaKey, _dismissKey]) {
              final rect = tester.getRect(find.byKey(key));
              expect(rect.left, greaterThanOrEqualTo(0));
              expect(rect.right, lessThanOrEqualTo(viewport.size.width));
            }
            expect(rawTranslationKeysOnScreen(tester), isEmpty);
          });
        }
      }
    }

    for (final viewport in [_se, _phone360]) {
      testWidgets(
          '${viewport.id} ×1.3 : le menu à cinq sujets défile et '
          'chaque tuile garde 56 dp', (tester) async {
        await pumpHub(tester, viewport: viewport, textScale: 1.3);
        await openMenu(tester);
        for (final option in EefBubbleMessages.optionsFor(suspended: false)) {
          await tester.ensureVisible(_option(option));
          await tester.pump();
          expect(
              tester.getSize(_option(option)).height, greaterThanOrEqualTo(56),
              reason: option.id);
        }
        expect(menuOptionCount(), 5);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('thème sombre : la feuille se lit, sans erreur',
        (tester) async {
      await seedKpbController(
        apiClient: api,
        snapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(
              countryOfResidence: 'Sénégal', preferredLanguage: 'fr'),
        ),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefCatalogScreen(),
        viewport: iphone14,
        themeMode: ThemeMode.dark,
        routesShareMediaQuery: true,
      );
      await openSheetFromNote(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      expect(tester.takeException(), isNull);
    });

    // Les marges système : le harnais des viewports les fournit (barre d'état
    // en haut, indicateur d'accueil de l'iPhone en bas).
    testWidgets('la feuille respecte la barre d\'état (320×568, texte ×1,3)',
        (tester) async {
      await pumpCatalog(tester, viewport: _se, textScale: 1.3);
      await openSheetFromNote(tester);
      expect(find.byKey(_sheetKey), findsOneWidget);
      expect(tester.getRect(find.byType(BottomSheet)).top,
          greaterThanOrEqualTo(_se.padding.top));
    });

    testWidgets(
        'le dernier bouton reste au-dessus de l\'indicateur d\'accueil '
        '(iPhone, texte ×1,3)', (tester) async {
      await pumpCatalog(tester, viewport: iphone14, textScale: 1.3);
      await openSheetFromNote(tester);
      await tester.ensureVisible(find.byKey(_dismissKey));
      await tester.pump();
      expect(tester.getRect(find.byKey(_dismissKey)).bottom,
          lessThanOrEqualTo(iphone14.size.height - iphone14.padding.bottom));
    });
  });

  group('la sémantique', () {
    testWidgets(
        'la ligne : un lien lu comme un bouton, pastille et texte '
        'lus', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester);
      await tester.ensureVisible(find.byKey(_linkKey));
      await tester.pump();
      final link = tester.getSemantics(find.byKey(_linkKey));
      expect(link.flagsCollection.isButton, isTrue);
      expect(link.label, contains(_fr.noteLink));
      expect(find.semantics.byLabel(RegExp(RegExp.escape(_fr.noteText))),
          findsWidgets);
      handle.dispose();
    });

    testWidgets('l\'option du menu : un bouton « libellé. Service KPB »',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);
      await openMenu(tester);
      final tile = _option(EefBubbleOption.private);
      await tester.ensureVisible(tile);
      await tester.pump();
      final data = tester.getSemantics(tile);
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.label, '${_fr.optionLabel}. ${_fr.chip}');
      handle.dispose();
    });

    testWidgets(
        'la feuille : un titre, deux boutons nommés, le message lu '
        'avant le tap', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCatalog(tester);
      await openSheetFromNote(tester);

      final title = tester.getSemantics(_inSheet(find.text(_fr.title)));
      expect(title.flagsCollection.isHeader, isTrue);
      expect(title.label, _fr.title);

      final cta = tester.getSemantics(find.byKey(_ctaKey));
      expect(cta.flagsCollection.isButton, isTrue);
      expect(cta.label, contains(_fr.cta));
      final dismiss = tester.getSemantics(find.byKey(_dismissKey));
      expect(dismiss.flagsCollection.isButton, isTrue);
      expect(dismiss.label, contains(_fr.dismiss));

      // Le message qui partira est exposé AU lecteur d'écran avant le tap.
      expect(find.semantics.byLabel(RegExp(RegExp.escape(_fr.messageCatalog))),
          findsWidgets);
      handle.dispose();
    });
  });
}

/// Dans la ligne du catalogue.
Finder _inNote(String text) => find.descendant(
      of: find.byKey(_noteKey),
      matching: find.text(text),
    );
