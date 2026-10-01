// L'invitation douce à mettre à jour : elle doit pouvoir se taire, se fermer, et
// ne jamais enfermer.
//
// Le test ne regarde pas le serveur : il alimente `RemoteFeatureFlags` comme le
// fait `refresh`, c'est-à-dire par un `AppApiClient` simulé qui sert un
// `/config/app` — le chemin réel, sans réseau.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/services/remote_feature_flags.dart';
import 'package:karatou/app/core/ui/components/update_recommended_banner.dart';

import '../../support/raw_key_guard.dart';
import '../../support/screen_harness.dart';

class _MockApi extends Mock implements AppApiClient {}

const _androidStore =
    'https://play.google.com/store/apps/details?id=com.karatou.android';
const _iosStore = 'https://apps.apple.com/app/id1128659292';

Future<void> _serve(
  _MockApi api, {
  Object? recommendedVersion = '2.3.0',
  Object? androidStoreUrl = _androidStore,
  Object? iosStoreUrl = _iosStore,
}) async {
  when(api.getAppConfig).thenAnswer((_) async => <String, dynamic>{
        'minVersion': '0.0.0',
        'recommendedVersion': recommendedVersion,
        'androidStoreUrl': androidStoreUrl,
        'iosStoreUrl': iosStoreUrl,
      });
  await RemoteFeatureFlags.instance.refresh(api);
}

Future<String?> Function() _installed(String? version) => () async => version;

Future<KpbScreenReport> _pump(
  WidgetTester tester, {
  String? installed = '2.2.0',
  KpbViewport viewport = iphone14,
  double textScale = 1.0,
}) =>
    pumpKpbScreen(
      tester,
      screen: Padding(
        padding: const EdgeInsets.all(16),
        child: UpdateRecommendedBanner(installedVersion: _installed(installed)),
      ),
      viewport: viewport,
      textScale: textScale,
      ownsScaffold: false,
    );

void main() {
  late _MockApi api;

  setUp(() {
    api = _MockApi();
    RemoteFeatureFlags.resetForTest();
    UpdateRecommendedBanner.resetForTest();
    debugDefaultTargetPlatformOverride = null;
  });

  tearDown(() {
    RemoteFeatureFlags.resetForTest();
    UpdateRecommendedBanner.resetForTest();
    debugDefaultTargetPlatformOverride = null;
    Get.reset();
  });

  final banner = find.text('Une mise à jour est disponible');

  testWidgets(
      'invite quand la version installée est en dessous de la '
      'version recommandée', (tester) async {
    await _serve(api);
    await _pump(tester);

    expect(banner, findsOneWidget);
    expect(find.text('Mettre à jour'), findsOneWidget);
  });

  testWidgets('se tait quand le serveur ne recommande rien', (tester) async {
    await _serve(api, recommendedVersion: null);
    await _pump(tester);

    expect(banner, findsNothing);
  });

  testWidgets('se tait quand on est déjà à la version recommandée ou au-delà',
      (tester) async {
    await _serve(api, recommendedVersion: '2.3.0');
    await _pump(tester, installed: '2.3.0');
    expect(banner, findsNothing);

    await _pump(tester, installed: '2.4.1');
    expect(banner, findsNothing);
  });

  // `isVersionBelow` ignore le numéro de build : 2.3.0+53 et 2.3.0+54 sont la
  // même version marketing, et un bandeau pour un simple numéro de build
  // enverrait chaque utilisateur vers un store qui n'a rien de plus.
  testWidgets('ignore le numéro de build', (tester) async {
    await _serve(api, recommendedVersion: '2.3.0');
    await _pump(tester, installed: '2.3.0+53');
    expect(banner, findsNothing);
  });

  testWidgets('se tait quand la version recommandée est illisible',
      (tester) async {
    await _serve(api, recommendedVersion: 'latest');
    await _pump(tester);
    expect(banner, findsNothing);

    await _serve(api, recommendedVersion: 3);
    await _pump(tester);
    expect(banner, findsNothing);
  });

  testWidgets('se tait quand la version installée est illisible',
      (tester) async {
    await _serve(api);
    await _pump(tester, installed: null);
    expect(banner, findsNothing);
  });

  // Inviter sans dire où est une instruction sans geste.
  testWidgets('se tait quand aucun lien de store n\'est servi', (tester) async {
    await _serve(api, androidStoreUrl: '', iosStoreUrl: '');
    await _pump(tester);
    expect(banner, findsNothing);
  });

  testWidgets('se tait quand le lien de store n\'est pas une adresse web',
      (tester) async {
    await _serve(
      api,
      androidStoreUrl: 'javascript:alert(1)',
      iosStoreUrl: 'javascript:alert(1)',
    );
    await _pump(tester);
    expect(banner, findsNothing);
  });

  testWidgets('lit le lien du store de SA plateforme', (tester) async {
    // Seul le store Android est servi : sur iOS, le bandeau n'a aucun endroit
    // où envoyer, donc il se tait. Preuve que la plateforme est bien lue.
    await _serve(api, iosStoreUrl: null);

    // Le binding vérifie, AVANT les tearDown, qu'aucune variable de debug n'a
    // survécu au test : la remise à zéro se fait donc dans le corps.
    try {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await _pump(tester);
      expect(banner, findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      await _pump(tester);
      expect(banner, findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  // Un bouton qui ne fait rien est indiscernable d'une app plantée : quand le
  // lancement échoue (aucune activité pour le lien, ici le plugin absent), le
  // bandeau le DIT.
  testWidgets('un lien de store qui ne s\'ouvre pas le dit', (tester) async {
    await _serve(api);
    await _pump(tester);

    await tester.tap(find.text('Mettre à jour'));
    // L'appel de plateforme se résout hors de l'horloge simulée.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('pas pu ouvrir cette page'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('se ferme, et ne revient pas pour la même version recommandée',
      (tester) async {
    await _serve(api);
    await _pump(tester);
    expect(banner, findsOneWidget);

    await tester.tap(find.byTooltip('Plus tard'));
    await tester.pump();
    expect(banner, findsNothing);

    // Un nouvel écran (même session) ne le ressort pas.
    await _pump(tester);
    expect(banner, findsNothing);
  });

  testWidgets('revient quand une version PLUS RÉCENTE est recommandée',
      (tester) async {
    await _serve(api, recommendedVersion: '2.3.0');
    await _pump(tester);
    await tester.tap(find.byTooltip('Plus tard'));
    await tester.pump();
    expect(banner, findsNothing);

    await _serve(api, recommendedVersion: '2.4.0');
    await _pump(tester);
    expect(banner, findsOneWidget);
  });

  testWidgets('apparaît quand la config arrive APRÈS le montage',
      (tester) async {
    await _pump(tester);
    expect(banner, findsNothing);

    await _serve(api);
    await tester.pump();
    expect(banner, findsOneWidget);
  });

  group('géométrie — aucun débordement, aucun texte coupé, aucune clé brute',
      () {
    for (final viewport in kpbPhoneViewports) {
      for (final scale in kpbTextScales) {
        testWidgets('${viewport.id} ×$scale', (tester) async {
          await _serve(api);
          final report = await _pump(
            tester,
            viewport: viewport,
            textScale: scale,
          );

          expect(banner, findsOneWidget);
          expect(report.overflows, isEmpty, reason: report.toString());
          expect(report.otherErrors, isEmpty, reason: report.toString());
          expect(truncatedTexts(tester), isEmpty);
          expect(rawTranslationKeysOnScreen(tester), isEmpty);
        });
      }
    }
  });
}
