import 'package:flutter/material.dart';
import '../app_tokens.dart';

// ── Section Header ────────────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
    this.textColor,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textColor != null
                  ? KpbTextStyles.title.copyWith(color: textColor)
                  : KpbTextStyles.title,
            ),
          ),
          if (actionLabel != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  // Sur un hero sombre (titre blanc), le bleu action est
                  // illisible : on passe à l'action claire (9,9:1 sur navy).
                  color: textColor == Colors.white
                      ? KpbColors.actionOnDark
                      : KpbColors.actionPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KPB Card (base) ───────────────────────────────────────────────────────────
