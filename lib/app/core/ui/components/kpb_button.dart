import 'package:flutter/material.dart';
import '../app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbButton — façade sémantique sur les boutons Material
// (architecture §9.1) : hérite du ThemeData les états pressed/disabled/focus,
// la hauteur tactile (52 px) et les styles — aucune couleur locale.
// ─────────────────────────────────────────────────────────────────────────────

/// Variantes sémantiques du bouton KPB.
enum KpbButtonVariant {
  /// CTA principal — action pleine (`FilledButton`).
  primary,

  /// Bouton secondaire — surface blanche + bordure (`OutlinedButton`).
  secondary,

  /// Action textuelle sans fond (`TextButton`), cible tactile préservée.
  tertiary,

  /// Action destructrice — fond `error`.
  destructive,
}

class KpbButton extends StatelessWidget {
  const KpbButton({
    super.key,
    this.label,
    this.text,
    this.onTap,
    this.onPressed,
    this.icon,
    this.variant,
    this.fullWidth = false,
    this.loading = false,
    // Compat héritée — préférer `variant:`. `secondary:` mappe sur la
    // variante secondary ; les couleurs hors rôle restent fonctionnelles le
    // temps de la migration mais sont une dette (allowlist, architecture §9.1).
    this.secondary = false,
    this.backgroundColor,
    this.bgColor,
    this.textColor,
  });

  final String? label;
  final String? text;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;
  final IconData? icon;
  final KpbButtonVariant? variant;
  final bool fullWidth;
  final bool loading;
  final bool secondary;
  final Color? backgroundColor;
  final Color? bgColor;
  final Color? textColor;

  KpbButtonVariant get _variant =>
      variant ??
      (secondary ? KpbButtonVariant.secondary : KpbButtonVariant.primary);

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? text ?? '';
    final onAction = onTap ?? onPressed;
    final effectiveOnPressed = loading ? null : onAction;
    final customBg = backgroundColor ?? bgColor;
    final minHeight = _variant == KpbButtonVariant.tertiary ? 48.0 : 52.0;

    // Le thème impose une largeur minimale infinie (CTA pleine largeur par
    // défaut) : hors `fullWidth`, le bouton doit épouser son contenu.
    var style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(
        fullWidth ? Size.fromHeight(minHeight) : Size(0, minHeight),
      ),
      backgroundColor:
          customBg != null ? WidgetStatePropertyAll(customBg) : null,
      foregroundColor:
          textColor != null ? WidgetStatePropertyAll(textColor) : null,
    );

    final child = _ButtonContent(
      label: effectiveLabel,
      icon: icon,
      loading: loading,
    );

    final Widget button = switch (_variant) {
      KpbButtonVariant.primary => FilledButton(
          style: style,
          onPressed: effectiveOnPressed,
          child: child,
        ),
      KpbButtonVariant.destructive => FilledButton(
          style: style.merge(
            const ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(KpbColors.error),
              foregroundColor: WidgetStatePropertyAll(Colors.white),
            ),
          ),
          onPressed: effectiveOnPressed,
          child: child,
        ),
      KpbButtonVariant.secondary => OutlinedButton(
          style: style,
          onPressed: effectiveOnPressed,
          child: child,
        ),
      KpbButtonVariant.tertiary => TextButton(
          style: style.merge(
            const ButtonStyle(
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
          ),
          onPressed: effectiveOnPressed,
          child: child,
        ),
    };

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({
    required this.label,
    required this.loading,
    this.icon,
  });

  final String label;
  final bool loading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // Le spinner et l'icône héritent du foreground du bouton (IconTheme posé
    // par ButtonStyleButton) : les états disabled/pressed restent corrects.
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: IconTheme.of(context).color,
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 18),
          ),
        Flexible(
          child: Text(label, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
