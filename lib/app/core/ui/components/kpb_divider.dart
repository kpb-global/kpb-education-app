import 'package:flutter/material.dart';
import '../kpb_theme_ext.dart';


// ── Thin Divider ─────────────────────────────────────────────────────────────
class KpbDivider extends StatelessWidget {
  const KpbDivider({super.key, this.height = 1, this.indent = 0});
  final double height;
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: height,
      thickness: height,
      indent: indent,
      color: context.kpb.divider,
    );
  }
}

// ── Pull-to-refresh wrapper ───────────────────────────────────────────────────
/// Wraps a scrollable child with a styled RefreshIndicator.
