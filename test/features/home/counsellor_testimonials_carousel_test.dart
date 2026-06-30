import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/ui/components/kpb_card.dart';
import 'package:karatou/app/features/home/counsellor_testimonials_carousel.dart';

import '../../widget_test_helpers.dart';

void main() {
  group('CounsellorTestimonialsCarousel', () {
    setUp(resetGetxSingleton);
    tearDown(resetGetxSingleton);

    testWidgets('renders nothing when there are no published reviews',
        (tester) async {
      final api = MockApiClient();
      when(api.getPublishedReviews).thenAnswer(
          (_) async => <String, dynamic>{'reviews': [], 'count': 0});

      await pumpTestApp(
        tester,
        child: const CounsellorTestimonialsCarousel(),
        mockApiClient: api,
      );
      await tester.pumpAndSettle();

      // Graceful empty state: the whole widget collapses to nothing.
      expect(find.byType(KpbCard), findsNothing);
      final shrink = tester.widget<SizedBox>(
        find.descendant(
          of: find.byType(CounsellorTestimonialsCarousel),
          matching: find.byType(SizedBox),
        ),
      );
      expect(shrink.width, 0.0);
      expect(shrink.height, 0.0);
    });

    testWidgets('renders one card per published review', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1600));
      final api = MockApiClient();
      when(api.getPublishedReviews).thenAnswer(
        (_) async => <String, dynamic>{
          'count': 3,
          'reviews': [
            {
              'id': 'r1',
              'counsellorId': 'c1',
              'reviewerName': 'Aïcha',
              'rating': 5,
              'body': 'Accompagnement exceptionnel du début à la fin.',
              'createdAt': '2026-06-20T10:00:00.000Z',
            },
            {
              'id': 'r2',
              'counsellorId': 'c2',
              'reviewerName': 'Boris',
              'rating': 4,
              'body': 'Très réactif et de bon conseil.',
              'createdAt': '2026-06-18T10:00:00.000Z',
            },
            {
              'id': 'r3',
              'counsellorId': 'c3',
              'reviewerName': 'Fatou',
              'rating': 5,
              'body': 'Visa obtenu grâce à leur aide.',
              'createdAt': '2026-06-15T10:00:00.000Z',
            },
          ],
        },
      );

      await pumpTestApp(
        tester,
        child: const CounsellorTestimonialsCarousel(),
        mockApiClient: api,
      );
      await tester.pumpAndSettle();

      expect(find.byType(KpbCard), findsNWidgets(3));
      expect(find.text('Aïcha'), findsOneWidget);
      expect(find.text('Boris'), findsOneWidget);
      expect(find.text('Fatou'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('stays hidden when the request fails', (tester) async {
      final api = MockApiClient();
      when(api.getPublishedReviews).thenThrow(Exception('offline'));

      await pumpTestApp(
        tester,
        child: const CounsellorTestimonialsCarousel(),
        mockApiClient: api,
      );
      await tester.pumpAndSettle();

      expect(find.byType(KpbCard), findsNothing);
    });
  });
}
