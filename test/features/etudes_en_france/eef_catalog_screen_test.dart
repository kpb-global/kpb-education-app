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

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/models/eef_catalog_attribution.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_data_notice.dart';

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
      'cycle': 'licence3',
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

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;

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
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = true;
    Get.locale = const Locale('fr');
  });

  tearDown(() {
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
