// PRIV-T2 : la politique in-app dit la vérité, en FR et en EN.
//
// Traductions réellement chargées (pas les clés brutes). Surface ≥ 1200 px
// pour que le défilé soit possible. On cherche les destinataires et les
// collectes que l'inventaire a tirés du code, et on vérifie l'absence de
// la conservation « 3 ans après la clôture » — une durée que rien dans
// le backend ne tient.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/features/legal/legal_pages.dart';

import '../../support/screen_harness.dart';

Future<void> _pumpPolicy(WidgetTester tester, Locale locale) async {
  tester.view.physicalSize = const Size(390, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  Get.addTranslations(AppTranslations().keys);
  Get.locale = locale;
  Get.fallbackLocale = locale;
  await seedKpbController();
  await tester.pumpWidget(
    GetMaterialApp(
      locale: locale,
      fallbackLocale: locale,
      translations: AppTranslations(),
      theme: AppTheme.buildTheme(),
      home: const PrivacyPolicyScreen(),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _scrollToBottom(WidgetTester tester) async {
  final scrollable = find.byType(Scrollable);
  expect(scrollable, findsWidgets);
  await tester.fling(scrollable.first, const Offset(0, -4000), 2000);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  testWidgets('politique FR : destinataires et collectes, pas de 3 ans',
      (tester) async {
    await _pumpPolicy(tester, const Locale('fr'));
    expect(tester.view.physicalSize.height, greaterThanOrEqualTo(1200));
    await _scrollToBottom(tester);

    for (final needle in [
      'Groq',
      'OneSignal',
      'Resend',
      'Supabase',
      'passeport',
      'Photo de profil',
      'micro',
      'États-Unis',
    ]) {
      expect(find.textContaining(needle), findsWidgets, reason: needle);
    }
    expect(find.textContaining('3 ans après la clôture'), findsNothing);
    expect(find.textContaining('www.kpbeducation.com'), findsNothing);
  });

  testWidgets('politique EN : same processors, no 3-year retention',
      (tester) async {
    await _pumpPolicy(tester, const Locale('en'));
    await _scrollToBottom(tester);

    for (final needle in [
      'Groq',
      'OneSignal',
      'Resend',
      'Supabase',
      'passport',
      'Profile photo',
      'microphone',
      'United States',
    ]) {
      expect(find.textContaining(needle), findsWidgets, reason: needle);
    }
    expect(find.textContaining('3 ans après la clôture'), findsNothing);
    expect(find.textContaining('www.kpbeducation.com'), findsNothing);
  });
}
