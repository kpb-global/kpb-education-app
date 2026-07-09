import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';

// Palette (App-engagement handoff). Local to this file — palette-only pass.
class _Palette {
  static const blue = Color(0xFF2563EB);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFDC2626);
}

/// A sleek, vertical timeline showing the high-level progress of an application.
class CaseTimelineStepper extends StatelessWidget {
  const CaseTimelineStepper({super.key, required this.currentStatus});
  final CaseStatus currentStatus;

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final currentIndex = _getCurrentStepIndex();

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
            'case_stepper_heading'.tr,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isCompleted = index < currentIndex;
            final isActive = index == currentIndex;
            final isLast = index == steps.length - 1;

            // Handle rejected/cancelled state styling
            final isErrorState = isActive &&
                (currentStatus == CaseStatus.rejected ||
                    currentStatus == CaseStatus.cancelled);

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Indicator Column
                  SizedBox(
                    width: 32,
                    child: Column(
                      children: [
                        // Node
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isErrorState
                                ? _Palette.red
                                : isCompleted
                                    ? _Palette.green
                                    : isActive
                                        ? _Palette.blue
                                        : context.kpb.gray200,
                            border: isActive && !isErrorState
                                ? Border.all(
                                    color: _Palette.blue.withValues(alpha: 0.3),
                                    width: 4)
                                : null,
                          ),
                          child: isCompleted
                              ? const Icon(Icons.check_rounded,
                                  color: Colors.white, size: 14)
                              : isActive && isErrorState
                                  ? const Icon(Icons.close_rounded,
                                      color: Colors.white, size: 14)
                                  : null,
                        ),
                        // Line
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isCompleted
                                  ? _Palette.green
                                  : context.kpb.gray200,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Content Column
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w600,
                              color: isErrorState
                                  ? _Palette.red
                                  : isActive || isCompleted
                                      ? context.kpb.textPrimary
                                      : context.kpb.textMuted,
                            ),
                          ),
                          if (step.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              step.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? context.kpb.textSecondary
                                    : context.kpb.textMuted,
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  int _getCurrentStepIndex() {
    switch (currentStatus) {
      case CaseStatus.draft:
      case CaseStatus.submitted:
        return 0; // Création
      case CaseStatus.underReview:
      case CaseStatus.documentsNeeded:
      case CaseStatus.counselorAssigned:
      case CaseStatus.awaitingStudent:
        return 1; // Analyse
      case CaseStatus.scheduled:
      case CaseStatus.inProgress:
      case CaseStatus.applicationSubmitted:
        return 2; // Traitement
      case CaseStatus.waitingDecision:
      case CaseStatus.awaitingPayment:
        return 3; // Décision
      case CaseStatus.completed:
      case CaseStatus.rejected:
      case CaseStatus.cancelled:
        return 4; // Finalisation
    }
  }

  List<_StepData> _buildSteps() {
    return [
      _StepData(
        title: 'case_stepper_creation_title'.tr,
        description: currentStatus == CaseStatus.draft
            ? 'case_stepper_creation_desc_draft'.tr
            : 'case_stepper_creation_desc_done'.tr,
      ),
      _StepData(
        title: 'case_stepper_analysis_title'.tr,
        description: currentStatus == CaseStatus.documentsNeeded
            ? 'case_stepper_analysis_desc_docs'.tr
            : currentStatus == CaseStatus.awaitingStudent
                ? 'case_stepper_analysis_desc_awaiting'.tr
                : 'case_stepper_analysis_desc_default'.tr,
      ),
      _StepData(
        title: 'case_stepper_processing_title'.tr,
        description: 'case_stepper_processing_desc'.tr,
      ),
      _StepData(
        title: 'case_stepper_decision_title'.tr,
        description: 'case_stepper_decision_desc'.tr,
      ),
      _StepData(
        title: 'case_stepper_finalization_title'.tr,
        description: currentStatus == CaseStatus.rejected
            ? 'case_stepper_finalization_desc_rejected'.tr
            : currentStatus == CaseStatus.cancelled
                ? 'case_stepper_finalization_desc_cancelled'.tr
                : 'case_stepper_finalization_desc_done'.tr,
      ),
    ];
  }
}

class _StepData {
  final String title;
  final String description;

  const _StepData({required this.title, required this.description});
}
