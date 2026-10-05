// La visite guidée de l'espace « Études en France » (build 56, PR 4) : trois à
// quatre cartes, montrées UNE fois à la première ouverture du hub réel, et
// rejouables par le « ? » de la barre du haut.
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · la visite s'ouvre à la première ouverture du hub réel — jamais la vitrine,
//     jamais l'écran des parents, jamais au-dessus d'un dialogue ou d'une autre
//     feuille — et jamais la deuxième fois ;
//   · le drapeau « vue » est posé à l'AFFICHAGE, pas à la fin : « Passer », le
//     retour Android, un glissement ou un plantage ne la font pas revenir en
//     boucle. Une panne du stockage (lecture OU écriture) vaut « déjà vue » :
//     pas de visite, pas d'exception ;
//   · le « ? » la rejoue sans toucher au drapeau ;
//   · une étape ne nomme jamais un élément absent (outils IA masqués, bulle
//     éteinte), et un compte dont le pays est suspendu lit une première étape
//     NEUTRE (ni « candidature », ni « dossier », aucun pays) ; la visite ne
//     parle JAMAIS des écoles privées ;
//   · la feuille tient sur un petit téléphone à l'échelle de texte 1,3, ses
//     boutons restent à l'écran et à 48 dp, ses libellés passent à la ligne ;
//   · la mesure ne porte que des identifiants fermés.
//
// Le magasin du drapeau et la mesure sont des COUTURES (`EefTour.store`,
// `EefTour.analytics`), comme `EefHelpCard.analytics`.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Dépendance transitive de shared_preferences (pubspec.lock) : on ne l'ajoute pas
// au pubspec pour un test ; elle donne le stockage de plateforme à faire échouer.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/analytics_service.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_entry.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_students_only_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_teaser_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_tour.dart';
import 'package:karatou/app/features/etudes_en_france/eef_tour_store.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/eef_tour_fakes.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

// ── Les textes attendus, ÉCRITS EN DUR ────────────────────────────────────────
//
// Un test qui relirait la clé que le code lit ne verrait pas qu'on l'a vidée ou
// retouchée : les textes du plan (guidage.etapes) sont recopiés ici.

class _Step {
  const _Step({
    required this.frTitle,
    required this.frBody,
    required this.enTitle,
    required this.enBody,
  });

  final String frTitle;
  final String frBody;
  final String enTitle;
  final String enBody;
}

const _welcome = _Step(
  frTitle: 'Bienvenue dans Études en France',
  frBody:
      "Ici, tu explores des formations et tu prépares ton projet. Ta candidature, elle, se dépose auprès des services officiels : KPB est un service privé d'accompagnement, pas un service de l'État.",
  enTitle: 'Welcome to Études en France',
  enBody:
      'Here you explore programmes and prepare your plans. Your application itself is submitted to the official services: KPB is a private support service, not a government service.',
);

const _welcomeNeutralFr =
    "Ici, tu explores des formations et tu prépares ton projet d'études. Les démarches officielles se font sur les plateformes de l'État : KPB est un service privé d'accompagnement, pas un service de l'État.";
const _welcomeNeutralEn =
    "Here you explore programmes and prepare your study plans. Official procedures take place on the State's platforms: KPB is a private support service, not a government service.";

const _find = _Step(
  frTitle: 'Trouve une formation',
  frBody:
      "Cherche parmi les formations des universités publiques, puis filtre par niveau, domaine, ville et procédure d'admission.",
  enTitle: 'Find a programme',
  enBody:
      'Search public university programmes, then filter by level, field, city and admission procedure.',
);

const _documents = _Step(
  frTitle: 'Prépare tes documents',
  frBody:
      "Un CV, des lettres de motivation et un simulateur d'entretien t'aident à te préparer.",
  enTitle: 'Prepare your documents',
  enBody:
      'A CV builder, motivation letters and an interview simulator help you get ready.',
);

const _bubble = _Step(
  frTitle: 'Une question ? Écris-nous',
  frBody:
      "Le bouton vert en bas à droite te met en contact avec l'équipe KPB sur WhatsApp. Le message est déjà écrit et tu peux le modifier avant de l'envoyer.",
  enTitle: 'A question? Write to us',
  enBody:
      'The green button at the bottom right connects you with the KPB team on WhatsApp. The message is already written and you can edit it before sending.',
);

/// L'ordre de la visite complète.
const _allSteps = <_Step>[_welcome, _find, _documents, _bubble];

/// Ce que dirait une invitation à ouvrir un dossier, en français comme en
/// anglais (même garde que la bulle et les lignes d'aide).
final _openAFileWording = RegExp(
  r'dossier|d[ée]marrer|campus\s*france|\bstart\b|\bfile\b|\breview\b|'
  r'candidature',
  caseSensitive: false,
);

/// Les pays qu'un texte ne doit jamais nommer. « France » n'y figure pas : c'est
/// le nom de l'espace.
final _countryWording = RegExp(
  r'togo|s[ée]n[ée]gal|c[ôo]te d.ivoire|cameroun|cameroon|maroc|morocco|'
  r'niger\b|mali|burkina|guin[ée]e|b[ée]nin|gabon|congo|tunisi|alg[ée]ri|'
  r'autre pays pour|another country',
  caseSensitive: false,
);

/// Une école privée, dans un texte (jamais « service privé d'accompagnement »,
/// qui est la mention de non-affiliation).
final _privateSchoolWording = RegExp(
  r'[ée]coles?\s+priv[ée]es?|private\s+schools?|priv[ée]e?s?\s+schools?|'
  r'business\s+schools?|[ée]coles?\s+de\s+commerce',
  caseSensitive: false,
);

/// Les clés de la visite : l'ensemble EXACT.
const _tourKeys = <String>[
  'eef_tour_title',
  'eef_tour_counter',
  'eef_tour_skip',
  'eef_tour_next',
  'eef_tour_done',
  'eef_tour_replay',
  'eef_tour_1_title',
  'eef_tour_1_body',
  'eef_tour_1_neutral_body',
  'eef_tour_2_title',
  'eef_tour_2_body',
  'eef_tour_3_title',
  'eef_tour_3_body',
  'eef_tour_4_title',
  'eef_tour_4_body',
];

/// Le texte sans accents, en minuscules : pour balayer aussi le français écrit
/// SANS accents (« candidature » se garde, mais « Etape » ou « ecole » aussi).
String _fold(String s) {
  const from = 'àâäéèêëîïôöùûüçÀÂÄÉÈÊËÎÏÔÖÙÛÜÇ';
  const to = 'aaaeeeeiioouuucAAAEEEEIIOOUUUC';
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buffer.write(i >= 0 ? to[i] : ch);
  }
  return buffer.toString().toLowerCase();
}

// ── La géométrie ──────────────────────────────────────────────────────────────

const _se = KpbViewport(
  id: 'phone320',
  name: 'Petit téléphone 320×568',
  size: Size(320, 568),
  padding: EdgeInsets.only(top: 20),
);

