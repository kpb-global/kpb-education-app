import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbLoading — indicateur de chargement unifié
// ─────────────────────────────────────────────────────────────────────────────
// Remplace les `CircularProgressIndicator` nus éparpillés dans les écrans :
// couleur token, libellé optionnel et sémantique « chargement » intégrée.
// Règle produit : le premier chargement d'un écran reste un skeleton ; ce
// widget sert aux chargements partiels (sections, steps, actions bloquantes).
class KpbLoading extends StatelessWidget {
  const KpbLoading({
    super.key,
    this.label,
    this.size = 28,
    this.strokeWidth = 2.5,
    this.color,
    this.padding = const EdgeInsets.all(KpbSpacing.lg),
  });

  /// Libellé affiché sous le spinner (aussi lu par le lecteur d'écran).
  final String? label;
  final double size;
  final double strokeWidth;
  final Color? color;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Semantics(
      label: label ?? 'loading'.tr,
      liveRegion: true,
      child: Center(
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: strokeWidth,
                  color: color ?? KpbColors.actionPrimary,
                ),
              ),
              if (label != null) ...[
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  label!,
                  style: KpbTextStyles.caption.copyWith(color: c.textMuted),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
