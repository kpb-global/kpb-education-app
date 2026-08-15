// PRIV-T6 : le plancher de 16 ans que les CGU affirment est APPLIQUÉ.
//
// Deux preuves, parce que le sélecteur seul ne suffit pas : une date peut
// venir d'un profil restauré. (1) lastDate du DatePicker = aujourd'hui − 16
// ans. (2) une date injectée de 10 ans fait refuser l'étape 0, en français.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';

import '../support/screen_harness.dart';
import '../widget_test_helpers.dart';

const _tall = KpbViewport(
  id: 'tall1200',
  name: 'tall 390×1400',
  size: Size(390, 1400),
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

void main() {
  tearDown(Get.reset);

  Future<void> pumpOnboarding(WidgetTester tester,
      {AppSnapshot? snapshot}) async {
    tester.view.physicalSize = _tall.size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await seedKpbController(snapshot: snapshot);
    await pumpKpbScreen(
      tester,
      screen: const OnboardingScreen(),
      viewport: _tall,
    );
  }

  testWidgets('le sélecteur de date refuse tout âge < 16', (tester) async {
    await pumpOnboarding(
      tester,
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        profile: createTestProfile(),
      ),
    );
    expect(tester.view.physicalSize.height, greaterThanOrEqualTo(1200));

    final dateInk = find.ancestor(
      of: find.text('Date de naissance'),
      matching: find.byType(InkWell),
    );
    await tester.ensureVisible(dateInk);
    await tester.tap(dateInk);
    await tester.pumpAndSettle();

    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    final now = DateTime.now();
    final expected = DateTime(now.year - 16, now.month, now.day);
    expect(picker.lastDate, expected);
    expect(picker.lastDate.isBefore(DateTime(now.year, now.month, now.day)),
        isTrue);
  });

  testWidgets('une date restaurée de 10 ans est refusée à l\'étape 0',
      (tester) async {
    final now = DateTime.now();
    final tenYearsAgo = DateTime(now.year - 10, now.month, now.day);
    await pumpOnboarding(
      tester,
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: false,
        profile: createTestProfile().copyWith(
          birthDate: tenYearsAgo,
          consentedAt: now,
          countryOfResidence: 'Niger',
        ),
      ),
    );

    final phone = find.byWidgetPredicate(
      (w) => w is TextField && w.keyboardType == TextInputType.phone,
    );
    expect(phone, findsOneWidget);
    await tester.enterText(phone, '07000000');
    await tester.pump();

    final next = find.widgetWithText(FilledButton, 'Continuer');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('16 ans'), findsWidgets);
    expect(find.text('1 / 3'), findsOneWidget);

    // Get.snackbar tient un ticker + un minuteur de 3 s. Un seul `pump(4s)`
    // déclenche la sortie mais laisse l'animation reverse en cours, et le
    // teardown échoue. On avance par petites trames jusqu'à quiescence.
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  });
}
