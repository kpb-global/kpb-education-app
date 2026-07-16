import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KPB Education — Component Library
// ─────────────────────────────────────────────────────────────────────────────

// ── Input Decoration ──────────────────────────────────────────────────────────
// Délègue intégralement au `inputDecorationTheme` global (architecture §9.4) :
// fond, bordures, focus et couleurs viennent du ThemeData — ce helper ne garde
// que la plomberie label/préfixe. La signature est conservée pour les
// call-sites existants.
class KpbInputDecoration {
  static InputDecoration build(
    BuildContext context, {
    required String label,
    IconData? prefixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
    );
  }
}
