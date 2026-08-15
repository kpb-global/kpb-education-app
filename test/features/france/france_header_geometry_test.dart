// L'en-tête France : la GÉOMÉTRIE en plus de l'absence de rayures jaunes.
//
// L'absence de débordement ne prouve pas la lisibilité : un texte peut être
// coupé, poussé sous l'app bar ou rétréci sans qu'un seul pixel ne « déborde ».
// Le plan exigeait donc une seconde assertion : le BAS du sous-titre (la ligne
// qui porte `france_sept_intake`) doit rester À L'INTÉRIEUR de l'app bar
// déployée. Avant correctif il dépassait la limite de 4 à 44 px selon
// l'encoche — le sous-titre s'écrivait par-dessus le contenu de la page.
//
// La hauteur de l'en-tête étant désormais MESURÉE (TextPainter avec le style du
// thème), cette assertion vérifie exactement le contrat : la mesure et le rendu
// donnent le même nombre.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/data/intake_calendar.dart';
import 'package:karatou/app/features/france/france_private_admission_screen.dart';

import '../../support/screen_harness.dart';

void main() {
  tearDown(() {
    IntakeCalendar.clock = DateTime.now;
    Get.reset();
  });

  for (final viewport in kpbPhoneViewports) {
    for (final scale in kpbTextScales) {
      testWidgets(
          'le sous-titre reste dans l\'app bar — ${viewport.id} @ $scale',
          (tester) async {
        await seedKpbController();
        final report = await pumpKpbScreen(
          tester,
          screen: const FrancePrivateAdmissionScreen(),
          viewport: viewport,
          textScale: scale,
        );

        expect(report.overflows, isEmpty,
            reason: 'L\'en-tête déborde encore — FLU-07 est revenu.');

        // Le sous-titre : la seule ligne de l'écran qui contient le compte de
        // programmes. On ne cherche pas le libellé de rentrée, qui est
        // désormais calculé et changerait avec l'horloge.
        final subtitle = find.textContaining('programs_available'.tr);
        expect(subtitle, findsOneWidget);

        final subtitleBottom = tester.getRect(subtitle).bottom;
        final appBarBottom =
            tester.getRect(find.byType(FlexibleSpaceBar)).bottom;

        expect(
          subtitleBottom,
          lessThanOrEqualTo(appBarBottom),
          reason: 'Le sous-titre (bas à ${subtitleBottom.toStringAsFixed(1)}) '
              'dépasse l\'app bar déployée '
              '(${appBarBottom.toStringAsFixed(1)}) : le texte s\'écrit '
              'par-dessus le contenu de la page. C\'était l\'état d\'origine, '
              'avec `expandedHeight: 220` figé.',
        );
      });
    }
  }
}
