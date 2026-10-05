// Les déclencheurs d'aide de la build 55 (EefHelpLine), éprouvés seuls : les
// messages WhatsApp qu'ils écrivent, la règle qui choisit UNE ligne d'aide dans
// le catalogue, les textes (FR et EN, normal et neutre), la mesure, la géométrie
// et le contraste.
//
// Ce que ce fichier garantit, pour l'étudiant :
//   · un message prérempli NOMME ce que l'étudiant regardait (formation,
//     filtres, outil) et ne contient AUCUNE donnée personnelle ;
//   · un message ne dépasse jamais sa borne, et ce qu'il cite est coupé
//     proprement (jamais au milieu d'un mot ni d'un emoji) — WhatsApp tronque
//     les liens trop longs ;
//   · un compte dont le pays est suspendu VOIT les déclencheurs (décision du
//     propriétaire, 03/10/2026) mais n'y lit jamais « démarrer l'étude de ton
//     dossier », ni un pays de remplacement, ni son propre pays ;
//   · la mesure ne porte que l'étape, l'écran et la forme — jamais l'intitulé
//     d'une formation, un filtre, une ville.
//
// Le lanceur d'URL est intercepté à `UrlLauncherPlatform`, comme dans
// eef_help_card_test.dart : le code de production n'a pas été modifié pour être
// testable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_card.dart';
import 'package:karatou/app/features/etudes_en_france/eef_help_line.dart';

import '../../support/eef_help_fakes.dart';
import '../../support/pixel_contrast.dart';
import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

/// Ce que dirait une invitation à ouvrir un dossier, en français comme en
/// anglais, et le nom de l'opérateur de l'État : aucun texte destiné à un pays
/// suspendu ne doit en contenir un seul (même garde que eef_help_card_test.dart).
final _openAFileWording = RegExp(
  r'dossier|d[ée]marrer|campus\s*france|\bstart\b|\bfile\b|\breview\b',
  caseSensitive: false,
);

/// Un outil, tel que l'écrit le message prérempli, ÉCRIT EN DUR : un test qui
/// lirait la même clé que le code ne détecterait pas qu'on l'a vidée.
class _ToolCase {
  const _ToolCase(
    this.trigger, {
    required this.frQuestion,
    required this.enQuestion,
    required this.frLabel,
    required this.enLabel,
  });

  final EefHelpTrigger trigger;
  final String frQuestion;
  final String enQuestion;
  final String frLabel;
  final String enLabel;
}

const _tools = <_ToolCase>[
  _ToolCase(
    EefHelpTrigger.toolCv,
    frQuestion: "Besoin d'aide pour rédiger ton CV ?",
    enQuestion: 'Need help writing your CV?',
    frLabel: 'CV',
    enLabel: 'CV',
  ),
  _ToolCase(
    EefHelpTrigger.toolLetters,
    frQuestion: "Besoin d'aide pour ta lettre de motivation ?",
    enQuestion: 'Need help with your motivation letter?',
    frLabel: 'lettre de motivation',
    enLabel: 'motivation letter',
  ),
  _ToolCase(
    EefHelpTrigger.toolInterview,
    frQuestion: "Besoin d'aide pour préparer ton entretien ?",
    enQuestion: 'Need help preparing for your interview?',
    frLabel: "préparation d'entretien",
    enLabel: 'interview preparation',
  ),
];

String _frToolPrefill(String tool) =>
    "Bonjour KPB Education, je suis dans l'espace Études en France de l'app, "
    "sur l'outil « $tool ». J'aimerais de l'aide.";

String _frToolSuspendedPrefill(String tool) =>
    "Bonjour KPB Education, je regarde l'outil « $tool » dans l'espace Études "
    "en France de l'app. La procédure est suspendue dans mon pays : "
    "j'aimerais savoir quelles options existent.";

String _enToolPrefill(String tool) =>
    'Hello KPB Education, I am in the Études en France space of the app, on '
    'the “$tool” tool. I would like some help.';

String _enToolSuspendedPrefill(String tool) =>
    'Hello KPB Education, I am looking at the “$tool” tool in the Études en '
    'France space of the app. The procedure is suspended in my country: I '
    'would like to know which options exist.';

/// Aucune moitié de paire de substitution : `String.isWellFormed` n'existe qu'à
/// partir de Dart 3.8, et le dépôt déclare un SDK plus ancien.
bool _isWellFormedUtf16(String text) {
  final units = text.codeUnits;
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit >= 0xD800 && unit <= 0xDBFF) {
      final hasLow = i + 1 < units.length &&
          units[i + 1] >= 0xDC00 &&
          units[i + 1] <= 0xDFFF;
      if (!hasLow) return false;
      i++;
    } else if (unit >= 0xDC00 && unit <= 0xDFFF) {
      return false;
    }
  }
  return true;
}

/// Pose le doigt sur le lien, laisse la surcouche et l'encre se peindre, mesure le
/// contraste, puis lève le doigt SANS valider (`cancel` : aucun lancement de
/// WhatsApp).
///
/// Trois `pump` SÉPARÉS : l'encre d'un bouton ne démarre qu'après `kPressTimeout`
/// (100 ms), par un minuteur, et sa première image n'est peinte qu'au cadre
/// SUIVANT — un seul `pump(400 ms)` la laisse à zéro et mesure le repos (première
/// version de cette mesure : « pressé » à l'identique du repos).
Future<PixelContrast> measurePixelContrastWhilePressed(
  WidgetTester tester,
  Finder text,
) async {
  final gesture =
      await tester.startGesture(tester.getCenter(find.byType(TextButton)));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 150));
  await tester.pump(const Duration(milliseconds: 300));
  final measured = await measurePixelContrast(tester, text);
  await gesture.cancel();
  await tester.pumpAndSettle();
  return measured;
}

