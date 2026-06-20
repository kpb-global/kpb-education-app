import 'package:flutter/material.dart';
import '../app_tokens.dart';


// ── Data-Trust "Vérifié le…" Badge ────────────────────────────────────────────
/// Surfaces when a piece of catalog data was last verified.
///
/// When [lastVerifiedAt] is non-null we show a green "Vérifié le …" chip;
/// when null (the unverified default) we fall back to an amber "À confirmer".
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({
    super.key,
    required this.lastVerifiedAt,
    this.compact = false,
  });

  final DateTime? lastVerifiedAt;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool verified = lastVerifiedAt != null;
    final Color color = verified ? KpbColors.success : KpbColors.warning;
    final IconData icon =
        verified ? Icons.verified_outlined : Icons.schedule_outlined;

    final String label;
    if (verified) {
      final d = lastVerifiedAt!;
      label = 'Vérifié le ${d.day}/${d.month}/${d.year}';
    } else {
      label = 'À confirmer';
    }

    final double px = compact ? 8 : 10;
    final double py = compact ? 3 : 5;
    final double fs = compact ? 11 : 12;

    return Container(
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
    );
  }
}
