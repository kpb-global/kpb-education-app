// Verrouille le ThemeData global (L1 — app_theme.dart) : palette KPB
// Intelligence, typographie Inter + Plus Jakarta Sans, extension sémantique
// enregistrée, formes et tailles tactiles des composants Material
// (docs/fable-global-theme-architecture.md §7–8, §11.3).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/ui/app_theme.dart';
import 'package:karatou/app/core/ui/app_tokens.dart';
import 'package:karatou/app/core/ui/kpb_theme_ext.dart';

void main() {
  final theme = AppTheme.buildTheme();

  group('ColorScheme et surfaces', () {
    test('light, palette KPB Intelligence explicite', () {
      expect(theme.brightness, Brightness.light);
      expect(theme.colorScheme.primary, KpbColors.actionPrimary);
      expect(theme.colorScheme.onPrimary, Colors.white);
      expect(theme.colorScheme.secondary, KpbColors.brandNavy);
      expect(theme.colorScheme.tertiary, KpbColors.gold);
      expect(theme.colorScheme.error, KpbColors.error);
      expect(theme.colorScheme.surface, KpbColors.surface);
      expect(theme.colorScheme.onSurface, KpbColors.textPrimary);
      expect(theme.colorScheme.outline, KpbColors.border);
      expect(theme.scaffoldBackgroundColor, KpbColors.canvas);
    });

    test('surfaceTint transparent : pas de teinte M3 sur les élévations', () {
      expect(theme.colorScheme.surfaceTint, Colors.transparent);
    });

    test('InkRipple (InkSparkle coûteux sur Android entrée de gamme)', () {
      expect(theme.splashFactory, InkRipple.splashFactory);
    });
  });

  group('extension sémantique (context.kpb)', () {
    test('KpbThemeColors.light est enregistrée dans le ThemeData', () {
      expect(theme.extension<KpbThemeColors>(), same(KpbThemeColors.light));
    });

    test('le builder dark reste compilable et porte KpbThemeColors.dark', () {
      final dark = AppTheme.buildDarkTheme();
      expect(dark.brightness, Brightness.dark);
      expect(dark.extension<KpbThemeColors>(), same(KpbThemeColors.dark));
    });

    testWidgets('context.kpb se résout via le ThemeData', (tester) async {
      late KpbThemeColors c;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(),
          home: Builder(
            builder: (context) {
              c = context.kpb;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(c, same(KpbThemeColors.light));
      expect(c.pageBg, KpbColors.canvas);
      expect(c.border, KpbColors.border);
    });

    test('les styles ts* conservent les familles de polices', () {
      expect(KpbThemeColors.light.tsDisplay.fontFamily,
          KpbTextStyles.headingFamily);
      expect(
          KpbThemeColors.light.tsTitle.fontFamily, KpbTextStyles.headingFamily);
      expect(KpbThemeColors.light.tsBody.color, KpbColors.textPrimary);
    });
  });

  group('typographie', () {
    test('Inter global, titres en Plus Jakarta Sans', () {
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Inter');
      expect(theme.textTheme.labelLarge!.fontFamily, 'Inter');
      expect(theme.textTheme.displayLarge!.fontFamily, 'PlusJakartaSans');
      expect(theme.textTheme.headlineMedium!.fontFamily, 'PlusJakartaSans');
      expect(theme.textTheme.titleLarge!.fontFamily, 'PlusJakartaSans');
    });

    test('titre AppBar en Plus Jakarta Sans navy', () {
      final style = theme.appBarTheme.titleTextStyle!;
      expect(style.fontFamily, 'PlusJakartaSans');
      expect(style.color, KpbColors.textPrimary);
      expect(style.fontWeight, FontWeight.w700);
    });
  });

  group('composants Material', () {
    test('FilledButton : action pleine, hauteur ≥ 52, radius md', () {
      final style = theme.filledButtonTheme.style!;
      expect(style.backgroundColor!.resolve({}), KpbColors.actionPrimary);
      expect(style.minimumSize!.resolve({})!.height, 52);
      expect(
        (style.shape!.resolve({}) as RoundedRectangleBorder).borderRadius,
        KpbRadius.mdBr,
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        KpbColors.surfaceMuted,
      );
    });

    test('ElevatedButton hérité aligné sur FilledButton', () {
      final style = theme.elevatedButtonTheme.style!;
      expect(style.backgroundColor!.resolve({}), KpbColors.actionPrimary);
      expect(style.minimumSize!.resolve({})!.height, 52);
    });

    test('OutlinedButton : surface blanche, bordure appuyée, texte navy', () {
      final style = theme.outlinedButtonTheme.style!;
      expect(style.foregroundColor!.resolve({}), KpbColors.textPrimary);
      expect(style.side!.resolve({})!.color, KpbColors.borderStrong);
      expect(style.minimumSize!.resolve({})!.height, 52);
    });

    test('TextButton : action bleue', () {
      final style = theme.textButtonTheme.style!;
      expect(style.foregroundColor!.resolve({}), KpbColors.actionPrimary);
    });

    test('Card : blanche, bordure, elevation 0, radius lg', () {
      expect(theme.cardTheme.color, KpbColors.surface);
      expect(theme.cardTheme.elevation, 0);
      final shape = theme.cardTheme.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, KpbRadius.lgBr);
      expect(shape.side.color, KpbColors.border);
    });

    test('Chip : sélection action, repos surface muted + bordure', () {
      expect(theme.chipTheme.color!.resolve({WidgetState.selected}),
          KpbColors.actionPrimary);
      expect(theme.chipTheme.color!.resolve({}), KpbColors.surfaceMuted);
    });

    test('Input : focus action 1.5, bordure par défaut', () {
      final focused =
          theme.inputDecorationTheme.focusedBorder as OutlineInputBorder;
      expect(focused.borderSide.color, KpbColors.actionPrimary);
      expect(focused.borderSide.width, 1.5);
      final enabled =
          theme.inputDecorationTheme.enabledBorder as OutlineInputBorder;
      expect(enabled.borderSide.color, KpbColors.border);
      expect(theme.inputDecorationTheme.fillColor, KpbColors.surface);
    });

    test('NavigationBar : indicator soft, repos textMuted (≥ 3:1)', () {
      final nav = theme.navigationBarTheme;
      expect(nav.indicatorColor, KpbColors.actionPrimarySoft);
      expect(nav.iconTheme!.resolve({WidgetState.selected})!.color,
          KpbColors.actionPrimary);
      expect(nav.iconTheme!.resolve({})!.color, KpbColors.textMuted);
    });

    test('SnackBar : navy, action lisible, flottante', () {
      expect(theme.snackBarTheme.backgroundColor, KpbColors.brandNavy);
      expect(theme.snackBarTheme.actionTextColor, KpbColors.actionOnDark);
      expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
    });

    test('Dialog et BottomSheet : surfaces blanches, radius haut de gamme', () {
      expect(theme.dialogTheme.backgroundColor, KpbColors.surface);
      expect(theme.bottomSheetTheme.backgroundColor, KpbColors.surface);
      final sheetShape = theme.bottomSheetTheme.shape as RoundedRectangleBorder;
      expect(
        sheetShape.borderRadius,
        const BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
      );
    });

    test('TabBar / progress / divider harmonisés', () {
      expect(theme.tabBarTheme.labelColor, KpbColors.actionPrimary);
      expect(theme.tabBarTheme.unselectedLabelColor, KpbColors.textMuted);
      expect(theme.progressIndicatorTheme.color, KpbColors.actionPrimary);
      expect(theme.progressIndicatorTheme.linearTrackColor,
          KpbColors.surfaceMuted);
      expect(theme.dividerTheme.color, KpbColors.surfaceMuted);
    });

    testWidgets('cible tactile : FilledButton rend ≥ 48 dp de haut',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.buildTheme(),
          home: Scaffold(
            body: Center(
              child: FilledButton(onPressed: () {}, child: const Text('CTA')),
            ),
          ),
        ),
      );
      final size = tester.getSize(find.byType(FilledButton));
      expect(size.height, greaterThanOrEqualTo(48));
    });
  });
}
