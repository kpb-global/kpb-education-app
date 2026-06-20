import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';


// ── KPB Card (base) ───────────────────────────────────────────────────────────
class KpbCard extends StatelessWidget {
  const KpbCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(KpbSpacing.md),
    this.margin,
    this.color = KpbColors.bgCard,
    this.borderRadius = KpbRadius.lgBr,
    this.shadow = KpbShadow.card,
    this.onTap,
    this.border,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color color;
  final BorderRadius borderRadius;
  final List<BoxShadow> shadow;
  final VoidCallback? onTap;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final effectiveColor = color == KpbColors.bgCard ? c.cardBg : color;
    final effectiveShadow = identical(shadow, KpbShadow.card) ? c.cardShadow : shadow;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        margin: margin,
        decoration: BoxDecoration(
          color: effectiveColor,
          borderRadius: borderRadius,
          boxShadow: effectiveShadow,
          border: border,
        ),
        child: child,
      ),
    );
  }
}

// ── Gradient Hero Card ────────────────────────────────────────────────────────
