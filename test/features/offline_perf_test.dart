import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/kpb_network_image.dart';
import 'package:karatou/app/core/ui/components/kpb_offline_banner.dart';

import '../widget_test_helpers.dart';

void main() {
  group('kpbFreshnessLabel', () {
    final now = DateTime(2026, 6, 20, 10, 0);

    // The label is localized via `.tr`; register translations + a FR locale so
    // these assert the real French output rather than the raw key.
    setUp(() {
      Get.reset();
      Get.addTranslations(AppTranslations().keys);
      Get.locale = const Locale('fr');
    });
    tearDown(Get.reset);

    test('null sync time → generic label', () {
      expect(kpbFreshnessLabel(null, now: now), 'données enregistrées');
    });

    test('same day → aujourd\'hui', () {
      final label = kpbFreshnessLabel(DateTime(2026, 6, 20, 8), now: now);
      expect(label, contains("aujourd'hui"));
    });

    test('one day ago → hier', () {
      final label = kpbFreshnessLabel(DateTime(2026, 6, 19, 22), now: now);
      expect(label, contains('hier'));
    });

    test('a few days ago → il y a N jours', () {
      final label = kpbFreshnessLabel(DateTime(2026, 6, 17), now: now);
      expect(label, contains('il y a 3 jours'));
    });

    test('over a week ago → absolute numeric date', () {
      final label = kpbFreshnessLabel(DateTime(2026, 6, 8), now: now);
      expect(label, contains('8/6'));
    });
  });

  group('KpbNetworkImage', () {
    tearDown(Get.reset);

    testWidgets('renders CachedNetworkImage when data-saver is off',
        (tester) async {
      await pumpTestApp(
        tester,
        initialSnapshot: const AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
        ),
        child: const KpbNetworkImage(
          imageUrl: 'https://example.com/thumb.png',
          width: 120,
          height: 90,
        ),
      );

      expect(find.byType(CachedNetworkImage), findsOneWidget);
    });

    testWidgets('suppresses a decorative image in data-saver mode',
        (tester) async {
      await pumpTestApp(
        tester,
        initialSnapshot: const AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
          dataSaverEnabled: true,
        ),
        child: const KpbNetworkImage(
          imageUrl: 'https://example.com/thumb.png',
          width: 120,
          height: 90,
          placeholderIcon: Icons.ondemand_video_rounded,
        ),
      );

      // No network fetch happens; the lightweight placeholder shows instead.
      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byIcon(Icons.ondemand_video_rounded), findsOneWidget);
    });

    testWidgets('empty url → fallback icon, never a network fetch',
        (tester) async {
      await pumpTestApp(
        tester,
        initialSnapshot: const AppSnapshot(
          localeCode: 'fr',
          hasCompletedOnboarding: true,
        ),
        child: const KpbNetworkImage(
          imageUrl: '',
          width: 120,
          height: 90,
          placeholderIcon: Icons.business,
        ),
      );

      expect(find.byType(CachedNetworkImage), findsNothing);
      expect(find.byIcon(Icons.business), findsOneWidget);
    });
  });
}
