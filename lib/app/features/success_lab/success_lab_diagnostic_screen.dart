import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_diagnostic_controller.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';

class SuccessLabDiagnosticScreen extends StatefulWidget {
  const SuccessLabDiagnosticScreen({
    super.key,
    required this.workspaceId,
    this.controller,
  });

  final String workspaceId;
  final SuccessLabDiagnosticController? controller;

  @override
  State<SuccessLabDiagnosticScreen> createState() =>
      _SuccessLabDiagnosticScreenState();
}

class _SuccessLabDiagnosticScreenState
    extends State<SuccessLabDiagnosticScreen> {
  final _excerptController = TextEditingController();
  SuccessLabDiagnosticController? _controller;
  bool _ownsController = false;
  String? _acceptedNoticeContentHash;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    if (_controller?.phase == SuccessLabDiagnosticPhase.initial) {
      unawaited(_controller!.load());
    }
  }

  SuccessLabDiagnosticController? _buildController() {
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
    return SuccessLabDiagnosticController(
      repository: SuccessLabRepository.standard(
        apiClient: app.apiClient,
        userId: userId,
      ),
      workspaceId: widget.workspaceId,
      language: Get.locale?.languageCode == 'en' ? 'en' : 'fr',
    );
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _excerptController.dispose();
    _controller?.removeListener(_onChanged);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final phase = controller?.phase;
    final networkState = switch (phase) {
      SuccessLabDiagnosticPhase.offline => SuccessLabNetworkUiState.offline,
      SuccessLabDiagnosticPhase.initial ||
      SuccessLabDiagnosticPhase.loading ||
      SuccessLabDiagnosticPhase.running =>
        SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(title: Text('success_lab_diagnostic_title'.tr)),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: phase == SuccessLabDiagnosticPhase.running
            ? 'success_lab_diagnostic_running'.tr
            : 'success_lab_diagnostic_loading'.tr,
        ensureScrollable: controller == null ||
            switch (phase) {
              SuccessLabDiagnosticPhase.consentRequired ||
              SuccessLabDiagnosticPhase.ready ||
              SuccessLabDiagnosticPhase.completed =>
                false,
              _ => true,
            },
        child: controller == null
            ? KpbEmptyState(
                icon: Icons.lock_outline_rounded,
                title: 'success_lab_forbidden_title'.tr,
                subtitle: 'success_lab_missing_identity'.tr,
              )
            : _buildState(controller),
      ),
    );
  }

  Widget _buildState(SuccessLabDiagnosticController controller) {
    switch (controller.phase) {
      case SuccessLabDiagnosticPhase.initial:
      case SuccessLabDiagnosticPhase.loading:
      case SuccessLabDiagnosticPhase.running:
        return _LoadingDiagnostic(
          running: controller.phase == SuccessLabDiagnosticPhase.running,
        );
      case SuccessLabDiagnosticPhase.offline:
        return KpbEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'success_lab_offline_title'.tr,
          subtitle: 'success_lab_diagnostic_online_required'.tr,
          action: KpbButton(label: 'retry'.tr, onPressed: controller.load),
        );
      case SuccessLabDiagnosticPhase.unavailable:
        return KpbEmptyState(
          icon: Icons.shield_outlined,
          title: 'success_lab_diagnostic_unavailable_title'.tr,
          subtitle: 'success_lab_diagnostic_unavailable'.tr,
        );
      case SuccessLabDiagnosticPhase.error:
        return KpbErrorState(
          title: 'success_lab_diagnostic_error_title'.tr,
          subtitle: _errorMessage(controller.failure),
          onRetry: controller.load,
        );
      case SuccessLabDiagnosticPhase.consentRequired:
      case SuccessLabDiagnosticPhase.ready:
        return _buildStart(controller);
      case SuccessLabDiagnosticPhase.completed:
        return _buildResult(controller.diagnostic);
    }
  }

  Widget _buildStart(SuccessLabDiagnosticController controller) {
    final notice = controller.notice;
    final consentAccepted =
        notice != null && _acceptedNoticeContentHash == notice.contentHash;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.md,
        KpbSpacing.page,
        KpbSpacing.xxl,
      ),
      children: [
        KpbCard(
          variant: KpbCardVariant.highlighted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'success_lab_diagnostic_promise'.tr,
                style: KpbTextStyles.title.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                'success_lab_diagnostic_disclaimer'.tr,
                style: KpbTextStyles.body.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (notice != null) ...[
          const SizedBox(height: KpbSpacing.md),
          KpbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: KpbTextStyles.titleMd.copyWith(
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  notice.body,
                  style: KpbTextStyles.bodySm.copyWith(
                    color: context.kpb.textSecondary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consentAccepted,
                  title: Text('success_lab_ai_consent_checkbox'.tr),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      _acceptedNoticeContentHash =
                          value == true ? notice.contentHash : null;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: KpbSpacing.md),
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'success_lab_excerpt_title'.tr,
                style: KpbTextStyles.titleMd.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.xs),
              Text(
                'success_lab_excerpt_body'.tr,
                style: KpbTextStyles.bodySm.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              TextField(
                controller: _excerptController,
                minLines: 4,
                maxLines: 8,
                maxLength: 8000,
                decoration: InputDecoration(
                  hintText: 'success_lab_excerpt_hint'.tr,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        if (controller.failure?.code == 'AI_CONSENT_REQUIRED') ...[
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'success_lab_ai_consent_required'.tr,
            style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
          ),
        ],
        const SizedBox(height: KpbSpacing.md),
        KpbButton(
          key: const ValueKey<String>('success-lab-run-diagnostic'),
          label: 'success_lab_diagnostic_action'.tr,
          icon: Icons.auto_awesome_rounded,
          fullWidth: true,
          onPressed: notice != null && !consentAccepted
              ? null
              : () => unawaited(
                    controller.start(
                      consentAccepted: consentAccepted,
                      acceptedNoticeContentHash:
                          consentAccepted ? notice.contentHash : null,
                      applicationExcerpt: _excerptController.text,
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildResult(SuccessLabDiagnostic? diagnostic) {
    final result = diagnostic?.result;
    if (diagnostic == null || result == null) {
      return KpbErrorState(
        title: 'success_lab_diagnostic_error_title'.tr,
        subtitle: 'success_lab_diagnostic_error_body'.tr,
        onRetry: _controller?.load,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.page,
        KpbSpacing.md,
        KpbSpacing.page,
        KpbSpacing.xxl,
      ),
      children: [
        if (diagnostic.stale)
          _DiagnosticSection(
            icon: Icons.update_rounded,
            title: 'success_lab_diagnostic_stale_title'.tr,
            body: 'success_lab_diagnostic_stale_body'.tr,
          ),
        _DiagnosticSection(
          icon: Icons.verified_outlined,
          title: 'success_lab_diagnostic_strength'.tr,
          body: result.strength,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DiagnosticSection(
          icon: Icons.track_changes_rounded,
          title: 'success_lab_diagnostic_priority'.tr,
          body: result.priorityImprovement,
          highlighted: true,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DiagnosticSection(
          icon: Icons.fact_check_outlined,
          title: 'success_lab_diagnostic_rationale'.tr,
          body: result.rationale,
        ),
        const SizedBox(height: KpbSpacing.md),
        _DiagnosticSection(
          icon: Icons.arrow_circle_right_outlined,
          title: 'success_lab_diagnostic_next_action'.tr,
          body: result.nextAction,
        ),
        const SizedBox(height: KpbSpacing.md),
        Text(
          'success_lab_diagnostic_disclaimer'.tr,
          style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
        ),
      ],
    );
  }

  String _errorMessage(SuccessLabFailure? failure) {
    return switch (failure?.code) {
      'GUARDIAN_CONSENT_REQUIRED' =>
        'success_lab_guardian_authorization_required'.tr,
      'AI_CONSENT_REQUIRED' => 'success_lab_ai_consent_required'.tr,
      _ => 'success_lab_diagnostic_error_body'.tr,
    };
  }
}

class _LoadingDiagnostic extends StatelessWidget {
  const _LoadingDiagnostic({required this.running});

  final bool running;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: KpbSpacing.md),
            Text(
              running
                  ? 'success_lab_diagnostic_running'.tr
                  : 'success_lab_diagnostic_loading'.tr,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DiagnosticSection extends StatelessWidget {
  const _DiagnosticSection({
    required this.icon,
    required this.title,
    required this.body,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      variant:
          highlighted ? KpbCardVariant.highlighted : KpbCardVariant.standard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: KpbColors.actionPrimary),
              const SizedBox(width: KpbSpacing.sm),
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
            style: KpbTextStyles.body.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
