import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/parcours/parcours_screen.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('ParcoursScreen', () {
    setUp(resetGetxSingleton);
    tearDown(() {
      AppConfig.enableRemoteSyncOverride = null;
      resetGetxSingleton();
    });

    testWidgets('shows an empty state when there are no videos',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const ParcoursScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      // Cold start with parcoursConfigured=false (the new default) — UI shows
      // the friendly "Bientôt disponible" empty state, NOT the harsh
      // "Contenu indisponible / wifi_off" error. The harsh state only triggers
      // once the backend explicitly reports configured=true but no videos.
      expect(find.byType(ParcoursScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('parcours_empty_soon_title'), findsOneWidget);
    });

    testWidgets('renders video cards when the playlist returns items',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.listParcoursVideos()).thenAnswer(
        (_) async => (
          items: const [
            YoutubeVideo(
              videoId: 'v1',
              title: 'Mon parcours au Canada',
              thumbnailUrl: 'https://img/v1.jpg',
            ),
            YoutubeVideo(
              videoId: 'v2',
              title: 'Réussir son visa étudiant',
              thumbnailUrl: 'https://img/v2.jpg',
            ),
          ],
          configured: true,
        ),
      );

      tester.view.physicalSize = const Size(1400, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpTestApp(
        tester,
        child: const ParcoursScreen(),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
        mockApiClient: mock,
      );

      // pumpTestApp forces remote sync OFF (so the post-frame initState fetch
      // early-returns). Re-enable it, then drive an explicit refetch.
      AppConfig.enableRemoteSyncOverride = true;
      await Get.find<AppController>().fetchParcoursVideos(force: true);
      await tester.pump();

      expect(find.text('Mon parcours au Canada'), findsOneWidget);
      expect(find.text('Réussir son visa étudiant'), findsOneWidget);
    });
  });
}
