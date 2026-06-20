import 'package:flutter/material.dart';
import '../app_tokens.dart';


// ── Gradient Hero Card ────────────────────────────────────────────────────────
class GradientHeroCard extends StatelessWidget {
  const GradientHeroCard({
    super.key,
    required this.child,
    this.gradient = KpbColors.heroGradient,
    this.padding = const EdgeInsets.all(KpbSpacing.lg),
    this.borderRadius = KpbRadius.xlBr,
    this.height,
  });

  final Widget child;
  final Gradient gradient;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
        boxShadow: KpbShadow.blue,
      ),
      child: child,
    );
  }
}

// ── Status / Category Badge ───────────────────────────────────────────────────
