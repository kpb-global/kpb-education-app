import 'package:flutter/material.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';


// ─────────────────────────────────────────────────────────────────────────────
// KpbSyncErrorBanner — subtle top banner for connectivity issues
//
// Use when: cached catalog data is still available (so the screen renders)
// but a live sync against the backend failed. The user can still browse;
// the banner informs them that personalised or real-time data may be stale.
// ─────────────────────────────────────────────────────────────────────────────
class KpbSyncErrorBanner extends StatelessWidget {
  const KpbSyncErrorBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.kpb.warningLight,
      padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.pagePad, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 16, color: KpbColors.warning),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Données potentiellement obsolètes — hors ligne',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: KpbColors.warning,
              ),
            ),
          ),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Réessayer',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KpbColors.warning,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ── Admission Meter Gauge ───────────────────────────────────────────────────
