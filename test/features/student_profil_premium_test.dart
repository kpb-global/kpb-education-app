import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/premium/premium_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../widget_test_helpers.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement Profil restyle + honest Premium (PR8):
//   • Premium is NOT a paywall — value props bind the REAL AI-coach weekly quota
//     (5), the lone CTA hands off to the KPB advisor, and there is NO price,
//     checkout, external pay landing, or "Karatou ID payment" block anywhere.
//   • Profil restyle binds real data and omits the design's fabricated elements
//     (no streak, no in-app price).
// ─────────────────────────────────────────────────────────────────────────────

Future<AppController> _seed({
  AccountType accountType = AccountType.student,
}) async {
  AppConfig.enableRemoteSyncOverride = false;
  setupPlatformChannelMocks();

  final snapshot = AppSnapshot(
    localeCode: 'en',
    hasCompletedOnboarding: true,
    profile: createTestProfile(
      fullName: 'Awa Diallo',
      accountType: accountType,
    ),
  );

  final controller = AppController(
    repository: FakeRepository(snapshot: snapshot),
    apiClient: MockApiClient(),
  );
  await controller.hydrate();

  Get.put<AppController>(controller, permanent: true);
  return controller;
}

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: home,
    );

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    resetGetxSingleton();
  });
  tearDown(resetGetxSingleton);

  testWidgets(
      'PremiumScreen: honest value props + real quota + advisor CTA, '
      'and NO price / checkout / billing', (tester) async {
    await _seed();
    await tester.pumpWidget(_wrap(const PremiumScreen()));
    await tester.pumpAndSettle();

    // Value proposition (coming soon), incl. the REAL free AI-coach quota row.
    expect(find.text('premium_hero_title'.tr), findsOneWidget);
    expect(find.text('premium_value_advisors'.tr), findsOneWidget);
    expect(find.text('premium_free_ai_coach'.trParams({'count': '5'})),
        findsOneWidget);
    expect(find.text('premium_unlimited_soon'.tr), findsOneWidget);

    // Single advisor-routed CTA (reuses the parent premium key).
    expect(find.text('parent_premium_cta'.tr), findsOneWidget);

    // NO price, subscription, external checkout, or Karatou-ID payment block.
    expect(find.textContaining('FCFA'), findsNothing);
    expect(find.textContaining('4 900'), findsNothing);
    expect(find.textContaining('4,900'), findsNothing);
    expect(find.textContaining('karatou.app/premium'), findsNothing);
    expect(find.textContaining('/month'), findsNothing);
    expect(find.textContaining('/mois'), findsNothing);
    expect(find.textContaining('KARATOU ID'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'ProfileScreen: binds real name + honest Premium entry, '
      'omits fabricated streak/price', (tester) async {
    await _seed();
    await tester.pumpWidget(_wrap(const ProfileScreen()));
    await tester.pumpAndSettle();

    // Real profile name is bound.
    expect(find.textContaining('Awa'), findsWidgets);
    // Fabricated design elements are omitted.
    expect(find.textContaining('🔥'), findsNothing);
    expect(find.textContaining('FCFA'), findsNothing);

    // The honest Premium entry card is present (scroll it into view).
    final vScroll = find.byWidgetPredicate(
      (w) =>
          w is Scrollable &&
          (w.axisDirection == AxisDirection.down ||
              w.axisDirection == AxisDirection.up),
    );
    await tester.scrollUntilVisible(
      find.text('profile_premium_card_title'.tr),
      300,
      scrollable: vScroll,
    );
    expect(find.text('profile_premium_card_title'.tr), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
