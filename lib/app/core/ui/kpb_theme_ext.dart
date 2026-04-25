import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Theme Extension — context-aware color resolution
// ─────────────────────────────────────────────────────────────────────────────
// Usage:
//   final c = context.kpb;
//   Container(color: c.cardBg, child: Text('Hi', style: TextStyle(color: c.textPrimary)));
// ─────────────────────────────────────────────────────────────────────────────

extension KpbThemeContext on BuildContext {
  KpbThemeColors get kpb => KpbThemeColors.of(this);
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class KpbThemeColors {
  KpbThemeColors._(this._isDark);

  factory KpbThemeColors.of(BuildContext context) {
    return KpbThemeColors._(Theme.of(context).brightness == Brightness.dark);
  }

  final bool _isDark;

  // ── Backgrounds ──────────────────────────────────────────────────────────
  Color get pageBg => _isDark ? const Color(0xFF111827) : const Color(0xFFF4F6FB);
  Color get cardBg => _isDark ? const Color(0xFF1E2535) : Colors.white;
  Color get mutedBg => _isDark ? const Color(0xFF1A2332) : const Color(0xFFF9FAFB);
  Color get inputBg => _isDark ? const Color(0xFF1E2535) : Colors.white;
  Color get surfaceBg => _isDark ? const Color(0xFF1E2535) : const Color(0xFFF3F4F6);

  // ── Text ─────────────────────────────────────────────────────────────────
  Color get textPrimary => _isDark ? Colors.white : const Color(0xFF0F1729);
  Color get textSecondary => _isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
  Color get textMuted => _isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);

  // ── Borders & Dividers ───────────────────────────────────────────────────
  Color get divider => _isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6);
  Color get border => _isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
  Color get borderLight => _isDark ? const Color(0xFF2D3748) : const Color(0xFFF3F4F6);

  // ── Neutral fills (for icon backgrounds, chips, etc.) ────────────────────
  Color get gray50 => _isDark ? const Color(0xFF1A2332) : const Color(0xFFF9FAFB);
  Color get gray100 => _isDark ? const Color(0xFF1E2840) : const Color(0xFFF3F4F6);
  Color get gray200 => _isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
  Color get gray300 => _isDark ? const Color(0xFF4B5563) : const Color(0xFFD1D5DB);
  Color get gray400 => _isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF);
  Color get gray500 => _isDark ? const Color(0xFF4B5563) : const Color(0xFF6B7280);

  // ── Semantic light fills (for success/error/warning backgrounds) ─────────
  Color get successLight => _isDark ? const Color(0xFF0D3D2E) : const Color(0xFFECFDF5);
  Color get warningLight => _isDark ? const Color(0xFF3D2F0D) : const Color(0xFFFFFBEB);
  Color get errorLight => _isDark ? const Color(0xFF3D1515) : const Color(0xFFFEF2F2);
  Color get goldLight => _isDark ? const Color(0xFF3D2F0D) : const Color(0xFFFFF8E7);
  Color get skyLight => _isDark ? const Color(0xFF0D2940) : const Color(0xFFE8F5FD);

  // ── Shadows ──────────────────────────────────────────────────────────────
  List<BoxShadow> get cardShadow => _isDark
      ? const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 3))]
      : const [BoxShadow(color: Color(0x09000000), blurRadius: 12, offset: Offset(0, 3))];

  List<BoxShadow> get softShadow => _isDark
      ? const []
      : const [BoxShadow(color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2))];

  // ── Theme-aware text styles ──────────────────────────────────────────────
  // Use these instead of KpbTextStyles.* when you need the text to adapt.
  TextStyle get tsDisplay => TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: textPrimary, height: 1.2, letterSpacing: -0.5);
  TextStyle get tsHeadline => TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textPrimary, height: 1.25, letterSpacing: -0.3);
  TextStyle get tsTitle => TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary, height: 1.3);
  TextStyle get tsTitleMd => TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary, height: 1.3);
  TextStyle get tsBody => TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: textPrimary, height: 1.5);
  TextStyle get tsBodySm => TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: textSecondary, height: 1.4);
  TextStyle get tsLabel => TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary, letterSpacing: 0.4);
  TextStyle get tsCaption => TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: textMuted, height: 1.4);
}
