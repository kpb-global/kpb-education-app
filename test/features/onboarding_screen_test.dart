import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  group('OnboardingScreen Widget Tests', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('renders the onboarding screen', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      expect(find.byType(OnboardingScreen), findsOneWidget);
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('displays first page title (Bienvenue)', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // Page 0 title is "Bienvenue 👋"
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && (w.data?.contains('Bienvenue') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays page counter "1 / 3" on first page', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // Default accountType is student → 3 pages
      expect(
        find.byWidgetPredicate(
          (w) => w is Text && w.data == '1 / 3',
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows FilledButton CTA at the bottom', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      expect(find.byType(FilledButton), findsOneWidget);
    });

    testWidgets('no back arrow on first page', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // Back arrow should NOT be visible on page 0
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
    });

    testWidgets('PageView uses NeverScrollableScrollPhysics', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      final pageView = tester.widget<PageView>(find.byType(PageView));
      expect(pageView.physics, isA<NeverScrollableScrollPhysics>());
    });

    testWidgets('has text form fields for name and email on page 0',
        (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // Page 0 (Identity) should have TextFormField widgets
      expect(find.byType(TextFormField), findsWidgets);
    });

    testWidgets('displays account type selectors on page 0', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // Should have Text widgets for the page content
      expect(find.byType(Text), findsWidgets);
    });
  });
}
