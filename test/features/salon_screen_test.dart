import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:karatou/app/core/repositories/app_api_client.dart';
import 'package:karatou/app/core/ui/kpb_components.dart';
import 'package:karatou/app/features/salon/salon_screen.dart';

class _MockApi extends Mock implements AppApiClient {}

void main() {
  late _MockApi mock;

  setUp(() {
    mock = _MockApi();
  });

  testWidgets('shows KpbErrorState when listSalonEvents throws',
      (tester) async {
    when(() => mock.listSalonEvents()).thenThrow(Exception('network'));

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.byType(KpbErrorState), findsOneWidget);
    expect(find.text('salon_unavailable_title'), findsOneWidget);
    expect(find.textContaining('Réessayer'), findsOneWidget);
  });

  testWidgets('shows KpbEmptyState when list returns empty', (tester) async {
    when(() => mock.listSalonEvents()).thenAnswer((_) async => []);

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.byType(KpbEmptyState), findsOneWidget);
    expect(find.text('salon_no_edition_title'), findsOneWidget);
  });

  testWidgets('shows event row when list returns data', (tester) async {
    when(() => mock.listSalonEvents()).thenAnswer((_) async => [
          <String, dynamic>{
            'slug': 'spring-2026',
            'nameFr': 'Salon Printemps',
            'year': 2026,
            'startAt': '2026-06-01T10:00:00.000Z',
            'endAt': '2026-06-02T18:00:00.000Z',
            'descriptionFr': 'Universités invitées',
            'status': 'scheduled',
          },
        ]);

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Salon Printemps'), findsWidgets);
    expect(find.text('salon_view_sessions'), findsOneWidget);
  });

  testWidgets('retry calls listSalonEvents again after failure',
      (tester) async {
    var calls = 0;
    when(() => mock.listSalonEvents()).thenAnswer((_) async {
      calls++;
      if (calls == 1) throw Exception('fail');
      return <dynamic>[];
    });

    await tester.pumpWidget(MaterialApp(home: SalonScreen(apiClient: mock)));
    await tester.pumpAndSettle();

    expect(find.byType(KpbErrorState), findsOneWidget);

    await tester.tap(find.textContaining('Réessayer'));
    await tester.pumpAndSettle();

    expect(find.byType(KpbEmptyState), findsOneWidget);
    expect(calls, 2);
  });
}
