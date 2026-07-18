import 'package:get/get.dart';

import '../../../core/models/success_lab.dart';
import '../../../core/ui/kpb_components.dart';

String successLabWorkspaceStatusLabel(SuccessLabWorkspaceStatus status) {
  return switch (status) {
    SuccessLabWorkspaceStatus.started => 'success_lab_status_started'.tr,
    SuccessLabWorkspaceStatus.preparing => 'success_lab_status_preparing'.tr,
    SuccessLabWorkspaceStatus.readyForReview =>
      'success_lab_status_ready_for_review'.tr,
    SuccessLabWorkspaceStatus.reviewRequested =>
      'success_lab_status_review_requested'.tr,
    SuccessLabWorkspaceStatus.submitted => 'success_lab_status_submitted'.tr,
    SuccessLabWorkspaceStatus.decisionReceived =>
      'success_lab_status_decision_received'.tr,
    SuccessLabWorkspaceStatus.archived => 'success_lab_status_archived'.tr,
    SuccessLabWorkspaceStatus.unknown => 'success_lab_status_unknown'.tr,
  };
}

KpbStatus successLabWorkspaceKpbStatus(SuccessLabWorkspaceStatus status) {
  return switch (status) {
    SuccessLabWorkspaceStatus.readyForReview ||
    SuccessLabWorkspaceStatus.submitted ||
    SuccessLabWorkspaceStatus.decisionReceived =>
      KpbStatus.success,
    SuccessLabWorkspaceStatus.preparing ||
    SuccessLabWorkspaceStatus.reviewRequested =>
      KpbStatus.info,
    SuccessLabWorkspaceStatus.started => KpbStatus.warning,
    SuccessLabWorkspaceStatus.archived ||
    SuccessLabWorkspaceStatus.unknown =>
      KpbStatus.neutral,
  };
}

String successLabStepCategoryLabel(SuccessLabWorkspaceStepCategory category) {
  return switch (category) {
    SuccessLabWorkspaceStepCategory.profileEligibility =>
      'success_lab_category_profile'.tr,
    SuccessLabWorkspaceStepCategory.documents =>
      'success_lab_category_documents'.tr,
    SuccessLabWorkspaceStepCategory.formAndEssays =>
      'success_lab_category_form_essays'.tr,
    SuccessLabWorkspaceStepCategory.reviewAndSubmission =>
      'success_lab_category_review_submission'.tr,
    SuccessLabWorkspaceStepCategory.unknown =>
      'success_lab_category_unknown'.tr,
  };
}

String successLabStepStatusLabel(SuccessLabWorkspaceStepStatus status) {
  return switch (status) {
    SuccessLabWorkspaceStepStatus.notStarted =>
      'success_lab_step_not_started'.tr,
    SuccessLabWorkspaceStepStatus.inProgress =>
      'success_lab_step_in_progress'.tr,
    SuccessLabWorkspaceStepStatus.completed => 'success_lab_step_completed'.tr,
    SuccessLabWorkspaceStepStatus.notApplicable =>
      'success_lab_step_not_applicable'.tr,
    SuccessLabWorkspaceStepStatus.unknown =>
      'success_lab_step_status_unknown'.tr,
  };
}

KpbStatus successLabStepKpbStatus(SuccessLabWorkspaceStepStatus status) {
  return switch (status) {
    SuccessLabWorkspaceStepStatus.completed => KpbStatus.success,
    SuccessLabWorkspaceStepStatus.inProgress => KpbStatus.info,
    SuccessLabWorkspaceStepStatus.notApplicable ||
    SuccessLabWorkspaceStepStatus.notStarted ||
    SuccessLabWorkspaceStepStatus.unknown =>
      KpbStatus.neutral,
  };
}
