// La vitrine « Études en France » sur la matrice d'écrans réels.
//
// L'écran France a dû MESURER la hauteur de son en-tête au TextPainter parce
// qu'un `expandedHeight: 220` figé débordait de 88 px à l'échelle de texte 1,0.
// Cette vitrine prend le chemin inverse : pas de hauteur figée du tout, un
// en-tête à hauteur intrinsèque dans une liste défilante. Ce fichier vérifie que
// ce choix tient — et il vérifie DEUX propriétés, parce que l'absence de
// débordement ne prouve pas la lisibilité : un texte peut être coupé par un
// ellipsis sans qu'un seul pixel ne « déborde », et `takeException` n'en voit
// rien.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_teaser_screen.dart';

import '../../support/screen_harness.dart';

void main() {
  setUp(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
  });

  tearDown(() {
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    Get.reset();
  });

  /// Sert une fenêtre de campagne : c'est le cas le PLUS chargé de l'en-tête
  /// (badge + titre + corps + ligne de dates + compte à rebours), donc celui
  /// qui déborderait en premier.
  void serveBusiestWindow() {
    EefCalendar.clock = () => DateTime(2026, 8, 21);
    EefCalendar.windowSource = () => EefCampaignWindow(
          opensAt: DateTime(2026, 8, 26),
          closesAt: DateTime(2026, 12, 15),
        );
  }

  for (final viewport in kpbPhoneViewports) {
    for (final scale in kpbTextScales) {
      testWidgets('vitrine — ${viewport.id} @ $scale', (tester) async {
        serveBusiestWindow();
        await seedKpbController();

        final report = await pumpKpbScreen(
          tester,
          screen: const EefTeaserScreen(),
          viewport: viewport,
          textScale: scale,
        );

        expect(
          report.overflows,
          isEmpty,
          reason: 'La vitrine déborde : ${report.overflowPixels} px. '
              'Un en-tête à hauteur intrinsèque ne devrait pas pouvoir — '
              'chercher une hauteur ou une largeur figée ajoutée depuis.',
        );

        expect(
          truncatedTexts(tester),
          isEmpty,
          reason: 'Du texte est VISUELLEMENT coupé (ellipsis ou maxLines). '
              'Un débordement lève, une troncature ne fait rien : sans cette '
              'assertion, un « ouverture dans 5 jou… » passerait vert.',
        );

        // Aucune clé brute à l'écran : le harnais monte l'app AVEC ses
        // traductions, donc une clé non traduite s'afficherait telle quelle.
        expect(
          find.textContaining('eef_'),
          findsNothing,
          reason: 'Une clé de traduction s\'affiche brute — clé absente du '
              'dictionnaire FR.',
        );
      });
    }
  }

  for (final viewport in kpbPhoneViewports) {
    for (final scale in kpbTextScales) {
      testWidgets('coquille de l\'espace — ${viewport.id} @ $scale',
          (tester) async {
        serveBusiestWindow();
        await seedKpbController();

        final report = await pumpKpbScreen(
          tester,
          screen: const EefHomeScreen(),
          viewport: viewport,
          textScale: scale,
        );

        expect(report.overflows, isEmpty,
            reason: 'La coquille déborde : ${report.overflowPixels} px.');
        expect(truncatedTexts(tester), isEmpty);
        expect(find.textContaining('eef_'), findsNothing);
      });
    }
  }

  // L'auto-contrôle du harnais, repris ici : si le canari se tait, toutes les
  // assertions « sans débordement » de ce fichier ne veulent plus rien dire.
  testWidgets('le canari déborde bien — le mécanisme d\'assertion est vivant',
      (tester) async {
    await seedKpbController();
    final report = await pumpKpbScreen(
      tester,
      screen: const KpbOverflowCanary(),
      viewport: iphone14,
    );
    expect(report.overflows, isNotEmpty);
  });
}
