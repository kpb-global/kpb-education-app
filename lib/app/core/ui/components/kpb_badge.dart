import 'package:flutter/material.dart';
import '../app_tokens.dart';

// ── Status / Category Badge ───────────────────────────────────────────────────
class KpbBadge extends StatelessWidget {
  const KpbBadge({
    super.key,
    required this.label,
    this.color = KpbColors.blue,
    this.textColor = Colors.white,
    this.icon,
    this.small = false,
  });

  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final double px = small ? 8 : 10;
    final double py = small ? 3 : 5;
    final double fs = small ? 10 : 11;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
      decoration: BoxDecoration(
        color: color,
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fs + 2, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fs,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Outlined Badge (light bg) ─────────────────────────────────────────────────
