import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/parcours/parcours_link_screen.dart';
import 'package:karatou/app/features/parcours/parcours_screen.dart';
import 'package:karatou/app/features/parcours/parcours_story_screen.dart';

import '../../widget_test_helpers.dart';

/// `/parcours/<slug>` ne porte que le slug : l'écran doit retrouver le récit
/// (le push hebdomadaire vise le récit mis en avant) et retomber sur la
/// bibliothèque — jamais sur un écran vide — quand le slug est inconnu.
void main() {
  group('ParcoursLinkScreen', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    const story = ParcoursStory(
      id: 's1',
      slug: 'awa-ingenieure',
      kind: ParcoursKind.text,
      personName: 'Awa Diallo',
      title: LocalizedText(fr: 'Ingénieure au Canada', en: 'Engineer'),
    );

    Future<void> pumpLink(
      WidgetTester tester,
      MockApiClient mock,
      String slug,
    ) async {
      await pumpTestApp(
        tester,
        child: ParcoursLinkScreen(slug: slug),
        mockApiClient: mock,
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );
      // Pas de pumpAndSettle : le spinner de résolution tourne sans fin.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    MockApiClient mockWithFeatured() {
      final mock = MockApiClient();
      when(() => mock.fetchStoryOfWeek()).thenAnswer((_) async => story);
      when(() => mock.listParcoursStories()).thenAnswer((_) async => []);
      return mock;
    }

    testWidgets('opens the featured story named by the push', (tester) async {
      await pumpLink(tester, mockWithFeatured(), 'awa-ingenieure');

      expect(find.byType(ParcoursStoryScreen), findsOneWidget);
      expect(find.byType(ParcoursScreen), findsNothing);
    });

    testWidgets('falls back to the library for an unknown slug',
        (tester) async {
      await pumpLink(tester, mockWithFeatured(), 'inconnu');

      expect(find.byType(ParcoursStoryScreen), findsNothing);
      expect(find.byType(ParcoursScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
