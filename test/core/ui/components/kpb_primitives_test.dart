// Primitives du lot 2 (architecture §9) : variantes KpbCard, statuts
// KpbStatusChip, tiers accessibles du MatchBadge, bannière theme-aware.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/kpb_card.dart';
import 'package:karatou/app/core/ui/components/kpb_pressable.dart';
import 'package:karatou/app/core/ui/components/kpb_sample_data_banner.dart';
import 'package:karatou/app/core/ui/components/kpb_status_chip.dart';
import 'package:karatou/app/core/ui/components/match_badge.dart';

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.buildTheme(),
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration _cardDecoration(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byType(KpbCard), matching: find.byType(Container)),
  );
  return container.decoration! as BoxDecoration;
}

void main() {
  group('KpbCard', () {
    testWidgets('standard : surface blanche, sans bordure', (tester) async {
      await tester.pumpWidget(_wrap(const KpbCard(child: Text('x'))));
      final deco = _cardDecoration(tester);
      expect(deco.color, KpbColors.surface);
      expect(deco.border, isNull);
    });

    testWidgets('highlighted : fond soft + bordure action', (tester) async {
      await tester.pumpWidget(_wrap(const KpbCard(
        variant: KpbCardVariant.highlighted,
        child: Text('x'),
      )));
      final deco = _cardDecoration(tester);
      expect(deco.color, KpbColors.actionPrimarySoft);
      expect((deco.border! as Border).top.color, KpbColors.actionPrimary);
    });

    testWidgets('interactive : press-scale + onTap déclenché', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_wrap(KpbCard(
        variant: KpbCardVariant.interactive,
        onTap: () => taps++,
        child: const Text('x'),
      )));
      expect(find.byType(KpbPressable), findsOneWidget);
      await tester.tap(find.byType(KpbCard));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });

    testWidgets('override explicite de couleur respecté', (tester) async {
      await tester.pumpWidget(_wrap(const KpbCard(
        color: KpbColors.brandNavy,
        child: Text('x'),
      )));
      expect(_cardDecoration(tester).color, KpbColors.brandNavy);
    });
  });

  group('KpbStatusChip', () {
    Future<BoxDecoration> pumpChip(
        WidgetTester tester, KpbStatus status) async {
      await tester.pumpWidget(_wrap(KpbStatusChip(status: status, label: 's')));
      final container = tester.widget<Container>(
        find.descendant(
            of: find.byType(KpbStatusChip), matching: find.byType(Container)),
      );
      return container.decoration! as BoxDecoration;
    }

    testWidgets('statuts sémantiques → fond light correspondant',
        (tester) async {
      expect((await pumpChip(tester, KpbStatus.success)).color,
          KpbColors.successLight);
      expect((await pumpChip(tester, KpbStatus.warning)).color,
          KpbColors.warningLight);
      expect((await pumpChip(tester, KpbStatus.error)).color,
          KpbColors.errorLight);
      expect((await pumpChip(tester, KpbStatus.info)).color,
          KpbColors.actionPrimarySoft);
      expect((await pumpChip(tester, KpbStatus.neutral)).color,
          KpbColors.surfaceMuted);
    });

    testWidgets('icône + libellé toujours présents (pas de couleur seule)',
        (tester) async {
      await tester.pumpWidget(_wrap(const KpbStatusChip(
        status: KpbStatus.success,
        label: 'Ouverte',
      )));
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      expect(find.text('Ouverte'), findsOneWidget);
    });
  });

  group('MatchBadge — tiers lisibles (AA)', () {
    Future<Color?> tierColor(WidgetTester tester, int score) async {
      await tester.pumpWidget(_wrap(MatchBadge(score: score)));
      return tester
          .widget<Icon>(find.descendant(
              of: find.byType(MatchBadge), matching: find.byType(Icon)))
          .color;
    }

    testWidgets('≥80 success, ≥60 warning, sinon actionPrimary',
        (tester) async {
      expect(await tierColor(tester, 85), KpbColors.success);
      expect(await tierColor(tester, 65), KpbColors.warning);
      expect(await tierColor(tester, 40), KpbColors.actionPrimary);
    });
  });

  group('Bannières système', () {
    testWidgets('KpbSampleDataBanner : sémantique warning conservée',
        (tester) async {
      await tester.pumpWidget(_wrap(const KpbSampleDataBanner()));
      final material = tester.widget<Material>(
        find
            .descendant(
                of: find.byType(KpbSampleDataBanner),
                matching: find.byType(Material))
            .first,
      );
      expect(material.color, KpbColors.warningLight);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });
  });
}
