import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbErrorState — full-screen error with retry button
//
// Use when: data required to render the screen could not be loaded AND
// no cached data is available (e.g. profile == null after sync failure).
// ─────────────────────────────────────────────────────────────────────────────
class KpbErrorState extends StatelessWidget {
  const KpbErrorState({
    super.key,
    this.title = 'Connexion impossible',
    this.subtitle = 'Vérifiez votre connexion internet et réessayez.',
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.kpb.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.wifi_off_rounded,
                size: 34,
                color: KpbColors.error,
              ),
            ),
            const SizedBox(height: KpbSpacing.lg),
            Text(
              title,
              style:
                  KpbTextStyles.title.copyWith(color: context.kpb.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: KpbSpacing.sm),
            Text(
              subtitle,
              style: KpbTextStyles.bodySm.copyWith(
                color: context.kpb.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: KpbSpacing.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text('retry'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// KpbSyncErrorBanner — subtle top banner for connectivity issues
//
// Use when: cached catalog data is still available (so the screen renders)
// but a live sync against the backend failed. The user can still browse;
// the banner informs them that personalised or real-time data may be stale.
// ─────────────────────────────────────────────────────────────────────────────
