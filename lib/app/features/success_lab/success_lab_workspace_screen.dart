import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_controller.dart';
import '../../core/config/app_routes.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';
import 'widgets/success_lab_progress_card.dart';
import 'widgets/success_lab_step_tile.dart';

class SuccessLabWorkspaceScreen extends StatefulWidget {
  const SuccessLabWorkspaceScreen({
    super.key,
    required this.workspaceId,
    this.controller,
    this.onDiagnosticRequested,
    this.onCounsellorStudyRequested,
  });

  final String workspaceId;
  final SuccessLabController? controller;

  /// Optional extension points used by tests and host applications.
  /// Production defaults navigate to the consented backend workflows.
  final VoidCallback? onDiagnosticRequested;
  final VoidCallback? onCounsellorStudyRequested;

  @override
  State<SuccessLabWorkspaceScreen> createState() =>
      _SuccessLabWorkspaceScreenState();
}

class _SuccessLabWorkspaceScreenState extends State<SuccessLabWorkspaceScreen> {
  SuccessLabController? _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    if (_controller?.phase == LabLoadPhase.initial) {
      unawaited(_controller!.load());
    }
  }

  SuccessLabController? _buildController() {
    if (!Get.isRegistered<AppController>() || widget.workspaceId.isEmpty) {
      return null;
    }
    final app = Get.find<AppController>();
    final authUserId = Get.isRegistered<AuthService>()
        ? Get.find<AuthService>().userId?.trim()
        : null;
    final profileUserId = app.profile?.id.trim();
    final userId = authUserId?.isNotEmpty == true
        ? authUserId
        : profileUserId?.isNotEmpty == true
            ? profileUserId
            : null;
    if (userId == null) return null;
    return SuccessLabController(
      repository: SuccessLabRepository.standard(
        apiClient: app.apiClient,
        userId: userId,
      ),
      workspaceId: widget.workspaceId,
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onChanged);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final networkState = switch (controller?.phase) {
      LabLoadPhase.offline => SuccessLabNetworkUiState.offline,
      LabLoadPhase.initial ||
      LabLoadPhase.loading ||
      LabLoadPhase.syncing =>
        SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('success_lab_workspace_title'.tr),
        actions: [
          IconButton(
            tooltip: 'a11y_refresh'.tr,
            onPressed: controller?.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: 'success_lab_cached_label'.tr,
        ensureScrollable: controller == null || controller.workspace == null,
        child: controller == null
            ? KpbEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'success_lab_forbidden_title'.tr,
                subtitle: 'success_lab_missing_identity'.tr,
              )
            : _buildControllerState(controller),
      ),
    );
  }

  Widget _buildControllerState(SuccessLabController controller) {
    final workspace = controller.workspace;
    if (workspace == null) {
      switch (controller.phase) {
        case LabLoadPhase.initial:
        case LabLoadPhase.loading:
        case LabLoadPhase.cached:
        case LabLoadPhase.syncing:
          return const Center(child: CircularProgressIndicator());
        case LabLoadPhase.offline:
          return KpbEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'success_lab_offline_title'.tr,
            subtitle: 'success_lab_offline_empty_body'.tr,
            action: KpbButton(
              label: 'retry'.tr,
              onPressed: controller.load,
            ),
          );
        case LabLoadPhase.forbidden:
          return KpbEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'success_lab_forbidden_title'.tr,
            subtitle: 'success_lab_forbidden_body'.tr,
          );
        case LabLoadPhase.featureDisabled:
          return KpbEmptyState(
            icon: Icons.construction_rounded,
            title: 'success_lab_disabled_title'.tr,
            subtitle: 'success_lab_disabled_body'.tr,
          );
        case LabLoadPhase.error:
          return KpbErrorState(
            title: 'success_lab_error_title'.tr,
            subtitle: 'success_lab_error_body'.tr,
            onRetry: controller.load,
          );
        case LabLoadPhase.empty:
        case LabLoadPhase.ready:
          return KpbErrorState(
            title: 'success_lab_error_title'.tr,
            subtitle: 'success_lab_error_body'.tr,
            onRetry: controller.load,
          );
      }
    }

    final languageCode = Get.locale?.languageCode ?? 'fr';
    final hasQueuedChanges = workspace.steps.any((step) {
      final phase = controller.mutationPhaseFor(step.id);
      return phase == MutationPhase.queuedOffline ||
          phase == MutationPhase.failed ||
          phase == MutationPhase.conflict;
    });

    return KpbRefresh(
      onRefresh: controller.load,
      child: ListView(
        key: const PageStorageKey<String>('success-lab-workspace'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.page,
          KpbSpacing.sm,
          KpbSpacing.page,
          KpbSpacing.xxl,
        ),
        children: [
          if (controller.phase == LabLoadPhase.cached ||
              controller.phase == LabLoadPhase.syncing ||
              controller.phase == LabLoadPhase.offline) ...[
            _WorkspaceBanner(
              icon: controller.phase == LabLoadPhase.offline
                  ? Icons.cloud_off_rounded
                  : Icons.sync_rounded,
              label: controller.phase == LabLoadPhase.offline
                  ? 'success_lab_offline_cached_body'.tr
                  : 'success_lab_cached_label'.tr,
            ),
            const SizedBox(height: KpbSpacing.md),
          ],
          if (hasQueuedChanges) ...[
            _WorkspaceBanner(
              icon: Icons.outbox_outlined,
              label: 'success_lab_pending_changes_body'.tr,
              action: KpbButton(
                label: 'success_lab_retry'.tr,
                icon: Icons.refresh_rounded,
                variant: KpbButtonVariant.tertiary,
                onPressed: controller.retryPending,
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],
          if (workspace.scholarship != null) ...[
            Text(
              workspace.scholarship!.name,
              style: KpbTextStyles.headlineSm.copyWith(
                color: context.kpb.textPrimary,
              ),
            ),
            if (workspace.scholarship!.countryName.trim().isNotEmpty) ...[
              const SizedBox(height: KpbSpacing.xs),
              Text(
                workspace.scholarship!.countryName,
                style: KpbTextStyles.body.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: KpbSpacing.md),
          ],
          SuccessLabProgressCard(workspace: workspace),
          if (workspace.nextAction?.label.trim().isNotEmpty == true) ...[
            const SizedBox(height: KpbSpacing.md),
            KpbCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.arrow_circle_right_outlined,
                    color: KpbColors.actionPrimary,
                  ),
                  const SizedBox(width: KpbSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'success_lab_next_action'.tr,
                          style: KpbTextStyles.label.copyWith(
                            color: context.kpb.textMuted,
                          ),
                        ),
                        const SizedBox(height: KpbSpacing.xs),
                        Text(
                          workspace.nextAction!.label,
                          style: KpbTextStyles.body.copyWith(
                            color: context.kpb.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.lg),
          Text(
            'success_lab_steps_title'.tr,
            style: KpbTextStyles.title.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          if (workspace.steps.isEmpty)
            KpbCard(
              child: Text(
                'success_lab_steps_empty'.tr,
                style: KpbTextStyles.body.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
            )
          else
            ...workspace.steps.expand(
              (step) => [
                SuccessLabStepTile(
                  step: step,
                  languageCode: languageCode,
                  mutationPhase: controller.mutationPhaseFor(step.id),
                  onToggle: () => unawaited(
                    controller.setStepStatus(
                      step,
                      step.status == SuccessLabWorkspaceStepStatus.completed ||
                              step.status ==
                                  SuccessLabWorkspaceStepStatus.notApplicable
                          ? SuccessLabWorkspaceStepStatus.inProgress
                          : SuccessLabWorkspaceStepStatus.completed,
                    ),
                  ),
                  onRetry: () => unawaited(controller.retryPending()),
                ),
                const SizedBox(height: KpbSpacing.md),
              ],
            ),
          if (controller.canOpenDiagnostic) ...[
            const SizedBox(height: KpbSpacing.sm),
            _FutureActionCard(
              icon: Icons.auto_awesome_rounded,
              title: 'success_lab_diagnostic_title'.tr,
              body: 'success_lab_diagnostic_body'.tr,
              actionLabel: 'success_lab_diagnostic_action'.tr,
              unavailableLabel: 'success_lab_diagnostic_unavailable'.tr,
              onPressed: widget.onDiagnosticRequested ??
                  () => Get.toNamed(
                        AppRoutes.successLabDiagnosticPath(workspace.id),
                      ),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          _FutureActionCard(
            icon: Icons.support_agent_rounded,
            title: 'success_lab_study_title'.tr,
            body: 'success_lab_study_body'.tr,
            actionLabel: 'success_lab_study_action'.tr,
            unavailableLabel: 'success_lab_study_unavailable'.tr,
            onPressed: controller.canRequestCounsellorStudy
                ? widget.onCounsellorStudyRequested ??
                    () => Get.toNamed(
                          AppRoutes.successLabStudyReviewPath(workspace.id),
                        )
                : null,
          ),
          if (controller.canDeclareOutcomes) ...[
            const SizedBox(height: KpbSpacing.md),
            _FutureActionCard(
              icon: Icons.send_outlined,
              title: 'success_lab_submission_title'.tr,
              body: 'success_lab_submission_workspace_body'.tr,
              actionLabel: 'success_lab_submission_open'.tr,
              unavailableLabel: 'success_lab_outcome_unavailable_title'.tr,
              onPressed: () => Get.toNamed(
                AppRoutes.successLabSubmissionPath(workspace.id),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            _FutureActionCard(
              icon: Icons.fact_check_outlined,
              title: 'success_lab_outcome_title'.tr,
              body: 'success_lab_outcome_workspace_body'.tr,
              actionLabel: 'success_lab_outcome_open'.tr,
              unavailableLabel: 'success_lab_outcome_unavailable_title'.tr,
              onPressed: () => Get.toNamed(
                AppRoutes.successLabOutcomePath(workspace.id),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WorkspaceBanner extends StatelessWidget {
  const _WorkspaceBanner({
    required this.icon,
    required this.label,
    this.action,
  });

  final IconData icon;
  final String label;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final message = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: KpbColors.actionPrimary, size: 18),
        const SizedBox(width: KpbSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
        ),
      ],
    );
    final content = action != null && successLabUseStackedLayout(context)
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              message,
              const SizedBox(height: KpbSpacing.sm),
              Align(alignment: Alignment.centerLeft, child: action!),
            ],
          )
        : Row(
            children: [
              Expanded(child: message),
              if (action != null) ...[
                const SizedBox(width: KpbSpacing.sm),
                action!,
              ],
            ],
          );
    return Semantics(
      container: true,
      liveRegion: true,
      child: KpbCard(
        variant: KpbCardVariant.highlighted,
        padding: const EdgeInsets.all(KpbSpacing.sm),
        child: content,
      ),
    );
  }
}

class _FutureActionCard extends StatelessWidget {
  const _FutureActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.unavailableLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final String unavailableLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: context.kpb.skyLight,
                  borderRadius: KpbRadius.smBr,
                ),
                child: Icon(icon, color: KpbColors.actionPrimary),
              ),
              const SizedBox(width: KpbSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: KpbTextStyles.titleMd.copyWith(
                    color: context.kpb.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            body,
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
          if (onPressed == null) ...[
            const SizedBox(height: KpbSpacing.sm),
            Text(
              unavailableLabel,
              style: KpbTextStyles.bodySm.copyWith(
                color: context.kpb.textMuted,
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            label: actionLabel,
            icon: icon,
            fullWidth: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }
}
