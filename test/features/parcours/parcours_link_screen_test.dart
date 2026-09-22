import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/parcours/parcours_feed_screen.dart';
import 'package:karatou/app/features/parcours/parcours_link_screen.dart';
import 'package:karatou/app/features/parcours/parcours_screen.dart';
import 'package:karatou/app/features/parcours/parcours_story_screen.dart';

import '../../widget_test_helpers.dart';

/// `/parcours/<slug>` ne porte que le slug : l'écran doit retrouver le récit
/// (le push hebdomadaire vise le récit mis en avant) et retomber sur la
/// bibliothèque — jamais sur un écran vide — quand le slug est inconnu.
///
/// Les cas « catalogue » ouvrent le portillon réseau (`enableRemoteSync: true`) :
/// portillon fermé, `fetchParcoursStories` rend la main sans appeler le client
/// et ces tests passeraient sans rien prouver.
void main() {
  group('ParcoursLinkScreen', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      resetGetxSingleton();
      AppConfig.enableRemoteSyncOverride = false;
    });

    const textStory = ParcoursStory(
      id: 's1',
      slug: 'awa-ingenieure',
      kind: ParcoursKind.text,
      personName: 'Awa Diallo',
      title: LocalizedText(fr: 'Ingénieure au Canada', en: 'Engineer'),
    );
    const videoStory = ParcoursStory(
      id: 's2',
      slug: 'moussa-medecin',
      kind: ParcoursKind.video,
      personName: 'Moussa Sow',
      title: LocalizedText(fr: 'Médecin à Lyon', en: 'Doctor in Lyon'),
      youtubeId: 'abc',
    );

    /// Monte l'app sur un écran neutre, puis pousse l'écran de lien comme le
    /// ferait `Get.toNamed`. Pas de pumpAndSettle sur l'écran de lien : son
    /// spinner tourne sans fin tant que la résolution n'est pas finie.
    Future<void> openLink(
      WidgetTester tester,
      MockApiClient mock,
      String slug, {
      bool enableRemoteSync = false,
      Future<void> Function()? beforeOpen,
    }) async {
      await pumpTestApp(
        tester,
        child: const SizedBox.shrink(),
        mockApiClient: mock,
        enableRemoteSync: enableRemoteSync,
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );
      await beforeOpen?.call();
      unawaited(Get.to<void>(() => ParcoursLinkScreen(slug: slug)));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('opens the featured story named by the push', (tester) async {
      final mock = MockApiClient();
      when(() => mock.fetchStoryOfWeek()).thenAnswer((_) async => textStory);

      await openLink(tester, mock, 'awa-ingenieure');

      expect(find.byType(ParcoursStoryScreen), findsOneWidget);
      expect(find.byType(ParcoursScreen), findsNothing);
    });

    testWidgets('falls back to the library for an unknown slug',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.fetchStoryOfWeek()).thenAnswer((_) async => textStory);

      await openLink(tester, mock, 'inconnu');

      expect(find.byType(ParcoursStoryScreen), findsNothing);
      expect(find.byType(ParcoursScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('opens a catalog video in the feed, tagged deep_link',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.listParcoursStories())
          .thenAnswer((_) async => [textStory, videoStory]);

      await openLink(tester, mock, 'moussa-medecin', enableRemoteSync: true);

      final feed =
          tester.widget<ParcoursFeedScreen>(find.byType(ParcoursFeedScreen));
      expect(feed.stories.single.slug, 'moussa-medecin');
      // Sans ce tag, un tap sur le push compterait comme du trafic « feed ».
      expect(feed.analyticsSource, 'deep_link');
      verifyNever(() => mock.fetchStoryOfWeek());
    });

    testWidgets('does not repeat a catalog request that just failed',
        (tester) async {
      final mock = MockApiClient();
      var catalogCalls = 0;
      when(() => mock.listParcoursStories()).thenAnswer((_) async {
        catalogCalls++;
        throw Exception('timeout');
      });
      when(() => mock.fetchStoryOfWeek()).thenThrow(Exception('timeout'));

      await openLink(tester, mock, 'awa-ingenieure', enableRemoteSync: true);

      expect(find.byType(ParcoursScreen), findsOneWidget);
      // 1 appel de l'écran de lien + 1 de la bibliothèque (son initState).
      // Avant le correctif : 3, chacun pouvant coûter un délai réseau complet.
      expect(catalogCalls, 2);
    });

    testWidgets('waits for a catalog load already in flight (cold start)',
        (tester) async {
      final mock = MockApiClient();
      final pending = Completer<List<ParcoursStory>>();
      var catalogCalls = 0;
      when(() => mock.listParcoursStories()).thenAnswer((_) {
        catalogCalls++;
        return pending.future;
      });
      when(() => mock.fetchStoryOfWeek()).thenAnswer((_) async => null);

      await openLink(
        tester,
        mock,
        'awa-ingenieure',
        enableRemoteSync: true,
        // L'accueil a déjà lancé le chargement quand le push arrive.
        beforeOpen: () async {
          unawaited(Get.find<AppController>().fetchParcoursStories());
        },
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pending.complete([textStory]);
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.byType(ParcoursStoryScreen), findsOneWidget);
      expect(catalogCalls, 1);
    });
  });
}
