import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/translations/app_translations.dart';
import 'package:karatou/app/core/ui/components/verified_badge.dart';

void main() {
  // Wrap the badge in a GetMaterialApp so `.tr` resolves against a real locale,
  // letting us assert the localized output (not just the key).
  Future<void> pump(
    WidgetTester tester, {
    required DateTime? lastVerifiedAt,
    required String locale,
    Duration staleAfter = VerifiedBadge.tuitionFreshness,
    double textScale = 1.0,
  }) {
    return tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: Locale(locale),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: Center(
              child: VerifiedBadge(
                lastVerifiedAt: lastVerifiedAt,
                staleAfter: staleAfter,
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('VerifiedBadge accessibility & freshness', () {
    testWidgets('FR: labelled node + survives 2.0x text scale', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 5)),
        locale: 'fr',
        textScale: 2.0,
      );
      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp('Information vérifiée le')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('EN locale renders English (no leaked French)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(
        tester,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 5)),
        locale: 'en',
      );
      expect(find.textContaining('Verified on'), findsOneWidget);
      expect(find.textContaining('Vérifié'), findsNothing);
      expect(
        find.bySemanticsLabel(RegExp('Information verified on')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('unverified → amber "À confirmer" (FR)', (tester) async {
      final handle = tester.ensureSemantics();
      await pump(tester, lastVerifiedAt: null, locale: 'fr');
      expect(find.text('À confirmer'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('à confirmer')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('verified long ago → "À revérifier", not green verified',
        (tester) async {
      await pump(
        tester,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 400)),
        locale: 'fr',
      );
      expect(find.text('À revérifier'), findsOneWidget);
      expect(find.textContaining('Vérifié le'), findsNothing);
    });

    testWidgets('tighter deadline horizon decays a 40-day-old fact',
        (tester) async {
      await pump(
        tester,
        lastVerifiedAt: DateTime.now().subtract(const Duration(days: 40)),
        locale: 'fr',
        staleAfter: VerifiedBadge.deadlineFreshness,
      );
      expect(find.text('À revérifier'), findsOneWidget);
    });
  });
}
