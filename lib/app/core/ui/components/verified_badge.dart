import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../app_tokens.dart';

// ── Data-Trust "Vérifié le…" Badge ────────────────────────────────────────────
/// Surfaces when a piece of catalog data was last verified, with time decay:
///
///  * never verified ([lastVerifiedAt] == null) → amber "À confirmer";
///  * verified within [staleAfter]               → green  "Vérifié le …";
///  * verified longer ago than [staleAfter]       → amber "À revérifier".
///
/// A scholarship verified three years ago must NOT wear the same confident
/// green chip as one verified yesterday — a stale "verified" claim is
/// indistinguishable from a scam result, so the signal decays over time.
/// All strings are localized via `.tr` (no hardcoded French).
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    required this.lastVerifiedAt,
    this.compact = false,
    this.staleAfter = tuitionFreshness,
  });

  final DateTime? lastVerifiedAt;
  final bool compact;

  /// How long a verification stays "fresh" before decaying to amber. Defaults
  /// to the tuition/visa horizon; pass [deadlineFreshness] for date-sensitive
  /// facts like application deadlines.
  final Duration staleAfter;

  /// Tuition / cost-of-living / visa overview: re-verify ~every 6 months.
  static const Duration tuitionFreshness = Duration(days: 180);

  /// Deadlines and other date-sensitive facts: re-verify ~monthly.
  static const Duration deadlineFreshness = Duration(days: 31);

  @override
  Widget build(BuildContext context) {
    final d = lastVerifiedAt;
    final bool stale =
        d != null && DateTime.now().difference(d) > staleAfter;
    final bool fresh = d != null && !stale;

    final Color color = fresh ? KpbColors.success : KpbColors.warning;
    final IconData icon =
        fresh ? Icons.verified_outlined : Icons.schedule_outlined;
    final String date = d == null ? '' : '${d.day}/${d.month}/${d.year}';

    final String label;
    final String semanticsLabel;
    if (fresh) {
      label = 'verified_on'.trParams({'date': date});
      semanticsLabel = 'verified_semantics'.trParams({'date': date});
    } else if (stale) {
      label = 'reverify_label'.tr;
      semanticsLabel = 'reverify_semantics'.trParams({'date': date});
    } else {
      label = 'to_confirm_label'.tr;
      semanticsLabel = 'to_confirm_semantics'.tr;
    }

    final double px = compact ? 8 : 10;
    final double py = compact ? 3 : 5;
    final double fs = compact ? 11 : 12;

    // a11y: expose the chip as a single labelled node (the icon is decorative)
    // so a screen reader announces the meaning rather than an unlabelled icon.
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: px, vertical: py),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: KpbRadius.pillBr,
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: fs, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: fs,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
