import 'package:flutter/material.dart';

import 'app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Theme Extension — rôles sémantiques résolus via le ThemeData
// ─────────────────────────────────────────────────────────────────────────────
// L2 de l'architecture de thème (docs/fable-global-theme-architecture.md §8) :
// ce fichier ne stocke AUCUNE valeur de couleur — les deux instances lisent
// les tokens de app_tokens.dart. L'API des écrans est inchangée :
//   final c = context.kpb;
//   Container(color: c.cardBg, child: Text('Hi', style: c.tsBody));
// ─────────────────────────────────────────────────────────────────────────────

extension KpbThemeContext on BuildContext {
  KpbThemeColors get kpb =>
      Theme.of(this).extension<KpbThemeColors>() ??
      (isDark ? KpbThemeColors.dark : KpbThemeColors.light);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class KpbThemeColors extends ThemeExtension<KpbThemeColors> {
  const KpbThemeColors({
    required this.pageBg,
    required this.cardBg,
    required this.mutedBg,
    required this.inputBg,
    required this.surfaceBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.divider,
    required this.border,
    required this.borderLight,
    required this.gray50,
    required this.gray100,
    required this.gray200,
    required this.gray300,
    required this.gray400,
    required this.gray500,
    required this.successLight,
    required this.warningLight,
    required this.errorLight,
    required this.goldLight,
    required this.skyLight,
    required this.cardShadow,
    required this.softShadow,
  });

  /// Compat historique : `KpbThemeColors.of(context)` ≡ `context.kpb`.
  static KpbThemeColors of(BuildContext context) => context.kpb;

  // ── Backgrounds ──────────────────────────────────────────────────────────
  final Color pageBg;
  final Color cardBg;
  final Color mutedBg;
  final Color inputBg;
  final Color surfaceBg;

  // ── Text ─────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  // ── Borders & Dividers ───────────────────────────────────────────────────
  final Color divider;
  final Color border;
  final Color borderLight;

  // ── Neutral fills (icon backgrounds, chips, etc.) ────────────────────────
  final Color gray50;
  final Color gray100;
  final Color gray200;
  final Color gray300;
  final Color gray400;
  final Color gray500;

  // ── Semantic light fills ─────────────────────────────────────────────────
  final Color successLight;
  final Color warningLight;
  final Color errorLight;
  final Color goldLight;
  final Color skyLight;

  // ── Shadows ──────────────────────────────────────────────────────────────
  final List<BoxShadow> cardShadow;
  final List<BoxShadow> softShadow;

  static const light = KpbThemeColors(
    pageBg: KpbColors.canvas,
    cardBg: KpbColors.surface,
    mutedBg: KpbColors.gray50,
    inputBg: KpbColors.surface,
    surfaceBg: KpbColors.surfaceMuted,
    textPrimary: KpbColors.textPrimary,
    textSecondary: KpbColors.textSecondary,
    textMuted: KpbColors.textMuted,
    divider: KpbColors.surfaceMuted,
    border: KpbColors.border,
    borderLight: KpbColors.surfaceMuted,
    gray50: KpbColors.gray50,
    gray100: KpbColors.gray100,
    gray200: KpbColors.gray200,
    gray300: KpbColors.gray300,
    gray400: KpbColors.gray400,
    gray500: KpbColors.gray500,
    successLight: KpbColors.successLight,
    warningLight: KpbColors.warningLight,
    errorLight: KpbColors.errorLight,
    goldLight: KpbColors.goldLight,
    skyLight: KpbColors.skyLight,
    cardShadow: KpbShadow.card,
    softShadow: KpbShadow.soft,
  );

  /// Mode sombre : compilable, non conçu pour cette livraison (light-only).
  static const dark = KpbThemeColors(
    pageBg: KpbColorsDark.pageBg,
    cardBg: KpbColorsDark.cardBg,
    mutedBg: KpbColorsDark.mutedBg,
    inputBg: KpbColorsDark.inputBg,
    surfaceBg: KpbColorsDark.surfaceBg,
    textPrimary: KpbColorsDark.textPrimary,
    textSecondary: KpbColorsDark.textSecondary,
    textMuted: KpbColorsDark.textMuted,
    divider: KpbColorsDark.divider,
    border: KpbColorsDark.border,
    borderLight: KpbColorsDark.borderLight,
    gray50: KpbColorsDark.gray50,
    gray100: KpbColorsDark.gray100,
    gray200: KpbColorsDark.gray200,
    gray300: KpbColorsDark.gray300,
    gray400: KpbColorsDark.gray400,
    gray500: KpbColorsDark.gray500,
    successLight: KpbColorsDark.successLight,
    warningLight: KpbColorsDark.warningLight,
    errorLight: KpbColorsDark.errorLight,
    goldLight: KpbColorsDark.goldLight,
    skyLight: KpbColorsDark.skyLight,
    cardShadow: KpbColorsDark.cardShadow,
    softShadow: <BoxShadow>[],
  );

  // ── Theme-aware text styles ──────────────────────────────────────────────
  // Dérivés de KpbTextStyles : les familles (Inter/Plus Jakarta Sans) suivent
  // automatiquement — l'ancienne implémentation les perdait.
  TextStyle get tsDisplay => KpbTextStyles.display.copyWith(color: textPrimary);
  TextStyle get tsHeadline =>
      KpbTextStyles.headline.copyWith(color: textPrimary);
  TextStyle get tsTitle => KpbTextStyles.title.copyWith(color: textPrimary);
  TextStyle get tsTitleMd => KpbTextStyles.titleMd.copyWith(color: textPrimary);
  TextStyle get tsBody => KpbTextStyles.body.copyWith(color: textPrimary);
  TextStyle get tsBodySm => KpbTextStyles.bodySm.copyWith(color: textSecondary);
  TextStyle get tsLabel => KpbTextStyles.label.copyWith(color: textSecondary);
  TextStyle get tsCaption => KpbTextStyles.caption.copyWith(color: textMuted);

  @override
  KpbThemeColors copyWith({
    Color? pageBg,
    Color? cardBg,
    Color? mutedBg,
    Color? inputBg,
    Color? surfaceBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? divider,
    Color? border,
    Color? borderLight,
    Color? gray50,
    Color? gray100,
    Color? gray200,
    Color? gray300,
    Color? gray400,
    Color? gray500,
    Color? successLight,
    Color? warningLight,
    Color? errorLight,
    Color? goldLight,
    Color? skyLight,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? softShadow,
  }) {
    return KpbThemeColors(
      pageBg: pageBg ?? this.pageBg,
      cardBg: cardBg ?? this.cardBg,
      mutedBg: mutedBg ?? this.mutedBg,
      inputBg: inputBg ?? this.inputBg,
      surfaceBg: surfaceBg ?? this.surfaceBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      divider: divider ?? this.divider,
      border: border ?? this.border,
      borderLight: borderLight ?? this.borderLight,
      gray50: gray50 ?? this.gray50,
      gray100: gray100 ?? this.gray100,
      gray200: gray200 ?? this.gray200,
      gray300: gray300 ?? this.gray300,
      gray400: gray400 ?? this.gray400,
      gray500: gray500 ?? this.gray500,
      successLight: successLight ?? this.successLight,
      warningLight: warningLight ?? this.warningLight,
      errorLight: errorLight ?? this.errorLight,
      goldLight: goldLight ?? this.goldLight,
      skyLight: skyLight ?? this.skyLight,
      cardShadow: cardShadow ?? this.cardShadow,
      softShadow: softShadow ?? this.softShadow,
    );
  }

  @override
  KpbThemeColors lerp(KpbThemeColors? other, double t) {
    if (other == null) return this;
    return KpbThemeColors(
      pageBg: Color.lerp(pageBg, other.pageBg, t)!,
      cardBg: Color.lerp(cardBg, other.cardBg, t)!,
      mutedBg: Color.lerp(mutedBg, other.mutedBg, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      surfaceBg: Color.lerp(surfaceBg, other.surfaceBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderLight: Color.lerp(borderLight, other.borderLight, t)!,
      gray50: Color.lerp(gray50, other.gray50, t)!,
      gray100: Color.lerp(gray100, other.gray100, t)!,
      gray200: Color.lerp(gray200, other.gray200, t)!,
      gray300: Color.lerp(gray300, other.gray300, t)!,
      gray400: Color.lerp(gray400, other.gray400, t)!,
      gray500: Color.lerp(gray500, other.gray500, t)!,
      successLight: Color.lerp(successLight, other.successLight, t)!,
      warningLight: Color.lerp(warningLight, other.warningLight, t)!,
      errorLight: Color.lerp(errorLight, other.errorLight, t)!,
      goldLight: Color.lerp(goldLight, other.goldLight, t)!,
      skyLight: Color.lerp(skyLight, other.skyLight, t)!,
      cardShadow: t < 0.5 ? cardShadow : other.cardShadow,
      softShadow: t < 0.5 ? softShadow : other.softShadow,
    );
  }
}
