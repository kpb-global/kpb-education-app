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

    testWidgets('displays first page title', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      expect(
        find.byWidgetPredicate(
          // .tr resolves to the key in tests (no translations loaded in the harness).
          (w) =>
              w is Text &&
              (w.data?.contains('onboarding_welcome_title') ?? false),
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays page counter "1 / 3" on first page', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // Student account => 3 pages; the redesigned header shows "1 / 3".
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

    testWidgets('displays account type selectors on page 0', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // .tr resolves to the key in tests (no translations loaded in the harness).
      expect(find.text('account_type_student'), findsOneWidget);
      expect(find.text('account_type_parent_short'), findsOneWidget);
      expect(find.text('badge_partner'), findsOneWidget);
    });

    testWidgets('has identity text fields on page 0', (tester) async {
      await pumpTestApp(
        tester,
        child: const OnboardingScreen(),
      );

      // The redesigned page 0 collects identity (first/last name, email,
      // phone) up front, so identity text fields ARE present here.
      expect(find.byType(TextFormField), findsWidgets);
    });
  });
}
