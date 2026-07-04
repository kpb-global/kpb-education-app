import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/ui/kpb_components.dart';

/// Distinguishes a scholarship attributed automatically at admission from one
/// requiring a separate application (Chevening/MEXT-style) — the ApplyBoard
/// pattern: tells the student upfront whether there's anything to do.
class ApplicationRequirementBadge extends StatelessWidget {
  const ApplicationRequirementBadge({
    super.key,
    required this.isAutomatic,
    required this.accent,
    this.compact = false,
  });

  final bool isAutomatic;
  final Color accent;

  /// Small pill (list card) vs the larger bordered badge (detail sheet).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = isAutomatic
        ? 'live_scholarships_requirement_automatic'.tr
        : 'live_scholarships_requirement_separate_application'.tr;
    final icon =
        isAutomatic ? Icons.auto_awesome_rounded : Icons.assignment_outlined;

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: accent),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}
