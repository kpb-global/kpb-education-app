import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/success_lab.dart';
import '../../../core/ui/kpb_components.dart';
import 'success_lab_labels.dart';

class SuccessLabStepTile extends StatelessWidget {
  const SuccessLabStepTile({
    super.key,
    required this.step,
    required this.languageCode,
    required this.mutationPhase,
    this.onToggle,
    this.onRetry,
  });

  final SuccessLabWorkspaceStep step;
  final String languageCode;
  final MutationPhase mutationPhase;
  final VoidCallback? onToggle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.kpb;
    final isSending = mutationPhase == MutationPhase.sending;
    final hasPendingMutation = mutationPhase == MutationPhase.queuedOffline ||
        mutationPhase == MutationPhase.failed ||
        mutationPhase == MutationPhase.conflict;
    final canMutate = step.status != SuccessLabWorkspaceStepStatus.unknown;
    final isDone = step.status == SuccessLabWorkspaceStepStatus.completed ||
        step.status == SuccessLabWorkspaceStepStatus.notApplicable;

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDone ? colors.successLight : colors.skyLight,
                  borderRadius: KpbRadius.smBr,
                ),
                child: Icon(
                  isDone ? Icons.check_rounded : Icons.assignment_outlined,
                  color: isDone ? KpbColors.success : KpbColors.actionPrimary,
                ),
              ),
              const SizedBox(width: KpbSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.titleForLanguage(languageCode),
                      style: KpbTextStyles.titleMd.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: KpbSpacing.xs),
                    Text(
                      successLabStepCategoryLabel(step.category),
                      style: KpbTextStyles.bodySm.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.md),
          Wrap(
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.sm,
            children: [
              KpbStatusChip(
                status: successLabStepKpbStatus(step.status),
                label: successLabStepStatusLabel(step.status),
                compact: true,
              ),
              if (step.isRequired)
                KpbStatusChip(
                  status: KpbStatus.warning,
                  label: 'success_lab_step_required'.tr,
                  compact: true,
                ),
              if (mutationPhase != MutationPhase.idle &&
                  mutationPhase != MutationPhase.success)
                KpbStatusChip(
                  status: _mutationKpbStatus(mutationPhase),
                  label: _mutationLabel(mutationPhase),
                  compact: true,
                ),
            ],
          ),
          if (step.notApplicableReason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: KpbSpacing.sm),
            Text(
              step.notApplicableReason!,
              style: KpbTextStyles.bodySm.copyWith(
                color: colors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            key: ValueKey<String>('success-lab-step-action-${step.id}'),
            label: hasPendingMutation
                ? 'success_lab_retry'.tr
                : isDone
                    ? 'success_lab_step_reopen'.tr
                    : 'success_lab_step_complete'.tr,
            icon: hasPendingMutation
                ? Icons.refresh_rounded
                : isDone
                    ? Icons.replay_rounded
                    : Icons.check_rounded,
            variant: KpbButtonVariant.secondary,
            fullWidth: true,
            loading: isSending,
            onPressed: !canMutate || isSending
                ? null
                : hasPendingMutation
                    ? onRetry
                    : onToggle,
          ),
        ],
      ),
    );
  }

  String _mutationLabel(MutationPhase phase) {
    return switch (phase) {
      MutationPhase.queuedOffline => 'success_lab_step_queued'.tr,
      MutationPhase.sending => 'success_lab_step_sending'.tr,
      MutationPhase.conflict => 'success_lab_step_conflict'.tr,
      MutationPhase.failed => 'success_lab_step_failed'.tr,
      MutationPhase.idle || MutationPhase.success => '',
    };
  }

  KpbStatus _mutationKpbStatus(MutationPhase phase) {
    return switch (phase) {
      MutationPhase.queuedOffline => KpbStatus.warning,
      MutationPhase.sending => KpbStatus.info,
      MutationPhase.conflict || MutationPhase.failed => KpbStatus.error,
      MutationPhase.idle || MutationPhase.success => KpbStatus.success,
    };
  }
}
