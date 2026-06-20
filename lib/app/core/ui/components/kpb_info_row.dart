import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';


// ── Info Row (label + value) ──────────────────────────────────────────────────
class KpbInfoRow extends StatelessWidget {
  const KpbInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor = KpbColors.blue,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: KpbRadius.smBr,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: KpbTextStyles.caption),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.kpb.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Thin Divider ─────────────────────────────────────────────────────────────
