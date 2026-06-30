import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Education — Component Library
// ─────────────────────────────────────────────────────────────────────────────

// ── Input Decoration ──────────────────────────────────────────────────────────
class KpbInputDecoration {
  static InputDecoration build(
    BuildContext context, {
    required String label,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
      filled: true,
      fillColor: context.kpb.cardBg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: BorderSide(color: context.kpb.gray200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: BorderSide(color: context.kpb.gray200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: const BorderSide(color: KpbColors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(KpbRadius.md),
        borderSide: const BorderSide(color: KpbColors.error),
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
