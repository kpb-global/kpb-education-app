import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:karatou/app/core/ui/components/verified_badge.dart';

void main() {
  group('VerifiedBadge accessibility', () {
    testWidgets('exposes a screen-reader label and survives 2.0x text scale',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: Center(
                child: VerifiedBadge(lastVerifiedAt: DateTime(2026, 6, 20)),
              ),
            ),
          ),
        ),
      );

      // No RenderFlex overflow / layout exception at a large OS text scale.
      expect(tester.takeException(), isNull);

      // The chip is announced as a single, meaningful node (icon is decorative).
      expect(
        find.bySemanticsLabel(RegExp('Information vérifiée le')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('announces an unverified "à confirmer" state', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: VerifiedBadge(lastVerifiedAt: null)),
          ),
        ),
      );
      expect(
        find.bySemanticsLabel(RegExp('à confirmer')),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