const _android640 = KpbViewport(
  id: 'android360x640',
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

/// La hauteur utile minimale de la zone des cartes, à ×1,3 : sans
/// `isScrollControlled` la feuille est plafonnée à 9/16 de l'écran et la zone
/// tombe à ~100 dp sur 320×568 (titre + une ligne, le reste à faire défiler).
const _minCardView = 180.0;

const _matrixViewports = <KpbViewport>[_se, _android640, iphone14, _ipad];

// ── Les clés des widgets ──────────────────────────────────────────────────────

const _sheetKey = ValueKey('eef-tour-sheet');
const _skipKey = ValueKey('eef-tour-skip');
const _nextKey = ValueKey('eef-tour-next');
const _replayKey = ValueKey('eef-tour-replay');
const _titleKey = ValueKey('eef-tour-title');
const _bodyKey = ValueKey('eef-tour-body');
const _bubbleKey = ValueKey('eef-help-bubble');
const _entranceKey = ValueKey('eef-help-bubble-entrance');

/// Un stockage dont l'écriture est REFUSÉE (`setValue` rend `false`) : disque
/// plein, commit Android refusé.
class _NoWriteStore extends InMemorySharedPreferencesStore {
  _NoWriteStore() : super.empty();

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}

/// Un événement tel que `AnalyticsService` l'émet vers Firebase.
class _Emitted {
  const _Emitted(this.name, this.params);

  final String name;
  final Map<String, Object> params;

  @override
  String toString() => '$name$params';
}

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late FakeEefTourStore store;
  late RecordingTourAnalytics tourAnalytics;
  late UrlLauncherPlatform previousLauncher;

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
    when(() => api.getEefInterest())
        .thenAnswer((_) async => <String, dynamic>{'declared': false});
    previousLauncher = UrlLauncherPlatform.instance;
    UrlLauncherPlatform.instance = RecordingUrlLauncher();
    EefHelpCard.analytics = RecordingHelpAnalytics();
    store = FakeEefTourStore();
    tourAnalytics = RecordingTourAnalytics();
    EefTour.store = store;
    EefTour.analytics = tourAnalytics;
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = true;
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = true;
    AppConfig.eefHelpBubbleEnabledOverride = true;
    AppConfig.eefPrivateSchoolsEnabledOverride = null;
    Get.locale = const Locale('fr');
    EefCalendar.clock = () => DateTime(2026, 9, 28);
    setSuspendedCountries(const ['Niger']);
  });

  tearDown(() {
    AnalyticsService.instance.logEventSink = null;
    UrlLauncherPlatform.instance = previousLauncher;
    EefTour.resetForTest();
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

  // ── Les montages ────────────────────────────────────────────────────────────

  Future<void> seed(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    AccountType accountType = AccountType.student,
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
                accountType: accountType,
                preferredLanguage: locale.languageCode,
              ),
      ),
    );
  }

  Future<KpbScreenReport> pumpScreen(
    WidgetTester tester,
    Widget screen, {
    String country = 'Sénégal',
    bool guest = false,
    AccountType accountType = AccountType.student,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
    bool disableAnimations = false,
  }) async {
    await seed(
      tester,
      country: country,
      guest: guest,
      accountType: accountType,
      locale: locale,
    );
    return pumpKpbScreen(
      tester,
      screen: screen,
      viewport: viewport,
      textScale: textScale,
      locale: locale,
      disableAnimations: disableAnimations,
      // La feuille reprend la taille et l'échelle de texte de l'écran éprouvé.
      routesShareMediaQuery: true,
    );
  }

  Future<KpbScreenReport> pumpHub(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    Locale locale = const Locale('fr'),
    bool disableAnimations = false,
  }) =>
      pumpScreen(
        tester,
        const EefHomeScreen(),
        country: country,
        guest: guest,
        viewport: viewport,
        textScale: textScale,
        locale: locale,
        disableAnimations: disableAnimations,
      );

  // ── Les lectures ────────────────────────────────────────────────────────────

  bool tourOpen() => find.byKey(_sheetKey).evaluate().isNotEmpty;

  /// La zone visible des cartes : le défilement vertical qui contient le
  /// `PageView` (les boutons, eux, sont épinglés dessous).
  Rect cardViewRect(WidgetTester tester) => tester.getRect(find
      .ancestor(
        of: find.byType(PageView),
        matching: find.byType(SingleChildScrollView),
      )
      .first);

  /// « Passer » et « Suivant » : dans l'écran, AU-DESSUS de la barre des gestes
  /// (la feuille n'applique que le haut par `useSafeArea` : le bas est affaire
  /// du `SafeArea` interne), sous la barre de statut, et à 48 dp au moins.
  void expectButtonsOnScreen(
    WidgetTester tester,
    KpbViewport viewport, {
    required String reason,
  }) {
    for (final key in [_skipKey, _nextKey]) {
      final rect = tester.getRect(find.byKey(key));
      expect(rect.left, greaterThanOrEqualTo(0), reason: '$key $reason');
      expect(rect.right, lessThanOrEqualTo(viewport.size.width),
          reason: '$key $reason');
      expect(rect.bottom,
          lessThanOrEqualTo(viewport.size.height - viewport.padding.bottom),
          reason: '$key $reason : sous la barre des gestes');
      expect(rect.top, greaterThanOrEqualTo(viewport.padding.top),
          reason: '$key $reason');
      expect(rect.height, greaterThanOrEqualTo(48), reason: '$key $reason');
    }
  }

  /// Un texte DANS la page courante du `PageView` (les pages « jauge » cachées,
  /// qui donnent sa hauteur à la feuille, n'y sont pas).
  Finder inPage(String text) => find.descendant(
        of: find.byType(PageView),
        matching: find.text(text),
      );

  String titleOnScreen(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
        of: find.byType(PageView),
        matching: find.byKey(_titleKey),
      ))
      .data!;

  String bodyOnScreen(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
        of: find.byType(PageView),
        matching: find.byKey(_bodyKey),
      ))
      .data!;

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.byKey(_nextKey));
    await settleBounded(tester);
  }

  Future<void> skip(WidgetTester tester) async {
    await tester.tap(find.byKey(_skipKey));
    await settleBounded(tester);
  }

  Future<void> pressAndroidBack(WidgetTester tester) async {
    final message =
        const JSONMethodCodec().encodeMethodCall(const MethodCall('popRoute'));
    await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/navigation', message, (_) {});
    await settleBounded(tester);
  }

  /// Le libellé du bouton principal : « Suivant », ou « Compris » à la dernière.
  String primaryLabel(WidgetTester tester) => tester
      .widget<Text>(find.descendant(
          of: find.byKey(_nextKey), matching: find.byType(Text)))
      .data!;

  /// Parcourt la visite et rend (titre, corps) de chaque carte, en s'arrêtant sur
  /// la dernière (sans la fermer). Borné : une visite qui ne se termine pas
  /// échoue au lieu de boucler.
  Future<List<(String, String)>> walk(WidgetTester tester) async {
    final seen = <(String, String)>[];
    for (var guard = 0; guard < 6; guard++) {
      seen.add((titleOnScreen(tester), bodyOnScreen(tester)));
      if (primaryLabel(tester) == 'eef_tour_done'.tr) return seen;
      await next(tester);
    }
    fail('la visite ne se termine pas : ${seen.length} cartes parcourues');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // 1. LE MAGASIN DU DRAPEAU
  // ═══════════════════════════════════════════════════════════════════════════

  group('le magasin du drapeau « vue »', () {
    test('la clé est versionnée et suit la convention du dépôt', () {
      expect(SharedPreferencesEefTourStore.key, 'kpb_relaunch_v1.eef_tour_v1');
      expect(
        SharedPreferencesEefTourStore.key,
        startsWith('${AppConfig.storageNamespace}.'),
      );
    });

    test('rien n\'a été montré : faux ; après markShown : vrai, persisté',
        () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      const real = SharedPreferencesEefTourStore();
      expect(await real.hasBeenShown(), isFalse);
      await real.markShown();
      expect(await real.hasBeenShown(), isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kpb_relaunch_v1.eef_tour_v1'), isTrue);
    });

    test('un drapeau déjà posé se relit', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{'kpb_relaunch_v1.eef_tour_v1': true},
      );
      expect(
          await const SharedPreferencesEefTourStore().hasBeenShown(), isTrue);
    });

    // Le VRAI adaptateur, éprouvé en échec : le faux magasin lève de lui-même et
    // ne prouve donc pas que `setBool == false` devient une panne.
    test('un setBool REFUSÉ (rend false) est une panne : markShown LÈVE',
        () async {
      SharedPreferencesStorePlatform.instance = _NoWriteStore();
      SharedPreferences.resetStatic();
      addTearDown(() {
        SharedPreferences.setMockInitialValues(<String, Object>{});
        SharedPreferences.resetStatic();
      });

      await expectLater(
        const SharedPreferencesEefTourStore().markShown(),
        throwsA(isA<StateError>()),
      );
    });

    test('une valeur NON booléenne sous la clé : la lecture lève', () async {
      SharedPreferences.setMockInitialValues(
        <String, Object>{SharedPreferencesEefTourStore.key: 'oui'},
      );
      await expectLater(
        const SharedPreferencesEefTourStore().hasBeenShown(),
        throwsA(anything),
      );
    });

    test('le magasin par défaut est celui de SharedPreferences', () {
      EefTour.resetForTest();
      expect(EefTour.store, isA<SharedPreferencesEefTourStore>());
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. LE DÉCLENCHEMENT
  // ═══════════════════════════════════════════════════════════════════════════

  group('le déclenchement', () {
    testWidgets('première ouverture du hub : la visite s\'ouvre, carte 1 sur 4',
        (tester) async {
      final report = await pumpHub(tester);

      expect(tourOpen(), isTrue);
      expect(titleOnScreen(tester), _welcome.frTitle);
      expect(find.text('Étape 1 sur 4'), findsOneWidget);
      expect(report.overflows, isEmpty);
      expect(tourAnalytics.shownTriggers, ['first_open']);
    });

    testWidgets('le hub reste visible derrière : ce n\'est pas un mur',
        (tester) async {
      await pumpHub(tester);

      expect(tourOpen(), isTrue);
      expect(find.text('Trouver ma formation'), findsOneWidget);
      // On peut écarter la feuille en touchant le voile derrière.
      await tester.tapAt(const Offset(10, 60));
      await settleBounded(tester);
      expect(tourOpen(), isFalse);
      expect(tourAnalytics.completedCalls.single.exit, 'skipped');
    });

    testWidgets('le drapeau est posé à l\'AFFICHAGE, pas à la fin',
        (tester) async {
      await pumpHub(tester);

      expect(tourOpen(), isTrue);
      expect(store.reads, 1);
      expect(store.writes, 1);
      expect(store.seen, isTrue);
      // Pas un seul tap : la visite est encore à l'écran, le drapeau est posé.
      expect(tourAnalytics.completedCalls, isEmpty);
    });

    testWidgets('la deuxième ouverture ne la remontre pas', (tester) async {
      await pumpHub(tester);
      expect(tourOpen(), isTrue);
      await skip(tester);
      expect(tourOpen(), isFalse);

      // Le hub est fermé puis rouvert : même magasin.
      await pumpHub(tester);
      expect(tourOpen(), isFalse);
      expect(tourAnalytics.shownTriggers, ['first_open']);
      expect(store.writes, 1);
    });

    testWidgets('déjà vue : pas de feuille, et le drapeau n\'est pas réécrit',
        (tester) async {
      store.seen = true;
      await pumpHub(tester);

      expect(tourOpen(), isFalse);
      expect(store.writes, 0);
      expect(tourAnalytics.shownTriggers, isEmpty);
    });

    testWidgets('un invité la voit aussi (le hub l\'accueille)',
        (tester) async {
      await pumpHub(tester, guest: true);

      expect(tourOpen(), isTrue);
      expect(titleOnScreen(tester), _welcome.frTitle);
      expect(tourAnalytics.shownTriggers, ['first_open']);
    });

    testWidgets('la vitrine ne la montre pas, et ne touche pas au magasin',
        (tester) async {
      AppConfig.eefSpaceEnabledOverride = false;
      AppConfig.eefTeaserEnabledOverride = true;
      await pumpScreen(tester, const EefEntry());

      expect(find.byType(EefTeaserScreen), findsOneWidget);
      expect(tourOpen(), isFalse);
      expect(store.reads, 0);
      expect(store.writes, 0);
      expect(tourAnalytics.shownTriggers, isEmpty);
    });

    testWidgets('l\'écran des parents ne la montre pas non plus',
        (tester) async {
      await pumpScreen(tester, const EefEntry(),
          accountType: AccountType.parent);

      expect(find.byType(EefStudentsOnlyScreen), findsOneWidget);
      expect(tourOpen(), isFalse);
      expect(store.reads, 0);
      expect(tourAnalytics.shownTriggers, isEmpty);
    });

    testWidgets('pas de « ? » de rejeu sur la vitrine', (tester) async {
      AppConfig.eefSpaceEnabledOverride = false;
      AppConfig.eefTeaserEnabledOverride = true;
      await pumpScreen(tester, const EefEntry());

      expect(find.byType(EefTeaserScreen), findsOneWidget);
      expect(find.byKey(_replayKey), findsNothing);
    });

    testWidgets('pas de « ? » de rejeu sur l\'écran des parents',
        (tester) async {
      await pumpScreen(tester, const EefEntry(),
          accountType: AccountType.parent);

      expect(find.byType(EefStudentsOnlyScreen), findsOneWidget);
      expect(find.byKey(_replayKey), findsNothing);
    });

    testWidgets(
        'jamais au-dessus d\'un DIALOGUE : le drapeau n\'est pas consommé',
        (tester) async {
      // La lecture attend : le temps d'ouvrir un dialogue entre la lecture et
      // l'affichage.
      store.readGate = Completer<void>();
      await pumpHub(tester);
      expect(store.reads, 1);
      expect(tourOpen(), isFalse);

      final context = tester.element(find.byType(EefHomeScreen));
      unawaited(showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Un autre dialogue')),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Un autre dialogue'), findsOneWidget);

      store.readGate!.complete();
      await settleBounded(tester);

      expect(tourOpen(), isFalse,
          reason: 'la visite s\'est ouverte par-dessus');
      expect(find.text('Un autre dialogue'), findsOneWidget);
      expect(store.writes, 0, reason: 'la visite n\'a pas été montrée');
      expect(store.seen, isFalse);
      expect(tourAnalytics.shownTriggers, isEmpty);

      // Contrôle positif : au prochain hub, sans dialogue, elle s'ouvre.
      store.readGate = null;
      await pumpHub(tester);
      expect(tourOpen(), isTrue);
      expect(store.writes, 1);
    });

    testWidgets(
        'jamais au-dessus d\'une autre FEUILLE (ex. la déclaration d\'intérêt)',
        (tester) async {
      store.readGate = Completer<void>();
      await pumpHub(tester);

      final context = tester.element(find.byType(EefHomeScreen));
      unawaited(showModalBottomSheet<void>(
        context: context,
        builder: (_) => const SizedBox(
          height: 200,
          child: Center(child: Text('Une autre feuille')),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Une autre feuille'), findsOneWidget);

      store.readGate!.complete();
      await settleBounded(tester);

      expect(tourOpen(), isFalse);
      expect(find.text('Une autre feuille'), findsOneWidget);
      expect(store.writes, 0);
      expect(store.seen, isFalse);

      // Contrôle positif : au prochain hub, sans feuille, elle s'ouvre.
      store.readGate = null;
      await pumpHub(tester);
      expect(tourOpen(), isTrue);
    });

    testWidgets('le hub démonté pendant la lecture : rien ne s\'ouvre',
        (tester) async {
      store.readGate = Completer<void>();
      await pumpHub(tester);
      await tester.pumpWidget(const SizedBox.shrink());

      store.readGate!.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tourOpen(), isFalse);
      expect(store.writes, 0);
      expect(tester.takeException(), isNull);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. LES SORTIES : PASSER, RETOUR ANDROID, COMPRIS
  // ═══════════════════════════════════════════════════════════════════════════

  group('les sorties', () {
    testWidgets('« Passer » ferme la visite, le drapeau reste posé',
        (tester) async {
      await pumpHub(tester);
      await skip(tester);

      expect(tourOpen(), isFalse);
      expect(store.seen, isTrue);
      expect(store.writes, 1);
      expect(tourAnalytics.completedCalls, hasLength(1));
      expect(tourAnalytics.completedCalls.single.exit, 'skipped');
      expect(tourAnalytics.completedCalls.single.cardsSeen, 1);
    });

    testWidgets('« Passer » est présent à CHAQUE carte, dernière comprise',
        (tester) async {
      await pumpHub(tester);
      for (var i = 0; i < 4; i++) {
        expect(find.byKey(_skipKey), findsOneWidget, reason: 'carte ${i + 1}');
        expect(find.text('Passer'), findsOneWidget);
        expect(tester.widget<TextButton>(find.byKey(_skipKey)).onPressed,
            isNotNull,
            reason: '« Passer » doit être actif, carte ${i + 1}');
        if (i < 3) await next(tester);
      }
    });

    testWidgets('« Passer » sur la DERNIÈRE carte ferme aussi : quatre vues',
        (tester) async {
      await pumpHub(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      await skip(tester);

      expect(tourOpen(), isFalse);
      expect(tourAnalytics.completedCalls.single.exit, 'skipped');
      expect(tourAnalytics.completedCalls.single.cardsSeen, 4);
    });

    testWidgets('le retour Android vaut « Passer » : fermée, drapeau gardé',
        (tester) async {
      await pumpHub(tester);
      await next(tester);
      await pressAndroidBack(tester);

      expect(tourOpen(), isFalse);
      expect(find.byType(EefHomeScreen), findsOneWidget,
          reason: 'le retour ferme la visite, pas le hub');
      expect(store.seen, isTrue);
      expect(store.writes, 1);
      expect(tourAnalytics.completedCalls.single.exit, 'skipped');
      expect(tourAnalytics.completedCalls.single.cardsSeen, 2);
    });

    testWidgets(
        '« Compris » à la dernière carte : terminée, quatre cartes vues',
        (tester) async {
      await pumpHub(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      expect(find.text('Étape 4 sur 4'), findsOneWidget);
      expect(find.text('Compris'), findsOneWidget);
      expect(find.text('Suivant'), findsNothing);

      await tester.tap(find.byKey(_nextKey));
      await settleBounded(tester);

      expect(tourOpen(), isFalse);
      expect(tourAnalytics.completedCalls.single.exit, 'finished');
      expect(tourAnalytics.completedCalls.single.cardsSeen, 4);
      expect(store.writes, 1);
    });

    testWidgets('un double tap sur « Compris » ne ferme qu\'UNE fois',
        (tester) async {
      await pumpHub(tester);
      await next(tester);
      await next(tester);
      await next(tester);

      // Deux activations sans cadre entre elles (un lecteur d'écran, un double
      // tap rapide) : toutes deux tombent sur le bouton encore là.
      final handle = tester.ensureSemantics();
      tester.semantics.tap(find.semantics.byLabel('Compris'));
      tester.semantics.tap(find.semantics.byLabel('Compris'));
      await settleBounded(tester);
      handle.dispose();

      expect(find.byType(EefHomeScreen), findsOneWidget,
          reason: 'un second pop aurait fermé le hub');
      expect(tourAnalytics.completedCalls, hasLength(1));
    });

    testWidgets('un glissement du doigt change de carte (PageView)',
        (tester) async {
      await pumpHub(tester);
      await tester.drag(find.byType(PageView), const Offset(-300, 0));
      await settleBounded(tester);

      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      expect(titleOnScreen(tester), _find.frTitle);
      await skip(tester);
      expect(tourAnalytics.completedCalls.single.cardsSeen, 2);
    });

    testWidgets('revenir en arrière ne diminue pas les cartes vues',
        (tester) async {
      await pumpHub(tester);
      await next(tester);
      await next(tester);
      await tester.drag(find.byType(PageView), const Offset(300, 0));
      await settleBounded(tester);
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
      await skip(tester);
      expect(tourAnalytics.completedCalls.single.cardsSeen, 3);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. UNE PANNE DU STOCKAGE VAUT « DÉJÀ VUE »
  // ═══════════════════════════════════════════════════════════════════════════

  group('le stockage en panne', () {
    testWidgets('lecture impossible : pas de visite, pas d\'exception',
        (tester) async {
      store.failRead = true;
      await pumpHub(tester);

      expect(tourOpen(), isFalse);
      expect(store.reads, 1);
      expect(store.writes, 0);
      expect(tourAnalytics.shownTriggers, isEmpty);
      expect(tester.takeException(), isNull);
      // Le hub, lui, est intact.
      expect(find.text('Trouver ma formation'), findsOneWidget);
    });

    testWidgets('écriture impossible : pas de visite (elle ne bouclerait pas)',
        (tester) async {
      store.failWrite = true;
      await pumpHub(tester);

      expect(tourOpen(), isFalse);
      expect(store.writes, 1);
      expect(tourAnalytics.shownTriggers, isEmpty);
      expect(tester.takeException(), isNull);

      // Et au hub suivant, toujours rien : jamais de boucle.
      await pumpHub(tester);
      expect(tourOpen(), isFalse);
      expect(tourAnalytics.shownTriggers, isEmpty);
    });

    testWidgets(
        'le VRAI magasin, valeur non booléenne sous la clé : pas de visite, '
        'pas d\'exception', (tester) async {
      EefTour.store = const SharedPreferencesEefTourStore();
      SharedPreferences.setMockInitialValues(
        <String, Object>{SharedPreferencesEefTourStore.key: 'oui'},
      );
      await seed(tester);
      // Le harnais ne doit pas avoir écrasé la valeur piégée.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.get(SharedPreferencesEefTourStore.key), 'oui');

      await pumpKpbScreen(
        tester,
        screen: const EefHomeScreen(),
        viewport: iphone14,
        routesShareMediaQuery: true,
      );

      expect(tourOpen(), isFalse);
      expect(tourAnalytics.shownTriggers, isEmpty);
      expect(tester.takeException(), isNull);
      expect(find.text('Trouver ma formation'), findsOneWidget);
    });

    testWidgets('le « ? » ne dépend pas du stockage : il rejoue quand même',
        (tester) async {
      store.failRead = true;
      store.failWrite = true;
      await pumpHub(tester);
      expect(tourOpen(), isFalse);

      await tester.tap(find.byKey(_replayKey));
      await settleBounded(tester);

      expect(tourOpen(), isTrue);
      expect(tester.takeException(), isNull);
      expect(tourAnalytics.shownTriggers, ['replay']);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. LE REJEU
  // ═══════════════════════════════════════════════════════════════════════════

  group('le rejeu par le « ? »', () {
    testWidgets(
        'le bouton existe dans la barre du hub : 48 dp, infobulle, sémantique',
        (tester) async {
      final handle = tester.ensureSemantics();
      store.seen = true;
      await pumpHub(tester);

      expect(find.byKey(_replayKey), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.byIcon(Icons.help_outline_rounded),
        ),
        findsOneWidget,
      );
      final size = tester.getSize(find.byKey(_replayKey));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
      expect(tester.widget<IconButton>(find.byKey(_replayKey)).tooltip,
          'Revoir la visite');
      final node = find.semantics.byLabel('Revoir la visite').evaluate();
      expect(node, isNotEmpty);
      expect(node.first.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets(
        'le « ? » rejoue la visite, sans toucher au drapeau, en « replay »',
        (tester) async {
      store.seen = true;
      await pumpHub(tester);
      expect(tourOpen(), isFalse);

      await tester.tap(find.byKey(_replayKey));
      await settleBounded(tester);

      expect(tourOpen(), isTrue);
      expect(titleOnScreen(tester), _welcome.frTitle);
      expect(tourAnalytics.shownTriggers, ['replay']);
      expect(store.writes, 0);
      expect(store.reads, 1, reason: 'seule la lecture de l\'ouverture');
      await skip(tester);
      expect(store.writes, 0);
      expect(store.seen, isTrue);
      expect(tourAnalytics.completedCalls.single.exit, 'skipped');
    });

    testWidgets(
        'deux activations d\'affilée du « ? » n\'ouvrent QU\'UNE feuille',
        (tester) async {
      final handle = tester.ensureSemantics();
      store.seen = true;
      await pumpHub(tester);

      tester.semantics.tap(find.semantics.byLabel('Revoir la visite'));
      tester.semantics.tap(find.semantics.byLabel('Revoir la visite'));
      await settleBounded(tester);

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(tourAnalytics.shownTriggers, ['replay']);
      handle.dispose();
    });

    testWidgets('rejouée, puis terminée : toujours rien d\'écrit',
        (tester) async {
      store.seen = true;
      await pumpHub(tester);
      await tester.tap(find.byKey(_replayKey));
      await settleBounded(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.byKey(_nextKey));
      await settleBounded(tester);

      expect(store.writes, 0);
      expect(tourAnalytics.completedCalls.single.exit, 'finished');
      expect(tourAnalytics.completedCalls.single.cardsSeen, 4);
    });

    testWidgets(
        'rejouée alors que la première visite n\'a jamais eu lieu : le '
        'drapeau reste intact', (tester) async {
      // Lecture en panne : la première ouverture n'a rien montré.
      store.failRead = true;
      await pumpHub(tester);
      store.failRead = false;
      await tester.tap(find.byKey(_replayKey));
      await settleBounded(tester);
      await skip(tester);

      expect(store.writes, 0);
      expect(store.seen, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. LES ÉTAPES
  // ═══════════════════════════════════════════════════════════════════════════

  group('les étapes', () {
    testWidgets('quatre étapes, dans l\'ordre, avec les textes du plan (FR)',
        (tester) async {
      await pumpHub(tester);
      final seen = await walk(tester);

      expect(seen, [
        for (final step in _allSteps) (step.frTitle, step.frBody),
      ]);
    });

    testWidgets('quatre étapes, dans l\'ordre, avec les textes du plan (EN)',
        (tester) async {
      await pumpHub(tester, locale: const Locale('en'));
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      expect(find.text('Next'), findsOneWidget);
      final seen = await walk(tester);

      expect(seen, [
        for (final step in _allSteps) (step.enTitle, step.enBody),
      ]);
      expect(find.text('Step 4 of 4'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });

    testWidgets(
        'outils IA désactivés : TROIS étapes, « Prépare tes documents » omise',
        (tester) async {
      AppConfig.aiToolsEnabledOverride = false;
      await pumpHub(tester);

      expect(find.text('Étape 1 sur 3'), findsOneWidget);
      final seen = await walk(tester);
      expect(seen.map((e) => e.$1), [
        _welcome.frTitle,
        _find.frTitle,
        _bubble.frTitle,
      ]);
      expect(find.text('Étape 3 sur 3'), findsOneWidget);
      await tester.tap(find.byKey(_nextKey));
      await settleBounded(tester);
      expect(tourAnalytics.completedCalls.single.cardsSeen, 3);
      expect(tourAnalytics.completedCalls.single.exit, 'finished');
    });

    testWidgets('bulle éteinte (eefHelpBubble faux) : l\'étape bulle est omise',
        (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = false;
      await pumpHub(tester);

      expect(find.text('Étape 1 sur 3'), findsOneWidget);
      final seen = await walk(tester);
      expect(seen.map((e) => e.$1), [
        _welcome.frTitle,
        _find.frTitle,
        _documents.frTitle,
      ]);
      // Aucune carte ne décrit un bouton vert qui n'existe pas.
      expect(seen.any((e) => e.$2.contains('bouton vert')), isFalse);
    });

    testWidgets('bulle éteinte ET outils IA masqués : deux étapes',
        (tester) async {
      AppConfig.eefHelpBubbleEnabledOverride = false;
      AppConfig.aiToolsEnabledOverride = false;
      await pumpHub(tester);

      expect(find.text('Étape 1 sur 2'), findsOneWidget);
      final seen = await walk(tester);
      expect(seen.map((e) => e.$1), [_welcome.frTitle, _find.frTitle]);
    });

    testWidgets(
        'la bulle est décrite seulement si elle est réellement affichée',
        (tester) async {
      // L'espace ouvert mais la bulle fermée côté serveur : le test précédent.
      // Ici : bulle ouverte, l'étape existe ET la bulle est à l'écran.
      await pumpHub(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      expect(titleOnScreen(tester), _bubble.frTitle);
      await skip(tester);
      expect(find.byKey(_bubbleKey), findsOneWidget);
    });

    testWidgets('la dernière carte dit « Compris » ; les autres « Suivant »',
        (tester) async {
      await pumpHub(tester);
      for (var i = 1; i <= 3; i++) {
        expect(find.text('Étape $i sur 4'), findsOneWidget);
        expect(find.text('Suivant'), findsOneWidget);
        expect(find.text('Compris'), findsNothing);
        await next(tester);
      }
      expect(find.text('Compris'), findsOneWidget);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. UN COMPTE DONT LE PAYS EST SUSPENDU
  // ═══════════════════════════════════════════════════════════════════════════

  group('compte suspendu', () {
    testWidgets('l\'étape 1 est NEUTRE (FR), les trois autres sont identiques',
        (tester) async {
      await pumpHub(tester, country: 'Niger');

      expect(tourOpen(), isTrue);
      final seen = await walk(tester);
      expect(seen, [
        (_welcome.frTitle, _welcomeNeutralFr),
        (_find.frTitle, _find.frBody),
        (_documents.frTitle, _documents.frBody),
        (_bubble.frTitle, _bubble.frBody),
      ]);
    });

    testWidgets('l\'étape 1 est NEUTRE (EN)', (tester) async {
      await pumpHub(tester, country: 'Niger', locale: const Locale('en'));

      final seen = await walk(tester);
      expect(seen.first, (_welcome.enTitle, _welcomeNeutralEn));
      expect(seen.skip(1).toList(), [
        (_find.enTitle, _find.enBody),
        (_documents.enTitle, _documents.enBody),
        (_bubble.enTitle, _bubble.enBody),
      ]);
    });

    for (final locale in ['fr', 'en']) {
      testWidgets(
          'aucun mot de dossier/candidature/démarrer, aucun pays, sur TOUTES '
          'les cartes ($locale)', (tester) async {
        await pumpHub(tester, country: 'Niger', locale: Locale(locale));

        final texts = [
          for (final (title, body) in await walk(tester)) '$title $body',
        ];
        for (final text in texts) {
          expect(_openAFileWording.hasMatch(_fold(text)), isFalse,
              reason: text);
          expect(_openAFileWording.hasMatch(text), isFalse, reason: text);
          expect(_countryWording.hasMatch(text), isFalse, reason: text);
        }
      });
    }

    testWidgets('un compte NON suspendu garde la variante standard',
        (tester) async {
      await pumpHub(tester, country: 'Sénégal');
      expect(bodyOnScreen(tester), _welcome.frBody);
      expect(bodyOnScreen(tester), contains('candidature'));
    });

    testWidgets('la mesure ne trahit pas la suspension', (tester) async {
      await pumpHub(tester, country: 'Niger');
      await next(tester);
      await skip(tester);

      expect(tourAnalytics.shownTriggers, ['first_open']);
      expect(tourAnalytics.completedCalls.single.exit, 'skipped');
      expect(tourAnalytics.completedCalls.single.cardsSeen, 2);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. JAMAIS D'ÉCOLES PRIVÉES
  // ═══════════════════════════════════════════════════════════════════════════

  group('les écoles privées', () {
    for (final open in [false, true]) {
      for (final locale in ['fr', 'en']) {
        testWidgets(
            'la visite n\'en parle jamais (interrupteur ${open ? 'ouvert' : 'fermé'}, '
            '$locale)', (tester) async {
          AppConfig.eefPrivateSchoolsEnabledOverride = open;
          await pumpHub(tester, locale: Locale(locale));

          final texts = [
            for (final (title, body) in await walk(tester)) '$title $body',
          ];
          expect(texts, hasLength(4));
          for (final text in texts) {
            expect(_privateSchoolWording.hasMatch(text), isFalse, reason: text);
          }
        });
      }
    }
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 9. L'ACCESSIBILITÉ
  // ═══════════════════════════════════════════════════════════════════════════

  group('accessibilité', () {
    testWidgets('route nommée, titre en en-tête, compteur en région vive',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);

      // La route porte un nom.
      final named = find.semantics.byLabel("Visite de l'espace").evaluate();
      expect(named, isNotEmpty);
      expect(named.any((n) => n.flagsCollection.namesRoute), isTrue);

      // Le titre de la carte est un en-tête.
      final title = tester.getSemantics(inPage(_welcome.frTitle));
      expect(title.flagsCollection.isHeader, isTrue);

      // Le compteur est une région vive : l'annonce « Étape 2 sur 4 » se fait
      // d'elle-même quand on change de carte.
      final counter = tester.getSemantics(find.text('Étape 1 sur 4'));
      expect(counter.label, 'Étape 1 sur 4');
      expect(counter.flagsCollection.isLiveRegion, isTrue);

      await next(tester);
      final counter2 = tester.getSemantics(find.text('Étape 2 sur 4'));
      expect(counter2.flagsCollection.isLiveRegion, isTrue);
      handle.dispose();
    });

    testWidgets('« Passer » et « Suivant » sont des boutons nommés, à 48 dp',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);

      for (final entry in {
        'Passer': _skipKey,
        'Suivant': _nextKey,
      }.entries) {
        final nodes = find.semantics.byLabel(entry.key).evaluate();
        expect(nodes, isNotEmpty, reason: entry.key);
        expect(nodes.any((n) => n.flagsCollection.isButton), isTrue,
            reason: entry.key);
        final size = tester.getSize(find.byKey(entry.value));
        expect(size.height, greaterThanOrEqualTo(48), reason: entry.key);
        expect(size.width, greaterThanOrEqualTo(48), reason: entry.key);
      }
      handle.dispose();
    });

    testWidgets(
        'le focus lecteur d\'écran est confiné à la feuille, puis rendu',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);

      // Derrière la feuille, le hub n'est pas exposé au lecteur d'écran.
      expect(find.semantics.byLabel(RegExp('Trouver ma formation')).evaluate(),
          isEmpty,
          reason:
              'le hub reste atteignable au lecteur d\'écran sous la feuille');

      await skip(tester);
      // Rendu au hub une fois la feuille fermée.
      expect(find.semantics.byLabel(RegExp('Trouver ma formation')).evaluate(),
          isNotEmpty);
      handle.dispose();
    });

    testWidgets('les points indicateurs sont exclus de la sémantique',
        (tester) async {
      await pumpHub(tester);

      final dots = find.byKey(const ValueKey('eef-tour-dots'));
      expect(dots, findsOneWidget);
      final exclude = tester.widget<ExcludeSemantics>(dots);
      expect(exclude.excluding, isTrue);
      // Quatre points, un par carte.
      expect(
        find.descendant(of: dots, matching: find.byType(DecoratedBox)),
        findsNWidgets(4),
      );
    });

    testWidgets(
        'une carte lue par le lecteur d\'écran ne répète pas les jauges',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpHub(tester);

      // Les pages « jauge » cachées (qui donnent sa hauteur à la feuille) ne
      // sont pas exposées : le titre n'est lu qu'UNE fois.
      expect(
        find.semantics.byLabel(_welcome.frTitle).evaluate().length,
        1,
      );
      handle.dispose();
    });

    testWidgets('« réduire les animations » : la carte change sans glisser',
        (tester) async {
      await pumpHub(tester, disableAnimations: true);

      await tester.tap(find.byKey(_nextKey));
      await tester.pump();
      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(controller.page, 1.0,
          reason: 'jumpToPage : la page est atteinte au premier cadre');
      expect(find.text('Étape 2 sur 4'), findsOneWidget);
    });

    testWidgets('animations permises : la carte GLISSE (animateToPage)',
        (tester) async {
      await pumpHub(tester);

      await tester.tap(find.byKey(_nextKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final controller =
          tester.widget<PageView>(find.byType(PageView)).controller!;
      expect(controller.page, greaterThan(0.0));
      expect(controller.page, lessThan(1.0),
          reason: 'le glissement est en cours, pas un saut');
      await settleBounded(tester);
      expect(controller.page, 1.0);
    });

    testWidgets('aucune minuterie : la visite s\'immobilise', (tester) async {
      await pumpHub(tester);
      // `pumpAndSettle` rend la main seulement s'il ne reste ni animation ni
      // image planifiée ; le test échoue de lui-même sur une `Timer` pendante.
      await tester.pumpAndSettle(const Duration(seconds: 1));
      expect(tourOpen(), isTrue);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 10. LA GÉOMÉTRIE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la géométrie', () {
    testWidgets(
        'texte ×1,3 sur 320×568 : ni ellipse, ni débordement, tout le texte est '
        'ATTEIGNABLE en faisant défiler, les boutons restent à l\'écran',
        (tester) async {
      final report = await pumpHub(tester, viewport: _se, textScale: 1.3);
      expect(report.otherErrors, isEmpty);
      expect(report.overflows, isEmpty);

      for (var i = 0; i < 4; i++) {
        expect(tester.takeException(), isNull);
        expect(truncatedTexts(tester), isEmpty, reason: 'carte ${i + 1}');
        expectButtonsOnScreen(tester, _se, reason: 'carte ${i + 1}');
        expect(cardViewRect(tester).height, greaterThanOrEqualTo(_minCardView),
            reason: 'hauteur utile de la zone des cartes, carte ${i + 1}');

        // Le texte peut dépasser la zone visible (il y défile) ; il ne doit
        // jamais être INATTEIGNABLE : un glissement vertical amène son bas
        // dans la zone. C'est ce qui porte la phrase de non-affiliation.
        await tester.drag(find.byType(PageView), const Offset(0, -300));
        await tester.pump();
        final body = tester.getRect(find.descendant(
            of: find.byType(PageView), matching: find.byKey(_bodyKey)));
        final view = cardViewRect(tester);
        expect(body.bottom, lessThanOrEqualTo(view.bottom + 0.5),
            reason: 'le bas du texte reste hors de portée, carte ${i + 1}');
        await tester.drag(find.byType(PageView), const Offset(0, 300));
        await tester.pump();

        if (i < 3) await next(tester);
      }
    });

    testWidgets(
        'texte ×1,3 sur 360×640 : la zone des cartes garde sa hauteur utile',
        (tester) async {
      final report =
          await pumpHub(tester, viewport: _android640, textScale: 1.3);
      expect(report.otherErrors, isEmpty);
      expect(report.overflows, isEmpty);
      for (var i = 0; i < 4; i++) {
        expect(cardViewRect(tester).height, greaterThanOrEqualTo(_minCardView),
            reason: 'carte ${i + 1}');
        expectButtonsOnScreen(tester, _android640, reason: 'carte ${i + 1}');
        if (i < 3) await next(tester);
      }
    });

    testWidgets('les libellés des boutons passent à la ligne, sans ellipse',
        (tester) async {
      await pumpHub(tester, viewport: _se, textScale: 1.3);
      for (final key in [_skipKey, _nextKey]) {
        final text = tester.widget<Text>(
            find.descendant(of: find.byKey(key), matching: find.byType(Text)));
        expect(text.overflow, isNot(TextOverflow.ellipsis));
        expect(text.maxLines, isNull);
        expect(text.softWrap, isNot(false));
      }
    });

    for (final viewport in _matrixViewports) {
      for (final scale in [1.0, 1.3]) {
        for (final locale in ['fr', 'en']) {
          for (final country in ['Sénégal', 'Niger']) {
            testWidgets(
                'matrice : ${viewport.id} ×$scale $locale $country — quatre '
                'cartes sans débordement ni troncature', (tester) async {
              final report = await pumpHub(
                tester,
                viewport: viewport,
                textScale: scale,
                locale: Locale(locale),
                country: country,
              );
              expect(report.otherErrors, isEmpty);
              expect(report.overflows, isEmpty);
              expect(tourOpen(), isTrue);

              for (var i = 0; i < 4; i++) {
                expect(tester.takeException(), isNull);
                expect(truncatedTexts(tester), isEmpty,
                    reason: 'carte ${i + 1}');
                // La feuille est bornée à 480 dp (un iPad ne tire pas 768 dp).
                final sheet = tester.getSize(find.byKey(_sheetKey));
                expect(sheet.width, lessThanOrEqualTo(480.5));
                expect(sheet.width, lessThanOrEqualTo(viewport.size.width));
                expectButtonsOnScreen(tester, viewport,
                    reason: 'carte ${i + 1}');
                // Sur les petits écrans (où le plafond de 9/16 mordrait), la
                // zone des cartes garde sa hauteur utile.
                if (viewport.size.height <= 640) {
                  expect(cardViewRect(tester).height,
                      greaterThanOrEqualTo(_minCardView),
                      reason: 'hauteur utile de la zone des cartes, '
                          'carte ${i + 1}');
                }
                if (i < 3) await next(tester);
              }
            });
          }
        }
      }
    }

    testWidgets('l\'iPad : la feuille est bornée à 480 dp', (tester) async {
      await pumpHub(tester, viewport: _ipad);
      final width = tester.getSize(find.byKey(_sheetKey)).width;
      expect(width, lessThanOrEqualTo(480.5));
      expect(width, greaterThan(300));
    });

    testWidgets(
        'la feuille ne tire pas tout l\'écran : le hub se voit derrière',
        (tester) async {
      await pumpHub(tester, viewport: iphone14);
      final sheet = tester.getRect(find.byKey(_sheetKey));
      expect(sheet.height, lessThan(iphone14.size.height * 0.75));
      expect(sheet.bottom, greaterThan(iphone14.size.height * 0.5));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 11. LA BULLE, APRÈS LA VISITE
  // ═══════════════════════════════════════════════════════════════════════════

  group('l\'entrée de la bulle après la visite', () {
    double scale(WidgetTester tester) =>
        tester.widget<ScaleTransition>(find.byKey(_entranceKey)).scale.value;

    testWidgets('au repos, la bulle est à sa taille (aucune pulsation)',
        (tester) async {
      store.seen = true;
      await pumpHub(tester);

      expect(scale(tester), 1.0);
      expect(find.byKey(_bubbleKey), findsOneWidget);
      // Aucune étiquette ni pastille sur la bulle.
      expect(find.byType(Badge), findsNothing);
    });

    // Le test précédent lit l'échelle APRÈS le settle du harnais : une entrée
    // jouée à l'ouverture a déjà fini et il ne la voit pas. Celui-ci regarde
    // chaque cadre, sans settle, dès que la lecture du drapeau rend la main.
    testWidgets('visite déjà vue : AUCUNE entrée à l\'ouverture du hub',
        (tester) async {
      store.seen = true;
      store.readGate = Completer<void>();
      await pumpHub(tester);
      expect(scale(tester), 1.0);

      store.readGate!.complete();
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(scale(tester), 1.0, reason: 'cadre ${i + 1}');
      }
      expect(tourOpen(), isFalse);
    });

    testWidgets('stockage en panne : AUCUNE entrée à l\'ouverture du hub',
        (tester) async {
      store.failWrite = true;
      store.readGate = Completer<void>();
      await pumpHub(tester);
      expect(scale(tester), 1.0);

      store.readGate!.complete();
      await tester.pump();
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(scale(tester), 1.0, reason: 'cadre ${i + 1}');
      }
      expect(tourOpen(), isFalse);
    });

    testWidgets('visite fermée : UNE entrée en échelle, de 0,8 à 1,0',
        (tester) async {
      await pumpHub(tester);
      expect(tourOpen(), isTrue);
      await tester.tap(find.byKey(_skipKey));
      await tester.pump();
      // La feuille se referme ; l'entrée démarre à sa fin.
      var started = false;
      var minSeen = 1.0;
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        final v = scale(tester);
        if (v < 1.0) started = true;
        if (v < minSeen) minSeen = v;
      }
      expect(started, isTrue, reason: 'la bulle n\'a pas fait son entrée');
      expect(minSeen, greaterThanOrEqualTo(0.8));
      expect(minSeen, lessThan(0.95));
      await settleBounded(tester);
      expect(scale(tester), 1.0);

      // UNE seule : rien ne la relance.
      await tester.pump(const Duration(seconds: 2));
      expect(scale(tester), 1.0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    });

    testWidgets('« réduire les animations » : aucune animation',
        (tester) async {
      await pumpHub(tester, disableAnimations: true);
      await tester.tap(find.byKey(_skipKey));
      await tester.pump();
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 25));
        expect(scale(tester), 1.0);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 12. LA MESURE
  // ═══════════════════════════════════════════════════════════════════════════

  group('la mesure', () {
    late List<_Emitted> emitted;

    setUp(() {
      emitted = <_Emitted>[];
      AnalyticsService.instance.logEventSink =
          (name, params) async => emitted.add(_Emitted(name, params));
      // La vraie mesure, celle du service : on lit ce qui partirait vers
      // Firebase. `resetForTest` la remet ; le faux magasin est reposé.
      EefTour.resetForTest();
      EefTour.store = store;
    });

    List<_Emitted> tourEvents() =>
        emitted.where((e) => e.name.startsWith('eef_tour_')).toList();

    testWidgets(
        '`eef_tour_shown` : la seule propriété `tour_trigger` (first_open)',
        (tester) async {
      await pumpHub(tester);

      final shown = tourEvents().where((e) => e.name == 'eef_tour_shown');
      expect(shown, hasLength(1));
      expect(shown.single.params, {'tour_trigger': 'first_open'});
    });

    testWidgets(
        '`eef_tour_completed` : `tour_exit` et `tour_cards_seen` (un ENTIER)',
        (tester) async {
      await pumpHub(tester);
      await next(tester);
      await next(tester);
      await skip(tester);

      final done = tourEvents().where((e) => e.name == 'eef_tour_completed');
      expect(done, hasLength(1));
      expect(
          done.single.params, {'tour_exit': 'skipped', 'tour_cards_seen': 3});
      expect(done.single.params['tour_cards_seen'], isA<int>());
      expect(done.single.params.keys.toSet(), {'tour_exit', 'tour_cards_seen'});
    });

    testWidgets('terminée : `finished`, et un rejeu dit `replay`',
        (tester) async {
      store.seen = true;
      await pumpHub(tester);
      await tester.tap(find.byKey(_replayKey));
      await settleBounded(tester);
      await next(tester);
      await next(tester);
      await next(tester);
      await tester.tap(find.byKey(_nextKey));
      await settleBounded(tester);

      final events = tourEvents();
      expect(
          events.map((e) => e.name), ['eef_tour_shown', 'eef_tour_completed']);
      expect(events[0].params, {'tour_trigger': 'replay'});
      expect(events[1].params, {'tour_exit': 'finished', 'tour_cards_seen': 4});
    });

    testWidgets('compte suspendu : EXACTEMENT les mêmes propriétés',
        (tester) async {
      await pumpHub(tester, country: 'Niger');
      await skip(tester);

      final events = tourEvents();
      expect(events[0].params, {'tour_trigger': 'first_open'});
      expect(events[1].params, {'tour_exit': 'skipped', 'tour_cards_seen': 1});
      // Aucune valeur ne contient un pays ni un mot qui désigne la suspension.
      for (final e in events) {
        for (final value in e.params.values) {
          expect('$value',
              isNot(matches(RegExp('niger|suspend', caseSensitive: false))));
        }
      }
    });

    testWidgets('aucune mesure sur le stockage en panne', (tester) async {
      store.failRead = true;
      await pumpHub(tester);
      expect(tourEvents(), isEmpty);
    });

    test('les fonctions de paramètres du service sont fermées', () {
      expect(
        AnalyticsService.eefTourShownParams(trigger: 'replay'),
        {'tour_trigger': 'replay'},
      );
      expect(
        AnalyticsService.eefTourCompletedParams(exit: 'finished', cardsSeen: 4),
        {'tour_exit': 'finished', 'tour_cards_seen': 4},
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 13. LES TRADUCTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  group('les traductions', () {
    final keys = AppTranslations().keys;

    Set<String> tourKeys(String locale) =>
        keys[locale]!.keys.where((k) => k.startsWith('eef_tour_')).toSet();

    test('chaque clé existe en français ET en anglais, non vide', () {
      for (final locale in ['fr', 'en']) {
        for (final key in _tourKeys) {
          expect(keys[locale]![key], isNotNull,
              reason: '$key manque ($locale)');
          expect(keys[locale]![key]!.trim(), isNotEmpty, reason: key);
        }
      }
    });

    test(
        'parité : exactement les mêmes clés `eef_tour_*` en FR et EN, et '
        'aucune de plus', () {
      expect(tourKeys('fr'), tourKeys('en'));
      expect(tourKeys('fr'), _tourKeys.toSet());
    });

    test('FR et EN diffèrent (aucune traduction oubliée)', () {
      for (final key in _tourKeys) {
        expect(keys['en']![key], isNot(keys['fr']![key]), reason: key);
      }
    });

    test('les textes sont ceux du plan, mot pour mot', () {
      final fr = keys['fr']!;
      final en = keys['en']!;
      expect(fr['eef_tour_title'], "Visite de l'espace");
      expect(en['eef_tour_title'], 'Space tour');
      expect(fr['eef_tour_counter'], 'Étape @n sur @total');
      expect(en['eef_tour_counter'], 'Step @n of @total');
      expect(fr['eef_tour_skip'], 'Passer');
      expect(en['eef_tour_skip'], 'Skip');
      expect(fr['eef_tour_next'], 'Suivant');
      expect(en['eef_tour_next'], 'Next');
      expect(fr['eef_tour_done'], 'Compris');
      expect(en['eef_tour_done'], 'Got it');
      expect(fr['eef_tour_replay'], 'Revoir la visite');
      expect(en['eef_tour_replay'], 'Replay the tour');
      for (var i = 0; i < _allSteps.length; i++) {
        final n = i + 1;
        expect(fr['eef_tour_${n}_title'], _allSteps[i].frTitle);
        expect(fr['eef_tour_${n}_body'], _allSteps[i].frBody);
        expect(en['eef_tour_${n}_title'], _allSteps[i].enTitle);
        expect(en['eef_tour_${n}_body'], _allSteps[i].enBody);
      }
      expect(fr['eef_tour_1_neutral_body'], _welcomeNeutralFr);
      expect(en['eef_tour_1_neutral_body'], _welcomeNeutralEn);
    });

    test('le compteur porte @n et @total, et RIEN d\'autre à remplacer', () {
      for (final locale in ['fr', 'en']) {
        final value = keys[locale]!['eef_tour_counter']!;
        expect(value, contains('@n'));
        expect(value, contains('@total'));
        expect(value.replaceAll('@total', '').replaceAll('@n', ''),
            isNot(contains('@')));
      }
    });

    test('aucun texte de la visite ne chiffre, ne promet ni ne se déguise', () {
      final promise = RegExp(
        r'(admission|visa|bourse|scholarship)s?\s+(garanti|assur|certain|'
        r'guaranteed|assured|certain)|vous obtiendrez|tu obtiendras|'
        r'you will (get|obtain)|100\s?%|garanti|guarantee',
        caseSensitive: false,
      );
      final price = RegExp(
        r'€|\bfcfa\b|\bxof\b|\bfrancs?\b|\bprix\b|\bprice\b|gratuit|\bfree\b|'
        r'\beuros?\b|\btarif|\d',
        caseSensitive: false,
      );
      final delay = RegExp(
        r'\b(en|sous|within|in)\s+\d|\bjours?\b|\bdays?\b|\bheures?\b|\bhours?\b|'
        r'\brapide|\bquickly\b|\bfast\b|\bimmédiat|\binstant',
        caseSensitive: false,
      );
      for (final locale in ['fr', 'en']) {
        for (final key in _tourKeys) {
          final value = keys[locale]![key]!;
          expect(promise.hasMatch(value), isFalse, reason: '$key ($locale)');
          expect(price.hasMatch(value), isFalse, reason: '$key ($locale)');
          expect(delay.hasMatch(value), isFalse, reason: '$key ($locale)');
        }
      }
    });

    test('aucun « Campus France » dans un titre — ni nulle part', () {
      final operator = RegExp(r'campus[\s_-]*france', caseSensitive: false);
      for (final locale in ['fr', 'en']) {
        for (final key in _tourKeys) {
          expect(operator.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale) nomme l\'opérateur de l\'État');
        }
        for (final key in _tourKeys.where((k) => k.endsWith('_title'))) {
          expect(keys[locale]![key]!.toLowerCase(), isNot(contains('campus')));
        }
      }
    });

    test('aucun pays, ni de remplacement, dans les textes', () {
      for (final locale in ['fr', 'en']) {
        for (final key in _tourKeys) {
          expect(_countryWording.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale)');
        }
      }
    });

    test('aucune mention d\'école privée dans aucune clé', () {
      for (final locale in ['fr', 'en']) {
        for (final key in _tourKeys) {
          final value = keys[locale]![key]!;
          expect(_privateSchoolWording.hasMatch(value), isFalse,
              reason: '$key ($locale)');
          expect(_privateSchoolWording.hasMatch(_fold(value)), isFalse,
              reason: '$key ($locale) sans accents');
        }
      }
    });

    test(
        'le jeu NEUTRE : ni dossier, ni candidature, ni démarrer, ni start, '
        'ni file, ni review — accents ou non', () {
      const neutralSet = <String>[
        'eef_tour_1_neutral_body',
        'eef_tour_2_body',
        'eef_tour_3_body',
        'eef_tour_4_body',
        // Partagés avec le jeu standard et montrés aussi aux comptes suspendus.
        'eef_tour_1_title',
        'eef_tour_2_title',
        'eef_tour_3_title',
        'eef_tour_4_title',
        'eef_tour_title',
        'eef_tour_counter',
        'eef_tour_skip',
        'eef_tour_next',
        'eef_tour_done',
        'eef_tour_replay',
      ];
      for (final locale in ['fr', 'en']) {
        for (final key in neutralSet) {
          final value = keys[locale]![key]!;
          expect(_openAFileWording.hasMatch(value), isFalse,
              reason: '$key ($locale) : $value');
          expect(_openAFileWording.hasMatch(_fold(value)), isFalse,
              reason: '$key ($locale) sans accents : $value');
        }
      }
      // Le jeu standard, lui, a le droit de dire « candidature ».
      expect(keys['fr']!['eef_tour_1_body'], contains('candidature'));
    });

    test('le français est accentué (pas de « Etape », « ecole », « equipe »)',
        () {
      final fr = keys['fr']!;
      expect(fr['eef_tour_counter'], contains('Étape'));
      expect(fr['eef_tour_4_title'], contains('Écris'));
      expect(fr['eef_tour_4_body'], contains('équipe'));
      expect(fr['eef_tour_1_title'], contains('Études'));
      final unaccented = RegExp(
        r'\b(etape|etudes?|ecris|ecole|equipe|demarche|deja|procedure|'
        r'universites?|accompagnement\s+prive|etat|ete)\b',
        caseSensitive: false,
      );
      for (final key in _tourKeys) {
        expect(unaccented.hasMatch(fr[key]!), isFalse,
            reason: '$key : français sans accents : ${fr[key]}');
      }
    });

    for (final locale in ['fr', 'en']) {
      testWidgets(
          'aucune clé brute à l\'écran, sur les quatre cartes ($locale)',
          (tester) async {
        await pumpHub(tester, locale: Locale(locale));
        for (var i = 0; i < 4; i++) {
          expect(rawTranslationKeysOnScreen(tester), isEmpty,
              reason: 'carte ${i + 1}');
          if (i < 3) await next(tester);
        }
        await skip(tester);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });
    }

    testWidgets('aucune clé brute pour un compte suspendu (1re carte neutre)',
        (tester) async {
      await pumpHub(tester, country: 'Niger');
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      expect(bodyOnScreen(tester), _welcomeNeutralFr);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // 14. LES GARDES DE SOURCE
  // ═══════════════════════════════════════════════════════════════════════════

  group('gardes de source', () {
    late String tour;
    late String home;

    setUpAll(() {
      tour = File('lib/app/features/etudes_en_france/eef_tour.dart')
          .readAsStringSync();
      home = File('lib/app/features/etudes_en_france/eef_home_screen.dart')
          .readAsStringSync();
    });

    /// Le code sans ses commentaires `//` (les commentaires disent POURQUOI on
    /// n'utilise pas telle chose : ils la nomment).
    String code(String source) => source
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .join('\n');

    test('aucune minuterie', () {
      final c = code(tour);
      expect(c, isNot(contains('Timer')));
      expect(c, isNot(contains('Future.delayed')));
    });

    test('ni KpbButton (il coupe avec une ellipse), ni le diaporama de départ',
        () {
      final c = code(tour);
      expect(c, isNot(contains('KpbButton')));
      expect(c, isNot(contains('intro_slideshow')));
      expect(c, isNot(contains('Get.offAll')));
      expect(c, contains('FilledButton'));
      expect(c, contains('TextButton'));
    });

    test('aucune chaîne en dur : tout passe par une clé de traduction', () {
      final c = code(tour);
      for (final literal in [
        'Passer',
        'Suivant',
        'Compris',
        'Étape',
        'Skip',
        'Got it',
        'Revoir',
        'Bienvenue',
      ]) {
        expect(c, isNot(contains("'$literal")), reason: literal);
        expect(c, isNot(contains('"$literal')), reason: literal);
      }
    });

    test('le diaporama de départ et la ligne de profil ne sont pas touchés',
        () {
      expect(code(home), isNot(contains('intro_slideshow')));
      expect(code(home), isNot(contains('hasSeenIntro')));
    });

    test('le hub déclenche la visite depuis initState, après le premier cadre',
        () {
      final c = code(home);
      expect(c, contains('addPostFrameCallback'));
      expect(c, contains('EefTour.showIfFirstOpen'));
      expect(c, contains('EefTour.show('));
    });

    test('la visite est branchée sur le hub réel seulement', () {
      for (final file in [
        'eef_teaser_screen.dart',
        'eef_students_only_screen.dart',
        'eef_entry.dart',
        'eef_catalog_screen.dart',
      ]) {
        final source =
            File('lib/app/features/etudes_en_france/$file').readAsStringSync();
        expect(source, isNot(contains('EefTour')), reason: file);
      }
    });
  });
}
