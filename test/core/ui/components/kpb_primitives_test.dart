// Primitives du lot 2 (architecture §9) : variantes KpbCard, statuts
// KpbStatusChip, tiers accessibles du ProfileFitBadge, bannière theme-aware.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/models/app_models.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/components/kpb_card.dart';
import 'package:karatou/app/core/ui/components/kpb_pressable.dart';
import 'package:karatou/app/core/ui/components/kpb_sample_data_banner.dart';
import 'package:karatou/app/core/ui/components/kpb_status_chip.dart';
import 'package:karatou/app/core/ui/components/profile_fit_badge.dart';

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

  group('ProfileFit — paliers qualitatifs, jamais de pourcentage', () {
    test('seuils 70 / 50', () {
      expect(ProfileFit.fromScore(98), ProfileFit.strong);
      expect(ProfileFit.fromScore(70), ProfileFit.strong);
      expect(ProfileFit.fromScore(69), ProfileFit.good);
      expect(ProfileFit.fromScore(50), ProfileFit.good);
      expect(ProfileFit.fromScore(49), ProfileFit.explore);
      expect(ProfileFit.fromScore(0), ProfileFit.explore);
    });

    test('zones serveur → paliers', () {
      expect(ProfileFit.fromZone(SchoolMatchZone.green), ProfileFit.strong);
      expect(ProfileFit.fromZone(SchoolMatchZone.yellow), ProfileFit.good);
      expect(ProfileFit.fromZone(SchoolMatchZone.blue), ProfileFit.explore);
    });

    testWidgets('le badge affiche un libellé, sans « % »', (tester) async {
      for (final fit in ProfileFit.values) {
        await tester.pumpWidget(_wrap(ProfileFitBadge(fit: fit)));
        final text = tester.widget<Text>(find.descendant(
            of: find.byType(ProfileFitBadge), matching: find.byType(Text)));
        expect(text.data, isNotEmpty);
        expect(text.data, isNot(contains('%')));
        expect(text.style?.color, fit.colors.$2);
      }
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

    // Données VRAIES mais datées : la bannière doit être visiblement plus
    // discrète que « données d'exemple », sinon on crie au loup sur des
    // données correctes (et l'utilisateur apprend à ignorer les deux).
    testWidgets('KpbStaleCatalogBanner : surface soft, pas la paire warning',
        (tester) async {
      await tester.pumpWidget(_wrap(const KpbStaleCatalogBanner()));
      final material = tester.widget<Material>(
        find
            .descendant(
                of: find.byType(KpbStaleCatalogBanner),
                matching: find.byType(Material))
            .first,
      );
      expect(material.color, KpbColors.skyLight);
      expect(material.color, isNot(KpbColors.warningLight));
      expect(find.byIcon(Icons.history_rounded), findsOneWidget);
      // Contraste AA dans les deux thèmes : premier plan neutre, pas
      // `actionPrimary` (2,9:1 sur le `skyLight` sombre).
      final label = tester.widget<Text>(find.descendant(
        of: find.byType(KpbStaleCatalogBanner),
        matching: find.byType(Text),
      ));
      expect(label.style?.color, KpbColors.textPrimary);
    });

    testWidgets("KpbStaleCatalogBanner : l'ancienneté n'apparaît que si connue",
        (tester) async {
      // Sans horodatage : pas de séparateur, donc pas d'âge inventé.
      await tester.pumpWidget(_wrap(const KpbStaleCatalogBanner()));
      expect(find.textContaining(' · '), findsNothing);

      await tester.pumpWidget(_wrap(KpbStaleCatalogBanner(
        snapshotAt: DateTime.now().subtract(const Duration(days: 1)),
      )));
      expect(find.textContaining(' · '), findsOneWidget);
    });
  });
}
