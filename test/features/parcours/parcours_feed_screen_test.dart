import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/parcours/parcours_feed_screen.dart';

import '../../widget_test_helpers.dart';

/// KPB-169 feed. The rules that matter on an entry-level phone over paid data:
/// nothing plays until tapped, and the page you swiped away stops existing.
void main() {
  group('ParcoursFeedScreen', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    const stories = [
      ParcoursStory(
        id: 'v1',
        slug: 'v-canada',
        kind: ParcoursKind.video,
        fieldId: 'd01',
        personName: 'Awa Diallo',
        title: LocalizedText(fr: 'Mon parcours au Canada', en: 'To Canada'),
        hook: LocalizedText(fr: 'De Niamey à Montréal', en: 'Niamey to MTL'),
        youtubeId: 'abc123',
        thumbnailUrl: 'https://img/v1.jpg',
      ),
      ParcoursStory(
        id: 't1',
        slug: 't-visa',
        kind: ParcoursKind.text,
        title: LocalizedText(fr: 'Obtenir son visa', en: 'Getting the visa'),
        interviewFr: [ParcoursQa(question: 'Q', answer: 'A')],
      ),
    ];

    Future<void> pumpFeed(WidgetTester tester) => pumpTestApp(
          tester,
          child: const ParcoursFeedScreen(stories: stories),
          initialSnapshot: AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(),
          ),
        );

    testWidgets('shows the first story without starting a player',
        (tester) async {
      await pumpFeed(tester);

      expect(find.text('Mon parcours au Canada'), findsOneWidget);
      expect(find.textContaining('Awa Diallo'), findsOneWidget);
      // The load-bearing assertion: a page is a poster, not a playing video.
      expect(find.byType(YoutubePlayer), findsNothing);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });

    testWidgets('swiping up moves to the next story', (tester) async {
      await pumpFeed(tester);

      await tester.fling(find.byType(PageView), const Offset(0, -600), 1000);
      await tester.pumpAndSettle();

      expect(find.text('Obtenir son visa'), findsOneWidget);
      expect(find.text('Mon parcours au Canada'), findsNothing);
      // A written story offers a read CTA, not a play button.
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.text('parcours_feed_read'), findsOneWidget);
    });

    testWidgets('renders an empty-state instead of crashing on no stories',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const ParcoursFeedScreen(stories: []),
        initialSnapshot: AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          profile: createTestProfile(),
        ),
      );

      expect(find.byType(PageView), findsNothing);
      expect(find.text('parcours_empty_filter_title'), findsOneWidget);
    });
  });
}
