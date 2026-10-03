// Les filtres du catalogue « Études en France », montés dans l'emballage de
// production : quatre boutons, une feuille par famille, la rangée des filtres
// actifs.
//
// Ce qu'on éprouve, parce que l'étudiant le subit sans pouvoir le dire :
//  · cocher trois cases ne fait PAS trois requêtes — une seule, à « Voir N
//    formations » ; fermer la feuille ne change rien ;
//  · le nombre choisi est lisible sur le bouton (« Ville · 2 ») ;
//  · le texte de chaque état est lisible, CLAIR ET SOMBRE — mesuré sur les pixels,
//    parce que l'ancien défaut (libellé gris sur fond bleu, 1,09:1) naissait de
//    l'écart entre ce que le code déclare et ce que le moteur peint ;
//  · la feuille des villes ne bloque jamais : chargement, échec avec « Réessayer »,
//    repli quand le serveur n'a pas encore la route, « aucune ville ».

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Response;
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/kpb_theme_ext.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_catalog_filters.dart';
import 'package:karatou/app/features/etudes_en_france/eef_data_notice.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/pixel_contrast.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

DioException _dio(DioExceptionType type) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
      type: type,
    );

DioException _http(int status) => DioException(
      requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/etudes-en-france/cities'),
        statusCode: status,
      ),
    );

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
    };

/// Les facettes que le serveur sert (chiffres de la production du 02/10/2026).
Map<String, dynamic> _facets({bool withUnknownField = false}) =>
    <String, dynamic>{
      'cycle': [
        for (final (v, c) in [
          ('master', 2771),
          ('licence1', 2512),
          ('licence3', 1637),
          ('licence2', 1497),
          ('but1', 834),
          ('sante', 650),
          ('ingenieur', 80),
          ('deust', 48),
        ])
          <String, dynamic>{'value': v, 'count': c},
      ],
      'procedureType': [
        for (final (v, c) in [
          ('eef', 6804),
          ('dap_blanche', 3076),
          ('hors_eef', 119),
          ('dap_jaune', 29),
          ('parcoursup', 1),
        ])
          <String, dynamic>{'value': v, 'count': c},
      ],
      'fieldId': [
        for (final (v, c) in [
          ('d09', 3343),
          ('d02', 1364),
          ('d03', 1257),
          ('d04', 1195),
          ('d07', 897),
          ('d01', 638),
          ('d08', 436),
          ('d11', 420),
          ('d06', 226),
          ('d05', 116),
          ('d10', 72),
          ('d12', 65),
          if (withUnknownField) ('d99', 7),
        ])
          <String, dynamic>{'value': v, 'count': c},
      ],
      'campusCity': [
        for (final (v, c) in [
          ('Paris', 727),
          ('Toulouse', 271),
          ('Montpellier', 258),
          ('Lyon', 190),
          ('Nice', 142),
        ])
          <String, dynamic>{'value': v, 'count': c},
      ],
    };

Map<String, dynamic> _page({
  List<Map<String, dynamic>>? items,
  int total = 10029,
  Map<String, dynamic>? facets,
  bool catalogPublished = true,
}) =>
    <String, dynamic>{
      'items': items ?? [_program('a'), _program('b', name: 'Master Droit')],
      'total': total,
      'page': <String, dynamic>{
        'limit': 20,
        'hasMore': false,
        'nextCursor': null,
      },
      'facets': facets ?? _facets(),
      'facetsTruncated': ['campusCity', 'institutionId'],
      'catalogPublished': catalogPublished,
    };

/// La réponse de `GET /etudes-en-france/cities`.
Map<String, dynamic> _cities({
  List<(String, int)>? cities,
  int total = 10000,
}) =>
    <String, dynamic>{
      'cities': [
        for (final (v, c) in cities ?? _allCities)
          <String, dynamic>{'value': v, 'count': c},
      ],
      'total': total,
      'catalogPublished': true,
      'source': 'database',
    };

const _allCities = <(String, int)>[
  ('Paris', 727),
  ('Toulouse', 271),
  ('Montpellier', 258),
  ('Rennes', 240),
  ('Lyon', 190),
  ('Aix-en-Provence', 151),
  ("Villeneuve-d'Ascq", 148),
  ('Nice', 142),
  ('Saint-Étienne', 80),
  ('Besançon', 60),
  ('Dijon', 50),
  ('Évry-Courcouronnes', 12),
];

/// Toutes les clés que les filtres lisent.
const _filterKeys = <String>[
  'eef_catalog_facet_cycle',
  'eef_catalog_facet_field',
  'eef_catalog_facet_city',
  'eef_catalog_facet_procedure',
  'eef_catalog_filter_clear',
  'eef_catalog_filter_semantics_none',
  'eef_catalog_filter_semantics_count',
  'eef_catalog_filter_semantics_hint',
  'eef_catalog_option_semantics',
  'eef_catalog_sheet_apply_zero',
  'eef_catalog_sheet_apply_one',
  'eef_catalog_sheet_apply_many',
  'eef_catalog_sheet_apply_generic',
  'eef_catalog_active_filters',
  'eef_catalog_active_clear_all',
  'eef_catalog_active_remove',
  'eef_catalog_city_search_hint',
  'eef_catalog_city_loading',
  'eef_catalog_city_error_title',
  'eef_catalog_city_error_network',
  'eef_catalog_city_error_server',
  'eef_catalog_city_retry',
  'eef_catalog_city_empty',
  'eef_catalog_city_fallback',
];

/// Les clés dont la valeur peut légitimement être la même en français et en
/// anglais (aucune aujourd'hui : « Procédure » / « Procedure » diffèrent).
const _sameInBothLanguages = <String>{};

/// Un écran de 360 × 800 dp sans encoche : la géométrie du public visé.
const _compact = compactAndroid;

