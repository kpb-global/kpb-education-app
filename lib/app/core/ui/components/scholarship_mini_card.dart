import 'package:flutter/material.dart';
import '../app_tokens.dart';

import 'match_badge.dart';

// ── Scholarship Card ──────────────────────────────────────────────────────────
class ScholarshipMiniCard extends StatelessWidget {
  const ScholarshipMiniCard({
    super.key,
    required this.name,
    required this.countryFlag,
    required this.amount,
    required this.matchScore,
    required this.onTap,
    this.width = 200,
  });

  final String name;
  final String countryFlag;
  final String amount;
  final int matchScore;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KpbColors.bgDarkCard,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(color: KpbColors.glassBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(countryFlag, style: const TextStyle(fontSize: 22)),
                const Spacer(),
                MatchBadge(score: matchScore),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: KpbColors.textDarkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Institution Mini Card ──────────────────────────────────────────────────────
