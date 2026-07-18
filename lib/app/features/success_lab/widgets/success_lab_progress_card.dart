import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/success_lab.dart';
import '../../../core/ui/kpb_components.dart';
import 'success_lab_accessibility.dart';
import 'success_lab_labels.dart';

class SuccessLabProgressCard extends StatelessWidget {
  const SuccessLabProgressCard({
    super.key,
    required this.workspace,
  });

  final SuccessLabWorkspace workspace;

  @override
  Widget build(BuildContext context) {
    final colors = context.kpb;
    final progress = workspace.readinessPercent.clamp(0, 100);
    final progressBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'success_lab_progress_label'.tr,
          style: KpbTextStyles.titleMd.copyWith(
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: KpbSpacing.xs),
        Text(
          '$progress%',
          key: const ValueKey<String>('success-lab-progress'),
          style: KpbTextStyles.displaySm.copyWith(
            color: KpbColors.actionPrimary,
          ),
        ),
      ],
    );
    final statusChip = KpbStatusChip(
      status: successLabWorkspaceKpbStatus(workspace.status),
      label: successLabWorkspaceStatusLabel(workspace.status),
      compact: true,
    );
    return KpbCard(
      variant: KpbCardVariant.highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (successLabUseStackedLayout(context)) ...[
            progressBlock,
            const SizedBox(height: KpbSpacing.sm),
            statusChip,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: progressBlock),
                statusChip,
              ],
            ),
          const SizedBox(height: KpbSpacing.md),
          Semantics(
            label: '${'success_lab_progress_label'.tr}: $progress%',
            value: '$progress%',
            child: ClipRRect(
              borderRadius: KpbRadius.pillBr,
              child: LinearProgressIndicator(
                value: progress / 100,
                minHeight: 10,
                backgroundColor: colors.gray200,
                color: KpbColors.actionPrimary,
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: colors.textMuted,
              ),
              const SizedBox(width: KpbSpacing.xs),
              Expanded(
                child: Text(
                  'success_lab_progress_disclaimer'.tr,
                  style: KpbTextStyles.bodySm.copyWith(
                    color: colors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
