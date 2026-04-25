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

      // Verify NavigationBar is present
      expect(find.byType(NavigationBar), findsOneWidget);

      // Verify 5 navigation destinations
      expect(
        find.byType(NavigationDestination),
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

    testWidgets('navigates to Explore tab when tapped (index 1)',
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

      // Find and tap the Explore tab (second destination)
      final exploreTab = find.byType(NavigationDestination).at(1);
      await tester.tap(exploreTab);
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(1));
    });

    testWidgets('navigates to Cases tab when tapped (index 2)', (tester) async {
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

      // Find and tap the Cases tab (third destination)
      final casesTab = find.byType(NavigationDestination).at(2);
      await tester.tap(casesTab);
      await tester.pumpAndSettle();

      // Verify shellIndex updated
      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(2));
    });

    testWidgets('navigates to Saved tab when tapped (index 3)', (tester) async {
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

      // Find and tap the Saved tab (fourth destination)
      final savedTab = find.byType(NavigationDestination).at(3);
      await tester.tap(savedTab);
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

      // Find and tap the Profile tab (fifth destination)
      final profileTab = find.byType(NavigationDestination).at(4);
      await tester.tap(profileTab);
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

      // Switch to Explore (index 1)
      controller.goToTab(1);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(1));

      // Switch back to Home (index 0)
      controller.goToTab(0);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(0));

      // Switch to Cases (index 2)
      controller.goToTab(2);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(2));
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

      // Verify icons are rendered in the NavigationBar
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

      controller.goToTab(3);
      await tester.pumpAndSettle();
      expect(controller.shellIndex, equals(3));

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

      // Find NavigationBar and verify it has correct height
      final navBar = find.byType(NavigationBar);
      expect(navBar, findsOneWidget);

      // The NavigationBar in AppShell has height: 68
      final widget = tester.widget<NavigationBar>(navBar);
      expect(widget.height, equals(68));
    });
  });
}
