// L'écran du catalogue « Études en France », monté dans l'emballage de
// production : états, mentions, géométrie.
//
// Le contrôleur (recherche, séquence, pagination) a son propre fichier. Ici on
// éprouve ce que l'ÉTUDIANT voit : que « rien n'est publié » ne se lit pas comme
// « ta recherche est trop étroite », qu'une page suivante en panne ne détruit pas
// la liste, que la carte nomme l'université, et que les mentions obligatoires
// sont atteignables.

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/models/eef_catalog_attribution.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_data_notice.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

DioException _dio(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/search'),
      type: type,
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
      'facets': facets ?? <String, dynamic>{},
      'facetsTruncated': <String>[],
      if (catalogPublished != null) 'catalogPublished': catalogPublished,
    };

/// Un écran assez haut pour construire TOUTE la liste paresseuse d'un coup : les
/// tests de la carte d'aide cherchent des cartes, pas la position du pli.
const _tall = KpbViewport(
  id: 'tall',
  name: 'Écran haut 393×2600',
  size: Size(393, 2600),
  padding: EdgeInsets.zero,
);

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics helpAnalytics;

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

  setUp(() {
    api = MockApiClient();
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    helpAnalytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = helpAnalytics;
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = true;
    Get.locale = const Locale('fr');
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
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(countryOfResidence: country),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: const EefCatalogScreen(),
      viewport: viewport,
      textScale: textScale,
    );
  }

  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
    await tester.pumpAndSettle();
  }

  group('la porte', () {
    testWidgets('espace fermé → « bientôt », et AUCUNE requête',
        (tester) async {
      AppConfig.eefSpaceEnabledOverride = null;
      stub((_) async => _page([_program('a')]));

      await pump(tester);

      expect(find.text('Bientôt disponible'), findsWidgets);
      expect(find.text('Licence Droit'), findsNothing);
      verifyNever(() => api.searchEefCatalog(
            query: any(named: 'query'),
            cycles: any(named: 'cycles'),
            procedureTypes: any(named: 'procedureTypes'),
            fieldIds: any(named: 'fieldIds'),
            campusCities: any(named: 'campusCities'),
            institutionIds: any(named: 'institutionIds'),
            selectivities: any(named: 'selectivities'),
            cursor: any(named: 'cursor'),
            limit: any(named: 'limit'),
          ));
    });
  });

  group('la carte formation', () {
    testWidgets('nomme l\'université, la ville et la procédure',
        (tester) async {
      stub((_) async => _page([_program('a', institution: _university())]));
      await pump(tester);

      expect(find.text('Licence Droit'), findsOneWidget);
      expect(
        find.text('Université Claude Bernard (UCBL) · Lyon'),
        findsOneWidget,
      );
      expect(find.text('Études en France'), findsOneWidget);
      expect(find.text('3 ans'), findsOneWidget);
    });

    testWidgets('sans établissement servi, la carte reste honnête',
        (tester) async {
      stub((_) async => _page([_program('a', campusCity: null)]));
      await pump(tester);

      expect(find.text('Licence Droit'), findsOneWidget);
      // Aucune ligne « université » inventée.
      expect(find.byIcon(Icons.school_outlined), findsNothing);
    });

    testWidgets('une procédure inconnue n\'affiche aucun badge',
        (tester) async {
      stub((_) async => _page([
            _program('a',
                institution: _university(), procedureType: 'nouvelle_voie'),
          ]));
      final report = await pump(tester);

      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      expect(report.overflows, isEmpty);
      expect(find.textContaining('nouvelle_voie'), findsNothing);
    });

    testWidgets(
        'une 1re année d\'accès santé dit « Accès santé » — une L.AS « L1 - Chimie » '
        'trouvée par « médecine » doit dire pourquoi', (tester) async {
      stub((_) async => _page([
            _program('a',
                name: 'L1 - Chimie',
                institution: _university(),
                procedureType: 'dap_blanche',
                cycle: 'sante'),
            _program('b',
                name: 'L1 - Chimie',
                institution: _university(),
                procedureType: 'dap_blanche',
                cycle: 'licence1'),
          ]));
      final report = await pump(tester);

      expect(find.text('Accès santé'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
      expect(report.overflows, isEmpty);
    });

    testWidgets('une procédure « hors procédure » est dite telle',
        (tester) async {
      stub((_) async => _page([
            _program('a',
                institution: _university(), procedureType: 'hors_eef'),
          ]));
      await pump(tester);

      expect(find.text('Hors procédure'), findsOneWidget);
    });
  });

  group('LIV-11 — catalogue non publié', () {
    testWidgets('dit « le catalogue arrive » et ne propose pas de tout effacer',
        (tester) async {
      stub((_) async => _page([], catalogPublished: false));
      await pump(tester);

      expect(find.text('Le catalogue arrive'), findsOneWidget);
      expect(find.text('Aucune formation ne correspond'), findsNothing);
      expect(find.text('Tout effacer'), findsNothing);
    });

    testWidgets('une recherche trop étroite dit l\'inverse', (tester) async {
      stub((_) async => _page([], catalogPublished: true));
      await pump(tester);

      expect(find.text('Aucune formation ne correspond'), findsOneWidget);
      expect(find.text('Tout effacer'), findsOneWidget);
      expect(find.text('Le catalogue arrive'), findsNothing);
    });
  });

  group('pannes', () {
    testWidgets('une coupure réseau n\'est pas « aucun résultat »',
        (tester) async {
      stub((_) async => throw _dio(DioExceptionType.connectionError));
      await pump(tester);

      expect(find.text('Pas de connexion'), findsOneWidget);
      expect(find.text('Aucune formation ne correspond'), findsNothing);
    });

    testWidgets('un serveur en erreur est dit autrement', (tester) async {
      stub((_) async => throw _dio(DioExceptionType.badResponse));
      await pump(tester);

      expect(find.text('Catalogue indisponible'), findsOneWidget);
    });
  });

  // EEF-UX-M01 — le champ suit le contrôleur.
  group('tout effacer', () {
    testWidgets('vide AUSSI le champ de recherche', (tester) async {
      stub((invocation) async {
        final query = invocation.namedArguments[#query] as String?;
        return (query ?? '').isEmpty
            ? _page([_program('a')], catalogPublished: true)
            : _page([], catalogPublished: true);
      });
      await pump(tester);

      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleBounded(tester);
      expect(find.text('Aucune formation ne correspond'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'zzz'), findsOneWidget);

      await tester.tap(find.text('Tout effacer'));
      await settleBounded(tester);

      // Le texte a disparu du champ, et les résultats sont revenus.
      expect(find.widgetWithText(TextField, 'zzz'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(find.text('Licence Droit'), findsOneWidget);
    });
  });

  // EEF-UX-M02 — la page suivante qui échoue ne détruit pas la liste.
  group('page suivante en panne', () {
    testWidgets('garde la liste, dit l\'échec, et réessaie sur geste',
        (tester) async {
      var failing = true;
      stub((invocation) async {
        final cursor = invocation.namedArguments[#cursor] as String?;
        if (cursor == null) {
          return _page(
            [
              for (var i = 0; i < 12; i++) _program('p$i', name: 'Formation $i')
            ],
            total: 14,
            hasMore: true,
            nextCursor: 'c1',
          );
        }
        if (failing) throw _dio(DioExceptionType.connectionError);
        return _page(
          [
            _program('p12', name: 'Formation 12'),
            _program('p13', name: 'Formation 13')
          ],
          total: 14,
        );
      });
      await pump(tester);

      await scrollToEnd(tester);

      expect(find.text('Impossible de charger la suite.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      // La liste n'a pas été remplacée par un écran d'erreur.
      expect(find.text('Catalogue indisponible'), findsNothing);
      expect(find.text('Pas de connexion'), findsNothing);

      failing = false;
      await tester.tap(find.text('Réessayer'));
      await settleBounded(tester);

      expect(find.text('Impossible de charger la suite.'), findsNothing);
    });
  });

  group('mentions obligatoires', () {
    void serveAttribution() {
      EefCalendar.windowSource = () => const EefCampaignWindow(
            platformUrl: 'https://www.campusfrance.org/fr',
          );
    }

    testWidgets('la rangée « sources » est toujours à un geste',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester);

      expect(find.text('Sources des données et mentions'), findsOneWidget);
    });

    testWidgets('la feuille des sources porte la non-affiliation',
        (tester) async {
      serveAttribution();
      stub((_) async => _page([_program('a')]));
      await pump(tester);

      await tester.tap(find.text('Sources des données et mentions'));
      await tester.pumpAndSettle();

      // La liste, derrière, porte déjà ses propres mentions : on cherche donc
      // DANS la feuille.
      final sheet = find.byType(BottomSheet);
      expect(find.text('À propos des données'), findsOneWidget);
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('eef_affiliation_notice'.tr),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: sheet,
          matching: find.text('Voir la plateforme officielle'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('en fin de liste : paternité, licence, mise à jour',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester);
      _serveAttributionFlags();

      await scrollToEnd(tester);

      expect(
        find.textContaining('Ministère de l\'Enseignement supérieur'),
        findsOneWidget,
      );
      expect(find.textContaining('Licence Ouverte 2.0'), findsOneWidget);
      expect(find.textContaining('21 septembre 2026'), findsOneWidget);
      expect(find.text('eef_affiliation_notice'.tr), findsOneWidget);
    });

    testWidgets(
        'sans mention servie, la non-affiliation reste, rien n\'est inventé',
        (tester) async {
      stub((_) async => _page([_program('a')]));
      await pump(tester);

      await scrollToEnd(tester);

      expect(find.textContaining('Licence Ouverte'), findsNothing);
      expect(find.textContaining('Données :'), findsNothing);
      expect(find.text('eef_affiliation_notice'.tr), findsOneWidget);
    });

    testWidgets('les états vides portent aussi les mentions', (tester) async {
      stub((_) async => _page([], catalogPublished: false));
      await pump(tester);

      expect(find.text('eef_affiliation_notice'.tr), findsOneWidget);
    });
  });

  group('LIV-12 — suspension', () {
    void serveSuspension() {
      EefCalendar.windowSource = () => const EefCampaignWindow(
            suspendedCountries: ['Niger'],
            suspendedSources: {
              'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
            },
          );
    }

    testWidgets('un étudiant nigérien est prévenu AVANT la liste',
        (tester) async {
      serveSuspension();
      stub((_) async => _page([_program('a')]));
      await pump(tester, country: 'Niger');

      expect(find.text('eef_suspended_notice'.tr), findsOneWidget);
      expect(find.text('Voir la source officielle'), findsOneWidget);
      // Le catalogue reste consultable.
      expect(find.text('Licence Droit'), findsOneWidget);
    });

    testWidgets('un étudiant sénégalais n\'est pas prévenu', (tester) async {
      serveSuspension();
      stub((_) async => _page([_program('a')]));
      await pump(tester, country: 'Sénégal');

      expect(find.text('eef_suspended_notice'.tr), findsNothing);
    });
  });

  // « Tu ne trouves pas ta formation ? » — la carte d'aide du catalogue. Au plus
  // UNE carte pleine par écran ; la ligne de procédure n'apparaît que quand
  // l'étudiant filtre sur une procédure qu'on confond.
  group('aide à chaque étape floue', () {
    const listQuestion = 'Tu hésites sur ta formation ?';
    const listCta = "Démarrer l'étude de mon dossier sur WhatsApp";
    const emptyQuestion = 'Tu ne trouves pas ta formation ?';
    const unpublishedQuestion = 'Tu ne veux pas attendre ?';
    const procedureQuestion =
        'Pas sûr(e) de la procédure pour ces formations ?';
    const askForHelp = "Demander de l'aide sur WhatsApp";
    const neutralCta = 'Parler à un conseiller des autres options';
    final openAFile = RegExp(
      r'dossier|d[ée]marrer|campus\s*france',
      caseSensitive: false,
    );

    void serveSuspension() {
      EefCalendar.windowSource = () => const EefCampaignWindow(
            suspendedCountries: ['Niger'],
            suspendedSources: {
              'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
            },
          );
    }

    /// Les facettes d'une procédure qu'on confond (Parcoursup) et d'une qui
    /// ne l'est pas (Études en France).
    Map<String, dynamic> procedureFacets() => <String, dynamic>{
          'procedureType': [
            {'value': 'parcoursup', 'count': 3},
            {'value': 'eef', 'count': 9},
          ],
        };

    String helpTexts(WidgetTester tester) => tester
        .widgetList<Text>(find.descendant(
          of: find.byType(EefHelpCard),
          matching: find.byType(Text),
        ))
        .map((t) => t.data ?? '')
        .join(' | ');

    int fineprints(WidgetTester tester) =>
        find.text('eef_help_fineprint'.tr).evaluate().length;

    group('sous les résultats', () {
      testWidgets('une carte, quand la liste est ENTIÈRE', (tester) async {
        stub((_) async => _page([_program('a'), _program('b')]));
        await pump(tester);
        await scrollToEnd(tester);

        expect(find.text(listQuestion), findsOneWidget);
        expect(find.text(listCta), findsOneWidget);
        expect(fineprints(tester), 1);
        // Avant les mentions obligatoires, qui restent atteignables.
        expect(find.text('eef_affiliation_notice'.tr), findsOneWidget);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });

      testWidgets(
          'le tap ouvre WhatsApp avec l\'étape « choix de ma formation »',
          (tester) async {
        stub((_) async => _page([_program('a')]));
        await pump(tester);
        await scrollToEnd(tester);

        await tester.tap(find.text(listCta));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(Uri.parse(launcher.launched.single).host, 'wa.me');
        expect(launcher.lastText, frHelpPrefill('choix de ma formation'));
        expect(helpAnalytics.tappedCalls,
            [const RecordedHelpEvent('catalog_results', 'catalog', 'card')]);
      });

      // Tant qu'il reste des pages, le défilement la repousserait à chaque
      // chargement : elle n'apparaîtrait qu'une demi-seconde.
      testWidgets('PAS tant qu\'il reste des pages à charger', (tester) async {
        final secondPage = Completer<Map<String, dynamic>>();
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
          return secondPage.future;
        });
        await pump(tester);

        // Pas `scrollToEnd` : la page suivante charge, et son indicateur tourne
        // sans fin — `pumpAndSettle` ne converge pas. On défile à la main.
        await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byType(CircularProgressIndicator), findsOneWidget,
            reason: 'la page suivante est bien en cours de chargement');
        expect(find.text(listQuestion), findsNothing,
            reason: 'la liste n\'est pas entière : la page suivante charge');
        expect(helpAnalytics.shownCalls, isEmpty);

        secondPage.complete(_page(
          [_program('p12', name: 'F 12'), _program('p13', name: 'F 13')],
          total: 14,
        ));
        await settleBounded(tester);
        await scrollToEnd(tester);

        expect(find.text(listQuestion), findsOneWidget);
        expect(fineprints(tester), 1);
      });

      testWidgets('un échec de page suivante ne la montre pas non plus',
          (tester) async {
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
          throw _dio(DioExceptionType.connectionError);
        });
        await pump(tester);
        await scrollToEnd(tester);

        expect(find.text('Impossible de charger la suite.'), findsOneWidget);
        expect(find.text(listQuestion), findsNothing);
      });
    });

    group('aucun résultat', () {
      testWidgets('« Tu ne trouves pas ta formation ? » — une carte, pas deux',
          (tester) async {
        stub((_) async => _page([], catalogPublished: true));
        await pump(tester);

        expect(find.text('Aucune formation ne correspond'), findsOneWidget);
        expect(find.text(emptyQuestion), findsOneWidget);
        expect(
            find.text('Un conseiller KPB peut chercher avec toi, à partir '
                'de ton profil et de ton projet.'),
            findsOneWidget);
        expect(fineprints(tester), 1);
        // Le geste de la recherche reste là, et distinct de l'aide.
        expect(find.text('Tout effacer'), findsOneWidget);
        // Ni la carte de « sous les résultats », ni celle du catalogue vide.
        expect(find.text(listQuestion), findsNothing);
        expect(find.text(unpublishedQuestion), findsNothing);
        expect(find.byType(EefHelpCard), findsOneWidget);
      });

      testWidgets('le tap nomme l\'étape « recherche sans résultat »',
          (tester) async {
        stub((_) async => _page([], catalogPublished: true));
        await pump(tester);

        await tester.tap(find.text(askForHelp));
        await tester.pumpAndSettle();

        expect(launcher.lastText,
            frHelpPrefill('recherche de formation sans résultat'));
        expect(helpAnalytics.shownCalls,
            [const RecordedHelpEvent('catalog_empty', 'catalog', 'card')]);
      });
    });

    group('catalogue non publié', () {
      testWidgets(
          'le texte renvoie à un conseiller : la carte en donne le moyen',
          (tester) async {
        stub((_) async => _page([], catalogPublished: false));
        await pump(tester);

        expect(find.text('Le catalogue arrive'), findsOneWidget);
        expect(find.text(unpublishedQuestion), findsOneWidget);
        expect(fineprints(tester), 1);
        // Ce n'est pas une recherche trop étroite.
        expect(find.text(emptyQuestion), findsNothing);
        expect(find.text('Tout effacer'), findsNothing);

        await tester.tap(find.text(askForHelp));
        await tester.pumpAndSettle();
        expect(launcher.lastText,
            frHelpPrefill('catalogue pas encore disponible'));
      });
    });

    group('procédure qu\'on confond', () {
      testWidgets(
          'filtrer sur Parcoursup montre la ligne ; Études en France non',
          (tester) async {
        stub((_) async => _page([_program('a')], facets: procedureFacets()));
        await pump(tester);
        // Aucun filtre : pas de ligne permanente.
        expect(find.text(procedureQuestion), findsNothing);

        await tester.tap(find.text('Parcoursup · 3'));
        await settleBounded(tester);
        expect(find.text(procedureQuestion), findsOneWidget);
        expect(find.text(askForHelp), findsOneWidget);

        // On retire Parcoursup et on prend la procédure qu'on ne confond pas.
        await tester.tap(find.text('Parcoursup · 3'));
        await settleBounded(tester);
        await tester.tap(find.text('Études en France · 9'));
        await settleBounded(tester);
        expect(find.text(procedureQuestion), findsNothing);
      });

      testWidgets(
          'le tap sur la ligne nomme l\'étape « procédure d\'une formation »',
          (tester) async {
        stub((_) async => _page([_program('a')], facets: procedureFacets()));
        await pump(tester);
        await tester.tap(find.text('Parcoursup · 3'));
        await settleBounded(tester);

        await tester.tap(find.text(askForHelp));
        await tester.pumpAndSettle();

        expect(launcher.lastText, frHelpPrefill("procédure d'une formation"));
        expect(helpAnalytics.tappedCalls, [
          const RecordedHelpEvent('catalog_procedure', 'catalog', 'compact')
        ]);
      });

      testWidgets('une procédure INCONNUE sur une carte déclenche la ligne',
          (tester) async {
        stub((_) async => _page([
              _program('a', procedureType: 'nouvelle_voie'),
            ]));
        await pump(tester);

        expect(find.text(procedureQuestion), findsOneWidget);
      });

      testWidgets('des procédures toutes connues et non confondues : rien',
          (tester) async {
        stub((_) async => _page([
              _program('a', procedureType: 'eef'),
              _program('b', procedureType: 'dap_blanche'),
            ]));
        await pump(tester);

        // Pas de ligne permanente : elle ne sert que là où l'on confond.
        expect(find.text(procedureQuestion), findsNothing);
      });
    });

    testWidgets(
        'au plus UNE carte pleine, même avec la ligne de procédure et la liste '
        'entière', (tester) async {
      stub((_) async => _page([_program('a')], facets: procedureFacets()));
      // Un écran assez haut pour que TOUT soit construit et visible d'un coup :
      // c'est le pire cas pour « au plus une carte ».
      await pump(tester, viewport: _tall);
      await tester.tap(find.text('Parcoursup · 3'));
      await settleBounded(tester);

      // La ligne de procédure (compacte) + la carte du bas (pleine).
      expect(find.byType(EefHelpCard), findsNWidgets(2));
      expect(find.text(procedureQuestion), findsOneWidget);
      expect(find.text(listQuestion), findsOneWidget);
      expect(fineprints(tester), 1,
          reason: 'une seule carte pleine (donc une seule mention)');
      expect(helpAnalytics.shownSteps,
          containsAll(['catalog_procedure', 'catalog_results']));
    });

    group('pays suspendu (Niger)', () {
      testWidgets('aucun résultat : libellé neutre, message neutre',
          (tester) async {
        serveSuspension();
        stub((_) async => _page([], catalogPublished: true));
        // Le bandeau de suspension pousse la carte sous le pli : écran haut.
        await pump(tester, country: 'Niger', viewport: _tall);

        expect(find.text(neutralCta), findsOneWidget);
        expect(find.text(emptyQuestion), findsNothing);
        expect(find.text(askForHelp), findsNothing);
        final texts = helpTexts(tester);
        expect(openAFile.hasMatch(texts), isFalse, reason: texts);

        await tester.tap(find.text(neutralCta));
        await tester.pumpAndSettle();
        expect(launcher.lastText,
            frSuspendedHelpPrefill('recherche de formation sans résultat'));
        expect(openAFile.hasMatch(launcher.lastText), isFalse);
      });

      testWidgets('catalogue non publié : neutre aussi', (tester) async {
        serveSuspension();
        stub((_) async => _page([], catalogPublished: false));
        await pump(tester, country: 'Niger', viewport: _tall);

        expect(find.text(neutralCta), findsOneWidget);
        expect(find.text(unpublishedQuestion), findsNothing);
      });

      testWidgets(
          'liste : la ligne de procédure disparaît, la carte du bas est neutre',
          (tester) async {
        serveSuspension();
        stub((_) async => _page([_program('a')], facets: procedureFacets()));
        await pump(tester, country: 'Niger');
        await tester.tap(find.text('Parcoursup · 3'));
        await settleBounded(tester);
        await scrollToEnd(tester);

        expect(find.text(procedureQuestion), findsNothing);
        expect(find.text(listQuestion), findsNothing);
        expect(find.text(listCta), findsNothing);
        expect(find.text(neutralCta), findsOneWidget);
        expect(fineprints(tester), 1);
        final texts = helpTexts(tester);
        expect(openAFile.hasMatch(texts), isFalse, reason: texts);
        // Une carte invisible n'est pas « vue ».
        expect(helpAnalytics.shownSteps, ['catalog_results']);
      });
    });
  });

  group('géométrie', () {
    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets('${viewport.id} ×$scale — liste, facettes, suspension',
            (tester) async {
          EefCalendar.windowSource = () => const EefCampaignWindow(
                suspendedCountries: ['Niger'],
                suspendedSources: {
                  'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
                },
              );
          stub((_) async => _page(
                [
                  _program('a', institution: _university()),
                  _program('b',
                      name:
                          'Master Droit international et européen des affaires',
                      institution: _university(),
                      procedureType: 'dap_blanche'),
                ],
                facets: <String, dynamic>{
                  'cycle': [
                    {'value': 'licence1', 'count': 3112},
                    {'value': 'master', 'count': 4210},
                  ],
                  'procedureType': [
                    {'value': 'dap_blanche', 'count': 812},
                    {'value': 'eef', 'count': 9001},
                  ],
                },
              ));

          final report = await pump(
            tester,
            country: 'Niger',
            viewport: viewport,
            textScale: scale,
          );

          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expect(rawTranslationKeysOnScreen(tester), isEmpty);
          expect(truncatedTexts(tester), isEmpty);
        });
      }
    }

    testWidgets('états vide et non publié à 360 × 1,3', (tester) async {
      stub((_) async => _page([], catalogPublished: false));
      final report = await pump(
        tester,
        viewport: compactAndroid,
        textScale: 1.3,
      );
      expect(report.overflows, isEmpty, reason: report.toString());
      expect(truncatedTexts(tester), isEmpty);
    });

    // Les cartes d'aide EN SITUATION : le test de la carte seule ne dit rien du
    // retrait de la liste ni du bandeau de suspension. L'écran est assez haut
    // pour que la carte soit construite — sous le pli, elle ne serait pas mesurée.
    for (final scale in kpbTextScales) {
      for (final country in ['Sénégal', 'Niger']) {
        testWidgets('cartes d\'aide en situation, 360 ×$scale — $country',
            (tester) async {
          EefCalendar.windowSource = () => const EefCampaignWindow(
                suspendedCountries: ['Niger'],
                suspendedSources: {
                  'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
                },
              );
          const tall360 = KpbViewport(
            id: 'tall360',
            name: 'Écran haut 360×2600',
            size: Size(360, 2600),
            padding: EdgeInsets.zero,
          );

          // Aucun résultat.
          stub((_) async => _page([], catalogPublished: true));
          var report = await pump(
            tester,
            country: country,
            viewport: tall360,
            textScale: scale,
          );
          expect(find.byType(EefHelpCard), findsOneWidget);
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);
          expect(rawTranslationKeysOnScreen(tester), isEmpty);

          // Pas publié.
          stub((_) async => _page([], catalogPublished: false));
          report = await pump(
            tester,
            country: country,
            viewport: tall360,
            textScale: scale,
          );
          expect(find.byType(EefHelpCard), findsOneWidget);
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);

          // Liste entière, procédure filtrée : la ligne ET la carte du bas.
          stub((_) async => _page(
                [_program('a', institution: _university())],
                facets: <String, dynamic>{
                  'procedureType': [
                    {'value': 'parcoursup', 'count': 3},
                  ],
                },
              ));
          report = await pump(
            tester,
            country: country,
            viewport: tall360,
            textScale: scale,
          );
          await tester.tap(find.text('Parcoursup · 3'));
          await settleBounded(tester);
          expect(find.byType(EefHelpCard), findsWidgets);
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);
          expect(rawTranslationKeysOnScreen(tester), isEmpty);
        });
      }
    }
  });

  // ── Défauts trouvés par la relecture indépendante ─────────────────────────

  group('nouvelle recherche', () {
    List<Map<String, dynamic>> many(int n) =>
        [for (var i = 0; i < n; i++) _program('p$i', name: 'Formation $i')];

    testWidgets('remonte la liste en haut après un filtre posé en bas',
        (tester) async {
      stub((invocation) async {
        final cycles = invocation.namedArguments[#cycles] as List<String>;
        return cycles.isEmpty
            ? _page(many(12), total: 12, facets: <String, dynamic>{
                'cycle': [
                  {'value': 'master', 'count': 8},
                ],
              })
            : _page(many(3), total: 3, facets: <String, dynamic>{
                'cycle': [
                  {'value': 'master', 'count': 3},
                ],
              });
      });
      await pump(tester);

      // On défile jusqu'en bas…
      await tester.drag(find.byType(ListView).last, const Offset(0, -2000));
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find.descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        ),
      );
      expect(scrollable.position.pixels, greaterThan(0));

      // …puis on pose un filtre : la liste redevient courte.
      await tester.tap(find.textContaining('Master'));
      await settleBounded(tester);

      expect(scrollable.position.pixels, 0,
          reason: 'le compteur et le premier résultat doivent être visibles');
      expect(find.text('3 formation(s)'), findsOneWidget);
    });

    testWidgets('montre un chargement pendant une recherche AFFINÉE',
        (tester) async {
      final gate = Completer<void>();
      var first = true;
      stub((invocation) async {
        if (first) {
          first = false;
          return _page(many(2), total: 2, facets: <String, dynamic>{
            'cycle': [
              {'value': 'master', 'count': 2},
            ],
          });
        }
        await gate.future;
        return _page(many(1), total: 1);
      });
      await pump(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.tap(find.textContaining('Master'));
      await tester.pump();

      // L'ancienne liste est encore là, et on VOIT que la réponse est en route.
      expect(find.text('Formation 0'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      gate.complete();
      await settleBounded(tester);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });
  });

  group('mention de paternité', () {
    const attribution = {
      'producer': "Ministère de l'Enseignement supérieur et de la Recherche",
      'licence': 'Licence Ouverte 2.0',
      'updatedAt': '2026-09-21',
      'sources': ['Parcoursup', 'Trouver mon master'],
    };

    // « Licence Licence Ouverte 2.0 » : le gabarit répétait le mot que la valeur
    // servie porte déjà. Le test cherchait un fragment et ne le voyait pas.
    test('la phrase exacte, sans mot répété (FR)', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
      expect(
        EefDataNotice.attributionText(
            EefCatalogAttribution.fromJson(attribution)),
        "Données : Ministère de l'Enseignement supérieur et de la Recherche "
        '(Parcoursup, Trouver mon master). Licence : Licence Ouverte 2.0. '
        'Récupérées le 21 septembre 2026.',
      );
    });

    test('la phrase exacte, sans mot répété (EN)', () {
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('en');
      expect(
        EefDataNotice.attributionText(
            EefCatalogAttribution.fromJson(attribution)),
        "Data: Ministère de l'Enseignement supérieur et de la Recherche "
        '(Parcoursup, Trouver mon master). Licence: Licence Ouverte 2.0. '
        'Retrieved on 21 September 2026.',
      );
    });
  });

  // Les clés que ces écrans lisent existent dans les DEUX langues. (`key.tr`
  // rend la clé quand elle manque : l'ancien test `isNotEmpty` ne pouvait pas
  // échouer.)
  test('le vocabulaire testé existe dans les deux langues', () {
    final keys = AppTranslations().keys;
    for (final key in [
      'eef_catalog_unpublished_title',
      'eef_catalog_more_failed',
      'eef_catalog_sources_row',
      'eef_catalog_attribution',
      'eef_catalog_attribution_bare',
    ]) {
      expect(keys['fr']![key], isNotNull, reason: '$key manque en fr');
      expect(keys['en']![key], isNotNull, reason: '$key manque en en');
    }
  });
}

void _serveAttributionFlags() {
  // La mention est servie par `/config/app` ; le test pose ce que `refresh`
  // aurait posé.
  RemoteFeatureFlags.instance.debugSetCatalogAttributionForTest(
    EefCatalogAttribution.fromJson(<String, dynamic>{
      'producer': "Ministère de l'Enseignement supérieur et de la Recherche",
      'licence': 'Licence Ouverte 2.0',
      'updatedAt': '2026-09-21',
      'sources': ['Parcoursup', 'Trouver mon master'],
    }),
  );
}
