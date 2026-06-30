import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbButton — Jobs Edition
// ─────────────────────────────────────────────────────────────────────────────
class KpbButton extends StatelessWidget {
  const KpbButton({
    super.key,
    this.label,
    this.text,
    this.onTap,
    this.onPressed,
    this.icon,
    this.fullWidth = false,
    this.secondary = false,
    this.loading = false,
    this.backgroundColor,
    this.bgColor,
    this.textColor,
  });

  final String? label;
  final String? text;
  final VoidCallback? onTap;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool fullWidth;
  final bool secondary;
  final bool loading;
  final Color? backgroundColor;
  final Color? bgColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? text ?? '';
    final effectiveOnTap = onTap ?? onPressed;
    final effectiveBg = backgroundColor ??
        bgColor ??
        (secondary ? context.kpb.surfaceBg : KpbColors.blue);
    final effectiveFg =
        textColor ?? (secondary ? KpbColors.blue : Colors.white);

    Widget content = Row(
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
                color: effectiveFg,
              ),
            ),
          )
        else if (icon != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(icon, size: 18, color: effectiveFg),
          ),
        Text(
          effectiveLabel,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: effectiveFg,
          ),
        ),
      ],
    );

    return SizedBox(
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: effectiveBg,
        borderRadius: KpbRadius.mdBr,
        child: InkWell(
          onTap: loading ? null : effectiveOnTap,
          borderRadius: KpbRadius.mdBr,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: content,
          ),
        ),
      ),
    );
  }
}
