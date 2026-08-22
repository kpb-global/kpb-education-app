// LES QUATRE PORTES.
//
// `EefEntry.isVisible` est testé ailleurs — mais savoir que la garde rend le bon
// booléen ne prouve PAS que chaque porte l'honore. C'est précisément l'écart que
// les commentaires du dépôt nomment PARC-05 : « dix-huit points d'entrée, un
// seul gardé ». Une garde correcte posée sur trois portes sur quatre laisse la
// quatrième ouverte le jour où le module est éteint, et fermée le jour où il
// devrait s'ouvrir.
//
// Ce fichier vérifie les quatre dans les DEUX sens : absentes drapeau éteint,
// présentes drapeau allumé. Le second sens est celui qu'on oublie, et c'est
// pourtant lui qui casse le jour du lancement.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/config/app_routes.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/features/etudes_en_france/eef_home_card.dart';
import 'package:karatou/app/features/shell/kpb_tools_drawer.dart';
import 'package:karatou/app/features/tools/student_tools_screen.dart';

import '../../support/screen_harness.dart';

void main() {
  setUp(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
  });

  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    Get.reset();
  });

  // ── Porte 1 : la carte d'accueil ─────────────────────────────────────────
  group('porte 1 — la carte d\'accueil', () {
    testWidgets('absente quand le module est éteint', (tester) async {
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const EefHomeCard(),
        viewport: iphone14,
        ownsScaffold: false,
      );

      // Elle s'auto-masque : l'accueil ne porte aucune condition.
      expect(find.text('eef_title'.tr), findsNothing);
    });

    testWidgets('présente quand la vitrine est allumée', (tester) async {
      AppConfig.eefTeaserEnabledOverride = true;
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const EefHomeCard(),
        viewport: iphone14,
        ownsScaffold: false,
      );

      expect(find.text('eef_title'.tr), findsOneWidget);
    });
  });

  // ── Porte 2 : le tiroir à outils ─────────────────────────────────────────
  group('porte 2 — le tiroir à outils', () {
    testWidgets('absente quand le module est éteint', (tester) async {
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const KpbToolsDrawer(),
        viewport: iphone14,
        ownsScaffold: false,
      );

      expect(find.text('eef_title'.tr), findsNothing);
    });

    testWidgets('présente, et EN TÊTE, quand la vitrine est allumée',
        (tester) async {
      AppConfig.eefTeaserEnabledOverride = true;
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const KpbToolsDrawer(),
        viewport: iphone14,
        ownsScaffold: false,
      );

      final eef = find.text('eef_title'.tr);
      expect(eef, findsOneWidget);

      // En tête pendant la campagne : un tiroir où l'entrée serait huitième ne
      // la ferait pas trouver. Le scanner de documents est la première entrée
      // toujours visible, donc la référence de position.
      final scanner = find.text('tools_doc_scanner'.tr);
      expect(scanner, findsOneWidget);
      expect(
        tester.getRect(eef).top,
        lessThan(tester.getRect(scanner).top),
        reason: 'l\'entrée EEF doit précéder les outils permanents',
      );
    });
  });

  // ── Porte 3 : la boîte à outils étudiante ────────────────────────────────
  group('porte 3 — la boîte à outils étudiante', () {
    testWidgets('absente quand le module est éteint', (tester) async {
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const StudentToolsScreen(),
        viewport: iphone14,
      );

      expect(find.text('eef_title'.tr), findsNothing);
    });

    testWidgets('présente quand la vitrine est allumée', (tester) async {
      AppConfig.eefTeaserEnabledOverride = true;
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const StudentToolsScreen(),
        viewport: iphone14,
      );

      expect(find.text('eef_title'.tr), findsOneWidget);
      expect(find.text('eef_tools_subtitle'.tr), findsOneWidget);
    });
  });

  // ── Porte 4 : le lien profond ────────────────────────────────────────────
  //
  // Celle-ci se comporte à l'INVERSE des trois autres, et c'est voulu : la
  // route reste joignable drapeaux éteints, et `EefEntry` retombe sur
  // « bientôt disponible ». Masquer une entrée est un choix éditorial ; casser
  // un lien profond est un cul-de-sac, et la notification push du jour J passe
  // par là.
  group('porte 4 — le lien profond', () {
    test('la route est acceptée même drapeaux éteints', () {
      expect(
        AppRoutes.normalizeExternalRoute('/etudes-en-france'),
        AppRoutes.etudesEnFrance,
      );
    });

    test('la route est enregistrée dans les pages', () {
      expect(
        AppRoutes.pages.map((page) => page.name),
        contains(AppRoutes.etudesEnFrance),
      );
    });

    test('une variante non enregistrée est refusée', () {
      expect(AppRoutes.normalizeExternalRoute('/etudes-en-france/'), isNull);
      expect(AppRoutes.normalizeExternalRoute('/campus-france'), isNull);
    });
  });
}
