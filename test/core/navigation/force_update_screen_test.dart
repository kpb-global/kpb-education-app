// L'écran de mise à jour forcée doit TOUJOURS offrir une sortie.
//
// C'est un `PopScope(canPop: false)` : rien ne le referme. Son unique bouton
// était grisé quand l'URL de store est vide — et cette URL vient du serveur, donc
// elle peut l'être par oubli de configuration. Dans cet état, l'app était
// définitivement inutilisable.
//
// Ce n'est pas une hypothèse d'école : cet écran est le SEUL levier à distance
// pendant une fenêtre TestFlight, il ne peut voyager que dans une build, et s'en
// servir avant de l'avoir réparé transformait la 49 en brique chez chaque
// testeur. Le lot 2 l'a armé côté serveur ; il fallait qu'il ait une issue côté
// client.
//
// Le lanceur d'URL est intercepté au niveau de `UrlLauncherPlatform`, la couture
// officielle du plugin : aucune modification de la production n'a été nécessaire
// pour rendre l'écran testable.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:karatou/app/core/navigation/force_update_screen.dart';
import 'package:karatou/app/core/translations/app_translations.dart';

/// Enregistre les URL qu'on lui demande d'ouvrir, et prétend toujours réussir.
class _RecordingLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  final List<String> launched = <String>[];

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launched.add(url);
    return true;
  }
}

void main() {
  late _RecordingLauncher launcher;
  late UrlLauncherPlatform previous;

  setUp(() {
    previous = UrlLauncherPlatform.instance;
    launcher = _RecordingLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  tearDown(() {
    UrlLauncherPlatform.instance = previous;
    Get.reset();
  });

  Future<void> pump(WidgetTester tester, String storeUrl) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    Get.addTranslations(AppTranslations().keys);
    Get.locale = const Locale('fr');
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: ForceUpdateScreen(storeUrl: storeUrl),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Tous les boutons de l'écran qui sont RÉELLEMENT actionnables.
  List<Widget> enabledButtons(WidgetTester tester) => [
        ...tester
            .widgetList<FilledButton>(find.byType(FilledButton))
            .where((b) => b.onPressed != null),
        ...tester
            .widgetList<OutlinedButton>(find.byType(OutlinedButton))
            .where((b) => b.onPressed != null),
        ...tester
            .widgetList<TextButton>(find.byType(TextButton))
            .where((b) => b.onPressed != null),
        ...tester
            .widgetList<ElevatedButton>(find.byType(ElevatedButton))
            .where((b) => b.onPressed != null),
      ];

  group('URL de store vide — le cas qui transformait l\'app en brique', () {
    testWidgets('au moins un bouton reste actionnable', (tester) async {
      await pump(tester, '');

      expect(
        enabledButtons(tester),
        isNotEmpty,
        reason: 'Écran non refermable ET aucune action possible : l\'app est '
            'définitivement inutilisable. C\'est exactement l\'état dans lequel '
            'se trouvait la build avant ce correctif.',
      );
    });

    testWidgets('et il ouvre bien le WhatsApp du conseiller', (tester) async {
      await pump(tester, '');

      await tester.tap(find.text('force_update_contact_cta'.tr));
      await tester.pumpAndSettle();

      expect(launcher.launched, isNotEmpty,
          reason: 'Le bouton de secours n\'a lancé aucune URL.');
      expect(
        Uri.parse(launcher.launched.single).host,
        'wa.me',
        reason: 'La sortie de secours doit mener au conseiller, pas ailleurs.',
      );
    });

    testWidgets('le bouton de store est masqué, pas grisé', (tester) async {
      await pump(tester, '');
      // Un bouton désactivé sur un écran sans sortie est une impasse déguisée en
      // interface : l'utilisateur le voit, appuie, et rien ne se passe.
      expect(find.text('force_update_cta'.tr), findsNothing);
    });
  });

  group('URL de store renseignée', () {
    const storeUrl = 'https://apps.apple.com/app/id1128659292';

    testWidgets('le bouton de store reste l\'action principale',
        (tester) async {
      await pump(tester, storeUrl);

      // Le principal est le FilledButton ; le secours passe en OutlinedButton.
      final filled = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(filled.onPressed, isNotNull);
      expect(find.text('force_update_cta'.tr), findsOneWidget);
      expect(find.byType(OutlinedButton), findsOneWidget);
      expect(find.text('force_update_contact_cta'.tr), findsOneWidget);
    });

    testWidgets('et il ouvre le store', (tester) async {
      await pump(tester, storeUrl);

      await tester.tap(find.text('force_update_cta'.tr));
      await tester.pumpAndSettle();

      expect(launcher.launched, [storeUrl]);
    });

    testWidgets('la sortie de secours reste disponible en plus',
        (tester) async {
      await pump(tester, storeUrl);

      await tester.tap(find.text('force_update_contact_cta'.tr));
      await tester.pumpAndSettle();

      expect(Uri.parse(launcher.launched.single).host, 'wa.me');
    });
  });

  test('les deux nouvelles clés existent dans les deux langues', () {
    final keys = AppTranslations().keys;
    for (final key in const [
      'force_update_contact_cta',
      'force_update_prefill',
    ]) {
      expect(keys['fr']![key], isNotNull, reason: '$key manque en FR');
      expect(keys['en']![key], isNotNull, reason: '$key manque en EN');
    }
  });
}