/// Un écran de 360 dp de large et 2600 de haut : toute la liste d'une feuille
/// est construite d'un coup.
const _tall = KpbViewport(
  id: 'tall360',
  name: 'Écran haut 360×2600',
  size: Size(360, 2600),
  padding: EdgeInsets.zero,
);

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late List<Map<Symbol, Object?>> searches;
  late List<Map<Symbol, Object?>> cityCalls;

  void stubSearch([
    Future<Map<String, dynamic>> Function(Invocation)? answer,
  ]) {
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
        )).thenAnswer((invocation) {
      searches.add(Map<Symbol, Object?>.of(invocation.namedArguments));
      return answer != null ? answer(invocation) : Future.value(_page());
    });
  }

  void stubCities(Future<Map<String, dynamic>> Function(Invocation) answer) {
    when(() => api.fetchEefCities(
          query: any(named: 'query'),
          cycles: any(named: 'cycles'),
          procedureTypes: any(named: 'procedureTypes'),
          fieldIds: any(named: 'fieldIds'),
          institutionIds: any(named: 'institutionIds'),
          selectivities: any(named: 'selectivities'),
        )).thenAnswer((invocation) {
      cityCalls.add(Map<Symbol, Object?>.of(invocation.namedArguments));
      return answer(invocation);
    });
  }

  setUp(() {
    api = MockApiClient();
    searches = <Map<Symbol, Object?>>[];
    cityCalls = <Map<Symbol, Object?>>[];
    EefHelpCard.analytics = RecordingHelpAnalytics();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = true;
    Get.locale = const Locale('fr');
    stubSearch();
    stubCities((_) async => _cities());
  });

  tearDown(() {
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefSpaceEnabledOverride = null;
    Get.reset();
  });

  Future<KpbScreenReport> pump(
    WidgetTester tester, {
    KpbViewport viewport = _compact,
    double textScale = 1.0,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('fr'),
    EdgeInsets viewInsets = EdgeInsets.zero,
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(countryOfResidence: 'Sénégal'),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: const EefCatalogScreen(),
      viewport: viewport,
      textScale: textScale,
      themeMode: themeMode,
      locale: locale,
      viewInsets: viewInsets,
      // Les feuilles de filtre sont des routes modales : sans ceci elles seraient
      // mesurées à l'échelle de texte 1,0 et à la taille de la vue de test.
      routesShareMediaQuery: true,
    );
  }

  Finder button(String facetKey) =>
      find.byKey(ValueKey('eef-filter-button-$facetKey'));
  Finder option(String value) =>
      find.byKey(ValueKey('eef-filter-option-$value'));
  Finder chip(String facetKey, String value) =>
      find.byKey(ValueKey('eef-active-chip-$facetKey-$value'));
  final apply = find.byKey(const ValueKey('eef-filter-sheet-apply'));
  final sheet = find.byKey(const ValueKey('eef-filter-sheet'));

  Future<void> open(WidgetTester tester, String facetKey) async {
    await tester.ensureVisible(button(facetKey));
    await tester.tap(button(facetKey));
    await settleBounded(tester);
  }

  Future<void> tapApply(WidgetTester tester) async {
    await tester.tap(apply);
    await settleBounded(tester);
  }

  /// Fait défiler la liste de la feuille jusqu'à ce que [target] soit sous le
  /// doigt. La liste est paresseuse : une ville loin dans la liste n'est même pas
  /// construite tant qu'on n'a pas défilé — comme pour un étudiant.
  Future<void> reveal(WidgetTester tester, Finder target) async {
    final lists = find.descendant(of: sheet, matching: find.byType(ListView));
    if (lists.evaluate().isEmpty) return;
    final scrollable =
        find.descendant(of: lists.first, matching: find.byType(Scrollable));
    if (target.hitTestable().evaluate().isEmpty) {
      // On repart du haut : une ligne déjà dépassée n'est plus construite, et
      // `scrollUntilVisible` ne sait que descendre.
      tester.state<ScrollableState>(scrollable.first).position.jumpTo(0);
      await tester.pump();
    }
    await tester.scrollUntilVisible(
      target,
      60,
      scrollable: scrollable.first,
      maxScrolls: 200,
    );
    // Une ligne masquée par la barre « Voir » recevrait le tap à sa place — et
    // validerait la feuille sans rien cocher. On refuse de continuer plutôt que
    // de taper à côté.
    expect(target.hitTestable(), findsOneWidget,
        reason: 'la ligne n\'est pas atteignable au doigt');
  }

  /// Ouvre la feuille de [facetKey], coche [values], valide.
  Future<void> choose(
    WidgetTester tester,
    String facetKey,
    List<String> values,
  ) async {
    await open(tester, facetKey);
    for (final value in values) {
      await reveal(tester, option(value));
      await tester.tap(option(value));
      await tester.pump();
    }
    await tapApply(tester);
  }

  String applyLabel(WidgetTester tester) => tester
      .widget<Text>(
          find.descendant(of: apply, matching: find.byType(Text)).first)
      .data!;

  /// Les valeurs des cases de la feuille, dans l'ordre d'affichage.
  List<String> optionValues(WidgetTester tester) => [
        for (final element in find
            .byWidgetPredicate((w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>)
                    .value
                    .startsWith('eef-filter-option-'))
            .evaluate())
          (element.widget.key! as ValueKey<String>)
              .value
              .substring('eef-filter-option-'.length),
      ];

  List<String> optionLabels(WidgetTester tester) => [
        for (final value in optionValues(tester))
          tester
              .widget<Text>(find
                  .descendant(of: option(value), matching: find.byType(Text))
                  .first)
              .data!,
      ];

  bool checked(WidgetTester tester, String value) => tester
      .widget<Checkbox>(
          find.descendant(of: option(value), matching: find.byType(Checkbox)))
      .value!;

  // ── La barre ──────────────────────────────────────────────────────────────

  group('la barre de boutons', () {
    testWidgets(
        'quatre boutons, dans l\'ordre Niveau · Domaine · Ville · '
        'Procédure', (tester) async {
      await pump(tester);

      for (final label in ['Niveau', 'Domaine', 'Ville', 'Procédure']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      final order = [
        for (final key in ['cycle', 'fieldId', 'campusCity', 'procedureType'])
          tester.getTopLeft(button(key)),
      ];
      // Lecture de gauche à droite puis de haut en bas.
      for (var i = 1; i < order.length; i++) {
        final sameRow = (order[i].dy - order[i - 1].dy).abs() < 1;
        expect(
            sameRow
                ? order[i].dx > order[i - 1].dx
                : order[i].dy > order[i - 1].dy,
            isTrue,
            reason: 'le bouton $i est avant le bouton ${i - 1}');
      }
    });

    testWidgets(
        'l\'ancienne rangée de puces a disparu : ni FilterChip, ni '
        'puce « valeur · compte »', (tester) async {
      await pump(tester);

      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      // Les valeurs ne sont plus affichées à plat sous le champ de recherche.
      expect(find.textContaining('Master · '), findsNothing);
      expect(find.textContaining('Parcoursup · '), findsNothing);
      expect(find.text('Licence 1re année'), findsNothing);
    });

    testWidgets('au repos : pas de nombre sur le libellé', (tester) async {
      await pump(tester);
      expect(find.text('Ville'), findsOneWidget);
      expect(find.textContaining('Ville ·'), findsNothing);
    });

    testWidgets('aucune barre quand le serveur n\'a rien à filtrer',
        (tester) async {
      stubSearch((_) async => _page(items: [], total: 0, facets: {}));
      await pump(tester);

      expect(button('cycle'), findsNothing);
      expect(button('campusCity'), findsNothing);
    });

    // La VRAIE réponse d'un catalogue non publié : le serveur rend les six
    // clés de facette, chacune avec une liste VIDE (vérifié sur un backend
    // local branché sur une base sans publication). Tester `facets: {}`
    // seulement laissait passer un bouton « Ville » sur « Le catalogue arrive ».
    testWidgets(
        'aucune barre quand le serveur rend ses six facettes, toutes vides '
        '(catalogue non publié)', (tester) async {
      stubSearch((_) async => _page(
            items: [],
            total: 0,
            catalogPublished: false,
            facets: {
              for (final key in const [
                'procedureType',
                'cycle',
                'fieldId',
                'selectivity',
                'campusCity',
                'institutionId',
              ])
                key: <Map<String, dynamic>>[],
            },
          ));
      await pump(tester);

      expect(button('cycle'), findsNothing);
      expect(button('campusCity'), findsNothing);
      expect(find.text('Ville'), findsNothing);
    });

    testWidgets(
        'un domaine SANS NOM n\'est pas proposé ; sans aucun nom, le '
        'bouton disparaît', (tester) async {
      stubSearch((_) async => _page(facets: {
            'fieldId': [
              {'value': 'd99', 'count': 7},
            ],
            'cycle': [
              {'value': 'master', 'count': 3},
            ],
          }));
      await pump(tester);

      expect(button('fieldId'), findsNothing);
      expect(button('cycle'), findsOneWidget);
    });
  });

  // ── La feuille « Niveau » : un choix, une requête ─────────────────────────

  group('feuille « Niveau »', () {
    testWidgets('les niveaux dans l\'ordre d\'un parcours, avec leur compte',
        (tester) async {
      await pump(tester);
      await open(tester, 'cycle');

      expect(sheet, findsOneWidget);
      expect(optionValues(tester), [
        'licence1',
        'licence2',
        'licence3',
        'but1',
        'deust',
        'sante',
        'ingenieur',
        'master',
      ]);
      expect(optionLabels(tester).first, 'Licence 1re année');
      expect(optionLabels(tester).last, 'Master');
      // Le compte est servi avec la valeur.
      expect(
        find.descendant(of: option('master'), matching: find.text('2771')),
        findsOneWidget,
      );
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets('cocher trois cases ne lance AUCUNE requête avant « Voir »',
        (tester) async {
      await pump(tester);
      final before = searches.length;
      await open(tester, 'cycle');

      await tester.tap(option('licence1'));
      await tester.pump();
      await tester.tap(option('licence2'));
      await tester.pump();
      await tester.tap(option('master'));
      await settleBounded(tester);

      expect(searches.length, before,
          reason: 'une requête par case cochée : le défaut qu\'on évite');
      expect(checked(tester, 'licence1'), isTrue);
      expect(checked(tester, 'master'), isTrue);
      expect(checked(tester, 'but1'), isFalse);
    });

    testWidgets(
        '« Voir N formations » = la somme des comptes cochés, et UNE '
        'seule requête', (tester) async {
      await pump(tester);
      final before = searches.length;
      await open(tester, 'cycle');
      expect(applyLabel(tester), 'Voir 10029 formations',
          reason: 'rien de coché : le total de la liste');

      await tester.tap(option('licence1'));
      await tester.pump();
      expect(applyLabel(tester), 'Voir 2512 formations');
      await tester.tap(option('master'));
      await tester.pump();
      expect(applyLabel(tester), 'Voir 5283 formations');

      await tapApply(tester);

      expect(sheet, findsNothing);
      expect(searches.length, before + 1);
      expect(searches.last[#cycles], unorderedEquals(['licence1', 'master']));
    });

    testWidgets('un seul résultat : « Voir 1 formation » (singulier)',
        (tester) async {
      await pump(tester);
      await open(tester, 'procedureType');
      await tester.tap(option('parcoursup'));
      await tester.pump();
      expect(applyLabel(tester), 'Voir 1 formation');
    });

    testWidgets('le bouton porte ensuite le nombre choisi', (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['licence1', 'master']);

      expect(find.text('Niveau · 2'), findsOneWidget);
      expect(find.text('Niveau'), findsNothing);
    });

    testWidgets('fermer la feuille SANS valider ne change rien',
        (tester) async {
      await pump(tester);
      final before = searches.length;
      await open(tester, 'cycle');
      await tester.tap(option('master'));
      await tester.pump();

      // Un tap sur le fond, au-dessus de la feuille.
      await tester.tapAt(const Offset(180, 10));
      await settleBounded(tester);

      expect(sheet, findsNothing);
      expect(searches.length, before);
      expect(find.text('Niveau'), findsOneWidget);
      expect(chip('cycle', 'master'), findsNothing);

      // Et rouverte, la case n'est PAS cochée : le brouillon est jeté.
      await open(tester, 'cycle');
      expect(checked(tester, 'master'), isFalse);
    });

    testWidgets(
        'fermer SANS valider ne touche pas à un choix DÉJÀ posé — ni par le '
        'fond, ni par le retour système', (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['master']);
      final before = searches.length;

      // Le fond : on décoche « master », on coche « licence1 », on referme. Une
      // fermeture lue comme une validation à vide effacerait le filtre posé.
      await open(tester, 'cycle');
      await tester.tap(option('master'));
      await tester.pump();
      await tester.tap(option('licence1'));
      await tester.pump();
      await tester.tapAt(const Offset(180, 10));
      await settleBounded(tester);

      expect(sheet, findsNothing);
      expect(searches.length, before);
      expect(chip('cycle', 'master'), findsOneWidget);
      expect(chip('cycle', 'licence1'), findsNothing);
      expect(find.text('Niveau · 1'), findsOneWidget);

      // Le retour système.
      await open(tester, 'cycle');
      await tester.tap(option('master'));
      await tester.pump();
      final navigator =
          tester.state<NavigatorState>(find.byType(Navigator).first);
      await navigator.maybePop();
      await settleBounded(tester);

      expect(sheet, findsNothing);
      expect(searches.length, before);
      expect(chip('cycle', 'master'), findsOneWidget);
      expect(find.text('Niveau · 1'), findsOneWidget);
    });

    testWidgets(
        'la feuille ne rend pas le focus au champ de recherche : le clavier ne '
        'remonte pas sur la liste filtrée', (tester) async {
      await pump(tester);
      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      bool fieldHasFocus() => tester
          .widget<EditableText>(find.byType(EditableText).first)
          .focusNode
          .hasPrimaryFocus;
      expect(fieldHasFocus(), isTrue, reason: 'le champ doit avoir le focus');

      await open(tester, 'cycle');
      await tester.tap(option('master'));
      await tester.pump();
      await tapApply(tester);

      expect(sheet, findsNothing);
      expect(fieldHasFocus(), isFalse,
          reason: 'Flutter rend le focus au champ à la fermeture d\'une route '
              'modale : le clavier recouvrirait les résultats');
    });

    testWidgets('rouvrir la feuille montre le choix posé', (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['but1']);

      await open(tester, 'cycle');

      expect(checked(tester, 'but1'), isTrue);
      expect(checked(tester, 'master'), isFalse);
    });

    testWidgets('valider sans rien changer ne refait pas de recherche',
        (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['but1']);
      final before = searches.length;

      await open(tester, 'cycle');
      await tapApply(tester);

      expect(searches.length, before);
    });

    testWidgets('« Effacer » vide la famille — et « Voir » l\'applique',
        (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['licence1', 'master']);
      await choose(tester, 'procedureType', ['eef']);
      final before = searches.length;

      await open(tester, 'cycle');
      expect(
          find.byKey(const ValueKey('eef-filter-sheet-clear')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('eef-filter-sheet-clear')));
      await tester.pump();
      expect(checked(tester, 'licence1'), isFalse);
      expect(checked(tester, 'master'), isFalse);
      // Rien n'est parti : « Effacer » vide le brouillon, pas le catalogue.
      expect(searches.length, before);
      // Plus rien à effacer : le bouton disparaît.
      expect(
          find.byKey(const ValueKey('eef-filter-sheet-clear')), findsNothing);

      await tapApply(tester);

      expect(searches.length, before + 1);
      expect(searches.last[#cycles], isEmpty);
      // Les AUTRES familles sont intactes.
      expect(searches.last[#procedureTypes], ['eef']);
      expect(find.text('Niveau'), findsOneWidget);
      expect(find.text('Procédure · 1'), findsOneWidget);
    });

    testWidgets('« Effacer » n\'est pas proposé tant que rien n\'est coché',
        (tester) async {
      await pump(tester);
      await open(tester, 'cycle');
      expect(
          find.byKey(const ValueKey('eef-filter-sheet-clear')), findsNothing);
    });
  });

  // ── La feuille « Domaine » ────────────────────────────────────────────────

  group('feuille « Domaine »', () {
    testWidgets('les noms du référentiel de l\'app, triés par libellé',
        (tester) async {
      stubSearch((_) async => _page(facets: _facets(withUnknownField: true)));
      // Un écran assez haut pour que les douze domaines soient construits : la
      // feuille défile sur un vrai téléphone, et une liste paresseuse ne monte
      // que ce qui se voit.
      await pump(tester, viewport: _tall);
      await open(tester, 'fieldId');

      expect(optionLabels(tester), [
        'Agriculture & Agroalimentaire',
        'Architecture, BTP & Urbanisme',
        'Droit & Sciences Politiques',
        'Éducation, Sciences Humaines & Langues',
        'Énergie, Environnement & Développement durable',
        'Finance, Banque & Comptabilité',
        'Gestion, Business & Management',
        'Hôtellerie, Tourisme & Luxe',
        'Informatique & Intelligence Artificielle',
        'Ingénierie & Sciences Appliquées',
        'Marketing, Communication & Arts',
        'Santé & Sciences Médicales',
      ]);
      // « d99 » n'a pas de nom : ignoré, JAMAIS affiché sous son code.
      expect(optionValues(tester), isNot(contains('d99')));
      expect(find.textContaining('d99'), findsNothing);
      expect(find.textContaining('d07'), findsNothing);
    });

    testWidgets('envoie l\'identifiant du domaine, pas son nom',
        (tester) async {
      await pump(tester);
      await choose(tester, 'fieldId', ['d07']);

      expect(searches.last[#fieldIds], ['d07']);
      expect(find.text('Domaine · 1'), findsOneWidget);
      // La puce active porte le NOM.
      expect(
          find.descendant(
            of: chip('fieldId', 'd07'),
            matching: find.text('Droit & Sciences Politiques'),
          ),
          findsOneWidget);
    });

    testWidgets('en anglais : les noms anglais du même référentiel',
        (tester) async {
      await pump(tester, viewport: _tall, locale: const Locale('en'));
      await open(tester, 'fieldId');

      expect(find.text('Law & Political Science'), findsOneWidget);
      expect(find.text('Droit & Sciences Politiques'), findsNothing);
      expect(optionLabels(tester).first, 'Agriculture & Agri-food');
    });
  });

  // ── La feuille « Procédure » ──────────────────────────────────────────────

  group('feuille « Procédure »', () {
    testWidgets('garde l\'ordre du serveur, avec les libellés', (tester) async {
      await pump(tester);
      await open(tester, 'procedureType');

      expect(optionValues(tester),
          ['eef', 'dap_blanche', 'hors_eef', 'dap_jaune', 'parcoursup']);
      expect(optionLabels(tester).first, 'Études en France');
      expect(optionLabels(tester)[1], 'DAP dossier blanc');
    });
  });

  // ── La rangée des filtres actifs ──────────────────────────────────────────

  group('filtres actifs', () {
    testWidgets('aucune rangée, aucun « Tout effacer » sans filtre',
        (tester) async {
      await pump(tester);
      expect(find.byKey(const ValueKey('eef-active-clear-all')), findsNothing);
      expect(find.text('Tout effacer'), findsNothing);
    });

    testWidgets('chaque valeur choisie devient une puce supprimable',
        (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['master', 'licence1']);
      await choose(tester, 'fieldId', ['d07']);

      expect(chip('cycle', 'master'), findsOneWidget);
      expect(chip('cycle', 'licence1'), findsOneWidget);
      expect(chip('fieldId', 'd07'), findsOneWidget);
      expect(find.text('Master'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('eef-active-clear-all')), findsOneWidget);
      expect(find.text('Tout effacer'), findsOneWidget);
    });

    testWidgets('retirer une puce : UNE requête, sans cette valeur',
        (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['master', 'licence1']);
      final before = searches.length;

      await tester.tap(chip('cycle', 'master'));
      await settleBounded(tester);

      expect(searches.length, before + 1);
      expect(searches.last[#cycles], ['licence1']);
      expect(chip('cycle', 'master'), findsNothing);
      expect(find.text('Niveau · 1'), findsOneWidget);
    });

    testWidgets('retirer la dernière puce fait disparaître la rangée',
        (tester) async {
      await pump(tester);
      await choose(tester, 'procedureType', ['eef']);

      await tester.tap(chip('procedureType', 'eef'));
      await settleBounded(tester);

      expect(find.byKey(const ValueKey('eef-active-clear-all')), findsNothing);
      expect(find.text('Procédure'), findsOneWidget);
    });

    testWidgets('« Tout effacer » vide tout en UNE requête, champ compris',
        (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['master']);
      await choose(tester, 'fieldId', ['d07']);
      await choose(tester, 'campusCity', ['Paris', 'Lyon']);
      await tester.enterText(find.byType(TextField), 'droit');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await settleBounded(tester);
      final before = searches.length;

      await tester
          .ensureVisible(find.byKey(const ValueKey('eef-active-clear-all')));
      await tester.tap(find.byKey(const ValueKey('eef-active-clear-all')));
      await settleBounded(tester);

      expect(searches.length, before + 1);
      expect(searches.last[#cycles], isEmpty);
      expect(searches.last[#fieldIds], isEmpty);
      expect(searches.last[#campusCities], isEmpty);
      expect(searches.last[#query], '');
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      expect(find.byKey(const ValueKey('eef-active-clear-all')), findsNothing);
    });

    testWidgets('le compteur de résultats et l\'état vide ne changent pas',
        (tester) async {
      stubSearch((invocation) async {
        final cities = invocation.namedArguments[#campusCities] as List<String>;
        return cities.isEmpty
            ? _page()
            : _page(items: [], total: 0, catalogPublished: true);
      });
      await pump(tester);
      expect(find.text('10029 formation(s)'), findsOneWidget);

      await choose(tester, 'campusCity', ['Nice']);

      // L'état vide existant : même titre, même action, qui efface tout.
      expect(find.text('Aucune formation ne correspond'), findsOneWidget);
      expect(find.text('Tout effacer'), findsNWidgets(2));
    });
  });

  // ── La feuille « Ville » ──────────────────────────────────────────────────

  group('feuille « Ville »', () {
    testWidgets(
        'charge la liste ENTIÈRE à l\'ouverture, avec les filtres posés '
        '(hors ville)', (tester) async {
      await pump(tester);
      await choose(tester, 'cycle', ['master']);
      await choose(tester, 'campusCity', ['Nice']);
      cityCalls.clear();

      await open(tester, 'campusCity');

      expect(cityCalls, hasLength(1));
      expect(cityCalls.single[#cycles], ['master']);
      expect(cityCalls.single.containsKey(#campusCities), isFalse);
      // Les villes servies, triées par compte décroissant.
      expect(optionValues(tester).take(4),
          ['Paris', 'Toulouse', 'Montpellier', 'Rennes']);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets(
        'propose plus de villes que la facette (qui n\'en montre que 20)',
        (tester) async {
      await pump(tester);
      await open(tester, 'campusCity');
      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), 'dijon');
      await tester.pump();

      // « Dijon » n'est pas dans les facettes de la recherche.
      expect(optionValues(tester), ['Dijon']);
    });

    testWidgets('recherche locale : insensible aux accents et à la casse',
        (tester) async {
      await pump(tester);
      await open(tester, 'campusCity');
      final field = find.byKey(const ValueKey('eef-filter-sheet-search'));

      await tester.enterText(field, 'evry');
      await tester.pump();
      expect(optionValues(tester), ['Évry-Courcouronnes']);

      await tester.enterText(field, 'SAINT etienne');
      await tester.pump();
      expect(optionValues(tester), ['Saint-Étienne']);

      await tester.enterText(field, 'BESANCON');
      await tester.pump();
      expect(optionValues(tester), ['Besançon']);

      await tester.enterText(field, "d'ascq");
      await tester.pump();
      expect(optionValues(tester), ["Villeneuve-d'Ascq"]);
    });

    testWidgets('la recherche locale ne lance AUCUNE requête', (tester) async {
      await pump(tester);
      await open(tester, 'campusCity');
      final searchesBefore = searches.length;
      final citiesBefore = cityCalls.length;

      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), 'lyon');
      await tester.pump();

      expect(searches.length, searchesBefore);
      expect(cityCalls.length, citiesBefore);
    });

    testWidgets('« aucune ville ne correspond »', (tester) async {
      await pump(tester);
      await open(tester, 'campusCity');

      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), 'zzzz');
      await tester.pump();

      expect(
          find.byKey(const ValueKey('eef-filter-sheet-empty')), findsOneWidget);
      expect(find.text('Aucune ville ne correspond'), findsOneWidget);
      expect(optionValues(tester), isEmpty);
    });

    testWidgets('deux villes cochées = une requête, avec les DEUX',
        (tester) async {
      await pump(tester);
      final before = searches.length;
      await open(tester, 'campusCity');

      await tester.tap(option('Paris'));
      await tester.pump();
      await tester.tap(option('Lyon'));
      await tester.pump();
      expect(searches.length, before);
      expect(applyLabel(tester), 'Voir 917 formations');
      await tapApply(tester);

      expect(searches.length, before + 1);
      expect(searches.last[#campusCities], unorderedEquals(['Paris', 'Lyon']));
      expect(find.text('Ville · 2'), findsOneWidget);
      expect(chip('campusCity', 'Paris'), findsOneWidget);
      expect(chip('campusCity', 'Lyon'), findsOneWidget);
    });

    testWidgets('la recherche locale garde les cases déjà cochées',
        (tester) async {
      await pump(tester);
      await open(tester, 'campusCity');
      await tester.tap(option('Paris'));
      await tester.pump();

      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), 'lyon');
      await tester.pump();
      await tester.tap(option('Lyon'));
      await tester.pump();
      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), '');
      await tester.pump();

      expect(checked(tester, 'Paris'), isTrue);
      expect(checked(tester, 'Lyon'), isTrue);
    });

    testWidgets('« Voir N » avec le total du serveur quand rien n\'est coché',
        (tester) async {
      stubCities((_) async => _cities(total: 9876));
      await pump(tester);
      await open(tester, 'campusCity');
      expect(applyLabel(tester), 'Voir 9876 formations');
    });

    testWidgets(
        'chargement : un indicateur et son texte, la feuille reste '
        'utilisable', (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      stubCities((_) => gate.future);
      await pump(tester);

      await open(tester, 'campusCity');

      expect(find.text('Chargement des villes…'), findsOneWidget);
      expect(
          find.descendant(
              of: sheet, matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      expect(
          find.byKey(const ValueKey('eef-filter-sheet-search')), findsNothing);
      // La feuille n'est pas bloquante : on peut la fermer.
      expect(apply, findsOneWidget);
      expect(applyLabel(tester), 'Voir 10029 formations');

      gate.complete(_cities());
      await settleBounded(tester);
      expect(find.text('Chargement des villes…'), findsNothing);
      expect(optionValues(tester), isNotEmpty);
    });

    testWidgets('échec : message, « Réessayer », et la liste revient',
        (tester) async {
      var failing = true;
      stubCities((_) async {
        if (failing) throw _dio(DioExceptionType.connectionError);
        return _cities();
      });
      await pump(tester);

      await open(tester, 'campusCity');

      expect(find.text('Impossible de charger les villes'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('eef-filter-sheet-retry')), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      // Une coupure appelle à vérifier sa connexion.
      expect(find.text('Pas de connexion. Vérifie-la, puis réessaie.'),
          findsOneWidget);
      // Ce n'est PAS « aucune ville », et ce n'est pas un repli.
      expect(find.text('Aucune ville ne correspond'), findsNothing);
      expect(find.byKey(const ValueKey('eef-filter-sheet-fallback')),
          findsNothing);
      expect(optionValues(tester), isEmpty);

      failing = false;
      await tester.tap(find.byKey(const ValueKey('eef-filter-sheet-retry')));
      await settleBounded(tester);

      expect(find.text('Impossible de charger les villes'), findsNothing);
      expect(optionValues(tester).first, 'Paris');
      expect(cityCalls, hasLength(2));
    });

    testWidgets('un refus du serveur (401) n\'est ni un repli ni une coupure',
        (tester) async {
      stubCities((_) async => throw _http(401));
      await pump(tester);

      await open(tester, 'campusCity');

      expect(find.text('Impossible de charger les villes'), findsOneWidget);
      expect(
        find.text('Le serveur n\'a pas répondu. Réessaie dans un instant.'),
        findsOneWidget,
      );
      expect(find.text('Pas de connexion. Vérifie-la, puis réessaie.'),
          findsNothing);
      expect(find.byKey(const ValueKey('eef-filter-sheet-fallback')),
          findsNothing);
    });

    testWidgets(
        'une réponse arrivée après la fermeture de la feuille est '
        'jetée — elle ne touche pas la feuille suivante', (tester) async {
      final first = Completer<Map<String, dynamic>>();
      var call = 0;
      stubCities((_) {
        call += 1;
        return call == 1
            ? first.future
            : Future.value(_cities(cities: [('Nice', 3)]));
      });
      await pump(tester);

      // Première feuille : la réponse tarde. On la ferme, on en rouvre une.
      await open(tester, 'campusCity');
      await tester.tapAt(const Offset(180, 10));
      await settleBounded(tester);
      await open(tester, 'campusCity');
      expect(optionValues(tester), ['Nice']);

      // La réponse de la PREMIÈRE feuille arrive enfin.
      first.complete(_cities(cities: [('Paris', 727)]));
      await settleBounded(tester);

      expect(optionValues(tester), ['Nice']);
      expect(tester.takeException(), isNull);
    });

    for (final status in [404, 405, 500, 503]) {
      testWidgets(
          'REPLI sur $status : les villes de la dernière recherche, '
          'avec la mention honnête', (tester) async {
        stubCities((_) async => throw _http(status));
        await pump(tester);

        await open(tester, 'campusCity');

        expect(find.byKey(const ValueKey('eef-filter-sheet-fallback')),
            findsOneWidget);
        expect(
          find.text('Villes principales — pour une autre ville, tape-la dans '
              'la recherche'),
          findsOneWidget,
        );
        // Les cinq villes de la facette, pas un écran bloquant.
        expect(optionValues(tester),
            ['Paris', 'Toulouse', 'Montpellier', 'Lyon', 'Nice']);
        expect(
            find.byKey(const ValueKey('eef-filter-sheet-retry')), findsNothing);
        expect(find.text('Impossible de charger les villes'), findsNothing);
      });
    }

    testWidgets('en repli, on peut choisir une ville et appliquer',
        (tester) async {
      stubCities((_) async => throw _http(404));
      await pump(tester);

      await choose(tester, 'campusCity', ['Lyon']);

      expect(searches.last[#campusCities], ['Lyon']);
      expect(find.text('Ville · 1'), findsOneWidget);
    });

    testWidgets(
        'en repli, une ville choisie hors des 20 reste décochable, sans '
        'compte inventé', (tester) async {
      // Étape 1 : la liste complète, on choisit Dijon (hors facette).
      await pump(tester);
      await choose(tester, 'campusCity', ['Dijon']);
      expect(find.text('Ville · 1'), findsOneWidget);
      // Étape 2 : le point d'accès tombe ; la liste de repli n'a pas Dijon.
      stubCities((_) async => throw _http(503));

      await open(tester, 'campusCity');

      expect(checked(tester, 'Dijon'), isTrue);
      // Le compte de Dijon est INCONNU : pas de « 0 ».
      expect(
        find.descendant(of: option('Dijon'), matching: find.text('0')),
        findsNothing,
      );
      expect(applyLabel(tester), 'Voir les formations');
    });

    testWidgets(
        'le texte du champ de recherche principal n\'est pas touché par '
        'la feuille', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), 'droit');
      await settleBounded(tester);
      cityCalls.clear();

      await open(tester, 'campusCity');

      // La feuille tient compte du texte (les villes où l'on trouve « droit »)…
      expect(cityCalls.single[#query], 'droit');
      // …sans y toucher.
      await tester.tapAt(const Offset(180, 10));
      await settleBounded(tester);
      expect(find.widgetWithText(TextField, 'droit'), findsOneWidget);
    });
  });

  // ── Anglais ───────────────────────────────────────────────────────────────

  group('en anglais', () {
    testWidgets('boutons, feuille, états : tout est traduit', (tester) async {
      await pump(tester, locale: const Locale('en'));

      for (final label in ['Level', 'Field', 'City', 'Procedure']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Niveau'), findsNothing);

      await open(tester, 'cycle');
      expect(find.text('Bachelor, year 1'), findsOneWidget);
      expect(applyLabel(tester), 'Show 10029 programmes');
      await tester.tap(option('master'));
      await tester.pump();
      expect(applyLabel(tester), "Show 2771 programmes");
      await tapApply(tester);

      expect(find.text('Level · 1'), findsOneWidget);
      expect(find.text('Clear all'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets('la feuille des villes en anglais : recherche, repli, échec',
        (tester) async {
      stubCities((_) async => throw _http(404));
      await pump(tester, locale: const Locale('en'));
      await open(tester, 'campusCity');

      expect(find.text('Main cities — for another city, type it in the search'),
          findsOneWidget);
      expect(find.text('Search a city'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), 'zzz');
      await tester.pump();
      expect(find.text('No city matches'), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);

      stubCities((_) async => throw _dio(DioExceptionType.connectionError));
      await tester.tapAt(const Offset(180, 10));
      await settleBounded(tester);
      await open(tester, 'campusCity');
      expect(find.text("Couldn't load the cities"), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    test('chaque clé des filtres existe dans les deux langues', () {
      final keys = AppTranslations().keys;
      for (final key in _filterKeys) {
        final fr = keys['fr']![key];
        final en = keys['en']![key];
        expect(fr, isNotNull, reason: '$key manque en français');
        expect(en, isNotNull, reason: '$key manque en anglais');
        expect(fr, isNotEmpty);
        expect(en, isNotEmpty);
        // Une valeur recopiée à l'identique dans les deux langues est presque
        // toujours une traduction oubliée — hormis les noms propres et sigles.
        if (!_sameInBothLanguages.contains(key)) {
          expect(en, isNot(fr), reason: '$key : EN = FR, traduction oubliée ?');
        }
      }
    });
  });

  // ── Contraste : mesuré sur les pixels, en clair ET en sombre ──────────────

  group('contraste >= 4,5:1 (mesuré sur les pixels)', () {
    Finder labelOf(Finder owner) =>
        find.descendant(of: owner, matching: find.byType(Text)).first;

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      group(mode.name, () {
        testWidgets('bouton au repos : texte principal sur fond de carte',
            (tester) async {
          await pump(tester, themeMode: mode);

          final context = tester.element(button('cycle'));
          final tokens = context.kpb;
          final measured =
              await measurePixelContrast(tester, labelOf(button('cycle')));

          expect(measured.ratio, greaterThanOrEqualTo(4.5),
              reason: measured.toString());
          expect(sameColor(measured.background, tokens.cardBg), isTrue,
              reason: 'le fond mesuré n\'est pas celui du bouton : $measured');
          expect(sameColor(measured.foreground, tokens.textPrimary), isTrue,
              reason: measured.toString());
        });

        testWidgets('bouton ACTIF : texte blanc sur fond d\'action',
            (tester) async {
          await pump(tester, themeMode: mode);
          await choose(tester, 'cycle', ['master']);

          final measured =
              await measurePixelContrast(tester, labelOf(button('cycle')));

          expect(measured.ratio, greaterThanOrEqualTo(4.5),
              reason: measured.toString());
          expect(
              sameColor(measured.background, KpbColors.actionPrimary), isTrue,
              reason: 'le fond mesuré n\'est pas celui du bouton : $measured');
          expect(sameColor(measured.foreground, KpbColors.textOnDark), isTrue,
              reason: measured.toString());
        });

        testWidgets('puce de filtre actif', (tester) async {
          await pump(tester, themeMode: mode);
          await choose(tester, 'cycle', ['master']);

          final context = tester.element(chip('cycle', 'master'));
          final measured = await measurePixelContrast(
              tester, labelOf(chip('cycle', 'master')));

          expect(measured.ratio, greaterThanOrEqualTo(4.5),
              reason: measured.toString());
          expect(sameColor(measured.background, context.kpb.skyLight), isTrue,
              reason: measured.toString());
        });

        testWidgets('bouton « Voir N formations » de la feuille',
            (tester) async {
          await pump(tester, themeMode: mode);
          await open(tester, 'cycle');

          final measured = await measurePixelContrast(tester, labelOf(apply));

          expect(measured.ratio, greaterThanOrEqualTo(4.5),
              reason: measured.toString());
        });

        // La case est le SEUL signe de la sélection : son contour est un composant
        // d'interface, donc 3:1 au moins (WCAG 1.4.11) — le thème seul donnait
        // 1,48:1 en clair et 2,03:1 en sombre.
        testWidgets('case à cocher : contour >= 3:1, vide ET cochée',
            (tester) async {
          await pump(tester, themeMode: mode);
          await open(tester, 'cycle');
          final box = find.descendant(
              of: option('licence1'), matching: find.byType(Checkbox));

          final empty = await measurePixelContrast(tester, box);
          expect(empty.ratio, greaterThanOrEqualTo(3.0),
              reason: 'case vide : $empty');

          await tester.tap(option('licence1'));
          await tester.pump(const Duration(milliseconds: 300));
          final filled = await measurePixelContrast(tester, box);
          expect(filled.ratio, greaterThanOrEqualTo(3.0),
              reason: 'case cochée : $filled');
        });

        testWidgets('libellé et compte d\'une case de la feuille',
            (tester) async {
          await pump(tester, themeMode: mode);
          await open(tester, 'cycle');

          final texts = find.descendant(
              of: option('master'), matching: find.byType(Text));
          expect(texts, findsNWidgets(2));
          for (var i = 0; i < 2; i++) {
            final measured = await measurePixelContrast(tester, texts.at(i));
            expect(measured.ratio, greaterThanOrEqualTo(4.5),
                reason: 'texte $i : $measured');
          }
        });

        testWidgets('« Tout effacer », « Effacer » et le texte d\'état',
            (tester) async {
          await pump(tester, themeMode: mode);
          await choose(tester, 'cycle', ['master']);

          final clearAll = find.descendant(
              of: find.byKey(const ValueKey('eef-active-clear-all')),
              matching: find.byType(Text));
          var measured = await measurePixelContrast(tester, clearAll);
          expect(measured.ratio, greaterThanOrEqualTo(4.5),
              reason: 'Tout effacer : $measured');

          await open(tester, 'cycle');
          await tester.tap(option('licence1'));
          await tester.pump();
          measured = await measurePixelContrast(
              tester,
              find.descendant(
                  of: find.byKey(const ValueKey('eef-filter-sheet-clear')),
                  matching: find.byType(Text)));
          expect(measured.ratio, greaterThanOrEqualTo(4.5),
              reason: 'Effacer : $measured');
        });
      });
    }

    // Un harnais qui ne sait pas mordre ne prouve rien. L'ANCIENNE puce — un
    // `FilterChip` sélectionné dont le libellé portait `KpbTextStyles.caption`
    // (gris) — doit être jugée illisible par la MÊME mesure.
    testWidgets(
        'CANARI : l\'ancienne puce (caption gris sur bleu) est jugée '
        'illisible', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(),
          home: Scaffold(
            body: Center(
              child: FilterChip(
                selected: true,
                showCheckmark: false,
                onSelected: (_) {},
                label: Text(
                  'Master · 2771',
                  style: KpbTextStyles.caption,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final measured = await measurePixelContrast(
        tester,
        find.descendant(
            of: find.byType(FilterChip), matching: find.byType(Text)),
      );

      expect(sameColor(measured.background, KpbColors.actionPrimary), isTrue,
          reason: 'le canari doit peindre le fond bleu : $measured');
      expect(measured.ratio, lessThan(1.5),
          reason: 'la mesure doit voir le défaut (1,09:1 attendu) : $measured');
    });

    test('la formule WCAG : valeurs de référence', () {
      expect(wcagContrast(const Color(0xFFFFFFFF), const Color(0xFF000000)),
          closeTo(21, 0.01));
      expect(wcagContrast(KpbColors.textOnDark, KpbColors.actionPrimary),
          closeTo(5.17, 0.05));
      expect(wcagContrast(KpbColors.textMuted, KpbColors.actionPrimary),
          closeTo(1.09, 0.02));
    });
  });

  // ── Accessibilité ─────────────────────────────────────────────────────────

  group('accessibilité', () {
    testWidgets('chaque bouton dit son nom, son état et son nombre de choix',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);

      var node = tester.getSemantics(button('campusCity'));
      expect(node.label, 'Ville');
      expect(node.value, 'Aucun choix');
      expect(node.hint, 'Ouvre la liste des choix');
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.isSelected, ui.Tristate.isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

      await choose(tester, 'campusCity', ['Paris', 'Lyon']);

      node = tester.getSemantics(button('campusCity'));
      expect(node.label, 'Ville');
      expect(node.value, '2 choix');
      expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
      handle.dispose();
    });

    testWidgets('une case dit son libellé, son compte et son état coché',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await open(tester, 'cycle');

      var node = tester.getSemantics(option('master'));
      expect(node.label, 'Master, 2771 formation(s)');
      expect(node.flagsCollection.isChecked, ui.CheckedState.isFalse);

      await tester.tap(option('master'));
      await tester.pump();
      node = tester.getSemantics(option('master'));
      expect(node.flagsCollection.isChecked, ui.CheckedState.isTrue);
      handle.dispose();
    });

    testWidgets('au clavier : UN seul arrêt de focus par ligne, dans l\'ordre',
        (tester) async {
      await pump(tester);
      await open(tester, 'cycle');

      // Le widget à clé le plus proche au-dessus du nœud qui a le focus.
      String? owner(FocusNode? node) {
        String? found;
        node?.context?.visitAncestorElements((element) {
          final key = element.widget.key;
          if (key is ValueKey<String> && key.value.startsWith('eef-filter-')) {
            found = key.value;
            return false;
          }
          return true;
        });
        return found;
      }

      final stops = <String?>[];
      for (var i = 0; i < 9; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        stops.add(owner(FocusManager.instance.primaryFocus));
      }

      expect(
          stops,
          [
            for (final value in [
              'licence1',
              'licence2',
              'licence3',
              'but1',
              'deust',
              'sante',
              'ingenieur',
              'master',
            ])
              'eef-filter-option-$value',
            'eef-filter-sheet-apply',
          ],
          reason: 'la case et sa ligne ne doivent pas compter deux arrêts');
    });

    testWidgets('une puce dit qu\'elle retire le filtre', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await choose(tester, 'cycle', ['master']);

      final node = tester.getSemantics(chip('cycle', 'master'));
      expect(node.label, 'Retirer le filtre Master');
      expect(node.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('en anglais, les mêmes informations', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, locale: const Locale('en'));
      await choose(tester, 'cycle', ['master']);

      final node = tester.getSemantics(button('cycle'));
      expect(node.label, 'Level');
      expect(node.value, '1 selected');
      handle.dispose();
    });

    testWidgets('le titre de la feuille est un en-tête', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester);
      await open(tester, 'cycle');

      final title = find.descendant(of: sheet, matching: find.text('Niveau'));
      expect(tester.getSemantics(title).flagsCollection.isHeader, isTrue);
      handle.dispose();
    });
  });

  // ── Cibles tactiles ───────────────────────────────────────────────────────

  group('cibles tactiles >= 48 dp', () {
    void expectBig(WidgetTester tester, Finder finder, String what) {
      expect(finder, findsWidgets, reason: what);
      for (final element in finder.evaluate()) {
        final size = (element.renderObject! as RenderBox).size;
        expect(size.width, greaterThanOrEqualTo(48), reason: '$what : $size');
        expect(size.height, greaterThanOrEqualTo(48), reason: '$what : $size');
      }
    }

    for (final scale in kpbTextScales) {
      testWidgets('boutons, puces, « Tout effacer » — ×$scale', (tester) async {
        await pump(tester, textScale: scale);
        await choose(tester, 'cycle', ['master', 'licence1']);

        for (final key in ['cycle', 'fieldId', 'campusCity', 'procedureType']) {
          expectBig(tester, button(key), 'bouton $key');
        }
        expectBig(tester, chip('cycle', 'master'), 'puce master');
        expectBig(tester, chip('cycle', 'licence1'), 'puce licence1');
        expectBig(tester, find.byKey(const ValueKey('eef-active-clear-all')),
            'Tout effacer');
      });

      testWidgets('cases, « Effacer », « Voir », « Réessayer » — ×$scale',
          (tester) async {
        await pump(tester, textScale: scale);
        await open(tester, 'cycle');
        await tester.tap(option('master'));
        await tester.pump();

        expectBig(tester, find.byType(Checkbox), 'case');
        for (final value in optionValues(tester)) {
          expectBig(tester, option(value), 'ligne $value');
        }
        expectBig(tester, find.byKey(const ValueKey('eef-filter-sheet-clear')),
            'Effacer');
        expectBig(tester, apply, 'Voir N formations');
      });
    }

    testWidgets('« Réessayer » de la feuille des villes', (tester) async {
      stubCities((_) async => throw _dio(DioExceptionType.connectionError));
      await pump(tester, textScale: 1.3);
      await open(tester, 'campusCity');
      expectBig(tester, find.byKey(const ValueKey('eef-filter-sheet-retry')),
          'Réessayer');
    });
  });

  // ── Géométrie : 360 dp, texte à 1,3 ───────────────────────────────────────

  group('géométrie — aucun débordement, aucun texte coupé', () {
    void expectClean(WidgetTester tester, String where) {
      expect(truncatedTexts(tester), isEmpty, reason: where);
      expect(rawTranslationKeysOnScreen(tester), isEmpty, reason: where);
    }

    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets(
            '${viewport.id} ×$scale — barre, puces et les quatre '
            'feuilles', (tester) async {
          final report =
              await pump(tester, viewport: viewport, textScale: scale);
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expectClean(tester, 'barre');

          // Des choix aux libellés LONGS, pour que les puces passent à la ligne.
          await choose(tester, 'fieldId', ['d08', 'd01', 'd09']);
          await choose(tester, 'cycle', ['licence1', 'master']);
          await choose(tester, 'campusCity', ['Villeneuve-d\'Ascq', 'Paris']);
          await choose(tester, 'procedureType', ['dap_blanche']);
          expectClean(tester, 'barre + puces');
          expect(tester.takeException(), isNull);

          for (final key in [
            'cycle',
            'fieldId',
            'campusCity',
            'procedureType'
          ]) {
            await open(tester, key);
            expectClean(tester, 'feuille $key');
            expect(tester.takeException(), isNull, reason: 'feuille $key');
            await tester.tapAt(const Offset(180, 10));
            await settleBounded(tester);
          }
        });
      }
    }

    testWidgets(
        'états de la feuille des villes à 360 × 1,3 : chargement, '
        'échec, repli, vide', (tester) async {
      final gate = Completer<Map<String, dynamic>>();
      stubCities((_) => gate.future);
      await pump(tester, textScale: 1.3);

      await open(tester, 'campusCity');
      expectClean(tester, 'chargement');
      expect(tester.takeException(), isNull);

      gate.completeError(_dio(DioExceptionType.connectionError));
      await settleBounded(tester);
      expectClean(tester, 'échec');
      expect(tester.takeException(), isNull);

      await tester.tapAt(const Offset(180, 10));
      await settleBounded(tester);
      stubCities((_) async => throw _http(404));
      await open(tester, 'campusCity');
      expectClean(tester, 'repli');
      expect(tester.takeException(), isNull);

      await tester.enterText(
          find.byKey(const ValueKey('eef-filter-sheet-search')), 'zzzz');
      await tester.pump();
      expectClean(tester, 'vide');
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'clavier ouvert (300 dp) sur 360 × 640 à 1,3 : l\'écran et la '
        'recherche de ville tiennent, « Voir » reste visible', (tester) async {
      const small = KpbViewport(
        id: 'android360x640',
        name: 'Android 360×640',
        size: Size(360, 640),
        padding: EdgeInsets.only(top: 24),
      );
      const keyboard = EdgeInsets.only(bottom: 300);
      final report = await pump(
        tester,
        viewport: small,
        textScale: 1.3,
        viewInsets: keyboard,
      );
      expect(report.overflows, isEmpty, reason: report.toString());

      // Les deux PREMIÈRES lignes de chaque feuille : sous un clavier de 300 dp la
      // feuille est basse, et on n'éprouve pas ici le défilement mais la tenue.
      await choose(tester, 'fieldId', ['d10', 'd11']);
      await choose(tester, 'cycle', ['licence1', 'licence2']);
      expect(tester.takeException(), isNull);
      // L'en-tête des filtres est borné sur la hauteur libre du CORPS (260 dp ici),
      // pas sur celle de l'écran : il défile dans sa zone au lieu de pousser la
      // liste et le pied hors de l'écran.
      final bodyHeight = 640 - 300 - 80; // écran − clavier − barre d'app
      expect(tester.getSize(find.byType(EefFilterHeader)).height,
          lessThanOrEqualTo(bodyHeight * 0.34 + 0.5));
      expect(tester.getRect(find.byType(EefSourcesRow)).bottom,
          lessThanOrEqualTo(640 - 300 + 0.5),
          reason: 'le pied de page doit rester au-dessus du clavier');

      await open(tester, 'campusCity');
      await tester.tap(find.byKey(const ValueKey('eef-filter-sheet-search')));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(apply).bottom, lessThanOrEqualTo(640 - 300 + 0.5),
          reason: 'le bouton de validation doit rester au-dessus du clavier');
      expect(tester.getRect(apply).top, greaterThanOrEqualTo(0));
    });

    testWidgets('thème sombre à 360 × 1,3 : mêmes garanties', (tester) async {
      final report = await pump(
        tester,
        textScale: 1.3,
        themeMode: ThemeMode.dark,
      );
      expect(report.overflows, isEmpty, reason: report.toString());
      await choose(tester, 'fieldId', ['d08']);
      await open(tester, 'campusCity');
      expectClean(tester, 'sombre');
      expect(tester.takeException(), isNull);
    });
  });

  // ── Le code source ne ramène pas le défaut ────────────────────────────────

  test('SOURCES : aucune couleur en dur dans les filtres', () {
    final source =
        File('lib/app/features/etudes_en_france/eef_catalog_filters.dart')
            .readAsStringSync();
    expect(RegExp(r'Color\(0x').hasMatch(source), isFalse,
        reason: 'une couleur en dur : utilise KpbColors / context.kpb');
    // `KpbColors.` contient « Colors. » : on cherche la classe Flutter seule.
    expect(RegExp(r'(?<![A-Za-z])Colors\.').hasMatch(source), isFalse,
        reason: 'ni Colors.white ni Colors.grey : les tokens suffisent');
    expect(source.contains('FilterChip'), isFalse);
    expect(source.contains('ChoiceChip'), isFalse);
  });

  test('SOURCES : l\'écran n\'a plus l\'ancienne barre de puces', () {
    final screen =
        File('lib/app/features/etudes_en_france/eef_catalog_screen.dart')
            .readAsStringSync();
    expect(screen.contains('_FacetBar'), isFalse);
    expect(screen.contains('FilterChip'), isFalse);
    expect(screen.contains('EefFilterHeader'), isTrue);
  });
}
