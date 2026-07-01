import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import 'case_timeline_definition.dart';

/// M14 per-status timeline with ✅ passées / 🔄 en cours / ⏸ à venir.
class CaseStatusTimeline extends StatelessWidget {
  const CaseStatusTimeline({
    super.key,
    required this.steps,
    required this.localeCode,
  });

  final List<CaseTimelineStepViewModel> steps;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
        border: Border.all(color: context.kpb.gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'case_timeline_heading'.tr,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: KpbSpacing.md),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            return _TimelineRow(
              step: step,
              isLast: isLast,
              localeCode: localeCode,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.localeCode,
  });

  final CaseTimelineStepViewModel step;
  final bool isLast;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final (icon, iconColor, bgColor) = _visuals(context, step.state);
    final dateLabel = step.date != null
        ? DateFormat('dd MMM yyyy', localeCode).format(step.date!)
        : null;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: step.state == CaseTimelineStepState.current
                        ? Border.all(
                            color: KpbColors.blue.withValues(alpha: 0.35),
                            width: 3,
                          )
                        : null,
                  ),
                  child: Center(
                    child: Text(icon,
                        style: TextStyle(fontSize: 14, color: iconColor)),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: step.state == CaseTimelineStepState.passed
                          ? KpbColors.success
                          : context.kpb.gray200,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.titleFr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: step.state == CaseTimelineStepState.current
                          ? FontWeight.w700
                          : FontWeight.w600,
                      color: _titleColor(context, step.state),
                    ),
                  ),
                  if (step.subtitle != null) ...[
                    SizedBox(height: 2),
                    Text(
                      step.subtitle!,
                      style: KpbTextStyles.caption.copyWith(
                        color: context.kpb.textSecondary,
                      ),
                    ),
                  ],
                  if (dateLabel != null) ...[
                    SizedBox(height: 4),
                    Text(
                      step.state == CaseTimelineStepState.current
                          ? 'case_timeline_since_date'
                              .trParams({'date': dateLabel})
                          : 'case_timeline_on_date'
                              .trParams({'date': dateLabel}),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.kpb.textMuted,
                      ),
                    ),
                  ] else if (step.state == CaseTimelineStepState.upcoming) ...[
                    SizedBox(height: 4),
                    Text(
                      'upcoming'.tr,
                      style: TextStyle(
                        fontSize: 12,
                        color: context.kpb.textMuted,
                      ),
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

  (String, Color, Color) _visuals(
    BuildContext context,
    CaseTimelineStepState state,
  ) {
    switch (state) {
      case CaseTimelineStepState.passed:
        return ('✅', KpbColors.success, KpbColors.successLight);
      case CaseTimelineStepState.current:
        return ('🔄', KpbColors.blue, KpbColors.skyLight);
      case CaseTimelineStepState.upcoming:
        return ('⏸', context.kpb.textMuted, context.kpb.gray100);
      case CaseTimelineStepState.terminalSuccess:
        return ('✅', KpbColors.success, KpbColors.successLight);
      case CaseTimelineStepState.terminalError:
        return ('❌', KpbColors.error, KpbColors.errorLight);
    }
  }

  Color _titleColor(BuildContext context, CaseTimelineStepState state) {
    switch (state) {
      case CaseTimelineStepState.passed:
      case CaseTimelineStepState.terminalSuccess:
        return context.kpb.textPrimary;
      case CaseTimelineStepState.current:
        return context.kpb.textPrimary;
      case CaseTimelineStepState.upcoming:
        return context.kpb.textMuted;
      case CaseTimelineStepState.terminalError:
        return KpbColors.error;
    }
  }
}
