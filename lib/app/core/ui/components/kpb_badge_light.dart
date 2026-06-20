import 'package:flutter/material.dart';
import '../app_tokens.dart';


// ── Outlined Badge (light bg) ─────────────────────────────────────────────────
class KpbBadgeLight extends StatelessWidget {
  const KpbBadgeLight({
    super.key,
    required this.label,
    this.bgColor = KpbColors.skyLight,
    this.textColor = KpbColors.blue,
    this.icon,
  });

  final String label;
  final Color bgColor;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Match Score Badge ─────────────────────────────────────────────────────────
