import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/home/story_of_week_card.dart';

import '../../widget_test_helpers.dart';

/// The Home card must be honest: it exists only when the editorial slot is
/// filled. No skeleton, no "bientôt", nothing at all when the answer is null —
/// and a failing call is indistinguishable from an empty slot, on purpose.
void main() {
  group('StoryOfWeekCard', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    const story = ParcoursStory(
      id: 's1',
      slug: 'awa-ingenieure',
      kind: ParcoursKind.video,
      personName: 'Awa Diallo',
      title: LocalizedText(fr: 'Ingénieure au Canada', en: 'Engineer'),
      hook: LocalizedText(fr: 'De Niamey à Montréal', en: 'Niamey to MTL'),
      youtubeId: 'abc',
    );

    Future<void> pumpCard(WidgetTester tester, MockApiClient mock) =>
        pumpTestApp(
          tester,
          child: const Scaffold(body: StoryOfWeekCard()),
          mockApiClient: mock,
          initialSnapshot: AppSnapshot(
            localeCode: 'fr',
            hasCompletedOnboarding: true,
            profile: createTestProfile(),
          ),
        );

    testWidgets('renders the week\'s story', (tester) async {
      final mock = MockApiClient();
      when(() => mock.fetchStoryOfWeek()).thenAnswer((_) async => story);

      await pumpCard(tester, mock);
      await tester.pumpAndSettle();

      expect(find.text('story_of_week_title'), findsOneWidget);
      expect(find.text('Ingénieure au Canada'), findsOneWidget);
      expect(find.textContaining('Awa Diallo'), findsOneWidget);
    });

    testWidgets('renders nothing when no story is featured', (tester) async {
      final mock = MockApiClient();
      when(() => mock.fetchStoryOfWeek()).thenAnswer((_) async => null);

      await pumpCard(tester, mock);
      await tester.pumpAndSettle();

      expect(find.text('story_of_week_title'), findsNothing);
      expect(find.byType(InkWell), findsNothing);
    });

    testWidgets('renders nothing — and does not throw — when the call fails',
        (tester) async {
      final mock = MockApiClient();
      when(() => mock.fetchStoryOfWeek()).thenThrow(Exception('offline'));

      await pumpCard(tester, mock);
      await tester.pumpAndSettle();

      expect(find.text('story_of_week_title'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
