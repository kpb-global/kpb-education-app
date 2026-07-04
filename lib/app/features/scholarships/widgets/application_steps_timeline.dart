import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/app_models.dart';
import '../../../core/ui/kpb_components.dart';

/// Ordered "how to apply" steps for a single scholarship (e.g. Chevening:
/// online form then interview; MEXT: written exam). Static and per-scholarship
/// — NOT [RoadmapTimelineView], which renders a generic countdown to one
/// deadline shared with the orientation "parcours" and has no notion of
/// bourse-specific steps.
class ApplicationStepsTimeline extends StatelessWidget {
  const ApplicationStepsTimeline({
    super.key,
    required this.steps,
    required this.accent,
  });

  final List<ScholarshipApplicationStepModel> steps;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          _ApplicationStepTile(
            step: steps[i],
            accent: accent,
            isLast: i == steps.length - 1,
          ),
      ],
    );
  }
}

class _ApplicationStepTile extends StatelessWidget {
  const _ApplicationStepTile({
    required this.step,
    required this.accent,
    required this.isLast,
  });

  final ScholarshipApplicationStepModel step;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  border: Border.all(color: accent, width: 2),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${step.stepNumber}',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: accent.withValues(alpha: 0.2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: KpbTextStyles.body.copyWith(
                      color: context.kpb.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (step.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: KpbTextStyles.caption.copyWith(
                        color: context.kpb.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                  if (step.estimatedDurationDays != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'live_scholarships_step_duration'.trParams(
                        {'days': '${step.estimatedDurationDays}'},
                      ),
                      style: KpbTextStyles.caption
                          .copyWith(color: context.kpb.textMuted),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
