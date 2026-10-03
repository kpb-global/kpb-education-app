// Les déclencheurs d'aide DU CATALOGUE (build 55), montés dans l'écran réel :
//
//   1. un bouton « Demander de l'aide » sous chaque formation ;
//   2. une ligne « Tu hésites entre ces formations ? » quand un filtre est posé,
//      qui ne s'empile jamais avec la ligne de procédure (Aide-7).
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · le message prérempli nomme la formation (intitulé, université, ville) ou
//     les filtres choisis, et RIEN d'autre de personnel ;
//   · une seule ligne d'aide à la fois sous les filtres, et au plus UNE carte
//     pleine par écran (Aide-9) ;
//   · un compte dont le pays est suspendu voit les mêmes déclencheurs, au libellé
//     et au message NEUTRES, et la règle de non-empilement vaut pour lui aussi ;
//   · la mesure ne porte ni intitulé, ni université, ni ville, ni libellé de
//     filtre ;
//   · rien ne déborde à 360 dp × 1,3, en français comme en anglais ; le texte est
//     lisible (>= 4,5:1) en clair et en sombre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_line.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/pixel_contrast.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

/// Ce que dirait une invitation à ouvrir un dossier : jamais dans un texte
/// montré à un compte suspendu (même garde que eef_help_card_test.dart).
final _openAFileWording = RegExp(
  r'dossier|d[ée]marrer|campus\s*france|\bstart\b|\bfile\b|\breview\b',
  caseSensitive: false,
);

Map<String, dynamic> _program(
  String id, {
  String name = 'Licence Droit',
  Object? institution,
  Object? procedureType = 'eef',
  Object? campusCity = 'Lyon',
  String cycle = 'licence3',
}) =>
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
      'procedureType': procedureType,
      'cycle': cycle,
      'campusCity': campusCity,
      'institution': institution,
    };

Map<String, dynamic> _university() => <String, dynamic>{
      'id': 'eef-univ-x',
      'name': {
        'fr': 'Université Claude Bernard',
        'en': 'Claude Bernard University'
      },
      'acronym': 'UCBL',
      'location': {'fr': 'Villeurbanne, France', 'en': 'Villeurbanne, France'},
    };

/// Les facettes que le serveur sert : un peu de tout, pour que chaque famille
/// ait des valeurs à cocher.
Map<String, dynamic> _facets() => <String, dynamic>{
      'cycle': [
        {'value': 'licence1', 'count': 3112},
        {'value': 'master', 'count': 4210},
      ],
      'fieldId': [
        {'value': 'd07', 'count': 897},
        {'value': 'd01', 'count': 638},
        {'value': 'd02', 'count': 600},
      ],
      'campusCity': [
        {'value': 'Paris', 'count': 727},
        {'value': 'Toulouse', 'count': 271},
        {'value': 'Montpellier', 'count': 258},
        {'value': 'Lyon', 'count': 190},
        {'value': 'Nice', 'count': 142},
      ],
      'procedureType': [
        {'value': 'parcoursup', 'count': 3},
        {'value': 'eef', 'count': 9},
        {'value': 'dap_blanche', 'count': 5},
        {'value': 'dap_jaune', 'count': 2},
      ],
    };

Map<String, dynamic> _page(
  List<Map<String, dynamic>> items, {
  int? total,
  bool hasMore = false,
  String? nextCursor,
  bool? catalogPublished,
  Map<String, dynamic>? facets,
}) =>
    <String, dynamic>{
      'items': items,
      'total': total ?? items.length,
      'page': <String, dynamic>{
        'limit': 20,
        'hasMore': hasMore,
        'nextCursor': nextCursor,
      },
      'facets': facets ?? _facets(),
      'facetsTruncated': <String>[],
      if (catalogPublished != null) 'catalogPublished': catalogPublished,
    };

/// Un écran assez haut pour construire TOUTE la liste paresseuse d'un coup.
const _tall = KpbViewport(
  id: 'tall',
  name: 'Écran haut 393×2600',
  size: Size(393, 2600),
  padding: EdgeInsets.zero,
);

