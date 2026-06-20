import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';


// ── Empty State ───────────────────────────────────────────────────────────────
class KpbEmptyState extends StatelessWidget {
  const KpbEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.action,
    this.iconColor,
    this.iconBgColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  /// Optional fully custom action widget (takes priority over actionLabel+onAction).
  final Widget? action;
  final Color? iconColor;
  final Color? iconBgColor;

  @override
  Widget build(BuildContext context) {
    final tc = context.kpb;
    final effectiveIconColor = iconColor ?? KpbColors.blue;
    final effectiveIconBg = iconBgColor ?? tc.skyLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.8, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, v, child) =>
                  Transform.scale(scale: v, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: effectiveIconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: effectiveIconColor),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: tc.textPrimary,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: tc.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ] else if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Info Row (label + value) ──────────────────────────────────────────────────
