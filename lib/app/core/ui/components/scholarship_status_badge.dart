import 'package:flutter/material.dart';

import '../../models/app_models.dart';
import '../app_tokens.dart';

/// Small "Ouvert / Bientôt clôturé / Clôturé" pill derived from a
/// scholarship's application window ([ScholarshipModel.windowStatus]).
class ScholarshipStatusBadge extends StatelessWidget {
  const ScholarshipStatusBadge({
    super.key,
    required this.scholarship,
    this.compact = false,
  });

  final ScholarshipModel scholarship;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color, IconData icon) =
        switch (scholarship.windowStatus()) {
      ScholarshipWindowStatus.open => (
          'Ouvert',
          KpbColors.success,
          Icons.lock_open_rounded,
        ),
      ScholarshipWindowStatus.closingSoon => (
          'Bientôt clôturé',
          KpbColors.warning,
          Icons.hourglass_bottom_rounded,
        ),
      ScholarshipWindowStatus.closed => (
          'Clôturé',
          KpbColors.error,
          Icons.lock_rounded,
        ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