const _tall360 = KpbViewport(
  id: 'tall360',
  name: 'Écran haut 360×2600',
  size: Size(360, 2600),
  padding: EdgeInsets.zero,
);

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics analytics;

  void stub(Future<Map<String, dynamic>> Function(Invocation) answer) {
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

  /// La feuille « Ville » interroge le serveur (`GET /cities`) à l'ouverture.
  void stubCities() {
    when(() => api.fetchEefCities(
          query: any(named: 'query'),
          cycles: any(named: 'cycles'),
          procedureTypes: any(named: 'procedureTypes'),
          fieldIds: any(named: 'fieldIds'),
          institutionIds: any(named: 'institutionIds'),
          selectivities: any(named: 'selectivities'),
        )).thenAnswer((_) async => <String, dynamic>{
          'cities': [
            for (final (v, c) in const [
              ('Paris', 727),
              ('Toulouse', 271),
              ('Montpellier', 258),
              ('Lyon', 190),
              ('Nice', 142),
            ])
              <String, dynamic>{'value': v, 'count': c},
          ],
          'total': 1588,
          'catalogPublished': true,
          'source': 'database',
        });
  }

  void serveSuspension() {
    EefCalendar.windowSource = () => const EefCampaignWindow(
          suspendedCountries: ['Niger'],
          suspendedSources: {
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
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = true;
    Get.locale = const Locale('fr');
    serveSuspension();
    stubCities();
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    Get.reset();
  });

  Future<KpbScreenReport> pump(
    WidgetTester tester, {
    String country = 'Sénégal',
    bool guest = false,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    ThemeMode themeMode = ThemeMode.light,
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
                fullName: 'Awa Koné-Diallo',
                email: 'awa.kone.diallo@example.org',
                phone: '+221770001122',
              ),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: const EefCatalogScreen(),
      viewport: viewport,
      textScale: textScale,
      themeMode: themeMode,
      locale: locale,
      routesShareMediaQuery: true,
    );
  }

  /// Pose un filtre comme l'étudiant le fait : feuille, cases, « Voir N ».
  Future<void> choose(
    WidgetTester tester,
    String facet,
    List<String> values,
  ) async {
    final button = find.byKey(ValueKey('eef-filter-button-$facet'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await settleBounded(tester);
    for (final value in values) {
      await tester.tap(find.byKey(ValueKey('eef-filter-option-$value')));
      await tester.pump();
    }
    await tester.tap(find.byKey(const ValueKey('eef-filter-sheet-apply')));
    await settleBounded(tester);
  }

  Future<void> removeChip(
    WidgetTester tester,
    String facet,
    String value,
  ) async {
    await tester.tap(find.byKey(ValueKey('eef-active-chip-$facet-$value')));
    await settleBounded(tester);
  }

  int fineprints() => find.text('eef_help_fineprint'.tr).evaluate().length;

  /// Tous les textes de ce que les déclencheurs de la build 55 rendent.
  String lineTexts(WidgetTester tester) => tester
      .widgetList<Text>(find.descendant(
        of: find.byType(EefHelpLine),
        matching: find.byType(Text),
      ))
      .map((t) => t.data ?? '')
      .join(' | ');

  const filtersQuestion = 'Tu hésites entre ces formations ?';
  const procedureQuestion = 'Pas sûr(e) de la procédure pour ces formations ?';
  const ask = "Demander de l'aide";
  const talk = 'Parler à un conseiller';

  // ── 1. Le bouton sous chaque formation ──────────────────────────────────────

  group('un bouton « Demander de l\'aide » sous chaque formation', () {
    testWidgets(
        'une carte, un bouton — avec le nom de la formation pour les '
        'lecteurs d\'écran', (tester) async {
      final handle = tester.ensureSemantics();
      stub((_) async => _page([
            _program('a', name: 'L1 - Droit', institution: _university()),
            _program('b', name: 'Master Droit des affaires'),
            _program('c', name: 'L2 - Histoire'),
          ]));
      await pump(tester, viewport: _tall);

      expect(find.text(ask), findsNWidgets(3));
      expect(find.byType(EefHelpLine), findsNWidgets(3));
      expect(
          find.bySemanticsLabel(
              "Demander de l'aide à propos de « L1 - Droit »"),
          findsOneWidget);
      expect(
          find.bySemanticsLabel(
              "Demander de l'aide à propos de « Master Droit des affaires »"),
          findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      handle.dispose();
    });

    testWidgets('le tap ouvre WhatsApp : formation, université, ville',
        (tester) async {
      stub((_) async => _page([
            _program('a', name: 'L1 - Droit', institution: _university()),
            _program('b',
                name: 'Master Droit des affaires', campusCity: 'Paris'),
          ]));
      await pump(tester, viewport: _tall);

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      expect(launcher.launched, hasLength(1));
      final uri = Uri.parse(launcher.launched.single);
      expect(uri.host, 'wa.me');
      expect(
        uri.path,
        '/${AppConfig.whatsappNumber.replaceAll(RegExp(r'[^\d]'), '')}',
        reason: 'la ligne du conseiller, pas un autre numéro',
      );
      expect(uri.queryParameters.keys, ['text']);
      expect(
        launcher.lastText,
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
        '(Université Claude Bernard, Lyon) dans l\'espace Études en France de '
        'l\'app et j\'aimerais de l\'aide pour mon dossier.',
      );

      // La seconde carte nomme SA formation, pas celle de la première.
      launcher.launched.clear();
      await tester.tap(find.text(ask).last);
      await tester.pumpAndSettle();
      expect(launcher.lastText, contains('« Master Droit des affaires »'));
      expect(launcher.lastText, contains('(Paris)'));
      expect(launcher.lastText, isNot(contains('L1 - Droit')));
    });

    testWidgets(
        'RIEN d\'autre de personnel : ni nom, ni e-mail, ni téléphone, '
        'ni pays', (tester) async {
      stub((_) async => _page([_program('a', institution: _university())]));
      await pump(tester, viewport: _tall);

      await tester.tap(find.text(ask));
      await tester.pumpAndSettle();

      final text = launcher.lastText;
      for (final secret in [
        'Awa',
        'Koné',
        'Diallo',
        'awa.kone',
        'example.org',
        '221',
        '770001122',
        'Sénégal',
        'test-user-1',
      ]) {
        expect(text, isNot(contains(secret)), reason: text);
      }
      expect(text, isNot(contains('@')));
      expect(text, isNot(contains(RegExp(r'\d'))),
          reason: 'aucun chiffre : ni téléphone, ni passeport, ni id');
    });

    testWidgets('mesure : un tap, SANS intitulé, université ni ville',
        (tester) async {
      stub((_) async => _page([
            _program('a', name: 'L1 - Droit', institution: _university()),
            _program('b', name: 'L2 - Histoire'),
          ]));
      await pump(tester, viewport: _tall);

      // Pas de « vue » par carte affichée : du bruit. (La carte pleine du bas de
      // liste, elle, est mesurée comme avant.)
      expect(analytics.shownSteps, isNot(contains('catalog_program')));

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      expect(analytics.tappedCalls,
          [const RecordedHelpEvent('catalog_program', 'catalog', 'compact')]);
      for (final event in [...analytics.tappedCalls, ...analytics.shownCalls]) {
        for (final secret in ['Droit', 'Lyon', 'Claude', 'Histoire']) {
          expect('$event', isNot(contains(secret)));
        }
      }
    });

    testWidgets('des noms démesurés : message borné, coupé proprement',
        (tester) async {
      final long = 'Master Droit international, européen et comparé des '
              'affaires publiques et privées — parcours recherche ' *
          3;
      stub((_) async => _page([
            _program(
              'a',
              name: long,
              campusCity: 'Villeneuve-d\'Ascq-sur-la-Très-Longue-Rivière ' * 3,
            ),
          ]));
      await pump(tester, viewport: _tall);

      await tester.tap(find.text(ask));
      await tester.pumpAndSettle();

      final text = launcher.lastText;
      expect(
          text.runes.length, lessThanOrEqualTo(EefHelpMessages.maxMessageChars),
          reason: text);
      expect(Uri.encodeComponent(text).length,
          lessThan(EefHelpMessages.maxEncodedChars));
      expect(text, contains('…'));
      expect(
          text, startsWith('Bonjour KPB Education, je regarde la formation'));
      expect(text, endsWith('pour mon dossier.'));
    });

    testWidgets('sans université ni ville servies : la formation seule',
        (tester) async {
      stub((_) async =>
          _page([_program('a', name: 'L1 - Droit', campusCity: null)]));
      await pump(tester, viewport: _tall);

      await tester.tap(find.text(ask));
      await tester.pumpAndSettle();

      expect(
        launcher.lastText,
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » dans '
        'l\'espace Études en France de l\'app et j\'aimerais de l\'aide pour '
        'mon dossier.',
      );
    });

    testWidgets('en anglais : libellé et message', (tester) async {
      stub((_) async => _page([
            _program('a', name: 'L1 - Law', institution: _university()),
          ]));
      await pump(tester, viewport: _tall, locale: const Locale('en'));

      expect(find.text('Ask for help'), findsOneWidget);
      await tester.tap(find.text('Ask for help'));
      await tester.pumpAndSettle();

      expect(
        launcher.lastText,
        'Hello KPB Education, I am looking at the programme “L1 - Law” '
        '(Claude Bernard University, Lyon) in the Études en France space of '
        'the app and I would like some help with my file.',
      );
    });

    // L'invité n'a pas de profil, donc pas de pays — donc jamais suspendu : il voit
    // le déclencheur NORMAL (la fiche de recette le dit).
    testWidgets('un invité : le bouton normal, le message habituel',
        (tester) async {
      stub((_) async => _page([
            _program('a', name: 'L1 - Droit', institution: _university()),
          ]));
      await pump(tester, guest: true, viewport: _tall);

      expect(find.text(ask), findsOneWidget);
      expect(find.text(talk), findsNothing);
      await tester.tap(find.text(ask));
      await tester.pumpAndSettle();

      expect(
        launcher.lastText,
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
        '(Université Claude Bernard, Lyon) dans l\'espace Études en France de '
        'l\'app et j\'aimerais de l\'aide pour mon dossier.',
      );
    });

    group('compte du Niger', () {
      testWidgets('le bouton est VISIBLE, au libellé neutre', (tester) async {
        stub((_) async => _page([
              _program('a', name: 'L1 - Droit', institution: _university()),
              _program('b', name: 'L2 - Histoire'),
            ]));
        await pump(tester, country: 'Niger', viewport: _tall);

        expect(find.text(talk), findsNWidgets(2));
        expect(find.text(ask), findsNothing);
        final texts = lineTexts(tester);
        expect(_openAFileWording.hasMatch(texts), isFalse, reason: texts);
      });

      testWidgets(
          'message neutre : suspendue « dans mon pays », sans le '
          'nommer, ni autre pays', (tester) async {
        stub((_) async => _page([
              _program('a', name: 'L1 - Droit', institution: _university()),
            ]));
        await pump(tester, country: 'Niger', viewport: _tall);

        await tester.tap(find.text(talk));
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
          '(Université Claude Bernard, Lyon) dans l\'espace Études en France '
          'de l\'app. La procédure est suspendue dans mon pays : j\'aimerais '
          'savoir quelles options existent.',
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        for (final forbidden in ['Niger', 'Togo', 'Sénégal', 'Awa', '@']) {
          expect(launcher.lastText, isNot(contains(forbidden)));
        }
        expect(analytics.tappedCalls,
            [const RecordedHelpEvent('catalog_program', 'catalog', 'compact')]);
      });

      testWidgets('en anglais : « Talk to an advisor », message neutre',
          (tester) async {
        stub((_) async => _page([
              _program('a', name: 'L1 - Law', institution: _university()),
            ]));
        await pump(
          tester,
          country: 'Niger',
          viewport: _tall,
          locale: const Locale('en'),
        );

        expect(find.text('Talk to an advisor'), findsOneWidget);
        await tester.tap(find.text('Talk to an advisor'));
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Hello KPB Education, I am looking at the programme “L1 - Law” '
          '(Claude Bernard University, Lyon) in the Études en France space of '
          'the app. The procedure is suspended in my country: I would like to '
          'know which options exist.',
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse);
      });

      testWidgets('la carte neutre existante reste en place, au plus UNE carte',
          (tester) async {
        stub((_) async => _page([_program('a'), _program('b')]));
        await pump(tester, country: 'Niger', viewport: _tall);

        // La carte pleine du bas de liste (build 54) : neutre, une seule.
        expect(find.byType(EefHelpCard), findsOneWidget);
        expect(find.text("Besoin d'y voir plus clair ?"), findsOneWidget);
        expect(fineprints(), 1);
      });
    });
  });

  // ── 2. La ligne sous les filtres actifs ─────────────────────────────────────

  group('la ligne « Tu hésites entre ces formations ? »', () {
    testWidgets('aucun filtre : pas de ligne', (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);

      expect(find.text(filtersQuestion), findsNothing);
      expect(analytics.shownSteps, isNot(contains('catalog_filters')));
    });

    testWidgets('un filtre posé : la ligne, placée SOUS les filtres actifs',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      expect(find.text(filtersQuestion), findsOneWidget);
      expect(find.text(ask), findsNWidgets(2),
          reason: 'le lien de la ligne + le bouton de la formation');
      // Sous la puce du filtre actif ET sous le compteur de résultats, au-dessus
      // des formations : la fiche de recette (Aide-21) décrit cet ordre.
      final chip = tester
          .getBottomLeft(
              find.byKey(const ValueKey('eef-active-chip-cycle-master')))
          .dy;
      final counter = tester.getTopLeft(find.text('1 formation(s)')).dy;
      final line = tester.getTopLeft(find.text(filtersQuestion)).dy;
      final card = tester.getTopLeft(find.text('Licence Droit')).dy;
      expect(chip, lessThan(counter));
      expect(counter, lessThan(line),
          reason: 'la ligne est SOUS le compteur, pas au-dessus');
      expect(line, lessThan(card));
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets('elle disparaît quand le dernier filtre est retiré',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);
      expect(find.text(filtersQuestion), findsOneWidget);

      await removeChip(tester, 'cycle', 'master');
      expect(find.text(filtersQuestion), findsNothing);
    });

    testWidgets('le message reprend niveau, domaine et ville choisis',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);
      await choose(tester, 'campusCity', ['Lyon']);

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      expect(
        launcher.lastText,
        'Bonjour KPB Education, je regarde les formations de l\'espace Études '
        'en France de l\'app (Niveau : Master ; Ville : Lyon) et j\'hésite. '
        'J\'aimerais de l\'aide pour choisir.',
      );
      expect(launcher.launched, hasLength(1));
    });

    testWidgets('trois valeurs au plus par famille, puis « … »',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(
          tester, 'campusCity', ['Paris', 'Toulouse', 'Montpellier', 'Lyon']);

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      final text = launcher.lastText;
      // L'ordre de la feuille : les villes les plus fournies d'abord.
      expect(text, contains('Ville : Paris, Toulouse, Montpellier, …'));
      expect(text, isNot(contains('Lyon')));
    });

    testWidgets(
        'mesure : « vue » UNE fois par visite, « tap » au tap — sans '
        'libellé de filtre ni ville', (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);
      await choose(tester, 'campusCity', ['Lyon']);

      List<RecordedHelpEvent> filtersShown() => analytics.shownCalls
          .where((event) => event.step == 'catalog_filters')
          .toList();
      expect(filtersShown(),
          [const RecordedHelpEvent('catalog_filters', 'catalog', 'compact')]);

      // Retirer puis reposer un filtre : même visite, pas de seconde « vue ».
      await removeChip(tester, 'cycle', 'master');
      await removeChip(tester, 'campusCity', 'Lyon');
      await choose(tester, 'cycle', ['licence1']);
      expect(filtersShown(), hasLength(1));

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      expect(analytics.tappedCalls,
          [const RecordedHelpEvent('catalog_filters', 'catalog', 'compact')]);
      for (final event in [...analytics.tappedCalls, ...analytics.shownCalls]) {
        for (final secret in ['Master', 'Licence', 'Lyon', 'Niveau', 'Ville']) {
          expect('$event', isNot(contains(secret)));
        }
      }
    });

    testWidgets('en anglais : question, lien et message', (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall, locale: const Locale('en'));
      await choose(tester, 'cycle', ['master']);

      expect(find.text('Torn between these programmes?'), findsOneWidget);
      await tester.tap(find.text('Ask for help').first);
      await tester.pumpAndSettle();

      expect(
        launcher.lastText,
        'Hello KPB Education, I am looking at the programmes in the Études en '
        'France space of the app (Level: Master\'s) and I cannot decide. I would '
        'like some help choosing.',
      );
    });

    // La procédure n'est PAS retirée du message d'un compte non suspendu : c'est
    // ce qui dit au conseiller de quelle voie on parle (seul un compte suspendu
    // n'y cite pas la procédure — voir le groupe « compte du Niger »).
    testWidgets('la procédure choisie est citée pour un compte non suspendu',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);
      await choose(tester, 'procedureType', ['eef']);

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      expect(
        launcher.lastText,
        'Bonjour KPB Education, je regarde les formations de l\'espace Études '
        'en France de l\'app (Niveau : Master ; Procédure : Études en France) '
        'et j\'hésite. J\'aimerais de l\'aide pour choisir.',
      );
    });

    testWidgets('rien de personnel dans le message', (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      await tester.tap(find.text(ask).first);
      await tester.pumpAndSettle();

      for (final secret in [
        'Awa',
        'Koné',
        'Diallo',
        'awa.kone',
        'example.org',
        '221',
        'Sénégal',
      ]) {
        expect(launcher.lastText, isNot(contains(secret)),
            reason: launcher.lastText);
      }
    });

    group('compte du Niger', () {
      testWidgets('la ligne est VISIBLE, au libellé neutre', (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(tester, country: 'Niger', viewport: _tall);
        await choose(tester, 'cycle', ['master']);

        expect(find.text(filtersQuestion), findsOneWidget);
        // Le lien de la ligne ET le bouton de la formation sont neutres.
        expect(find.text(talk), findsNWidgets(2));
        expect(find.text(ask), findsNothing);
        final texts = lineTexts(tester);
        expect(_openAFileWording.hasMatch(texts), isFalse, reason: texts);
      });

      testWidgets('message neutre : suspendue, sans nommer le pays',
          (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(tester, country: 'Niger', viewport: _tall);
        await choose(tester, 'cycle', ['master']);

        await tester.tap(find.text(talk).first);
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app (Niveau : Master). La procédure est '
          'suspendue dans mon pays : j\'aimerais savoir quelles options '
          'existent.',
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        expect(launcher.lastText, isNot(contains('Niger')));
      });

      testWidgets('en anglais : « Talk to an advisor », message neutre',
          (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(
          tester,
          country: 'Niger',
          viewport: _tall,
          locale: const Locale('en'),
        );
        await choose(tester, 'cycle', ['master']);

        expect(find.text('Torn between these programmes?'), findsOneWidget);
        expect(find.text('Talk to an advisor'), findsNWidgets(2));
        expect(find.text('Ask for help'), findsNothing);
        final texts = lineTexts(tester);
        expect(_openAFileWording.hasMatch(texts), isFalse, reason: texts);

        await tester.tap(find.text('Talk to an advisor').first);
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Hello KPB Education, I am looking at the programmes in the Études en '
          'France space of the app (Level: Master\'s). The procedure is '
          'suspended in my country: I would like to know which options exist.',
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        expect(launcher.lastText, isNot(contains('Niger')));
      });

      // « DAP dossier jaune » est le NOM d'une procédure, mais le mot « dossier »
      // dans un message destiné à un pays suspendu contredit la règle de l'espace
      // (aucune invitation à ouvrir un dossier). Le résumé n'y cite donc pas la
      // procédure — et sans autre filtre, le message ne cite rien du tout, sans
      // parenthèses vides.
      testWidgets(
          'Niger + filtre de PROCÉDURE seul : le message ne cite pas la '
          'procédure, ni parenthèses vides', (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(tester, country: 'Niger', viewport: _tall);
        await choose(tester, 'procedureType', ['dap_jaune']);

        expect(find.text(filtersQuestion), findsOneWidget);
        await tester.tap(find.text(talk).first);
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app. La procédure est suspendue dans mon '
          'pays : j\'aimerais savoir quelles options existent.',
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        expect(launcher.lastText, isNot(contains('(')));
      });

      testWidgets(
          'Niger + niveau + procédure : seul le niveau est cité, aucun mot '
          '« dossier »', (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(tester, country: 'Niger', viewport: _tall);
        await choose(tester, 'cycle', ['master']);
        await choose(tester, 'procedureType', ['dap_jaune']);

        await tester.tap(find.text(talk).first);
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Bonjour KPB Education, je regarde les formations de l\'espace '
          'Études en France de l\'app (Niveau : Master). La procédure est '
          'suspendue dans mon pays : j\'aimerais savoir quelles options '
          'existent.',
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
      });

      testWidgets(
          'Niger + Parcoursup : pas de ligne de procédure, mais la '
          'ligne neutre des filtres', (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(tester, country: 'Niger', viewport: _tall);
        await choose(tester, 'procedureType', ['parcoursup']);

        expect(find.text(procedureQuestion), findsNothing);
        expect(find.text(filtersQuestion), findsOneWidget);
        expect(find.text(talk), findsWidgets);
      });
    });
  });

  // ── 3. Une seule ligne à la fois ────────────────────────────────────────────

  group('une seule ligne d\'aide sous les filtres, la procédure d\'abord', () {
    testWidgets(
        'Parcoursup filtré : la ligne de procédure, PAS celle des '
        'filtres', (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'procedureType', ['parcoursup']);

      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(filtersQuestion), findsNothing);
    });

    testWidgets('procédure confondue + autre filtre : toujours UNE ligne',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);
      // Seule la ligne des filtres, tant que la procédure n'est pas confondue.
      expect(find.text(filtersQuestion), findsOneWidget);
      expect(find.text(procedureQuestion), findsNothing);

      await choose(tester, 'procedureType', ['dap_jaune']);
      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(filtersQuestion), findsNothing);
    });

    testWidgets(
        '« Études en France » ou « DAP dossier blanc » filtrés : la '
        'ligne des filtres, pas celle de la procédure', (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'procedureType', ['eef']);

      expect(find.text(procedureQuestion), findsNothing);
      expect(find.text(filtersQuestion), findsOneWidget);
    });

    testWidgets(
        'une procédure INCONNUE sur une carte, sans filtre : la ligne '
        'de procédure seule', (tester) async {
      stub((_) async => _page([
            _program('a', procedureType: 'nouvelle_voie'),
          ]));
      await pump(tester, viewport: _tall);

      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(filtersQuestion), findsNothing);
    });

    testWidgets(
        'procédure INCONNUE + filtre posé : la procédure garde la '
        'priorité', (tester) async {
      stub((_) async => _page([
            _program('a', procedureType: 'nouvelle_voie'),
          ]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(filtersQuestion), findsNothing);
    });

    testWidgets('jamais deux lignes sous le compteur, quel que soit l\'état',
        (tester) async {
      stub((_) async => _page([
            _program('a', procedureType: 'nouvelle_voie'),
            _program('b'),
          ]));
      await pump(tester, viewport: _tall);

      for (final step in [
        ['cycle', 'master'],
        ['procedureType', 'parcoursup'],
        ['campusCity', 'Lyon'],
      ]) {
        await choose(tester, step[0], [step[1]]);
        final lines = [procedureQuestion, filtersQuestion]
            .where((q) => find.text(q).evaluate().isNotEmpty)
            .length;
        expect(lines, lessThanOrEqualTo(1), reason: 'après ${step[0]}');
      }
    });
  });

  // ── 4. Au plus UNE carte pleine par écran (Aide-9) ──────────────────────────

  group('Aide-9 : au plus une carte pleine', () {
    testWidgets(
        'liste entière + filtre posé + boutons : UNE carte, une '
        'mention', (tester) async {
      stub((_) async => _page([_program('a'), _program('b')]));
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      // Les lignes et les boutons sont des déclencheurs compacts…
      expect(find.byType(EefHelpLine), findsNWidgets(3));
      // … et la carte pleine du bas de liste est la seule.
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.text('Tu hésites sur ta formation ?'), findsOneWidget);
      expect(fineprints(), 1,
          reason: 'la mention n\'est pas répétée par bouton ni par ligne');
    });

    testWidgets('aucun résultat avec un filtre posé : la carte du vide SEULE',
        (tester) async {
      var first = true;
      stub((_) async {
        if (first) {
          first = false;
          return _page([_program('a')]);
        }
        return _page([], catalogPublished: true);
      });
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      expect(find.text('Aucune formation ne correspond'), findsOneWidget);
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.text('Tu ne trouves pas ta formation ?'), findsOneWidget);
      expect(find.text(filtersQuestion), findsNothing);
      expect(find.byType(EefHelpLine), findsNothing);
      expect(fineprints(), 1);
    });

    testWidgets('catalogue non publié : la carte seule, aucun bouton',
        (tester) async {
      stub((_) async => _page([], catalogPublished: false));
      await pump(tester, viewport: _tall);

      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.byType(EefHelpLine), findsNothing);
      expect(fineprints(), 1);
    });

    testWidgets('compte du Niger : mêmes règles, une carte neutre',
        (tester) async {
      stub((_) async => _page([_program('a'), _program('b')]));
      await pump(tester, country: 'Niger', viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.text("Besoin d'y voir plus clair ?"), findsOneWidget);
      expect(fineprints(), 1);
      expect(find.text(filtersQuestion), findsOneWidget);
    });
  });

  // ── 5. Les pages suivantes ──────────────────────────────────────────────────

  // La mention « Un accompagnement n'est pas une garantie » vit dans la carte
  // pleine du bas de liste — qui n'existe que sur une liste ENTIÈRE. Sur le
  // catalogue par défaut (des milliers de formations, paginé), chaque carte porte
  // pourtant « Demander de l'aide » : la mention ne doit jamais manquer à l'écran
  // où l'on propose l'aide. UNE seule, quel que soit l'état de la liste : dans
  // l'en-tête quand la carte du bas est absente, dans la carte quand elle est là.
  group('liste paginée', () {
    void stubTwoPages() {
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _page(
            [for (var i = 0; i < 3; i++) _program('p$i', name: 'F $i')],
            total: 5,
            hasMore: true,
            nextCursor: 'c1',
          );
        }
        return _page(
          [for (var i = 3; i < 5; i++) _program('p$i', name: 'F $i')],
          total: 5,
        );
      });
    }

    testWidgets(
        'chaque formation chargée porte son bouton, sans carte pleine '
        'tant qu\'il reste des pages', (tester) async {
      stubTwoPages();
      await pump(tester, viewport: _tall);

      expect(find.text(ask), findsNWidgets(3));
      expect(find.byType(EefHelpCard), findsNothing);
      expect(analytics.shownCalls, isEmpty);
    });

    testWidgets(
        'les boutons sont là : la mention de non-garantie aussi, UNE fois, '
        'sous le compteur', (tester) async {
      stubTwoPages();
      await pump(tester, viewport: _tall);

      expect(find.text(ask), findsNWidgets(3));
      expect(fineprints(), 1,
          reason: 'des boutons « Demander de l\'aide » sans la mention');
      final counter = tester.getTopLeft(find.text('5 formation(s)')).dy;
      final fineprint =
          tester.getTopLeft(find.text('eef_help_fineprint'.tr)).dy;
      final firstCard = tester.getTopLeft(find.text('F 0')).dy;
      expect(counter, lessThan(fineprint));
      expect(fineprint, lessThan(firstCard),
          reason:
              'avant la liste, pas en bas d\'une liste qui n\'a pas de fin');
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets(
        'une fois la liste ENTIÈRE, la mention passe dans la carte du bas : '
        'toujours UNE seule', (tester) async {
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _page(
            [for (var i = 0; i < 12; i++) _program('p$i', name: 'F $i')],
            total: 14,
            hasMore: true,
            nextCursor: 'c1',
          );
        }
        return _page(
          [for (var i = 12; i < 14; i++) _program('p$i', name: 'F $i')],
          total: 14,
        );
      });
      await pump(tester);
      expect(fineprints(), 1);
      expect(find.byType(EefHelpCard), findsNothing);

      // Page suivante : la liste devient entière, puis on va au bout.
      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await settleBounded(tester);
      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await settleBounded(tester);

      expect(find.text('F 13'), findsOneWidget);
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(find.text('Tu hésites sur ta formation ?'), findsOneWidget);
      expect(fineprints(), 1,
          reason: 'la carte du bas porte la mention, l\'en-tête plus');
    });

    testWidgets('un filtre posé : compteur, ligne, mention — dans cet ordre',
        (tester) async {
      stubTwoPages();
      await pump(tester, viewport: _tall);
      await choose(tester, 'cycle', ['master']);

      expect(find.text(filtersQuestion), findsOneWidget);
      expect(fineprints(), 1);
      final counter = tester.getTopLeft(find.text('5 formation(s)')).dy;
      final line = tester.getTopLeft(find.text(filtersQuestion)).dy;
      final fineprint =
          tester.getTopLeft(find.text('eef_help_fineprint'.tr)).dy;
      final firstCard = tester.getTopLeft(find.text('F 0')).dy;
      expect(counter, lessThan(line),
          reason: 'la ligne « Tu hésites… » est SOUS le compteur');
      expect(line, lessThan(fineprint));
      expect(fineprint, lessThan(firstCard));
    });

    testWidgets(
        'la ligne de procédure (carte compacte) ne double pas la mention',
        (tester) async {
      stub((_) async => _page(
            [_program('a', procedureType: 'nouvelle_voie')],
            total: 2,
            hasMore: true,
            nextCursor: 'c1',
          ));
      await pump(tester, viewport: _tall);

      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.byType(EefHelpCard), findsOneWidget);
      expect(fineprints(), 1);
    });

    testWidgets('compte du Niger : la même mention, une fois', (tester) async {
      stubTwoPages();
      await pump(tester, country: 'Niger', viewport: _tall);

      expect(find.text(talk), findsNWidgets(3));
      expect(find.byType(EefHelpCard), findsNothing);
      expect(fineprints(), 1);
    });

    testWidgets(
        'en anglais, à 360 dp × 1,3 : la mention tient, rien ne déborde',
        (tester) async {
      stubTwoPages();
      final report = await pump(
        tester,
        viewport: _tall360,
        textScale: 1.3,
        locale: const Locale('en'),
      );

      expect(fineprints(), 1);
      expect(report.overflows, isEmpty, reason: report.toString());
      expect(truncatedTexts(tester), isEmpty);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('la mention est lisible (>= 4,5:1) — ${mode.name}',
          (tester) async {
        stubTwoPages();
        await pump(tester, viewport: _tall, themeMode: mode);
        final measured = await measurePixelContrast(
            tester, find.text('eef_help_fineprint'.tr));
        expect(measured.ratio, greaterThanOrEqualTo(4.5),
            reason: measured.toString());
      });
    }
  });

  // ── 6. Géométrie, en situation ──────────────────────────────────────────────

  group('géométrie en situation', () {
    for (final scale in kpbTextScales) {
      for (final locale in ['fr', 'en']) {
        for (final country in ['Sénégal', 'Niger']) {
          testWidgets('360 ×$scale $locale — $country : liste, bouton, ligne',
              (tester) async {
            final long = 'Master Droit international et européen des affaires '
                'publiques et privées, parcours recherche';
            stub((_) async => _page([
                  _program('a', name: long, institution: _university()),
                  _program('b', name: 'L1 - Droit'),
                ]));
            var report = await pump(
              tester,
              country: country,
              viewport: _tall360,
              textScale: scale,
              locale: Locale(locale),
            );
            await choose(tester, 'cycle', ['master']);
            await choose(tester, 'campusCity', ['Lyon']);

            expect(find.byType(EefHelpLine), findsNWidgets(3));
            expect(report.overflows, isEmpty, reason: report.toString());
            expect(report.otherErrors, isEmpty, reason: report.toString());
            expect(truncatedTexts(tester), isEmpty);
            expect(rawTranslationKeysOnScreen(tester), isEmpty);

            // Cibles tactiles : au moins 48 dp de haut, partout.
            for (final element in find.byType(TextButton).evaluate()) {
              final box = element.renderObject! as RenderBox;
              expect(box.size.height, greaterThanOrEqualTo(48));
            }
          });
        }
      }
    }
  });

  // ── 7. Contraste, en clair et en sombre ─────────────────────────────────────

  group('contraste >= 4,5:1 (mesuré sur les pixels)', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final country in ['Sénégal', 'Niger']) {
        testWidgets(
            '${mode.name} — $country : bouton de formation et ligne '
            'des filtres', (tester) async {
          stub((_) async => _page([_program('a', name: 'L1 - Droit')]));
          await pump(tester,
              viewport: _tall, themeMode: mode, country: country);
          await choose(tester, 'cycle', ['master']);

          final link = country == 'Niger' ? talk : ask;
          final texts = <Finder>[
            find.text(filtersQuestion),
            find.text(link).first,
            find.text(link).last,
          ];
          for (final finder in texts) {
            final measured = await measurePixelContrast(tester, finder);
            expect(measured.ratio, greaterThanOrEqualTo(4.5),
                reason: '$measured');
          }
        });
      }
    }
  });
}
