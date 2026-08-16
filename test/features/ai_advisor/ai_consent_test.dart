import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/controllers/app_controller.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/repositories/app_snapshot.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/ai_advisor/ai_consent.dart';

import '../../support/screen_harness.dart';
import '../../widget_test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(Get.reset);

  Future<AppController> pumpHost(
    WidgetTester tester, {
    required UserProfile profile,
  }) async {
    final controller = await seedKpbController(
      snapshot: AppSnapshot(
        localeCode: 'fr',
        hasCompletedOnboarding: true,
        profile: profile,
      ),
    );
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('fr'),
        fallbackLocale: const Locale('fr'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => ensureAiConsent(context, controller),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('already-consented profile skips the dialog', (tester) async {
    await pumpHost(tester, profile: createTestProfile());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('missing consent shows the dialog and decline keeps it unset',
      (tester) async {
    final controller = await pumpHost(
      tester,
      profile: createTestProfile(withAiConsent: false),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('ai_consent_decline'.tr));
    await tester.pumpAndSettle();
    expect(controller.profile?.hasAiConsent, isFalse);
  });
}
