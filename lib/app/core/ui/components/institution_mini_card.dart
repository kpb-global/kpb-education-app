import 'package:flutter/material.dart';
import '../app_tokens.dart';

import 'kpb_badge.dart';
import 'admission_meter.dart';

// ── Institution Mini Card ──────────────────────────────────────────────────────
class InstitutionMiniCard extends StatelessWidget {
  const InstitutionMiniCard({
    super.key,
    required this.name,
    required this.countryFlag,
    required this.location,
    required this.tuitionLabel,
    required this.onTap,
    this.isPartner = false,
    required this.score,
    this.width = 200,
  });

  final String name;
  final String countryFlag;
  final String location;
  final String tuitionLabel;
  final bool isPartner;
  final int score;
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
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          AdmissionMeter(
                            score: score,
                            size: 28,
                            strokeWidth: 3,
                            showLabel: false,
                          ),
                          if (isPartner) ...[
                            const SizedBox(width: 8),
                            const KpbBadge(
                              label: 'Partenaire',
                              color: KpbColors.blue,
                              small: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
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
            const SizedBox(height: 4),
            Text(
              location,
              style: const TextStyle(
                fontSize: 11,
                color: KpbColors.textDarkSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Keep locations from bleeding
            ),
            const Spacer(),
            Text(
              tuitionLabel,
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

// ── Profile Completion Ring ───────────────────────────────────────────────────
