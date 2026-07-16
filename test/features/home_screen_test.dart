import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/home/home_screen.dart';

import '../widget_test_helpers.dart';

void main() {
  group('HomeScreen Widget Tests', () {
    setUp(() {
      resetGetxSingleton();
    });

    tearDown(() {
      resetGetxSingleton();
    });

    testWidgets('renders home screen and top actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      final profile = createTestProfile(fullName: 'Aminou Diallo');
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: snapshot,
      );

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byIcon(Icons.smart_toy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('profile action jumps to profile tab', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: snapshot,
      );

      final controller = Get.find<AppController>();
      expect(controller.shellIndex, equals(0));

      await tester.tap(find.byIcon(Icons.person_outline_rounded));
      await tester.pumpAndSettle();

      expect(controller.shellIndex, equals(4));

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('renders the Diambar Gauge card and the WhatsApp CTA',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2560));
      final profile = createTestProfile();
      final snapshot = AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      );

      await pumpTestApp(
        tester,
        child: const HomeScreen(),
        initialSnapshot: snapshot,
      );

      // Profile isn't 100% complete (no monthly budget) → the readiness ring
      // + its "Diambar Gauge" eyebrow render (App-engagement handoff).
      // `.tr` resolves to the raw key in this harness (no translations
      // loaded), matching the convention used across this test suite.
      expect(find.text('home_gauge_eyebrow'), findsOneWidget);

      // The "Talk to a KPB counselor" WhatsApp hand-off card is always on
      // Home now — real WhatsApp routing, no in-app checkout.
      expect(find.text('home_counselor_cta_title'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
