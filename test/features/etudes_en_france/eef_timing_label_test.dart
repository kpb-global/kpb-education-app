// `EefCalendar.timingLabel` — LE point unique qui décide si l'app parle de
// dates, et ce qu'elle en dit.
//
// ## Les trois défauts que ce fichier interdit
//
// **1. La règle appliquée par une seule surface.** « La suspension REMPLACE les
// dates » vivait dans le corps de la vitrine. La carte d'accueil, elle, lisait
// `daysUntilOpening()` et `rangeLabel()` sans consulter la suspension : un
// étudiant nigérien lisait donc « ouverture dans 41 jours » sur l'écran le plus
// fréquenté de l'app, alors que la vitrine refuse délibérément de lui donner une
// date — la source officielle disant que son dossier ne sera pas traité. Une
// garde sur une porte et pas sur l'autre, et c'était la mieux fréquentée qui
// n'en avait pas.
//
// **2. « ouverture dans 1 jours »**, affiché à tout le monde la veille de
// l'ouverture — le seul jour où cette ligne est lue avec attention.
//
// **3. Une fenêtre incohérente imprimée** alors que `phase()` refuse de
// l'interpréter : deux variables inversées dans un `.env` et l'app annonçait
// « du 15 décembre 2026 au 26 août 2026 ».
//
// Ces trois cas ont la même forme : une règle énoncée quelque part et non
// appliquée partout. D'où le point unique, et d'où ce fichier.

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

void main() {
  setUpAll(initializeDateFormatting);

  setUp(() {
    Get.locale = const Locale('fr');
    // Les vraies chaînes, pas des clés : le défaut n° 2 est un défaut de
    // pluriel, donc il ne se voit que sur le texte rendu.
    Get.addTranslations(AppTranslations().keys);
  });

  tearDown(() {
    EefCalendar.resetForTest();
    Get.reset();
  });

  void serve({
    DateTime? opensAt,
    DateTime? closesAt,
    List<String> suspended = const <String>[],
  }) {
    EefCalendar.windowSource = () => EefCampaignWindow(
          opensAt: opensAt,
          closesAt: closesAt,
          suspendedCountries: suspended,
        );
  }

  void freezeAt(DateTime now) => EefCalendar.clock = () => now;

  group('suspension — la date se tait, elle ne se juxtapose pas', () {
    test('un pays suspendu ne reçoit AUCUNE ligne temporelle', () {
      serve(
        opensAt: DateTime(2026, 10, 1),
        suspended: const ['Niger', 'NE'],
      );
      freezeAt(DateTime(2026, 8, 22));

      expect(EefCalendar.timingLabel(country: 'Niger'), isNull);
      // La casse et les accents ne sauvent pas : la normalisation vaut ici aussi.
      expect(EefCalendar.timingLabel(country: 'NIGER'), isNull);
      expect(EefCalendar.timingLabel(country: ' niger '), isNull);
    });

    test(
        '« Niger » est un préfixe de « Nigeria » — et ne doit pas le suspendre',
        () {
      serve(
        opensAt: DateTime(2026, 10, 1),
        suspended: const ['Niger', 'NE'],
      );
      freezeAt(DateTime(2026, 8, 22));

      final nigeria = EefCalendar.timingLabel(country: 'Nigeria');
      expect(nigeria, isNotNull);
      expect(nigeria, contains('1er octobre 2026'));
    });

    test('un pays non suspendu reçoit bien la date nationale', () {
      serve(opensAt: DateTime(2026, 10, 1), suspended: const ['Niger']);
      freezeAt(DateTime(2026, 8, 22));

      expect(
        EefCalendar.timingLabel(country: 'Côte d’Ivoire'),
        contains('1er octobre 2026'),
      );
    });

    test('un pays vide ou inconnu reçoit la date — le sens de l\'échec choisi',
        () {
      // Afficher une suspension à qui n'est pas concerné découragerait une
      // candidature possible. L'inverse — une date exacte pour la plateforme —
      // est le moindre mal, et c'est le choix documenté.
      serve(opensAt: DateTime(2026, 10, 1), suspended: const ['Niger']);
      freezeAt(DateTime(2026, 8, 22));

      expect(EefCalendar.timingLabel(country: null), isNotNull);
      expect(EefCalendar.timingLabel(country: ''), isNotNull);
      expect(EefCalendar.timingLabel(country: 'Pays Inexistant'), isNotNull);
    });
  });

  group('pluriel du compte à rebours', () {
    test('la veille, « ouverture demain » — jamais « dans 1 jours »', () {
      serve(opensAt: DateTime(2026, 10, 1));
      freezeAt(DateTime(2026, 9, 30, 8));

      final label = EefCalendar.timingLabel();
      expect(label, contains('demain'));
      expect(label, isNot(contains('1 jours')));
      expect(label, isNot(contains('1 jour ')));
    });

    test('à plus d\'un jour, le pluriel est correct', () {
      serve(opensAt: DateTime(2026, 10, 1));
      freezeAt(DateTime(2026, 9, 29, 8));

      expect(EefCalendar.timingLabel(), contains('2 jours'));
    });

    test('une fois la campagne ouverte, plus de compte à rebours', () {
      serve(opensAt: DateTime(2026, 10, 1));
      freezeAt(DateTime(2026, 10, 5));

      final label = EefCalendar.timingLabel();
      expect(label, contains('1er octobre 2026'));
      expect(label, isNot(contains('jours')));
      expect(label, isNot(contains('demain')));
    });
  });

  group('fenêtre incohérente — on se tait', () {
    test('une clôture avant l\'ouverture ne s\'imprime pas', () {
      serve(opensAt: DateTime(2026, 12, 15), closesAt: DateTime(2026, 8, 26));
      freezeAt(DateTime(2026, 8, 22));

      // `phase()` la traitait déjà comme inconnue ; `rangeLabel` l'imprimait
      // quand même, ce qui annulait la garde.
      expect(EefCalendar.phase(), EefCampaignPhase.unknown);
      expect(EefCalendar.rangeLabel(), isNull);
      expect(EefCalendar.timingLabel(), isNull);
    });

    test('aucune date servie : aucune ligne', () {
      serve();
      freezeAt(DateTime(2026, 8, 22));

      expect(EefCalendar.timingLabel(), isNull);
    });

    test('une fenêtre cohérente à deux bornes s\'imprime bien, elle', () {
      serve(opensAt: DateTime(2026, 10, 1), closesAt: DateTime(2026, 12, 15));
      freezeAt(DateTime(2026, 11, 1));

      final label = EefCalendar.timingLabel();
      expect(label, contains('1er octobre 2026'));
      expect(label, contains('15 décembre 2026'));
    });
  });
}
