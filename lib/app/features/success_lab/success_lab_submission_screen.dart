import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_submission_controller.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';
import 'widgets/success_lab_outcome_widgets.dart';

class SuccessLabSubmissionScreen extends StatefulWidget {
  const SuccessLabSubmissionScreen({
    super.key,
    required this.workspaceId,
    this.controller,
  });

  final String workspaceId;
  final SuccessLabSubmissionController? controller;

  @override
  State<SuccessLabSubmissionScreen> createState() =>
      _SuccessLabSubmissionScreenState();
}

class _SuccessLabSubmissionScreenState
    extends State<SuccessLabSubmissionScreen> {
  SuccessLabSubmissionController? _controller;
  bool _ownsController = false;
  final _channel = TextEditingController();
  final _reference = TextEditingController();
  DateTime _submittedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    if (_controller?.phase == SuccessLabSubmissionPhase.initial) {
      unawaited(
        _controller!.load(language: Get.locale?.languageCode ?? 'fr'),
      );
    }
  }

  SuccessLabSubmissionController? _buildController() {
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
    return SuccessLabSubmissionController(
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
    _channel.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final phase = controller?.phase;
    final networkState = switch (phase) {
      SuccessLabSubmissionPhase.offline => SuccessLabNetworkUiState.offline,
      SuccessLabSubmissionPhase.initial ||
      SuccessLabSubmissionPhase.loading =>
        SuccessLabNetworkUiState.busy,
      _ when controller?.isBusy == true => SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(title: Text('success_lab_submission_title'.tr)),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: phase == null
            ? 'success_lab_submission_sending'.tr
            : _busyLabel(phase),
        ensureScrollable: controller == null ||
            phase == SuccessLabSubmissionPhase.initial ||
            phase == SuccessLabSubmissionPhase.loading ||
            phase == SuccessLabSubmissionPhase.offline ||
            phase == SuccessLabSubmissionPhase.unavailable,
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

  Widget _buildState(SuccessLabSubmissionController controller) {
    if (controller.phase == SuccessLabSubmissionPhase.initial ||
        controller.phase == SuccessLabSubmissionPhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.phase == SuccessLabSubmissionPhase.offline) {
      return KpbEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'success_lab_offline_title'.tr,
        subtitle: 'success_lab_outcome_online_required'.tr,
        action: KpbButton(
          label: 'retry'.tr,
          onPressed: () => controller.load(
            language: Get.locale?.languageCode ?? 'fr',
          ),
        ),
      );
    }
    if (controller.phase == SuccessLabSubmissionPhase.unavailable) {
      return KpbEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'success_lab_outcome_unavailable_title'.tr,
        subtitle: _failureMessage(controller.failure),
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
        KpbCard(
          variant: KpbCardVariant.highlighted,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'success_lab_submission_intro_title'.tr,
                style: KpbTextStyles.title.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.xs),
              Text(
                'success_lab_submission_intro_body'.tr,
                style: KpbTextStyles.body.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
        _dateCard(controller),
        const SizedBox(height: KpbSpacing.md),
        TextField(
          controller: _channel,
          enabled: !controller.isBusy,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: 'success_lab_submission_channel'.tr,
            hintText: 'success_lab_submission_channel_hint'.tr,
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
        TextField(
          controller: _reference,
          enabled: !controller.isBusy,
          autocorrect: false,
          decoration: InputDecoration(
            labelText: 'success_lab_submission_reference'.tr,
            helperText: 'success_lab_submission_reference_private'.tr,
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
        SuccessLabEvidencePicker(
          fileName: controller.selectedFileName,
          onPressed: controller.isBusy ? null : () => _pickEvidence(controller),
        ),
        const SizedBox(height: KpbSpacing.md),
        SuccessLabOutcomeConsentCard(
          notice: controller.consentNotice,
          accepted: controller.consentAccepted,
          onChanged: controller.setConsentAccepted,
        ),
        if (controller.isBusy) ...[
          const SizedBox(height: KpbSpacing.md),
          LinearProgressIndicator(
            value: controller.phase == SuccessLabSubmissionPhase.uploading &&
                    controller.uploadProgress > 0
                ? controller.uploadProgress
                : null,
          ),
          const SizedBox(height: KpbSpacing.xs),
          Semantics(
            liveRegion: true,
            child: Text(_busyLabel(controller.phase)),
          ),
        ],
        if (controller.failure != null) ...[
          const SizedBox(height: KpbSpacing.md),
          Semantics(
            liveRegion: true,
            child: Text(
              _failureMessage(controller.failure),
              style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
            ),
          ),
        ],
        const SizedBox(height: KpbSpacing.md),
        KpbButton(
          key: const ValueKey<String>('success-lab-declare-submission'),
          label: 'success_lab_submission_action'.tr,
          icon: Icons.send_outlined,
          fullWidth: true,
          onPressed: controller.isBusy ||
                  controller.selectedFilePath == null ||
                  !controller.consentAccepted
              ? null
              : () => unawaited(
                    controller.declareSubmission(
                      submittedAt: _submittedAt,
                      submissionChannel: _channel.text,
                      applicationReference: _reference.text,
                    ),
                  ),
        ),
        if (controller.confirmedSubmission != null) ...[
          const SizedBox(height: KpbSpacing.md),
          KpbCard(
            child: Text(
              'success_lab_submission_confirmed_body'.tr,
              style: KpbTextStyles.body.copyWith(
                color: context.kpb.textPrimary,
              ),
            ),
          ),
        ],
        const SizedBox(height: KpbSpacing.xl),
        Text(
          'success_lab_submission_history'.tr,
          style: KpbTextStyles.title.copyWith(color: context.kpb.textPrimary),
        ),
        const SizedBox(height: KpbSpacing.md),
        if (controller.submissions.isEmpty)
          KpbCard(child: Text('success_lab_submission_history_empty'.tr))
        else
          ...controller.submissions.map(
            (submission) => Padding(
              padding: const EdgeInsets.only(bottom: KpbSpacing.md),
              child: _submissionCard(controller, submission),
            ),
          ),
      ],
    );
  }

  Widget _dateCard(SuccessLabSubmissionController controller) {
    final localizations = MaterialLocalizations.of(context);
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'success_lab_submission_date'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text(localizations.formatFullDate(_submittedAt)),
          Text(
            'success_lab_outcome_device_timezone'.trParams(
              <String, String>{
                'zone': successLabDeviceTimezoneLabel(_submittedAt.toLocal()),
              },
            ),
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          KpbButton(
            label: 'success_lab_outcome_choose_date'.tr,
            icon: Icons.calendar_today_outlined,
            variant: KpbButtonVariant.secondary,
            onPressed: controller.isBusy ? null : _chooseDate,
          ),
        ],
      ),
    );
  }

  Widget _submissionCard(
    SuccessLabSubmissionController controller,
    SuccessLabApplicationSubmission submission,
  ) {
    final local = submission.submittedAt.toLocal();
    final date = MaterialLocalizations.of(context).formatFullDate(local);
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'success_lab_submission_declared_label'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text('$date · ${successLabDeviceTimezoneLabel(local)}'),
          if (submission.submissionChannel != null)
            Text(submission.submissionChannel!),
          const SizedBox(height: KpbSpacing.sm),
          SuccessLabVerificationBadge(
            status: submission.verificationStatus,
            notes: submission.verificationNotes,
          ),
          if (submission.verificationNotes != null) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(submission.verificationNotes!),
          ],
          if (submission.verificationStatus ==
              SuccessLabEvidenceVerificationStatus.needsInformation) ...[
            const SizedBox(height: KpbSpacing.sm),
            KpbButton(
              label: 'success_lab_outcome_add_complement'.tr,
              icon: Icons.add_link_rounded,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              onPressed: controller.isBusy
                  ? null
                  : () => _pickSubmissionComplement(controller, submission),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _chooseDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _submittedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (value != null && mounted) {
      setState(() {
        _submittedAt = DateTime(
          value.year,
          value.month,
          value.day,
          _submittedAt.hour,
          _submittedAt.minute,
        );
      });
    }
  }

  Future<void> _pickEvidence(
    SuccessLabSubmissionController controller,
  ) async {
    final file = await _pickFile();
    if (file != null) {
      controller.selectEvidenceFile(path: file.$1, name: file.$2);
    }
  }

  Future<void> _pickSubmissionComplement(
    SuccessLabSubmissionController controller,
    SuccessLabApplicationSubmission submission,
  ) async {
    final file = await _pickFile();
    if (file != null) {
      await controller.attachEvidenceToSubmission(
        submission: submission,
        filePath: file.$1,
      );
    }
  }

  Future<(String, String)?> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
    );
    final file = result?.files.singleOrNull;
    if (file?.path == null) return null;
    return (file!.path!, file.name);
  }

  String _busyLabel(SuccessLabSubmissionPhase phase) {
    return switch (phase) {
      SuccessLabSubmissionPhase.grantingConsent =>
        'success_lab_outcome_granting_consent'.tr,
      SuccessLabSubmissionPhase.uploading => 'success_lab_outcome_uploading'.tr,
      SuccessLabSubmissionPhase.attachingEvidence =>
        'success_lab_outcome_attaching'.tr,
      _ => 'success_lab_submission_sending'.tr,
    };
  }

  String _failureMessage(SuccessLabFailure? failure) {
    return switch (failure?.code) {
      'GUARDIAN_CONSENT_REQUIRED' => 'success_lab_outcome_guardian_required'.tr,
      'OUTCOME_EVIDENCE_REQUIRED' => 'success_lab_outcome_evidence_required'.tr,
      'EVIDENCE_SCAN_PENDING' => 'success_lab_outcome_scan_pending'.tr,
      'EVIDENCE_REJECTED' => 'success_lab_outcome_evidence_rejected'.tr,
      'VERSION_CONFLICT' => 'success_lab_outcome_changed'.tr,
      'ARTIFACT_TOO_LARGE' => 'success_lab_outcome_file_too_large'.tr,
      'ARTIFACT_KIND_NOT_ALLOWED' => 'success_lab_outcome_file_not_allowed'.tr,
      _ => 'success_lab_outcome_error_body'.tr,
    };
  }
}
