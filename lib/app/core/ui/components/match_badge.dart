import 'package:flutter/material.dart';
import '../app_tokens.dart';


// ── Match Score Badge ─────────────────────────────────────────────────────────
class MatchBadge extends StatelessWidget {
  const MatchBadge({super.key, required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (score >= 80) {
      color = KpbColors.success;
    } else if (score >= 60) {
      color = KpbColors.gold;
    } else {
      color = KpbColors.sky;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KpbRadius.pillBr,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            '$score%',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Horizontal Scroll Section ─────────────────────────────────────────────────
