import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KpbColors.blue,
        primary: KpbColors.sky,
        secondary: KpbColors.sky,
        tertiary: KpbColors.gold,
        surface: const Color(0xFF1E2535),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Colors.white,
        error: KpbColors.error,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: const Color(0xFF111827),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),

      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Color(0xFF1E2535),
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: KpbRadius.lgBr,
        ),
      ),

      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: KpbRadius.pillBr,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        checkmarkColor: Colors.white,
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KpbColors.blue;
          return const Color(0xFF2D3748);
        }),
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            );
          }
          return const TextStyle(
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
            fontSize: 13,
          );
        }),
        side: BorderSide.none,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E2535),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: Color(0xFF374151)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.sky, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KpbColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KpbColors.sky,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          side: const BorderSide(color: KpbColors.sky),
          textStyle:
              const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KpbColors.sky,
          textStyle:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF1E2535),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x40000000),
        indicatorColor: KpbColors.blue.withAlpha(60),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: KpbColors.sky, size: 22);
          }
          return const IconThemeData(color: Color(0xFF6B7280), size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
                color: KpbColors.sky,
                fontSize: 11,
                fontWeight: FontWeight.w600);
          }
          return const TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 11,
              fontWeight: FontWeight.w500);
        }),
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF2D3748),
        thickness: 1,
        space: 1,
      ),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: KpbSpacing.md),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Color(0xFF1E2535),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
        ),
        showDragHandle: true,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return const Color(0xFF6B7280);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KpbColors.blue;
          return const Color(0xFF374151);
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KpbColors.blue;
          return Colors.transparent;
        }),
        side: const BorderSide(color: Color(0xFF4B5563), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KpbColors.sky,
        linearTrackColor: Color(0xFF2D3748),
        linearMinHeight: 8,
      ),

      textTheme: const TextTheme(
        displayLarge: KpbTextStyles.display,
        headlineMedium: KpbTextStyles.headline,
        titleLarge: KpbTextStyles.title,
        titleMedium: KpbTextStyles.titleMd,
        bodyLarge: KpbTextStyles.body,
        bodyMedium: KpbTextStyles.body,
        bodySmall: KpbTextStyles.bodySm,
        labelLarge: KpbTextStyles.label,
        labelSmall: KpbTextStyles.caption,
      ),
    );
  }

  static ThemeData buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: KpbColors.blue,
        primary: KpbColors.blue,
        secondary: KpbColors.sky,
        tertiary: KpbColors.gold,
        surface: KpbColors.bgCard,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: KpbColors.textPrimary,
        error: KpbColors.error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: KpbColors.bgPage,

      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: KpbColors.textPrimary,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: KpbColors.textPrimary,
        ),
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      cardTheme: const CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: KpbColors.bgCard,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: KpbRadius.lgBr,
        ),
      ),

      // ── Chips ───────────────────────────────────────────────────────────
      // Unselected chip: gray100 fill + gray300 border + textPrimary label.
      // The previous textSecondary label rendered as low-contrast grey-on-grey
      // across ~13 filter screens (universités, orientation, search, etc.).
      chipTheme: ChipThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: KpbRadius.pillBr,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        checkmarkColor: Colors.white,
        color: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KpbColors.blue;
          return KpbColors.gray100;
        }),
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            );
          }
          return const TextStyle(
            color: KpbColors.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          );
        }),
        side: WidgetStateBorderSide.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const BorderSide(color: Colors.transparent);
          }
          return const BorderSide(color: KpbColors.gray300, width: 1);
        }),
      ),

      // ── Inputs ──────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KpbColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.gray200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(KpbRadius.md),
          borderSide: const BorderSide(color: KpbColors.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: KpbColors.textSecondary),
        hintStyle: const TextStyle(color: KpbColors.textMuted),
      ),

      // ── Buttons ─────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: KpbColors.blue,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          elevation: 0,
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KpbColors.blue,
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(
            borderRadius: KpbRadius.mdBr,
          ),
          side: const BorderSide(color: KpbColors.blue),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KpbColors.blue,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),

      // ── Navigation ───────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KpbColors.bgCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shadowColor: const Color(0x14000000),
        indicatorColor: KpbColors.skyLight,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: KpbColors.blue, size: 22);
          }
          return const IconThemeData(color: KpbColors.gray400, size: 22);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: KpbColors.blue,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: KpbColors.gray400,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          );
        }),
      ),

      // ── Dividers ─────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: KpbColors.gray100,
        thickness: 1,
        space: 1,
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: KpbSpacing.md),
      ),

      // ── BottomSheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: KpbColors.bgCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(KpbRadius.xl),
          ),
        ),
        showDragHandle: true,
      ),

      // ── Switch ────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return KpbColors.gray300;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KpbColors.blue;
          return KpbColors.gray200;
        }),
      ),

      // ── Checkbox ──────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KpbColors.blue;
          return Colors.transparent;
        }),
        side: const BorderSide(color: KpbColors.gray300, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Progress ──────────────────────────────────────────────────────────
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KpbColors.blue,
        linearTrackColor: KpbColors.gray100,
        linearMinHeight: 8,
      ),

      // ── Text ─────────────────────────────────────────────────────────────
      textTheme: const TextTheme(
        displayLarge: KpbTextStyles.display,
        headlineMedium: KpbTextStyles.headline,
        titleLarge: KpbTextStyles.title,
        titleMedium: KpbTextStyles.titleMd,
        bodyLarge: KpbTextStyles.body,
        bodyMedium: KpbTextStyles.body,
        bodySmall: KpbTextStyles.bodySm,
        labelLarge: KpbTextStyles.label,
        labelSmall: KpbTextStyles.caption,
      ),
    );
  }
}
