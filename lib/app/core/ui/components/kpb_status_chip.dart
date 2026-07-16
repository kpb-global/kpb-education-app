import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbStatusChip — pastille de statut sémantique (architecture §9.1).
// Remplace les paires ad hoc fg/bg (green/greenBg…) des écrans : un statut,
// jamais une couleur arbitraire. La signification métier reste au call-site.
// ─────────────────────────────────────────────────────────────────────────────

enum KpbStatus { success, warning, error, info, neutral }

class KpbStatusChip extends StatelessWidget {
  const KpbStatusChip({
    super.key,
    required this.status,
    required this.label,
    this.icon,
    this.compact = false,
  });

  final KpbStatus status;
  final String label;

  /// Icône spécifique au contexte ; sinon l'icône par défaut du statut.
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final (Color fg, Color bg, IconData fallbackIcon) = switch (status) {
      KpbStatus.success => (
          KpbColors.success,
          c.successLight,
          Icons.check_circle_rounded,
        ),
      KpbStatus.warning => (
          KpbColors.warning,
          c.warningLight,
          Icons.schedule_rounded,
        ),
      KpbStatus.error => (
          KpbColors.error,
          c.errorLight,
          Icons.error_outline_rounded,
        ),
      KpbStatus.info => (
          KpbColors.actionPrimary,
          c.skyLight,
          Icons.info_outline_rounded,
        ),
      KpbStatus.neutral => (
          c.textSecondary,
          c.surfaceBg,
          Icons.circle_outlined,
        ),
    };

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: fg.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // L'information n'est jamais portée par la seule couleur :
          // icône + libellé accompagnent toujours le statut.
          Icon(icon ?? fallbackIcon, size: compact ? 11 : 13, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: compact ? 11 : 12,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
