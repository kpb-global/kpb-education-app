// L'aide à l'étape « Préparer mon dossier » (build 55) : une ligne dans chacun
// des trois écrans d'outils — CV, lettres de motivation, entretien —,
// UNIQUEMENT quand l'écran est ouvert depuis le hub de l'espace « Études en
// France ».
//
// Ces écrans servent aussi ailleurs dans l'app (la boîte à outils, le tiroir
// « Outils KPB », le dossier d'un étudiant, le coach) : là, rien ne change. Le
// hub le dit par un PARAMÈTRE EXPLICITE (`fromEefHub`), pas par un état global.
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · ouvert depuis le hub, chaque outil montre sa ligne d'aide ; ouvert
//     ailleurs, aucun des trois n'en montre ;
//   · le tap ouvre WhatsApp avec un message qui dit de QUEL outil il s'agit, et
//     aucune donnée personnelle ;
//   · un compte dont le pays est suspendu voit la ligne, au libellé et au
//     message neutres ;
//   · la ligne ne fait pas déborder l'écran, à 360 dp × 1,3, en FR comme en EN.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_line.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/tools/cv_generator_screen.dart';
import 'package:karatou/app/features/tools/interview_simulator_screen.dart';
import 'package:karatou/app/features/tools/motivation_letters_screen.dart';
import 'package:karatou/app/features/tools/student_tools_screen.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

/// Un outil : son écran, avec et sans le paramètre du hub, et ce qu'il dit.
class _Tool {
  const _Tool({
    required this.name,
    required this.trigger,
    required this.build,
    required this.frQuestion,
    required this.enQuestion,
    required this.frLabel,
    required this.enLabel,
    required this.hubTile,
    required this.screenType,
  });

  final String name;
  final EefHelpTrigger trigger;
  final Widget Function({required bool fromEefHub}) build;
  final String frQuestion;
  final String enQuestion;
  final String frLabel;
  final String enLabel;

  /// Le titre de la tuile du hub qui l'ouvre (clé de traduction).
  final String hubTile;

  /// Le type de l'écran : un tap qui n'ouvrirait RIEN ne doit pas faire passer
  /// « aucune ligne » pour un succès.
  final Type screenType;
}

final _tools = <_Tool>[
  _Tool(
    name: 'CV',
    trigger: EefHelpTrigger.toolCv,
    build: ({required fromEefHub}) => CvGeneratorScreen(fromEefHub: fromEefHub),
    frQuestion: "Besoin d'aide pour rédiger ton CV ?",
    enQuestion: 'Need help writing your CV?',
    frLabel: 'CV',
    enLabel: 'CV',
    hubTile: 'cv_generator_title',
    screenType: CvGeneratorScreen,
  ),
  _Tool(
    name: 'lettres de motivation',
    trigger: EefHelpTrigger.toolLetters,
    build: ({required fromEefHub}) =>
        MotivationLettersScreen(fromEefHub: fromEefHub),
    frQuestion: "Besoin d'aide pour ta lettre de motivation ?",
    enQuestion: 'Need help with your motivation letter?',
    frLabel: 'lettre de motivation',
    enLabel: 'motivation letter',
    hubTile: 'letters_title',
    screenType: MotivationLettersScreen,
  ),
  _Tool(
    name: 'entretien',
    trigger: EefHelpTrigger.toolInterview,
    build: ({required fromEefHub}) =>
        InterviewSimulatorScreen(fromEefHub: fromEefHub),
    frQuestion: "Besoin d'aide pour préparer ton entretien ?",
    enQuestion: 'Need help preparing for your interview?',
    frLabel: "préparation d'entretien",
    enLabel: 'interview preparation',
    hubTile: 'interview_title',
    screenType: InterviewSimulatorScreen,
  ),
];

final _openAFileWording = RegExp(
  r'dossier|d[ée]marrer|campus\s*france|\bstart\b|\bfile\b|\breview\b',
  caseSensitive: false,
);

