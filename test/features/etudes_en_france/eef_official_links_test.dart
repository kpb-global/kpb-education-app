// XC-05 — les sources officielles de ce que l'espace affirme.
//
// L'espace dit que la plateforme ouvre à une date, et que le traitement des
// dossiers est suspendu dans certains pays. Ces affirmations se vérifient à leur
// source : l'étudiant doit y avoir un lien, et un lien qui ne peut pas marcher
// ne doit pas être affiché.

import 'package:flutter/material.dart' show ListView;
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/data/eef_calendar.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_teaser_screen.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

const _platform = 'https://www.campusfrance.org/fr';
const _niger = 'https://ne.diplomatie.gouv.fr/informations-visas';

void main() {
  setUpAll(initializeDateFormatting);

  setUp(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    AppConfig.eefSpaceEnabledOverride = null;
    Get.locale = const Locale('fr');
  });

  tearDown(() {
    EefCalendar.resetForTest();
    RemoteFeatureFlags.resetForTest();
    Get.reset();
  });

  Future<void> pumpTeaser(
    WidgetTester tester, {
    required String country,
    required EefCampaignWindow window,
    KpbViewport viewport = iphone14,
    double textScale = 1.0,
  }) async {
    EefCalendar.clock = () => DateTime(2026, 8, 21);
    EefCalendar.windowSource = () => window;
    await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: createTestProfile(countryOfResidence: country),
      ),
    );
    final report = await pumpKpbScreen(
      tester,
      screen: const EefTeaserScreen(),
      viewport: viewport,
      textScale: textScale,
    );
    expect(report.overflows, isEmpty, reason: report.toString());
  }

  // La liste est paresseuse : la mention de non-affiliation, tout en bas, n'est
  // construite qu'une fois atteinte.
  Future<void> scrollToEnd(WidgetTester tester) async {
    await tester.drag(find.byType(ListView).first, const Offset(0, -4000));
    await tester.pumpAndSettle();
  }

  final platformLink = find.text('Voir la plateforme officielle');
  final sourceLink = find.text('Voir la source officielle');

  EefCampaignWindow window({
    String? platformUrl = _platform,
    Map<String, String> sources = const {'niger': _niger},
    List<String> suspended = const ['Niger'],
  }) =>
      EefCampaignWindow(
        opensAt: DateTime(2026, 10, 1),
        suspendedCountries: suspended,
        platformUrl: platformUrl,
        suspendedSources: sources,
      );

  group('la vitrine', () {
    testWidgets('un étudiant nigérien voit la source de la suspension',
        (tester) async {
      await pumpTeaser(tester, country: 'Niger', window: window());

      expect(find.text('eef_suspended_notice'.tr), findsOneWidget);
      expect(sourceLink, findsOneWidget);
    });

    testWidgets('un étudiant sénégalais ne voit PAS la source du Niger',
        (tester) async {
      await pumpTeaser(tester, country: 'Sénégal', window: window());

      expect(sourceLink, findsNothing);
    });

    testWidgets('la date d\'ouverture est accompagnée de la plateforme',
        (tester) async {
      await pumpTeaser(tester, country: 'Sénégal', window: window());

      // Un lien sous la date (en tête d'écran)…
      expect(platformLink, findsOneWidget);

      // …un autre dans la mention de non-affiliation (en bas).
      await scrollToEnd(tester);
      expect(platformLink, findsOneWidget);
      expect(find.text('eef_affiliation_notice'.tr), findsOneWidget);
    });

    testWidgets('la suspension REMPLACE la date, donc le lien de la date',
        (tester) async {
      await pumpTeaser(tester, country: 'Niger', window: window());

      // Le lien de la date a disparu avec la date…
      expect(platformLink, findsNothing);

      // …il ne reste que celui de la mention de non-affiliation.
      await scrollToEnd(tester);
      expect(platformLink, findsOneWidget);
    });

    testWidgets('sans adresse servie, aucun lien (jamais un bouton mort)',
        (tester) async {
      await pumpTeaser(
        tester,
        country: 'Sénégal',
        window: window(platformUrl: null),
      );

      expect(platformLink, findsNothing);
      await scrollToEnd(tester);
      expect(platformLink, findsNothing);
    });

    testWidgets('une suspension sans source servie n\'affiche aucun lien',
        (tester) async {
      await pumpTeaser(
        tester,
        country: 'Niger',
        window: window(sources: const {}),
      );

      expect(find.text('eef_suspended_notice'.tr), findsOneWidget);
      expect(sourceLink, findsNothing);
    });

    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets('géométrie ${viewport.id} ×$scale — suspension + liens',
            (tester) async {
          await pumpTeaser(
            tester,
            country: 'Niger',
            window: window(),
            viewport: viewport,
            textScale: scale,
          );
          expect(sourceLink, findsOneWidget);
        });
      }
    }
  });
}
