import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/features/scholarships/widgets/application_requirement_badge.dart';

void main() {
  tearDown(Get.reset);

  Future<void> pumpBadge(
    WidgetTester tester, {
    required bool isAutomatic,
    bool compact = false,
    Locale locale = const Locale('fr'),
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: locale,
        fallbackLocale: const Locale('fr'),
        home: Scaffold(
          body: ApplicationRequirementBadge(
            isAutomatic: isAutomatic,
            accent: Colors.blue,
            compact: compact,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the automatic-admission label in French', (tester) async {
    await pumpBadge(tester, isAutomatic: true);
    expect(find.text('Attribution automatique'), findsOneWidget);
  });

  testWidgets('shows the separate-application label in French', (tester) async {
    await pumpBadge(tester, isAutomatic: false);
    expect(find.text('Candidature séparée requise'), findsOneWidget);
  });

  testWidgets('shows the English label when locale is en', (tester) async {
    await pumpBadge(tester, isAutomatic: true, locale: const Locale('en'));
    expect(find.text('Automatically awarded'), findsOneWidget);
  });

  testWidgets('renders in compact mode without throwing', (tester) async {
    await pumpBadge(tester, isAutomatic: false, compact: true);
    expect(find.byType(ApplicationRequirementBadge), findsOneWidget);
  });
}