/// Les textes tronqués PAR une mise en page, sous [scope] seulement : l'écran
/// d'outil a ses propres défauts préexistants, que ce fichier ne juge pas.
List<String> _truncatedUnder(WidgetTester tester, Finder scope) {
  final out = <String>[];
  for (final element in find
      .descendant(of: scope, matching: find.byType(RichText))
      .evaluate()) {
    final renderObject = element.renderObject;
    if (renderObject is RenderParagraph && renderObject.didExceedMaxLines) {
      out.add(renderObject.text.toPlainText());
    }
  }
  return out;
}

void main() {
  setUpAll(initializeDateFormatting);

  late MockApiClient api;
  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics analytics;

  setUp(() {
    api = MockApiClient();
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    analytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = analytics;
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = true;
    AppConfig.eefSpaceEnabledOverride = true;
    Get.locale = const Locale('fr');
    EefCalendar.windowSource = () => const EefCampaignWindow(
          suspendedCountries: ['Niger'],
          suspendedSources: {
            'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
          },
        );
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.aiToolsEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = null;
    Get.reset();
  });

  Future<AppSnapshot> snapshotFor(String country, Locale locale) async =>
      AppSnapshot(
        localeCode: locale.languageCode,
        hasCompletedOnboarding: true,
        profile: createTestProfile(
          countryOfResidence: country,
          fullName: 'Awa Koné-Diallo',
          email: 'awa.kone.diallo@example.org',
          phone: '+221770001122',
        ),
      );

  Future<KpbScreenReport> pumpTool(
    WidgetTester tester,
    Widget screen, {
    String country = 'Sénégal',
    Locale locale = const Locale('fr'),
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    ThemeMode themeMode = ThemeMode.light,
  }) async {
    await seedKpbController(
      apiClient: api,
      snapshot: await snapshotFor(country, locale),
    );
    return pumpKpbScreen(
      tester,
      screen: screen,
      viewport: viewport,
      textScale: textScale,
      locale: locale,
      themeMode: themeMode,
    );
  }

  const ask = "Demander de l'aide";

  // ── Seulement depuis le hub ─────────────────────────────────────────────────

  group('seulement quand l\'écran est ouvert DEPUIS le hub', () {
    for (final tool in _tools) {
      testWidgets('${tool.name} : sans le paramètre, aucune ligne',
          (tester) async {
        await pumpTool(tester, tool.build(fromEefHub: false));

        expect(find.byType(EefHelpLine), findsNothing);
        expect(find.text(tool.frQuestion), findsNothing);
        expect(find.text(ask), findsNothing);
        expect(analytics.shownCalls, isEmpty);
      });

      testWidgets('${tool.name} : avec le paramètre, la ligne', (tester) async {
        await pumpTool(tester, tool.build(fromEefHub: true));

        expect(find.byType(EefHelpLine), findsOneWidget);
        expect(find.text(tool.frQuestion), findsOneWidget);
        expect(find.text(ask), findsOneWidget);
        // UNE ligne : ni carte pleine, ni bouton plein.
        expect(find.byType(EefHelpCard), findsNothing);
        expect(find.text('eef_help_fineprint'.tr), findsOneWidget);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);
      });

      testWidgets('${tool.name} : le tap nomme l\'outil, rien de personnel',
          (tester) async {
        await pumpTool(tester, tool.build(fromEefHub: true));

        await tester.tap(find.text(ask));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(Uri.parse(launcher.launched.single).host, 'wa.me');
        expect(
          launcher.lastText,
          "Bonjour KPB Education, je suis dans l'espace Études en France de "
          "l'app, sur l'outil « ${tool.frLabel} ». J'aimerais de l'aide.",
        );
        for (final secret in [
          'Awa',
          'Koné',
          'Diallo',
          'example.org',
          '221',
          'Sénégal',
        ]) {
          expect(launcher.lastText, isNot(contains(secret)));
        }
        expect(analytics.tappedCalls,
            [RecordedHelpEvent(tool.trigger.key, 'tools', 'compact')]);
      });

      testWidgets('${tool.name} : compte du Niger, ligne neutre',
          (tester) async {
        await pumpTool(tester, tool.build(fromEefHub: true), country: 'Niger');

        expect(find.text(tool.frQuestion), findsOneWidget);
        expect(find.text('Parler à un conseiller'), findsOneWidget);
        expect(find.text(ask), findsNothing);

        await tester.tap(find.text('Parler à un conseiller'));
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          "Bonjour KPB Education, je regarde l'outil « ${tool.frLabel} » dans "
          "l'espace Études en France de l'app. La procédure est suspendue "
          "dans mon pays : j'aimerais savoir quelles options existent.",
        );
        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        for (final forbidden in ['Niger', 'Togo', 'Awa']) {
          expect(launcher.lastText, isNot(contains(forbidden)));
        }
      });

      testWidgets('${tool.name} : en anglais', (tester) async {
        await pumpTool(
          tester,
          tool.build(fromEefHub: true),
          locale: const Locale('en'),
        );

        expect(find.text(tool.enQuestion), findsOneWidget);
        await tester.tap(find.text('Ask for help'));
        await tester.pumpAndSettle();

        expect(
          launcher.lastText,
          'Hello KPB Education, I am in the Études en France space of the '
          'app, on the “${tool.enLabel}” tool. I would like some help.',
        );
      });

      testWidgets('${tool.name} : en anglais, compte du Niger', (tester) async {
        await pumpTool(
          tester,
          tool.build(fromEefHub: true),
          locale: const Locale('en'),
          country: 'Niger',
        );

        expect(find.text('Talk to an advisor'), findsOneWidget);
        await tester.tap(find.text('Talk to an advisor'));
        await tester.pumpAndSettle();

        expect(_openAFileWording.hasMatch(launcher.lastText), isFalse,
            reason: launcher.lastText);
        expect(
            launcher.lastText,
            contains('procedure is suspended in my '
                'country'));
        expect(launcher.lastText, isNot(contains('Niger')));
      });
    }
  });

  // ── Les autres portes ne changent PAS ───────────────────────────────────────

  group('les autres portes d\'entrée restent inchangées', () {
    testWidgets('la boîte à outils étudiants ouvre les trois sans ligne',
        (tester) async {
      await pumpTool(tester, const StudentToolsScreen());

      for (final tool in _tools) {
        await tester.tap(find.text(tool.hubTile.tr).first);
        await tester.pumpAndSettle();

        // L'outil est BIEN ouvert (sinon « aucune ligne » ne prouverait rien).
        expect(find.byType(tool.screenType), findsOneWidget,
            reason: 'la tuile ${tool.name} n\'a rien ouvert');
        expect(find.text(tool.frQuestion), findsNothing,
            reason: '${tool.name} ouvert depuis la boîte à outils');
        expect(find.byType(EefHelpLine), findsNothing);

        // Retour à la boîte à outils.
        Get.back<void>();
        await tester.pumpAndSettle();
      }
    });

    test('seul le hub de l\'espace passe `fromEefHub: true`', () {
      // Un autre appelant qui passerait le paramètre ferait apparaître l'aide
      // « Études en France » dans un écran qui n'est pas de l'espace.
      final offenders = <String>[];
      final files = [
        'lib/app/features/tools/student_tools_screen.dart',
        'lib/app/features/shell/kpb_tools_drawer.dart',
        'lib/app/features/cases/case_detail_screen.dart',
        'lib/app/features/ai_advisor/ai_chat_screen.dart',
      ];
      for (final path in files) {
        final source = File(path).readAsStringSync();
        if (source.contains('fromEefHub')) offenders.add(path);
      }
      expect(offenders, isEmpty);

      // Le code, pas les commentaires : le hub explique le paramètre dans un
      // commentaire, qui ne doit pas compter pour un appel.
      final hub = File('lib/app/features/etudes_en_france/eef_home_screen.dart')
          .readAsLinesSync()
          .where((line) => !line.trimLeft().startsWith('//'))
          .join('\n');
      expect(RegExp('fromEefHub:\\s*true').allMatches(hub).length, 3,
          reason: 'le hub ouvre exactement trois outils');
    });
  });

  // ── Depuis le hub, pour de vrai ─────────────────────────────────────────────

  group('depuis le hub', () {
    for (final tool in _tools) {
      testWidgets('la tuile « ${tool.name} » ouvre l\'outil AVEC sa ligne',
          (tester) async {
        when(() => api.getEefInterest())
            .thenAnswer((_) async => <String, dynamic>{'declared': false});
        await seedKpbController(
          apiClient: api,
          snapshot: await snapshotFor('Sénégal', const Locale('fr')),
        );
        await pumpKpbScreen(
          tester,
          screen: const EefHomeScreen(),
          viewport: const KpbViewport(
            id: 'tall',
            name: 'Écran haut 393×2600',
            size: Size(393, 2600),
            padding: EdgeInsets.zero,
          ),
        );

        await tester.tap(find.text(tool.hubTile.tr).first);
        await tester.pumpAndSettle();

        expect(find.byType(tool.screenType), findsOneWidget);
        expect(find.text(tool.frQuestion), findsOneWidget,
            reason: 'la ligne d\'aide de ${tool.name}');
        expect(find.byType(EefHelpLine), findsOneWidget);
      });
    }

    testWidgets('compte du Niger : le hub ouvre la ligne neutre',
        (tester) async {
      when(() => api.getEefInterest())
          .thenAnswer((_) async => <String, dynamic>{'declared': false});
      await seedKpbController(
        apiClient: api,
        snapshot: await snapshotFor('Niger', const Locale('fr')),
      );
      await pumpKpbScreen(
        tester,
        screen: const EefHomeScreen(),
        viewport: const KpbViewport(
          id: 'tall',
          name: 'Écran haut 393×2600',
          size: Size(393, 2600),
          padding: EdgeInsets.zero,
        ),
      );

      await tester.tap(find.text('cv_generator_title'.tr).first);
      await tester.pumpAndSettle();

      expect(find.text("Besoin d'aide pour rédiger ton CV ?"), findsOneWidget);
      expect(find.text('Parler à un conseiller'), findsOneWidget);
      expect(find.text(ask), findsNothing);
    });
  });

  // ── Mesure ──────────────────────────────────────────────────────────────────

  group('la mesure', () {
    testWidgets('« vue » part UNE fois par visite de l\'écran', (tester) async {
      await pumpTool(tester, _tools.first.build(fromEefHub: true));
      expect(analytics.shownCalls,
          [const RecordedHelpEvent('tool_cv', 'tools', 'compact')]);

      RemoteFeatureFlags.instance.flagsVersion.value += 1;
      await tester.pumpAndSettle();
      expect(analytics.shownCalls, hasLength(1));
    });

    testWidgets('un écran ouvert ailleurs ne mesure RIEN', (tester) async {
      for (final tool in _tools) {
        await pumpTool(tester, tool.build(fromEefHub: false));
      }
      expect(analytics.shownCalls, isEmpty);
      expect(analytics.tappedCalls, isEmpty);
    });
  });

  // ── Géométrie ───────────────────────────────────────────────────────────────

  group('géométrie à 360 dp, échelle de texte 1,3', () {
    for (final tool in _tools) {
      for (final locale in ['fr', 'en']) {
        for (final country in ['Sénégal', 'Niger']) {
          testWidgets('${tool.name} $locale — $country', (tester) async {
            // Le « défaut de base » : l'écran SANS la ligne. La ligne n'a pas à
            // réparer un débordement préexistant, seulement à ne pas en ajouter.
            final base = await pumpTool(
              tester,
              tool.build(fromEefHub: false),
              viewport: compactAndroid,
              textScale: 1.3,
              locale: Locale(locale),
              country: country,
            );
            final withLine = await pumpTool(
              tester,
              tool.build(fromEefHub: true),
              viewport: compactAndroid,
              textScale: 1.3,
              locale: Locale(locale),
              country: country,
            );

            expect(find.byType(EefHelpLine), findsOneWidget);
            expect(withLine.overflows.length,
                lessThanOrEqualTo(base.overflows.length),
                reason: 'la ligne ajoute un débordement : $withLine');
            expect(withLine.otherErrors, isEmpty, reason: withLine.toString());
            expect(_truncatedUnder(tester, find.byType(EefHelpLine)), isEmpty);
            expect(rawTranslationKeysOnScreen(tester), isEmpty);

            // Cible tactile : 48 dp au moins.
            final size = tester.getSize(find.descendant(
              of: find.byType(EefHelpLine),
              matching: find.byType(TextButton),
            ));
            expect(size.height, greaterThanOrEqualTo(48));
          });
        }
      }
    }
  });
}
