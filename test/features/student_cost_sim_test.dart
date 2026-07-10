import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/utils/country_utils.dart';
import 'package:karatou/app/features/budget/budget_calculator_screen.dart';
import 'package:karatou/app/features/budget/data/budget_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Smoke tests for the App-engagement "Simulateur de coût" restyle (PR9):
//   • Binds the REAL KPB living-cost model (categories, currency, monthly total,
//     min/max band) from budget_data.dart.
//   • Omits the mock's fabricated specifics (Numbeo/Kayak/Eiffel, the
//     Grenoble/2-years/flatshare subtitle, and any cross-currency FCFA total).
//   • Destination + lifestyle remain real inputs that rebind without crashing.
// ─────────────────────────────────────────────────────────────────────────────

Widget _wrap(Widget home) => GetMaterialApp(
      translations: AppTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: home,
    );

void main() {
  tearDown(Get.reset);

  testWidgets(
      'renders real KPB living-cost data and honest chrome, '
      'omits fabricated specifics', (tester) async {
    // Tall viewport so every lazily-built ListView child (incl. the footnote
    // and CTA) is laid out and findable.
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const BudgetCalculatorScreen()));
    await tester.pumpAndSettle();

    final france = mockBudgetProfiles.first; // native currency = EUR

    // Title + eyebrow (monthly, not "2 years").
    expect(find.text('budget_calculator_title'.tr), findsOneWidget);
    expect(
        find.text('estimated_monthly_budget'.tr.toUpperCase()), findsOneWidget);

    // Real category rows + native currency bound from the model.
    expect(find.text('budget_category_rent'.tr), findsOneWidget);
    expect(find.text('budget_category_leisure'.tr), findsOneWidget);
    expect(find.textContaining(france.currency), findsWidgets); // EUR

    // Honest source footnote + generic scholarships CTA.
    expect(find.text('budget_sources_note'.tr), findsOneWidget);
    expect(find.text('budget_see_scholarships_cta'.tr), findsOneWidget);

    // Fabricated design specifics must never render.
    for (final banned in [
      'Numbeo',
      'Kayak',
      'Eiffel',
      'Grenoble',
      'flatshare',
      'FCFA',
      '28,200',
      '18,5',
    ]) {
      expect(find.textContaining(banned), findsNothing,
          reason: 'must not render fabricated "$banned"');
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('lifestyle + destination switches rebind real data safely',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrap(const BudgetCalculatorScreen()));
    await tester.pumpAndSettle();

    // Lifestyle band toggle exercises the recompute path.
    await tester.tap(find.text('budget_lifestyle_confort'.tr));
    await tester.pumpAndSettle();
    await tester.tap(find.text('budget_lifestyle_econome'.tr));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Destination selection rebinds the currency (France EUR → Canada CAD).
    final canada = mockBudgetProfiles[1];
    expect(find.textContaining(canada.currency), findsNothing); // CAD
    await tester
        .tap(find.text('${countryFlag(canada.country)} ${canada.country}'));
    await tester.pumpAndSettle();
    expect(find.textContaining(canada.currency), findsWidgets); // CAD
    expect(tester.takeException(), isNull);
  });
}
