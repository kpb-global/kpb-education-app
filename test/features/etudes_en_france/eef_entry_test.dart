// EefEntry : l'arbitrage « vitrine / espace / rien », écrit UNE fois.
//
// Il y a quatre portes vers ce module (accueil, tiroir, boîte à outils, lien
// profond). Recopier la condition à chaque porte garantirait qu'une porte garde
// l'ancienne règle le jour de la bascule — c'est le défaut PARC-05 que
// `student_tools_screen.dart` nomme déjà : dix-huit points d'entrée, un seul
// gardé.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/ui/components/coming_soon_screen.dart';
import 'package:karatou/app/features/etudes_en_france/eef_entry.dart';
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
    RemoteFeatureFlags.resetForTest();
    AppConfig.eefTeaserEnabledOverride = null;
    AppConfig.eefEnabledOverride = null;
    Get.reset();
  });

  group('isVisible — ce que les points d\'entrée lisent', () {
    test('faux quand les deux drapeaux sont éteints', () {
      expect(EefEntry.isVisible, isFalse);
    });

    test('vrai dès que la vitrine est allumée', () {
      AppConfig.eefTeaserEnabledOverride = true;
      expect(EefEntry.isVisible, isTrue);
    });

    test('vrai quand l\'espace réel est ouvert', () {
      AppConfig.eefEnabledOverride = true;
      expect(EefEntry.isVisible, isTrue);
    });
  });

  group('l\'écran servi', () {
    // Un lien profond reçu par un téléphone dont le serveur n'a pas encore
    // ouvert le module ne doit PAS être un cul-de-sac silencieux.
    testWidgets('drapeaux éteints → « bientôt disponible », pas un écran vide',
        (tester) async {
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const EefEntry(),
        viewport: iphone14,
      );

      expect(find.byType(ComingSoonScreen), findsOneWidget);
      expect(find.byType(EefTeaserScreen), findsNothing);
      expect(find.byType(EefHomeScreen), findsNothing);
    });

    testWidgets('vitrine allumée → la vitrine', (tester) async {
      AppConfig.eefTeaserEnabledOverride = true;
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const EefEntry(),
        viewport: iphone14,
      );

      expect(find.byType(EefTeaserScreen), findsOneWidget);
      expect(find.byType(ComingSoonScreen), findsNothing);
    });

    testWidgets('espace ouvert → l\'espace', (tester) async {
      AppConfig.eefEnabledOverride = true;
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const EefEntry(),
        viewport: iphone14,
      );

      expect(find.byType(EefHomeScreen), findsOneWidget);
      expect(find.byType(EefTeaserScreen), findsNothing);
    });

    // Le serveur garantit déjà que les deux ne sont jamais servis ensemble
    // (`eef` retire `eefTeaser`), mais l'ordre est écrit ici AUSSI : un repli de
    // compilation ou un backend plus ancien pourrait rendre les deux vrais, et
    // il vaut mieux montrer l'espace ouvert qu'un « bientôt » devant un espace
    // vivant.
    testWidgets('les deux allumés → l\'espace réel PRIME sur la vitrine',
        (tester) async {
      AppConfig.eefTeaserEnabledOverride = true;
      AppConfig.eefEnabledOverride = true;
      await seedKpbController();
      await pumpKpbScreen(
        tester,
        screen: const EefEntry(),
        viewport: iphone14,
      );

      expect(find.byType(EefHomeScreen), findsOneWidget);
      expect(find.byType(EefTeaserScreen), findsNothing);
    });
  });
}