void main() {
  setUpAll(initializeDateFormatting);

  late RecordingUrlLauncher launcher;
  late UrlLauncherPlatform previousLauncher;
  late RecordingHelpAnalytics analytics;

  EefCampaignWindow window() => const EefCampaignWindow(
        platformUrl: 'https://www.campusfrance.org/fr',
        suspendedCountries: ['Niger'],
        suspendedSources: {
          'niger': 'https://ne.diplomatie.gouv.fr/informations-visas',
        },
      );

  setUp(() {
    previousLauncher = UrlLauncherPlatform.instance;
    launcher = RecordingUrlLauncher();
    UrlLauncherPlatform.instance = launcher;
    analytics = RecordingHelpAnalytics();
    EefHelpCard.analytics = analytics;
    RemoteFeatureFlags.resetForTest();
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    Get.fallbackLocale = const Locale('fr');
    EefCalendar.windowSource = window;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previousLauncher;
    EefHelpCard.resetForTest();
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  // ── Couper proprement ───────────────────────────────────────────────────────

  group('EefHelpMessages.clip', () {
    test('un texte court passe tel quel, espaces normalisés', () {
      expect(EefHelpMessages.clip('  Licence   Droit \n', 80), 'Licence Droit');
      expect(EefHelpMessages.clip('L1 - Droit', 80), 'L1 - Droit');
    });

    test('retire retours à la ligne et caractères de contrôle', () {
      expect(
        EefHelpMessages.clip('Licence\nDroit\t\u0000\u0007 pro', 80),
        'Licence Droit pro',
      );
    });

    test('coupe à une limite de mot et le dit par « … »', () {
      final clipped = EefHelpMessages.clip(
        'Master Droit international et européen des affaires publiques',
        30,
      );
      expect(clipped, 'Master Droit international et…');
      expect(clipped.runes.length, lessThanOrEqualTo(30));
    });

    test('ne laisse pas de ponctuation orpheline avant « … »', () {
      final clipped = EefHelpMessages.clip(
        'Licence, mention droit, parcours carrières judiciaires',
        24,
      );
      expect(clipped, endsWith('…'));
      expect(clipped, isNot(contains(',…')));
      expect(clipped, isNot(contains(' …')));
      expect(clipped.runes.length, lessThanOrEqualTo(24));
    });

    test('un mot unique plus long que la borne est coupé net', () {
      final clipped = EefHelpMessages.clip('A' * 50, 20);
      expect(clipped, '${'A' * 19}…');
    });

    test('ne coupe jamais une paire de substitution (emoji)', () {
      final clipped = EefHelpMessages.clip(
        'Licence ${'😀' * 20}',
        12,
      );
      expect(clipped.runes.length, lessThanOrEqualTo(12));
      expect(clipped.runes, isNot(contains(0xFFFD)));
      // Un texte à moitié coupé ferait lever l'encodage de l'URL WhatsApp.
      expect(() => Uri.encodeComponent(clipped), returnsNormally);
      expect(Uri.decodeComponent(Uri.encodeComponent(clipped)), clipped);
    });

    // Le cas précédent coupe à la limite de mot (l'espace) AVANT d'atteindre une
    // paire de substitution : il ne prouvait pas le comptage en points de code.
    // Ici aucune espace : la coupe tombe au milieu d'une suite d'emojis, et une
    // coupe en unités UTF-16 (`codeUnits`) laisserait une moitié de paire.
    test('sans limite de mot à portée, ne coupe pas un emoji en deux', () {
      for (final max in [4, 5, 6, 7]) {
        final clipped = EefHelpMessages.clip('😀' * 20, max);
        expect(clipped, '${'😀' * (max - 1)}…', reason: 'borne $max');
        expect(clipped.runes.length, max, reason: 'borne $max');
        expect(_isWellFormedUtf16(clipped), isTrue, reason: 'borne $max');
      }
    });

    test('la borne est en points de code, jamais dépassée', () {
      for (final max in [1, 2, 5, 10, 33, 80]) {
        final clipped = EefHelpMessages.clip('é' * 200, max);
        expect(clipped.runes.length, lessThanOrEqualTo(max), reason: '$max');
      }
      expect(EefHelpMessages.clip('abc', 0), '');
    });
  });

  // ── Le message d'une formation ──────────────────────────────────────────────

  group('message d\'une formation', () {
    test('FR : intitulé, université, ville — et rien d\'autre', () {
      expect(
        EefHelpMessages.forProgram(
          program: 'L1 - Droit',
          institution: 'Université Claude Bernard',
          city: 'Lyon',
          suspended: false,
        ),
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
        '(Université Claude Bernard, Lyon) dans l\'espace Études en France de '
        'l\'app et j\'aimerais de l\'aide pour mon dossier.',
      );
    });

    test('FR neutre (pays suspendu) : la procédure est suspendue, sans pays',
        () {
      final text = EefHelpMessages.forProgram(
        program: 'L1 - Droit',
        institution: 'Université Claude Bernard',
        city: 'Lyon',
        suspended: true,
      );
      expect(
        text,
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
        '(Université Claude Bernard, Lyon) dans l\'espace Études en France de '
        'l\'app. La procédure est suspendue dans mon pays : j\'aimerais savoir '
        'quelles options existent.',
      );
      expect(_openAFileWording.hasMatch(text), isFalse, reason: text);
    });

    test('EN, normal et neutre', () {
      Get.locale = const Locale('en');
      expect(
        EefHelpMessages.forProgram(
          program: 'L1 - Law',
          institution: 'Claude Bernard University',
          city: 'Lyon',
          suspended: false,
        ),
        'Hello KPB Education, I am looking at the programme “L1 - Law” '
        '(Claude Bernard University, Lyon) in the Études en France space of '
        'the app and I would like some help with my file.',
      );
      final neutral = EefHelpMessages.forProgram(
        program: 'L1 - Law',
        institution: 'Claude Bernard University',
        city: 'Lyon',
        suspended: true,
      );
      expect(
        neutral,
        'Hello KPB Education, I am looking at the programme “L1 - Law” '
        '(Claude Bernard University, Lyon) in the Études en France space of '
        'the app. The procedure is suspended in my country: I would like to '
        'know which options exist.',
      );
      expect(_openAFileWording.hasMatch(neutral), isFalse, reason: neutral);
    });

    test('sans université ni ville, pas de parenthèses vides', () {
      final text = EefHelpMessages.forProgram(
        program: 'L1 - Droit',
        suspended: false,
      );
      expect(text, contains('« L1 - Droit » dans l\'espace'));
      expect(text, isNot(contains('()')));
      expect(text, isNot(contains('( ')));
      expect(
        EefHelpMessages.forProgram(
          program: 'L1 - Droit',
          institution: '  ',
          city: 'Lyon',
          suspended: false,
        ),
        contains('« L1 - Droit » (Lyon) dans l\'espace'),
      );
    });

    test('BORNÉ : des noms démesurés donnent un message court et propre', () {
      final long = 'Master Droit international, européen et comparé des '
              'affaires publiques et privées — parcours recherche ' *
          3;
      for (final locale in ['fr', 'en']) {
        Get.locale = Locale(locale);
        for (final suspended in [false, true]) {
          final text = EefHelpMessages.forProgram(
            program: long,
            institution: 'Université Paris-Est Créteil Val-de-Marne ' * 4,
            city: 'Villeneuve-d\'Ascq-sur-la-Très-Longue-Rivière ' * 3,
            suspended: suspended,
          );
          expect(text.runes.length,
              lessThanOrEqualTo(EefHelpMessages.maxMessageChars),
              reason: text);
          // Le lien entier reste sous ce que WhatsApp accepte sans tronquer.
          final url = Uri.encodeComponent(text);
          expect(url.length, lessThan(EefHelpMessages.maxEncodedChars),
              reason: '${url.length} caractères encodés');
          expect(text, contains('…'));
          expect(text, isNot(contains('@')));
          expect(text.trim(), text);
        }
      }
    });

    test('un « @ » dans un nom ne rejoue pas un paramètre de traduction', () {
      final text = EefHelpMessages.forProgram(
        program: 'Droit @institution',
        institution: 'Univ @city',
        city: 'Lyon',
        suspended: false,
      );
      expect(text, isNot(contains('@')));
      expect(text, contains('Univ'));
    });
  });

  // ── Le message d'un jeu de filtres ──────────────────────────────────────────

  group('message d\'un jeu de filtres', () {
    test('FR, normal et neutre', () {
      const summary = 'Niveau : Master ; Domaine : Droit ; Ville : Lyon';
      expect(
        EefHelpMessages.forFilters(summary: summary, suspended: false),
        'Bonjour KPB Education, je regarde les formations de l\'espace Études '
        'en France de l\'app ($summary) et j\'hésite. J\'aimerais de l\'aide '
        'pour choisir.',
      );
      final neutral =
          EefHelpMessages.forFilters(summary: summary, suspended: true);
      expect(
        neutral,
        'Bonjour KPB Education, je regarde les formations de l\'espace Études '
        'en France de l\'app ($summary). La procédure est suspendue dans mon '
        'pays : j\'aimerais savoir quelles options existent.',
      );
      expect(_openAFileWording.hasMatch(neutral), isFalse, reason: neutral);
    });

    test('EN, normal et neutre', () {
      Get.locale = const Locale('en');
      const summary = 'Level: Master; Field: Law; City: Lyon';
      expect(
        EefHelpMessages.forFilters(summary: summary, suspended: false),
        'Hello KPB Education, I am looking at the programmes in the Études en '
        'France space of the app ($summary) and I cannot decide. I would like '
        'some help choosing.',
      );
      final neutral =
          EefHelpMessages.forFilters(summary: summary, suspended: true);
      expect(
        neutral,
        'Hello KPB Education, I am looking at the programmes in the Études en '
        'France space of the app ($summary). The procedure is suspended in my '
        'country: I would like to know which options exist.',
      );
      expect(_openAFileWording.hasMatch(neutral), isFalse, reason: neutral);
    });

    // Un résumé vide arrivait à « (…) » : des parenthèses vides dans le message.
    // Rien à citer, rien entre parenthèses — pour tous les blancs possibles.
    test('rien à citer : pas de parenthèses vides (FR, EN, neutre)', () {
      for (final empty in ['', '   ', '\n\t ', '@']) {
        Get.locale = const Locale('fr');
        final fr = EefHelpMessages.forFilters(summary: empty, suspended: false);
        expect(
          fr,
          'Bonjour KPB Education, je regarde les formations de l\'espace Études '
          'en France de l\'app et j\'hésite. J\'aimerais de l\'aide pour '
          'choisir.',
          reason: 'résumé « $empty »',
        );
        final frNeutral =
            EefHelpMessages.forFilters(summary: empty, suspended: true);
        expect(
          frNeutral,
          'Bonjour KPB Education, je regarde les formations de l\'espace Études '
          'en France de l\'app. La procédure est suspendue dans mon pays : '
          'j\'aimerais savoir quelles options existent.',
        );
        expect(_openAFileWording.hasMatch(frNeutral), isFalse,
            reason: frNeutral);

        Get.locale = const Locale('en');
        expect(
          EefHelpMessages.forFilters(summary: empty, suspended: false),
          'Hello KPB Education, I am looking at the programmes in the Études en '
          'France space of the app and I cannot decide. I would like some help '
          'choosing.',
        );
        final enNeutral =
            EefHelpMessages.forFilters(summary: empty, suspended: true);
        expect(
          enNeutral,
          'Hello KPB Education, I am looking at the programmes in the Études en '
          'France space of the app. The procedure is suspended in my country: I '
          'would like to know which options exist.',
        );
        expect(_openAFileWording.hasMatch(enNeutral), isFalse,
            reason: enNeutral);

        for (final text in [fr, frNeutral, enNeutral]) {
          expect(text, isNot(contains('()')));
          expect(text, isNot(contains('( ')));
          expect(text, isNot(contains('@')));
        }
      }
    });

    test('un résumé démesuré est borné et coupé proprement', () {
      final text = EefHelpMessages.forFilters(
        summary: 'Domaine : ${'Énergie, Environnement & Développement ' * 20}',
        suspended: false,
      );
      expect(text.runes.length,
          lessThanOrEqualTo(EefHelpMessages.maxMessageChars));
      expect(Uri.encodeComponent(text).length,
          lessThan(EefHelpMessages.maxEncodedChars));
      expect(text, contains('…'));
    });
  });

  // ── Le message d'un outil ───────────────────────────────────────────────────

  group('message d\'un outil', () {
    for (final tool in _tools) {
      test('${tool.trigger.key} : FR et EN, normal et neutre', () {
        Get.locale = const Locale('fr');
        expect(EefHelpMessages.forTool(tool.trigger, suspended: false),
            _frToolPrefill(tool.frLabel));
        expect(EefHelpMessages.forTool(tool.trigger, suspended: true),
            _frToolSuspendedPrefill(tool.frLabel));

        Get.locale = const Locale('en');
        expect(EefHelpMessages.forTool(tool.trigger, suspended: false),
            _enToolPrefill(tool.enLabel));
        expect(EefHelpMessages.forTool(tool.trigger, suspended: true),
            _enToolSuspendedPrefill(tool.enLabel));
      });
    }

    test('seuls les trois outils ont un message d\'outil', () {
      expect(
        () => EefHelpMessages.forTool(EefHelpTrigger.catalogProgram,
            suspended: false),
        throwsAssertionError,
      );
    });
  });

  // ── UNE ligne d'aide à la fois dans le catalogue ────────────────────────────

  group('quelle ligne d\'aide le catalogue montre', () {
    EefCatalogHelpLine decide({
      required bool confusing,
      required bool filters,
      required bool suspended,
    }) =>
        eefCatalogHelpLineFor(
          confusingProcedure: confusing,
          filtersActive: filters,
          suspended: suspended,
        );

    test('rien à signaler : aucune ligne', () {
      for (final suspended in [false, true]) {
        expect(decide(confusing: false, filters: false, suspended: suspended),
            EefCatalogHelpLine.none);
      }
    });

    test('un filtre posé : la ligne des filtres', () {
      for (final suspended in [false, true]) {
        expect(decide(confusing: false, filters: true, suspended: suspended),
            EefCatalogHelpLine.filters);
      }
    });

    test('la ligne de procédure GARDE LA PRIORITÉ sur celle des filtres', () {
      expect(decide(confusing: true, filters: true, suspended: false),
          EefCatalogHelpLine.procedure);
      expect(decide(confusing: true, filters: false, suspended: false),
          EefCatalogHelpLine.procedure);
    });

    // La ligne de procédure disparaît pour un pays suspendu (règle de la
    // build 54) : lui laisser la priorité ne montrerait alors AUCUNE ligne à un
    // étudiant qui filtre — alors que le propriétaire veut qu'il voie
    // l'invitation neutre.
    test('pays suspendu : la ligne de procédure est invisible, donc cède', () {
      expect(decide(confusing: true, filters: true, suspended: true),
          EefCatalogHelpLine.filters);
      expect(decide(confusing: true, filters: false, suspended: true),
          EefCatalogHelpLine.none);
    });
  });

  // ── Les textes ──────────────────────────────────────────────────────────────

  group('les textes', () {
    final keys = AppTranslations().keys;

    Set<String> keysFor(EefHelpTrigger trigger) => {
          if (trigger.hasQuestion) 'eef_help_${trigger.key}_question',
          if (trigger.isTool) 'eef_help_${trigger.key}_label',
        };

    const shared = {
      'eef_help_line_cta',
      'eef_help_line_neutral_cta',
      'eef_help_line_subject',
      'eef_help_line_neutral_subject',
      'eef_help_filters_family',
      'eef_help_prefill_program',
      'eef_help_prefill_program_suspended',
      'eef_help_prefill_filters',
      'eef_help_prefill_filters_suspended',
      'eef_help_prefill_filters_none',
      'eef_help_prefill_filters_none_suspended',
      'eef_help_prefill_tool',
      'eef_help_prefill_tool_suspended',
    };

    test('chaque déclencheur a TOUS ses textes, en français ET en anglais', () {
      for (final locale in ['fr', 'en']) {
        for (final trigger in EefHelpTrigger.values) {
          for (final key in {...keysFor(trigger), ...shared}) {
            expect(keys[locale]![key], isNotNull,
                reason: '$key manque en $locale');
            expect(keys[locale]![key]!.trim(), isNotEmpty);
          }
        }
      }
    });

    test('FR et EN diffèrent (aucune traduction oubliée)', () {
      for (final trigger in EefHelpTrigger.values) {
        for (final key in {...keysFor(trigger), ...shared}) {
          // « CV » s'écrit pareil dans les deux langues.
          if (key == 'eef_help_tool_cv_label') continue;
          expect(keys['en']![key], isNot(keys['fr']![key]), reason: key);
        }
      }
    });

    test('le jeu neutre (pays suspendu) ne parle jamais d\'ouvrir un dossier',
        () {
      for (final locale in ['fr', 'en']) {
        for (final key in [
          'eef_help_line_neutral_cta',
          'eef_help_line_neutral_subject',
          'eef_help_prefill_program_suspended',
          'eef_help_prefill_filters_suspended',
          'eef_help_prefill_filters_none_suspended',
          'eef_help_prefill_tool_suspended',
          // Les questions sont montrées aussi aux comptes suspendus.
          'eef_help_catalog_filters_question',
          'eef_help_tool_cv_question',
          'eef_help_tool_letters_question',
          'eef_help_tool_interview_question',
          // La bulle de la build 56 : son jeu neutre (comptes suspendus) et ce
          // qu'elle partage avec le jeu standard (voir eef_help_bubble_test.dart
          // pour le détail).
          'eef_help_bubble_assistance_label_neutral',
          'eef_help_bubble_assistance_message_neutral',
          'eef_help_bubble_question_label',
          'eef_help_bubble_question_message_neutral',
          'eef_help_bubble_place_hub',
          'eef_help_bubble_place_catalog',
        ]) {
          expect(_openAFileWording.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale) : ${keys[locale]![key]}');
        }
      }
    });

    test('les messages préremplis portent la place de ce qu\'ils nomment', () {
      for (final locale in ['fr', 'en']) {
        for (final key in [
          'eef_help_prefill_program',
          'eef_help_prefill_program_suspended',
        ]) {
          expect(keys[locale]![key],
              allOf(contains('@program'), contains('@place')),
              reason: '$key ($locale)');
        }
        for (final key in [
          'eef_help_prefill_filters',
          'eef_help_prefill_filters_suspended',
        ]) {
          expect(keys[locale]![key], contains('@filters'),
              reason: '$key ($locale)');
        }
        for (final key in [
          'eef_help_prefill_tool',
          'eef_help_prefill_tool_suspended',
        ]) {
          expect(keys[locale]![key], contains('@tool'),
              reason: '$key ($locale)');
        }
        // La variante « rien à citer » n'a PAS de place : elle servirait un
        // paramètre que personne ne remplit.
        for (final key in [
          'eef_help_prefill_filters_none',
          'eef_help_prefill_filters_none_suspended',
        ]) {
          expect(keys[locale]![key], isNot(contains('@')),
              reason: '$key ($locale)');
        }
      }
    });

    // Aucune promesse de résultat, aucun prix, aucun nom d'opérateur de l'État :
    // même balayage que eef_help_card_test.dart, sur les clés de la build 55.
    test('aucun texte ne promet, ne chiffre ni ne se déguise', () {
      final promise = RegExp(
        r'(admission|visa|bourse|scholarship)s?\s+(garanti|assur|certain|'
        r'guaranteed|assured|certain)|vous obtiendrez|tu obtiendras|'
        r'you will (get|obtain)|100\s?%',
        caseSensitive: false,
      );
      final price = RegExp(
        r'€|\bfcfa\b|\bxof\b|\bfrancs?\b|\bprix\b|\bprice\b|gratuit|\bfree\b|'
        r'\beuros?\b|\btarif',
        caseSensitive: false,
      );
      final operator = RegExp(r'campus[\s_-]*france', caseSensitive: false);
      final ours = {
        for (final trigger in EefHelpTrigger.values) ...keysFor(trigger),
        ...shared,
        'eef_help_catalog_filters_question',
        // Tous les textes de la bulle de la build 56 (préfixe `eef_help_bubble_`) :
        // un texte de plus y est balayé sans qu'on ait à y penser.
        ...keys['fr']!.keys.where((k) => k.startsWith('eef_help_bubble_')),
        // Les écoles privées (build 56, PR 3) : la feuille « Service KPB », la
        // ligne du catalogue vide et l'option de la bulle (préfixe
        // `eef_help_private_`). Le détail est dans eef_private_schools_test.dart.
        ...keys['fr']!.keys.where((k) => k.startsWith('eef_help_private_')),
      };
      expect(ours.where((k) => k.startsWith('eef_help_bubble_')), isNotEmpty,
          reason: 'le balayage de la bulle ne doit pas être vide');
      expect(ours.where((k) => k.startsWith('eef_help_private_')), isNotEmpty,
          reason: 'le balayage des écoles privées ne doit pas être vide');
      for (final locale in ['fr', 'en']) {
        for (final key in ours) {
          final value = keys[locale]![key]!;
          expect(promise.hasMatch(value), isFalse,
              reason: '$key ($locale) promet un résultat : $value');
          expect(price.hasMatch(value), isFalse,
              reason: '$key ($locale) cite un prix : $value');
          expect(operator.hasMatch(value), isFalse,
              reason: '$key ($locale) nomme l\'opérateur de l\'État : $value');
        }
      }
    });

    test('nulle part un pays de remplacement n\'est cité', () {
      final replacement = RegExp(
        r'togo|s[ée]n[ée]gal|c[ôo]te d.ivoire|cameroun|cameroon|maroc|'
        r'morocco|niger\b|autre pays pour|another country',
        caseSensitive: false,
      );
      for (final locale in ['fr', 'en']) {
        for (final key in keys[locale]!.keys) {
          if (!key.startsWith('eef_help_')) continue;
          expect(replacement.hasMatch(keys[locale]![key]!), isFalse,
              reason: '$key ($locale) : ${keys[locale]![key]}');
        }
      }
    });
  });

  // ── Le contrat d'analytique ─────────────────────────────────────────────────

  group('la mesure', () {
    test('chaque déclencheur a un identifiant et un écran fermés', () {
      final identifier = RegExp(r'^[a-z]+(_[a-z]+)*$');
      expect(EefHelpTrigger.values.map((t) => t.key).toSet(),
          hasLength(EefHelpTrigger.values.length));
      // Pas de collision avec une étape de la build 54 : un tableau de bord qui
      // fusionnerait deux emplacements ne saurait plus où l'on clique.
      expect(
        EefHelpTrigger.values
            .map((t) => t.key)
            .toSet()
            .intersection(EefHelpStep.values.map((s) => s.key).toSet()),
        isEmpty,
      );
      for (final trigger in EefHelpTrigger.values) {
        expect(trigger.key, matches(identifier));
        expect({'catalog', 'tools'}, contains(trigger.surface));
      }
      expect(EefHelpTrigger.catalogProgram.surface, 'catalog');
      expect(EefHelpTrigger.catalogFilters.surface, 'catalog');
      for (final tool in _tools) {
        expect(tool.trigger.surface, 'tools');
      }
    });

    test('la carte formation ne compte PAS une « vue » par carte affichée', () {
      expect(EefHelpTrigger.catalogProgram.countsShown, isFalse);
      expect(EefHelpTrigger.catalogFilters.countsShown, isTrue);
      for (final tool in _tools) {
        expect(tool.trigger.countsShown, isTrue);
      }
    });

    // Un événement sans ligne dans le contrat est un événement que personne ne
    // saura lire : chaque valeur nouvelle y est écrite.
    test('docs/analytics-event-contract.md documente chaque nouvelle valeur',
        () {
      final doc = File('docs/analytics-event-contract.md').readAsStringSync();
      for (final trigger in EefHelpTrigger.values) {
        expect(doc, contains('`${trigger.key}`'),
            reason: 'help_step ${trigger.key} absent du contrat');
      }
      expect(doc, contains('`tools`'), reason: 'surface `tools` absente');
      expect(doc, contains('eef_help_card_shown'));
      expect(doc, contains('eef_help_cta_tapped'));
      // La build 56 : la bulle. Ses sujets sont des valeurs de `help_step`
      // (enum à part, `EefBubbleOption`), sa vue est `bubble`, et l'ouverture du
      // menu est un événement neuf.
      for (final needle in [
        '`bubble`',
        '`bubble_assistance`',
        '`bubble_dossier`',
        '`bubble_choose`',
        '`bubble_question`',
        '`eef_bubble_opened`',
        // Les écoles privées (PR 3) : l'option de la bulle n'est PAS un envoi
        // (`bubble_private` n'est jamais un `help_step`), la feuille l'est.
        '`eef_private_info_opened`',
        '`private_sheet`',
        '`private_note`',
      ]) {
        expect(doc, contains(needle), reason: '$needle absent du contrat');
      }
    });

    test('le suivi WhatsApp attribue `eef_help_<étape>` et le type `eef_help`',
        () {
      final source =
          File('lib/app/features/etudes_en_france/eef_help_line.dart')
              .readAsStringSync();
      expect(source, contains("source: 'eef_help_\${trigger.key}'"));
      expect(source, contains("contextType: 'eef_help'"));
    });
  });

  // ── Le widget, seul ─────────────────────────────────────────────────────────

  Future<KpbScreenReport> pumpLine(
    WidgetTester tester,
    Widget line, {
    String country = 'Sénégal',
    String fullName = 'Mouhamadou Diallo',
    String email = 'test@example.com',
    String phone = '+22501020304',
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
    ThemeMode themeMode = ThemeMode.light,
    Locale locale = const Locale('fr'),
  }) async {
    await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: locale.languageCode,
        hasCompletedOnboarding: true,
        profile: createTestProfile(
          countryOfResidence: country,
          fullName: fullName,
          email: email,
          phone: phone,
        ),
      ),
    );
    return pumpKpbScreen(
      tester,
      screen: ListView(
        padding: const EdgeInsets.all(16),
        children: [line],
      ),
      viewport: viewport,
      textScale: textScale,
      themeMode: themeMode,
      locale: locale,
      ownsScaffold: false,
    );
  }

  String sentText() => launcher.lastText;

  group('une ligne d\'outil', () {
    for (final tool in _tools) {
      final key = tool.trigger.key;

      testWidgets(
          '$key (FR) : question, lien, mention — et le tap nomme l\'outil',
          (tester) async {
        await pumpLine(tester, EefHelpLine(trigger: tool.trigger));

        expect(find.text(tool.frQuestion), findsOneWidget);
        expect(find.text("Demander de l'aide"), findsOneWidget);
        // Seule invitation de l'écran d'outil, et aucune carte pleine : la
        // mention « un accompagnement n'est pas une garantie » l'accompagne.
        expect(find.text('eef_help_fineprint'.tr), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);

        await tester.tap(find.text("Demander de l'aide"));
        await tester.pumpAndSettle();

        expect(launcher.launched, hasLength(1));
        expect(Uri.parse(launcher.launched.single).host, 'wa.me');
        expect(
          Uri.parse(launcher.launched.single).path,
          '/${AppConfig.whatsappNumber.replaceAll(RegExp(r'[^\d]'), '')}',
          reason: 'la ligne du conseiller, pas un autre numéro',
        );
        expect(sentText(), _frToolPrefill(tool.frLabel));
        expect(analytics.tappedCalls,
            [RecordedHelpEvent(key, 'tools', 'compact')]);
        expect(
            analytics.shownCalls, [RecordedHelpEvent(key, 'tools', 'compact')]);
      });

      testWidgets('$key (EN)', (tester) async {
        await pumpLine(
          tester,
          EefHelpLine(trigger: tool.trigger),
          locale: const Locale('en'),
        );

        expect(find.text(tool.enQuestion), findsOneWidget);
        expect(find.text('Ask for help'), findsOneWidget);
        expect(find.text('eef_help_fineprint'.tr), findsOneWidget);
        expect(rawTranslationKeysOnScreen(tester), isEmpty);

        await tester.tap(find.text('Ask for help'));
        await tester.pumpAndSettle();

        expect(sentText(), _enToolPrefill(tool.enLabel));
      });

      testWidgets('$key, compte du Niger (FR) : neutre, jamais « dossier »',
          (tester) async {
        await pumpLine(tester, EefHelpLine(trigger: tool.trigger),
            country: 'Niger');

        // VISIBLE : décision du propriétaire du 03/10/2026.
        expect(find.text(tool.frQuestion), findsOneWidget);
        expect(find.text('Parler à un conseiller'), findsOneWidget);
        expect(find.text("Demander de l'aide"), findsNothing);

        final visible = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' | ');
        expect(_openAFileWording.hasMatch(visible), isFalse, reason: visible);

        await tester.tap(find.text('Parler à un conseiller'));
        await tester.pumpAndSettle();

        expect(sentText(), _frToolSuspendedPrefill(tool.frLabel));
        expect(_openAFileWording.hasMatch(sentText()), isFalse,
            reason: sentText());
        expect(sentText(), isNot(contains('Niger')));
        // Même mesure que pour un autre compte : on ne mesure pas le pays.
        expect(analytics.tappedCalls,
            [RecordedHelpEvent(key, 'tools', 'compact')]);
      });

      testWidgets('$key, compte du Niger (EN)', (tester) async {
        await pumpLine(
          tester,
          EefHelpLine(trigger: tool.trigger),
          country: 'Niger',
          locale: const Locale('en'),
        );

        expect(find.text(tool.enQuestion), findsOneWidget);
        expect(find.text('Talk to an advisor'), findsOneWidget);
        expect(find.text('Ask for help'), findsNothing);

        final visible = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' | ');
        expect(_openAFileWording.hasMatch(visible), isFalse, reason: visible);

        await tester.tap(find.text('Talk to an advisor'));
        await tester.pumpAndSettle();

        expect(sentText(), _enToolSuspendedPrefill(tool.enLabel));
        expect(_openAFileWording.hasMatch(sentText()), isFalse,
            reason: sentText());
      });
    }

    testWidgets('le message ne contient AUCUNE donnée personnelle',
        (tester) async {
      const name = 'Awa Koné-Diallo';
      const email = 'awa.kone.diallo@example.org';
      const phone = '+221770001122';
      for (final country in ['Sénégal', 'Niger']) {
        launcher.launched.clear();
        await pumpLine(
          tester,
          const EefHelpLine(trigger: EefHelpTrigger.toolCv),
          country: country,
          fullName: name,
          email: email,
          phone: phone,
        );
        await tester.tap(find.byType(TextButton));
        await tester.pumpAndSettle();

        final uri = Uri.parse(launcher.launched.single);
        // Le seul paramètre est le texte : ni nom, ni e-mail en paramètre.
        expect(uri.queryParameters.keys, ['text']);
        for (final secret in [
          'Awa',
          'Koné',
          'Diallo',
          'awa.kone',
          'example.org',
          '221',
          '770001122',
          country,
          'test-user-1',
        ]) {
          expect(sentText(), isNot(contains(secret)), reason: sentText());
        }
        expect(sentText(), isNot(contains('@')));
        expect(sentText(), isNot(contains(RegExp(r'\d'))),
            reason: 'aucun chiffre : ni téléphone, ni passeport, ni id');
      }
    });

    testWidgets('« vue » part UNE fois, même quand la ligne est reconstruite',
        (tester) async {
      await pumpLine(tester, const EefHelpLine(trigger: EefHelpTrigger.toolCv));
      expect(analytics.shownCalls, hasLength(1));

      // Un drapeau serveur qui arrive reconstruit la ligne : pas un nouveau vu.
      RemoteFeatureFlags.instance.flagsVersion.value += 1;
      await tester.pumpAndSettle();
      await tester.pump();
      expect(analytics.shownCalls, hasLength(1));
    });

    testWidgets('la suspension servie APRÈS le montage est prise en compte',
        (tester) async {
      EefCalendar.windowSource = () => const EefCampaignWindow();
      await pumpLine(
        tester,
        const EefHelpLine(trigger: EefHelpTrigger.toolCv),
        country: 'Niger',
      );
      expect(find.text("Demander de l'aide"), findsOneWidget);

      EefCalendar.windowSource = window;
      RemoteFeatureFlags.instance.flagsVersion.value += 1;
      await tester.pumpAndSettle();

      expect(find.text("Demander de l'aide"), findsNothing);
      expect(find.text('Parler à un conseiller'), findsOneWidget);
    });
  });

  // Aide-37 : « jamais un bouton muet ». Chaque déclencheur passe par
  // `openWhatsAppOrToast` ; un lancement direct qui garderait les chaînes
  // `source` / `contextType` ne se verrait que sur un téléphone sans WhatsApp.
  group('WhatsApp absent : le toast s\'affiche, jamais un bouton muet', () {
    final triggers = <String, Widget>{
      'catalog_program': EefHelpLine(
        trigger: EefHelpTrigger.catalogProgram,
        subject: 'L1 - Droit',
        prefill: (suspended) => EefHelpMessages.forProgram(
          program: 'L1 - Droit',
          suspended: suspended,
        ),
      ),
      'catalog_filters': EefHelpLine(
        trigger: EefHelpTrigger.catalogFilters,
        prefill: (suspended) => EefHelpMessages.forFilters(
          summary: 'Niveau : Master',
          suspended: suspended,
        ),
      ),
      for (final tool in _tools)
        tool.trigger.key: EefHelpLine(trigger: tool.trigger),
    };

    for (final entry in triggers.entries) {
      for (final country in ['Sénégal', 'Niger']) {
        testWidgets('${entry.key} — $country', (tester) async {
          final failing = FailingUrlLauncher();
          UrlLauncherPlatform.instance = failing;
          await pumpLine(tester, entry.value, country: country);

          await tester.tap(find.byType(TextButton));
          await tester.pump(const Duration(milliseconds: 400));

          expect(failing.launched, hasLength(1),
              reason: 'le lancement a bien été TENTÉ');
          expect(find.text('whatsapp_open_failed'.tr), findsOneWidget,
              reason:
                  'sans WhatsApp, l\'étudiant doit lire pourquoi rien ne s\'ouvre');
          expect(rawTranslationKeysOnScreen(tester), isEmpty);

          // Laisse le toast finir : aucun minuteur en vol.
          await tester.pump(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        });
      }
    }
  });

  group('un bouton de formation', () {
    Widget button({String? city = 'Lyon'}) => EefHelpLine(
          trigger: EefHelpTrigger.catalogProgram,
          subject: 'L1 - Droit',
          prefill: (suspended) => EefHelpMessages.forProgram(
            program: 'L1 - Droit',
            institution: 'Université Claude Bernard',
            city: city,
            suspended: suspended,
          ),
        );

    testWidgets('un bouton seul : pas de question, pas de mention',
        (tester) async {
      await pumpLine(tester, button());

      expect(find.text("Demander de l'aide"), findsOneWidget);
      expect(find.text('eef_help_fineprint'.tr), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(TextButton), findsOneWidget);
      expect(rawTranslationKeysOnScreen(tester), isEmpty);
    });

    testWidgets('le tap : message de la formation, mesure SANS l\'intitulé',
        (tester) async {
      await pumpLine(tester, button());

      await tester.tap(find.text("Demander de l'aide"));
      await tester.pumpAndSettle();

      expect(
        sentText(),
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
        '(Université Claude Bernard, Lyon) dans l\'espace Études en France de '
        'l\'app et j\'aimerais de l\'aide pour mon dossier.',
      );
      expect(analytics.tappedCalls,
          [const RecordedHelpEvent('catalog_program', 'catalog', 'compact')]);
      // Pas de « vue » par carte : ce serait du bruit, une fois par carte
      // affichée.
      expect(analytics.shownCalls, isEmpty);
      for (final event in [...analytics.tappedCalls, ...analytics.shownCalls]) {
        expect('$event', isNot(contains('Droit')));
        expect('$event', isNot(contains('Lyon')));
        expect('$event', isNot(contains('Claude')));
      }
    });

    testWidgets('compte du Niger : « Parler à un conseiller », message neutre',
        (tester) async {
      await pumpLine(tester, button(), country: 'Niger');

      expect(find.text('Parler à un conseiller'), findsOneWidget);
      expect(find.text("Demander de l'aide"), findsNothing);

      await tester.tap(find.text('Parler à un conseiller'));
      await tester.pumpAndSettle();

      expect(
        sentText(),
        'Bonjour KPB Education, je regarde la formation « L1 - Droit » '
        '(Université Claude Bernard, Lyon) dans l\'espace Études en France de '
        'l\'app. La procédure est suspendue dans mon pays : j\'aimerais savoir '
        'quelles options existent.',
      );
      expect(sentText(), isNot(contains('Niger')));
    });

    testWidgets('lecteur d\'écran : le bouton dit DE QUELLE formation il parle',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLine(tester, button());

      expect(
          find.bySemanticsLabel(
              "Demander de l'aide à propos de « L1 - Droit »"),
          findsOneWidget);

      handle.dispose();
    });

    testWidgets('lecteur d\'écran, Niger : le libellé neutre', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpLine(tester, button(), country: 'Niger');

      expect(
          find.bySemanticsLabel(
              'Parler à un conseiller à propos de « L1 - Droit »'),
          findsOneWidget);

      handle.dispose();
    });
  });

  // ── Géométrie ───────────────────────────────────────────────────────────────

  group('géométrie', () {
    Iterable<Widget> everyLine() sync* {
      for (final tool in _tools) {
        yield EefHelpLine(trigger: tool.trigger);
      }
      yield EefHelpLine(
        trigger: EefHelpTrigger.catalogFilters,
        prefill: (suspended) => EefHelpMessages.forFilters(
          summary: 'Niveau : Master',
          suspended: suspended,
        ),
      );
      yield EefHelpLine(
        trigger: EefHelpTrigger.catalogProgram,
        subject: 'Master Droit international et européen des affaires',
        prefill: (suspended) => '',
      );
    }

    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        for (final locale in ['fr', 'en']) {
          for (final country in ['Sénégal', 'Niger']) {
            testWidgets('${viewport.id} ×$scale $locale — $country',
                (tester) async {
              final report = await pumpLine(
                tester,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: everyLine().toList(),
                ),
                viewport: viewport,
                textScale: scale,
                locale: Locale(locale),
                country: country,
              );
              expect(report.overflows, isEmpty, reason: report.toString());
              expect(report.otherErrors, isEmpty, reason: report.toString());
              expect(rawTranslationKeysOnScreen(tester), isEmpty);
              expect(truncatedTexts(tester), isEmpty);
            });
          }
        }
      }
    }

    testWidgets('la cible tactile fait au moins 48 dp (lien ET bouton)',
        (tester) async {
      await pumpLine(
        tester,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: everyLine().toList(),
        ),
        viewport: compactAndroid,
        textScale: 1.3,
      );
      final buttons = find.byType(TextButton);
      expect(buttons, findsNWidgets(5));
      for (var i = 0; i < 5; i++) {
        final size = tester.getSize(buttons.at(i));
        expect(size.height, greaterThanOrEqualTo(48), reason: 'bouton $i');
        expect(size.width, greaterThanOrEqualTo(48), reason: 'bouton $i');
      }
    });
  });

  // ── Contraste : mesuré sur les pixels, en clair ET en sombre ────────────────

  group('contraste >= 4,5:1 (mesuré sur les pixels)', () {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      group(mode.name, () {
        for (final country in ['Sénégal', 'Niger']) {
          testWidgets('ligne d\'outil : question, lien, mention — $country',
              (tester) async {
            await pumpLine(
              tester,
              const EefHelpLine(trigger: EefHelpTrigger.toolCv),
              themeMode: mode,
              country: country,
            );
            final link = country == 'Niger'
                ? 'Parler à un conseiller'
                : "Demander de l'aide";
            for (final text in [
              "Besoin d'aide pour rédiger ton CV ?",
              link,
              'eef_help_fineprint'.tr,
            ]) {
              final measured =
                  await measurePixelContrast(tester, find.text(text));
              expect(measured.ratio, greaterThanOrEqualTo(4.5),
                  reason: '« $text » : $measured');
            }
          });

          testWidgets('ligne du catalogue : question et lien — $country',
              (tester) async {
            await pumpLine(
              tester,
              EefHelpLine(
                trigger: EefHelpTrigger.catalogFilters,
                prefill: (suspended) => '',
              ),
              themeMode: mode,
              country: country,
            );
            final link = country == 'Niger'
                ? 'Parler à un conseiller'
                : "Demander de l'aide";
            for (final text in ['Tu hésites entre ces formations ?', link]) {
              final measured =
                  await measurePixelContrast(tester, find.text(text));
              expect(measured.ratio, greaterThanOrEqualTo(4.5),
                  reason: '« $text » : $measured');
            }
          });

          testWidgets('bouton de formation — $country', (tester) async {
            await pumpLine(
              tester,
              EefHelpLine(
                trigger: EefHelpTrigger.catalogProgram,
                subject: 'L1 - Droit',
                prefill: (suspended) => '',
              ),
              themeMode: mode,
              country: country,
            );
            final link = country == 'Niger'
                ? 'Parler à un conseiller'
                : "Demander de l'aide";
            final measured =
                await measurePixelContrast(tester, find.text(link));
            expect(measured.ratio, greaterThanOrEqualTo(4.5),
                reason: measured.toString());
          });
        }
      });
    }
  });

  // ── Contraste à l'état PRESSÉ ───────────────────────────────────────────────
  //
  // La surcouche pressée d'un `TextButton` assombrit le fond sous un texte
  // `actionPrimary` : mesuré, 3,78:1 (ligne des filtres) et 3,94:1 (bouton de
  // formation) en clair. Le doigt est SUR le lien au moment où l'on le lit.
  group('contraste >= 4,5:1 à l\'état PRESSÉ (mesuré sur les pixels)', () {
    Future<PixelContrast> measurePressed(WidgetTester tester, Finder text) =>
        measurePixelContrastWhilePressed(tester, text);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      group(mode.name, () {
        for (final country in ['Sénégal', 'Niger']) {
          final link = country == 'Niger'
              ? 'Parler à un conseiller'
              : "Demander de l'aide";

          testWidgets('ligne du catalogue — $country', (tester) async {
            await pumpLine(
              tester,
              EefHelpLine(
                trigger: EefHelpTrigger.catalogFilters,
                prefill: (suspended) => '',
              ),
              themeMode: mode,
              country: country,
            );
            final measured = await measurePressed(tester, find.text(link));
            expect(measured.ratio, greaterThanOrEqualTo(4.5),
                reason: measured.toString());
          });

          testWidgets('bouton de formation, sur sa carte — $country',
              (tester) async {
            await pumpLine(
              tester,
              KpbCard(
                child: EefHelpLine(
                  trigger: EefHelpTrigger.catalogProgram,
                  subject: 'L1 - Droit',
                  prefill: (suspended) => '',
                ),
              ),
              themeMode: mode,
              country: country,
            );
            final measured = await measurePressed(tester, find.text(link));
            expect(measured.ratio, greaterThanOrEqualTo(4.5),
                reason: measured.toString());
          });

          testWidgets('ligne d\'outil, sur sa surface — $country',
              (tester) async {
            await pumpLine(
              tester,
              const EefHelpLine(trigger: EefHelpTrigger.toolCv),
              themeMode: mode,
              country: country,
            );
            final measured = await measurePressed(tester, find.text(link));
            expect(measured.ratio, greaterThanOrEqualTo(4.5),
                reason: measured.toString());
          });
        }
      });
    }
  });

  // Un relecteur a cru que le lien d'un écran d'outil n'avait AUCUN retour au
  // toucher (l'encre peinte sous le `Container` opaque de la surface bleue). Faux :
  // le `TextButton` porte son propre `Material`, l'encre se peint AU-DESSUS du fond.
  // Sa mesure était prise trop tôt — l'encre ne démarre qu'après 100 ms et n'est
  // peinte qu'au cadre suivant (voir `measurePixelContrastWhilePressed`). Ce test
  // garde le comportement réel : le fond de la surface change sous le doigt.
  testWidgets(
      'ligne d\'outil : le toucher se VOIT (le fond de la surface change)',
      (tester) async {
    await pumpLine(
      tester,
      const EefHelpLine(trigger: EefHelpTrigger.toolCv),
    );
    final link = find.text("Demander de l'aide");
    final atRest = await measurePixelContrast(tester, link);

    final pressed = await measurePixelContrastWhilePressed(tester, link);

    expect(sameColor(atRest.background, pressed.background), isFalse,
        reason: 'au repos : $atRest ; pressé : $pressed');
  });
}
