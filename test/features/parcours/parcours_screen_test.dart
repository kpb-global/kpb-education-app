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

    testWidgets('shows the friendly empty state when there are no stories',
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

      // Cold start with no stories and no error → friendly "Bientôt disponible"
      // empty state (not the harsh error state).
      expect(find.byType(ParcoursScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('parcours_empty_soon_title'), findsOneWidget);
    });

    testWidgets('renders story cards and the theme filter when items load',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.listParcoursStories()).thenAnswer(
        (_) async => const [
          ParcoursStory(
            id: 'v1',
            slug: 'v-canada',
            kind: ParcoursKind.video,
            fieldId: 'd01',
            title: LocalizedText(
                fr: 'Mon parcours au Canada', en: 'My journey to Canada'),
            youtubeId: 'v1',
            thumbnailUrl: 'https://img/v1.jpg',
          ),
          ParcoursStory(
            id: 't1',
            slug: 't-visa',
            kind: ParcoursKind.text,
            fieldId: 'd07',
            personName: 'Awa Diallo',
            title: LocalizedText(
                fr: 'Réussir son visa étudiant', en: 'Ace your student visa'),
          ),
        ],
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
      await Get.find<AppController>().fetchParcoursStories(force: true);
      await tester.pump();

      expect(find.text('Mon parcours au Canada'), findsOneWidget);
      expect(find.text('Réussir son visa étudiant'), findsOneWidget);
      // The "All" theme chip appears once stories with fields are loaded.
      expect(find.text('parcours_filter_all'), findsOneWidget);
    });

    testWidgets('filters stories by search query', (tester) async {
      final mock = MockApiClient();
      when(() => mock.listParcoursStories()).thenAnswer(
        (_) async => const [
          ParcoursStory(
            id: 'v1',
            slug: 'v-canada',
            kind: ParcoursKind.video,
            fieldId: 'd01',
            title: LocalizedText(fr: 'Parcours Canada', en: 'Canada journey'),
            youtubeId: 'v1',
          ),
          ParcoursStory(
            id: 'v2',
            slug: 'v-avocat',
            kind: ParcoursKind.video,
            fieldId: 'd07',
            title: LocalizedText(fr: 'Devenir avocat', en: 'Become a lawyer'),
            youtubeId: 'v2',
          ),
        ],
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

      AppConfig.enableRemoteSyncOverride = true;
      final controller = Get.find<AppController>();
      await controller.fetchParcoursStories(force: true);
      await tester.pump();

      controller.setParcoursQuery('avocat');
      await tester.pump();

      expect(find.text('Devenir avocat'), findsOneWidget);
      expect(find.text('Parcours Canada'), findsNothing);
    });
  });
}
