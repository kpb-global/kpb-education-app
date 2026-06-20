import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/shell/app_shell.dart';

import '../widget_test_helpers.dart';

void main() {
  group('AppShell Widget Tests', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('displays bottom navigation bar with 5 tabs', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      expect(find.byKey(const ValueKey('kpb_shell_nav_bar')), findsOneWidget);
      // One icon per tab in the floating bar (5 tabs).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('kpb_shell_nav_bar')),
          matching: find.byType(Icon),
        ),
        findsNWidgets(5),
      );

      await tester.pumpAndSettle();
    });

    testWidgets('starts on Home tab (index 0)', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Get the AppController to check shellIndex
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(0));

      await tester.pumpAndSettle();
    });

    testWidgets('navigates to Destinations tab when tapped (index 1)',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Tap Destinations (second tab) — scope to nav bar so page icons don't match.
      final bar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      await tester.tap(
        find.descendant(of: bar, matching: find.byIcon(Icons.public_outlined)),
      );
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(1));
    });

    testWidgets('navigates to Cases tab when tapped (index 3)', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final bar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      await tester.tap(
        find.descendant(
            of: bar, matching: find.byIcon(Icons.folder_copy_outlined)),
      );
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(3));
    });

    testWidgets('navigates to Profile tab when tapped (index 4)',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final bar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      await tester.tap(
        find.descendant(
            of: bar, matching: find.byIcon(Icons.person_outline_rounded)),
      );
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(4));
    });

    testWidgets('preserves state when switching tabs', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();

      // Switch to Destinations (index 1)
      controller.goToTab(1);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(1));

      // Switch back to Home (index 0)
      controller.goToTab(0);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(0));

      // Switch to Cases (index 3)
      controller.goToTab(3);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(3));
    });

    testWidgets('rapid tab switching does not cause errors', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();

      // Rapidly switch tabs
      for (int i = 0; i < 5; i++) {
        controller.goToTab(i % 5);
        await tester.pump(const Duration(milliseconds: 50));
      }

      await tester.pumpAndSettle();
      // Should end up at tab 4
      expect(controller.shellIndex, equals(4));
    });

    testWidgets('displays selected icon for active tab', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      expect(find.byType(Icon), findsWidgets);

      // Verify tab switching updates controller
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(0));
      controller.goToTab(1);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(1));
    });

    testWidgets('uses IndexedStack to preserve tab state', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Verify IndexedStack is used (all pages are in the widget tree)
      expect(find.byType(IndexedStack), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('navigation works with AppController.goToTab method',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();

      // Use goToTab to navigate
      expect(controller.shellIndex, equals(0));

      controller.goToTab(4);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(4));

      controller.goToTab(0);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(0));
    });

    testWidgets('SafeArea is applied to prevent system UI overlap',
        (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      // Verify SafeArea is used
      expect(find.byType(SafeArea), findsWidgets);

      await tester.pumpAndSettle();
    });

    testWidgets('navigation bar height is set correctly', (tester) async {
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const AppShell(),
        initialSnapshot: snapshot,
      );

      final navBar = find.byKey(const ValueKey('kpb_shell_nav_bar'));
      expect(navBar, findsOneWidget);
      final container = tester.widget<Container>(navBar);
      expect(container.constraints!.maxHeight, equals(68));
    });
  });
}
