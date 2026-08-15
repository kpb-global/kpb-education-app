// TST-T19 : un utilisateur déjà en `en` se réveille en français, sans
// sélecteur. Les clés EN restent (parité) ; switchLanguage n'est pas détruit.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/i18n/app_locale.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/features/eligibility/eligibility_simulator_screen.dart';
import 'package:karatou/app/features/onboarding/onboarding_screen.dart';
import 'package:karatou/app/features/profile/profile_screen.dart';

import '../support/screen_harness.dart';
import '../widget_test_helpers.dart';

const _phone = KpbViewport(
  id: 'iphone390',
  name: '390×844',
  size: Size(390, 844),
  padding: EdgeInsets.only(top: 47, bottom: 34),
);

void main() {
  tearDown(Get.reset);

  test('canonicalAppLocale ramène tout à fr', () {
    expect(canonicalAppLocale('en'), 'fr');
    expect(canonicalAppLocale('en_US'), 'fr');
    expect(canonicalAppLocale('ar'), 'fr');
    expect(canonicalAppLocale(null), 'fr');
    expect(canonicalAppLocale('fr'), 'fr');
    expect(kLanguageSwitchVisible, isFalse);
  });

  testWidgets(
      'snapshot + profil en hydratés : FR, pas de sélecteur, coach lang=fr',
      (tester) async {
    final controller = await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'en',
        hasCompletedOnboarding: true,
        profile: createTestProfile(preferredLanguage: 'en'),
      ),
    );

    expect(controller.localeCode, 'fr');
    expect(controller.profile!.preferredLanguage, 'fr');

    await pumpKpbScreen(
      tester,
      screen: const ProfileScreen(),
      viewport: _phone,
    );
    expect(find.text('Langue de l\'application'), findsNothing);
    expect(find.text('App language'), findsNothing);
    expect(find.text('English'), findsNothing);
    expect(find.text('EN'), findsNothing);

    await pumpKpbScreen(
      tester,
      screen: const EligibilitySimulatorScreen(),
      viewport: _phone,
    );
    expect(find.text('Simulateur d\'éligibilité'), findsOneWidget);
    expect(find.text('Eligibility simulator'), findsNothing);
  });

  testWidgets('onboarding masqué : pas de bascule FR | EN', (tester) async {
    await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'en',
        hasCompletedOnboarding: false,
        profile: createTestProfile(preferredLanguage: 'en'),
      ),
    );
    await pumpKpbScreen(
      tester,
      screen: const OnboardingScreen(),
      viewport: _phone,
    );
    expect(find.text('Anglais'), findsNothing);
    expect(find.text('English'), findsNothing);
  });
}
