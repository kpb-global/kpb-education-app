import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Match score badge (reusable)
// ─────────────────────────────────────────────────────────────────────────────
class MatchScoreBadge extends StatelessWidget {
  const MatchScoreBadge({super.key, required this.score, this.size = 36});

  final int score;
  final double size;

  Color _color(BuildContext context) {
    if (score >= 85) return const Color(0xFF059669);
    if (score >= 70) return KpbColors.blue;
    if (score >= 50) return const Color(0xFFF59E0B);
    return context.kpb.gray400;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Center(
        child: Text(
          '$score%',
          style: TextStyle(
            fontSize: size * 0.28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match explanation bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
void showMatchExplanation(
  BuildContext context,
  String title,
  int score,
  List<String> reasons,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => Padding(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: KpbSpacing.md),
            decoration: BoxDecoration(
              color: context.kpb.gray200,
              borderRadius: KpbRadius.pillBr,
            ),
          ),
          // Score ring
          MatchScoreBadge(score: score, size: 64),
          const SizedBox(height: KpbSpacing.md),
          // Title
          Text(
            title,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: context.kpb.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Pourquoi ce match ?',
            style: TextStyle(fontSize: 13, color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.lg),
          // Reasons
          ...reasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        size: 18, color: Color(0xFF059669)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        reason,
                        style: TextStyle(
                            fontSize: 14, color: context.kpb.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: KpbSpacing.md),
          // CTA
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Get.back();
                controller.goToTab(StudentShellTab.profile);
              },
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: const Text('Améliorer mon profil'),
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
        ],
      ),
    ),
  );
}
