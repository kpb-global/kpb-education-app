import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/models/success_lab.dart';
import '../../../core/ui/app_tokens.dart';
import '../../../core/ui/components/kpb_button.dart';
import '../../../core/ui/components/kpb_card.dart';
import '../../../core/ui/kpb_theme_ext.dart';

class SuccessLabVerificationBadge extends StatelessWidget {
  const SuccessLabVerificationBadge({
    super.key,
    required this.status,
    this.notes,
  });

  final SuccessLabEvidenceVerificationStatus status;
  final String? notes;

  @override
  Widget build(BuildContext context) {
    final (icon, color, key) = switch (status) {
      SuccessLabEvidenceVerificationStatus.selfReported => (
          Icons.person_outline_rounded,
          KpbColors.actionPrimary,
          'success_lab_verification_declared',
        ),
      SuccessLabEvidenceVerificationStatus.pending => (
          Icons.hourglass_top_rounded,
          KpbColors.warning,
          'success_lab_verification_pending',
        ),
      SuccessLabEvidenceVerificationStatus.verified => (
          Icons.verified_outlined,
          KpbColors.success,
          'success_lab_verification_verified',
        ),
      SuccessLabEvidenceVerificationStatus.needsInformation => (
          Icons.info_outline_rounded,
          KpbColors.warning,
          'success_lab_verification_needs_information',
        ),
      SuccessLabEvidenceVerificationStatus.rejected => (
          Icons.cancel_outlined,
          KpbColors.error,
          'success_lab_verification_rejected',
        ),
      SuccessLabEvidenceVerificationStatus.unknown => (
          Icons.help_outline_rounded,
          context.kpb.textMuted,
          'success_lab_verification_unknown',
        ),
    };
    return Semantics(
      label: key.tr,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KpbSpacing.sm,
          vertical: KpbSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: KpbRadius.pillBr,
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: KpbSpacing.xs),
            Flexible(
              child: Text(
                key.tr,
                style: KpbTextStyles.label.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SuccessLabOutcomeConsentCard extends StatelessWidget {
  const SuccessLabOutcomeConsentCard({
    super.key,
    required this.notice,
    required this.accepted,
    required this.onChanged,
  });

  final SuccessLabAiNotice? notice;
  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final current = notice;
    return KpbCard(
      variant: KpbCardVariant.highlighted,
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: CheckboxListTile(
          key: const ValueKey<String>('success-lab-outcome-consent'),
          value: accepted,
          onChanged:
              current == null ? null : (value) => onChanged(value == true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: const EdgeInsets.all(KpbSpacing.sm),
          title: Text(
            current?.title ?? 'success_lab_outcome_consent_loading'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: KpbSpacing.xs),
            child: Text(
              current == null
                  ? 'success_lab_outcome_consent_loading'.tr
                  : '${current.body}\n\n'
                      '${'success_lab_outcome_consent_private'.tr}',
              style: KpbTextStyles.bodySm.copyWith(
                color: context.kpb.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SuccessLabEvidencePicker extends StatelessWidget {
  const SuccessLabEvidencePicker({
    super.key,
    required this.fileName,
    required this.onPressed,
  });

  final String? fileName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'success_lab_outcome_evidence_title'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            fileName ?? 'success_lab_outcome_evidence_body'.tr,
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          KpbButton(
            label: fileName == null
                ? 'success_lab_outcome_evidence_choose'.tr
                : 'success_lab_outcome_evidence_change'.tr,
            icon: Icons.attach_file_rounded,
            variant: KpbButtonVariant.secondary,
            fullWidth: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}

String successLabDeviceTimezoneLabel(DateTime local) {
  final offset = local.timeZoneOffset;
  final totalMinutes = offset.inMinutes.abs();
  final sign = offset.isNegative ? '-' : '+';
  final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
  final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
  final utcOffset = 'UTC$sign$hours:$minutes';
  final name = local.timeZoneName.trim();
  return name.isEmpty || name == utcOffset ? utcOffset : '$name · $utcOffset';
}
