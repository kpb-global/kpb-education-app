import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_study_review_controller.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';

class SuccessLabStudyReviewScreen extends StatefulWidget {
  const SuccessLabStudyReviewScreen({
    super.key,
    required this.workspaceId,
    this.controller,
  });

  final String workspaceId;
  final SuccessLabStudyReviewController? controller;

  @override
  State<SuccessLabStudyReviewScreen> createState() =>
      _SuccessLabStudyReviewScreenState();
}

class _SuccessLabStudyReviewScreenState
    extends State<SuccessLabStudyReviewScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  SuccessLabStudyReviewController? _controller;
  bool _ownsController = false;
  String? _acceptedNoticeContentHash;
  String _kind = 'cv';

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    if (_controller?.phase == SuccessLabStudyReviewPhase.initial) {
      unawaited(_controller!.load());
    }
  }

  SuccessLabStudyReviewController? _buildController() {
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
    return SuccessLabStudyReviewController(
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
    _titleController.dispose();
    _messageController.dispose();
    _controller?.removeListener(_onChanged);
    if (_ownsController) _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final phase = controller?.phase;
    final networkState = switch (phase) {
      SuccessLabStudyReviewPhase.offline => SuccessLabNetworkUiState.offline,
      SuccessLabStudyReviewPhase.initial ||
      SuccessLabStudyReviewPhase.loading ||
      SuccessLabStudyReviewPhase.uploading ||
      SuccessLabStudyReviewPhase.submitting ||
      SuccessLabStudyReviewPhase.complementing =>
        SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    final busyLabel = switch (phase) {
      SuccessLabStudyReviewPhase.uploading => 'success_lab_study_uploading'.tr,
      SuccessLabStudyReviewPhase.complementing =>
        'success_lab_study_complementing'.tr,
      _ => 'success_lab_study_submitting'.tr,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(title: Text('success_lab_study_title'.tr)),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: busyLabel,
        ensureScrollable: controller == null ||
            switch (phase) {
              SuccessLabStudyReviewPhase.ready ||
              SuccessLabStudyReviewPhase.submitted ||
              SuccessLabStudyReviewPhase.tracking =>
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

  Widget _buildState(SuccessLabStudyReviewController controller) {
    switch (controller.phase) {
      case SuccessLabStudyReviewPhase.initial:
      case SuccessLabStudyReviewPhase.loading:
        return const Center(child: CircularProgressIndicator());
      case SuccessLabStudyReviewPhase.uploading:
        return _BusyStudy(
          label: 'success_lab_study_uploading'.tr,
          progress: controller.uploadProgress,
        );
      case SuccessLabStudyReviewPhase.submitting:
        return _BusyStudy(label: 'success_lab_study_submitting'.tr);
      case SuccessLabStudyReviewPhase.complementing:
        return _BusyStudy(label: 'success_lab_study_complementing'.tr);
      case SuccessLabStudyReviewPhase.submitted:
      case SuccessLabStudyReviewPhase.tracking:
        return _buildTracking(controller);
      case SuccessLabStudyReviewPhase.offline:
        return KpbEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'success_lab_offline_title'.tr,
          subtitle: 'success_lab_study_online_required'.tr,
          action: KpbButton(label: 'retry'.tr, onPressed: controller.load),
        );
      case SuccessLabStudyReviewPhase.unavailable:
        return KpbEmptyState(
          icon: Icons.support_agent_rounded,
          title: 'success_lab_study_unavailable_title'.tr,
          subtitle: 'success_lab_study_unavailable'.tr,
        );
      case SuccessLabStudyReviewPhase.error:
        return KpbErrorState(
          title: 'success_lab_study_error_title'.tr,
          subtitle: _errorMessage(controller.failure),
          onRetry: controller.load,
        );
      case SuccessLabStudyReviewPhase.ready:
        return _buildForm(controller);
    }
  }

  Widget _buildForm(SuccessLabStudyReviewController controller) {
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
                'success_lab_study_free_title'.tr,
                style: KpbTextStyles.title.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                'success_lab_study_decision_disclaimer'.tr,
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
                _transparentListTile(CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: consentAccepted,
                  title: Text('success_lab_study_consent_checkbox'.tr),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      _acceptedNoticeContentHash =
                          value == true ? notice.contentHash : null;
                    });
                  },
                )),
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
                'success_lab_study_documents_title'.tr,
                style: KpbTextStyles.titleMd.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: InputDecoration(
                  labelText: 'success_lab_study_document_kind'.tr,
                  border: const OutlineInputBorder(),
                ),
                items: <String>[
                  'cv',
                  'motivation_letter',
                  'essay',
                  'transcript',
                  'diploma',
                ]
                    .map(
                      (kind) => DropdownMenuItem<String>(
                        value: kind,
                        child: Text(_kindLabel(kind)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value != null) setState(() => _kind = value);
                },
              ),
              const SizedBox(height: KpbSpacing.sm),
              TextField(
                controller: _titleController,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'success_lab_study_document_title'.tr,
                  hintText: _kindLabel(_kind),
                  border: const OutlineInputBorder(),
                ),
              ),
              KpbButton(
                label: 'success_lab_study_add_document'.tr,
                icon: Icons.upload_file_rounded,
                fullWidth: true,
                onPressed: !consentAccepted
                    ? null
                    : () => unawaited(
                          _pickAndUpload(
                            controller,
                            acceptedNoticeContentHash: notice.contentHash,
                          ),
                        ),
              ),
              if (controller.artifacts.isNotEmpty) ...[
                const SizedBox(height: KpbSpacing.md),
                ...controller.artifacts.expand(
                  (artifact) => artifact.versions
                      .where((version) => version.isClean)
                      .map(
                        (version) => _transparentListTile(CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: controller.selectedVersionIds.contains(
                            version.id,
                          ),
                          title: Text(artifact.title),
                          subtitle: Text(
                            'success_lab_study_version_label'.trParams(
                              <String, String>{
                                'number': '${version.versionNumber}',
                                'file': version.originalFileName,
                                'size': _fileSize(version.sizeBytes),
                              },
                            ),
                          ),
                          secondary: controller.isDeletingVersion(version.id)
                              ? Semantics(
                                  label: 'success_lab_study_deleting'.tr,
                                  child: const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  key: ValueKey<String>(
                                    'success-lab-delete-version-${version.id}',
                                  ),
                                  tooltip: 'success_lab_study_delete_action'.tr,
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: KpbColors.error,
                                  ),
                                  onPressed: controller.canDeleteVersions
                                      ? () => unawaited(
                                            _confirmDeleteVersion(
                                              controller,
                                              artifactTitle: artifact.title,
                                              version: version,
                                            ),
                                          )
                                      : null,
                                ),
                          onChanged: controller.isDeletingVersion(version.id)
                              ? null
                              : (selected) => controller.toggleVersion(
                                    version.id,
                                    selected == true,
                                  ),
                        )),
                      ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
        TextField(
          controller: _messageController,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          decoration: InputDecoration(
            labelText: 'success_lab_study_message_label'.tr,
            hintText: 'success_lab_study_message_hint'.tr,
            border: const OutlineInputBorder(),
          ),
        ),
        if (controller.failure != null) ...[
          const SizedBox(height: KpbSpacing.sm),
          Text(
            _errorMessage(controller.failure),
            style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
          ),
        ],
        const SizedBox(height: KpbSpacing.md),
        KpbButton(
          label: 'success_lab_study_submit_action'.tr,
          icon: Icons.send_rounded,
          fullWidth: true,
          onPressed: !consentAccepted || controller.selectedVersionIds.isEmpty
              ? null
              : () => unawaited(
                    controller.submit(
                      consentAccepted: consentAccepted,
                      acceptedNoticeContentHash: notice.contentHash,
                      studentMessage: _messageController.text,
                    ),
                  ),
        ),
      ],
    );
  }

  Widget _buildTracking(SuccessLabStudyReviewController controller) {
    final request = controller.request;
    if (request == null) {
      return KpbErrorState(
        title: 'success_lab_study_error_title'.tr,
        subtitle: 'success_lab_study_error_body'.tr,
        onRetry: controller.load,
      );
    }
    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                  'success_lab_study_request_number'.trParams(
                    <String, String>{
                      'number': '${request.requestNumber}',
                    },
                  ),
                  style: KpbTextStyles.title.copyWith(
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  _statusLabel(request.status),
                  style: KpbTextStyles.titleMd.copyWith(
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  _nextActionLabel(request.nextAction),
                  style: KpbTextStyles.body.copyWith(
                    color: context.kpb.textSecondary,
                  ),
                ),
                if (request.submittedAt != null) ...[
                  const SizedBox(height: KpbSpacing.sm),
                  Text(
                    'success_lab_study_submitted_on'.trParams(
                      <String, String>{
                        'date': _localizedDateTime(request.submittedAt!),
                        'zone': request.timezone,
                        'deviceZone': _deviceTimezoneLabel(
                          request.submittedAt!.toLocal(),
                        ),
                      },
                    ),
                    style: KpbTextStyles.bodySm.copyWith(
                      color: context.kpb.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (request.missingItems.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.md),
            KpbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'success_lab_study_missing_title'.tr,
                    style: KpbTextStyles.titleMd.copyWith(
                      color: context.kpb.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  ...request.missingItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ExcludeSemantics(
                            child: Padding(
                              padding: EdgeInsets.only(top: 3),
                              child: Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: KpbColors.warning,
                              ),
                            ),
                          ),
                          const SizedBox(width: KpbSpacing.sm),
                          Expanded(child: Text(item)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (request.activeSharedVersions.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.md),
            KpbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'success_lab_study_shared_title'.tr,
                    style: KpbTextStyles.titleMd.copyWith(
                      color: context.kpb.textPrimary,
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  ...request.activeSharedVersions.map(
                    (share) => _transparentListTile(ListTile(
                      contentPadding: EdgeInsets.zero,
                      minVerticalPadding: KpbSpacing.sm,
                      leading: const Icon(Icons.description_outlined),
                      title: Text(share.artifactTitle),
                      subtitle: Text(
                        'success_lab_study_version_label'.trParams(
                          <String, String>{
                            'number': '${share.versionNumber}',
                            'file': share.originalFileName,
                            'size': _fileSize(share.sizeBytes),
                          },
                        ),
                      ),
                    )),
                  ),
                ],
              ),
            ),
          ],
          if (request.canProvideMoreInformation) ...[
            const SizedBox(height: KpbSpacing.md),
            _buildComplement(controller, request),
          ],
          if (request.canChooseSlot) ...[
            const SizedBox(height: KpbSpacing.md),
            KpbButton(
              key: const ValueKey<String>('success-lab-open-schedule'),
              label: 'success_lab_study_choose_slot_action'.tr,
              icon: Icons.event_available_rounded,
              fullWidth: true,
              onPressed: () => Get.toNamed(
                AppRoutes.successLabSchedulePath(widget.workspaceId),
              ),
            ),
          ],
          if (controller.failure != null) ...[
            const SizedBox(height: KpbSpacing.sm),
            Semantics(
              liveRegion: true,
              child: Text(
                _errorMessage(controller.failure),
                style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            label: 'success_lab_study_refresh_action'.tr,
            icon: Icons.refresh_rounded,
            variant: KpbButtonVariant.secondary,
            fullWidth: true,
            onPressed: controller.load,
          ),
        ],
      ),
    );
  }

  Widget _buildComplement(
    SuccessLabStudyReviewController controller,
    SuccessLabStudyReviewRequest request,
  ) {
    final notice = controller.notice;
    final consentAccepted =
        notice != null && _acceptedNoticeContentHash == notice.contentHash;
    final sharedIds = request.sharedVersionIds.toSet();
    final availableVersions = controller.artifacts
        .expand(
          (artifact) => artifact.versions
              .where(
                (version) => version.isClean && !sharedIds.contains(version.id),
              )
              .map((version) => (artifact: artifact, version: version)),
        )
        .toList(growable: false);
    final hasMessage = _messageController.text.trim().isNotEmpty;
    final hasDocuments = controller.newComplementVersionIds.isNotEmpty;
    final canSubmit =
        (hasMessage || hasDocuments) && (!hasDocuments || consentAccepted);

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'success_lab_study_complement_title'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'success_lab_study_complement_body'.tr,
            style: KpbTextStyles.body.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          TextField(
            controller: _messageController,
            minLines: 3,
            maxLines: 6,
            maxLength: 2000,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'success_lab_study_complement_message'.tr,
              hintText: 'success_lab_study_complement_message_hint'.tr,
              border: const OutlineInputBorder(),
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: KpbSpacing.sm),
            Text(
              notice.title,
              style: KpbTextStyles.titleMd.copyWith(
                color: context.kpb.textPrimary,
              ),
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              notice.body,
              style: KpbTextStyles.bodySm.copyWith(
                color: context.kpb.textSecondary,
              ),
            ),
            _transparentListTile(CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: consentAccepted,
              title: Text('success_lab_study_consent_checkbox'.tr),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (value) {
                setState(() {
                  _acceptedNoticeContentHash =
                      value == true ? notice.contentHash : null;
                });
              },
            )),
          ],
          const SizedBox(height: KpbSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _kind,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'success_lab_study_document_kind'.tr,
              border: const OutlineInputBorder(),
            ),
            items: <String>[
              'cv',
              'motivation_letter',
              'essay',
              'transcript',
              'diploma',
            ]
                .map(
                  (kind) => DropdownMenuItem<String>(
                    value: kind,
                    child: Text(_kindLabel(kind)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value != null) setState(() => _kind = value);
            },
          ),
          const SizedBox(height: KpbSpacing.sm),
          TextField(
            controller: _titleController,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'success_lab_study_document_title'.tr,
              hintText: _kindLabel(_kind),
              border: const OutlineInputBorder(),
            ),
          ),
          KpbButton(
            label: 'success_lab_study_add_document'.tr,
            icon: Icons.upload_file_rounded,
            fullWidth: true,
            onPressed: !consentAccepted
                ? null
                : () => unawaited(
                      _pickAndUpload(
                        controller,
                        acceptedNoticeContentHash: notice.contentHash,
                      ),
                    ),
          ),
          if (availableVersions.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.sm),
            ...availableVersions.map(
              (entry) => _transparentListTile(CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: controller.selectedVersionIds.contains(
                  entry.version.id,
                ),
                title: Text(entry.artifact.title),
                subtitle: Text(entry.version.originalFileName),
                controlAffinity: ListTileControlAffinity.leading,
                onChanged: (selected) => controller.toggleVersion(
                  entry.version.id,
                  selected == true,
                ),
              )),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            key: const ValueKey<String>('success-lab-submit-complement'),
            label: 'success_lab_study_complement_action'.tr,
            icon: Icons.send_rounded,
            fullWidth: true,
            onPressed: !canSubmit
                ? null
                : () => unawaited(
                      _submitComplement(
                        controller,
                        consentAccepted: consentAccepted,
                        acceptedNoticeContentHash: notice?.contentHash,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitComplement(
    SuccessLabStudyReviewController controller, {
    required bool consentAccepted,
    required String? acceptedNoticeContentHash,
  }) async {
    await controller.submitComplement(
      consentAccepted: consentAccepted,
      acceptedNoticeContentHash: acceptedNoticeContentHash,
      studentMessage: _messageController.text,
    );
    if (!mounted) return;
    if (controller.request?.status !=
        SuccessLabStudyReviewStatus.moreInformationNeeded) {
      _messageController.clear();
      _acceptedNoticeContentHash = null;
      setState(() {});
    }
  }

  String _statusLabel(SuccessLabStudyReviewStatus status) => switch (status) {
        SuccessLabStudyReviewStatus.draft =>
          'success_lab_study_status_draft'.tr,
        SuccessLabStudyReviewStatus.submitted =>
          'success_lab_study_status_submitted'.tr,
        SuccessLabStudyReviewStatus.triaged =>
          'success_lab_study_status_triaged'.tr,
        SuccessLabStudyReviewStatus.moreInformationNeeded =>
          'success_lab_study_status_more_information_needed'.tr,
        SuccessLabStudyReviewStatus.callOffered =>
          'success_lab_study_status_call_offered'.tr,
        SuccessLabStudyReviewStatus.scheduled =>
          'success_lab_study_status_scheduled'.tr,
        SuccessLabStudyReviewStatus.convertedToCase =>
          'success_lab_study_status_converted_to_case'.tr,
        SuccessLabStudyReviewStatus.autonomyRecommended =>
          'success_lab_study_status_autonomy_recommended'.tr,
        SuccessLabStudyReviewStatus.declined =>
          'success_lab_study_status_declined'.tr,
        SuccessLabStudyReviewStatus.closed =>
          'success_lab_study_status_closed'.tr,
        SuccessLabStudyReviewStatus.unknown =>
          'success_lab_study_status_unknown'.tr,
      };

  String _nextActionLabel(SuccessLabStudyReviewNextAction action) =>
      switch (action) {
        SuccessLabStudyReviewNextAction.completeRequest =>
          'success_lab_study_next_complete_request'.tr,
        SuccessLabStudyReviewNextAction.waitForTriage =>
          'success_lab_study_next_wait_for_triage'.tr,
        SuccessLabStudyReviewNextAction.provideMoreInformation =>
          'success_lab_study_next_provide_more_information'.tr,
        SuccessLabStudyReviewNextAction.waitForSlotOffer =>
          'success_lab_study_next_wait_for_slot_offer'.tr,
        SuccessLabStudyReviewNextAction.chooseSlot =>
          'success_lab_study_next_choose_slot'.tr,
        SuccessLabStudyReviewNextAction.appointmentScheduled =>
          'success_lab_study_next_appointment_scheduled'.tr,
        SuccessLabStudyReviewNextAction.caseCreated =>
          'success_lab_study_next_case_created'.tr,
        SuccessLabStudyReviewNextAction.continueAutonomously =>
          'success_lab_study_next_continue_autonomously'.tr,
        SuccessLabStudyReviewNextAction.none =>
          'success_lab_study_next_none'.tr,
        SuccessLabStudyReviewNextAction.unknown =>
          'success_lab_study_next_unknown'.tr,
      };

  String _localizedDateTime(DateTime value) {
    final localizations = MaterialLocalizations.of(context);
    final local = value.toLocal();
    return '${localizations.formatFullDate(local)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }

  String _deviceTimezoneLabel(DateTime local) {
    final offset = local.timeZoneOffset;
    final totalMinutes = offset.inMinutes.abs();
    final sign = offset.isNegative ? '-' : '+';
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    final name = local.timeZoneName.trim();
    final utcOffset = 'UTC$sign$hours:$minutes';
    return name.isEmpty || name == utcOffset ? utcOffset : '$name · $utcOffset';
  }

  Future<void> _pickAndUpload(SuccessLabStudyReviewController controller,
      {required String? acceptedNoticeContentHash}) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const <String>['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
      withData: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.isEmpty) return;
    final title = _titleController.text.trim().isEmpty
        ? _kindLabel(_kind)
        : _titleController.text.trim();
    await controller.upload(
      consentAccepted: acceptedNoticeContentHash != null,
      acceptedNoticeContentHash: acceptedNoticeContentHash,
      kind: _kind,
      title: title,
      filePath: path,
    );
  }

  Future<void> _confirmDeleteVersion(
    SuccessLabStudyReviewController controller, {
    required String artifactTitle,
    required SuccessLabArtifactVersion version,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('success_lab_study_delete_confirm_title'.tr),
        content: Text(
          'success_lab_study_delete_confirm_body'.trParams(
            <String, String>{
              'title': artifactTitle,
              'file': version.originalFileName,
            },
          ),
        ),
        actions: [
          KpbButton(
            key: const ValueKey<String>('success-lab-delete-cancel'),
            label: 'cancel'.tr,
            variant: KpbButtonVariant.tertiary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          KpbButton(
            key: const ValueKey<String>('success-lab-delete-confirm'),
            label: 'success_lab_study_delete_confirm_action'.tr,
            icon: Icons.delete_outline_rounded,
            variant: KpbButtonVariant.destructive,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await controller.deleteVersion(version.id);
  }

  Widget _transparentListTile(Widget child) => Material(
        type: MaterialType.transparency,
        child: child,
      );

  String _kindLabel(String kind) => switch (kind) {
        'cv' => 'success_lab_document_cv'.tr,
        'motivation_letter' => 'success_lab_document_motivation'.tr,
        'essay' => 'success_lab_document_essay'.tr,
        'transcript' => 'success_lab_document_transcript'.tr,
        'diploma' => 'success_lab_document_diploma'.tr,
        _ => kind,
      };

  String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _errorMessage(SuccessLabFailure? failure) {
    return switch (failure?.code) {
      'GUARDIAN_CONSENT_REQUIRED' =>
        'success_lab_guardian_authorization_required'.tr,
      'ARTIFACT_TOO_LARGE' => 'success_lab_study_file_too_large'.tr,
      'ARTIFACT_KIND_NOT_ALLOWED' => 'success_lab_study_file_not_allowed'.tr,
      'EVIDENCE_REJECTED' => 'success_lab_study_document_required'.tr,
      'REVIEW_REQUEST_ALREADY_OPEN' => 'success_lab_study_already_open'.tr,
      'ADVISOR_DOCUMENT_SHARE_CONSENT_REQUIRED' =>
        'success_lab_study_consent_required'.tr,
      'FORBIDDEN_SCOPE' => 'success_lab_study_delete_shared'.tr,
      'REVIEW_REQUEST_NOT_TRIAGED' =>
        'success_lab_study_complement_not_allowed'.tr,
      'VERSION_CONFLICT' => 'success_lab_study_complement_changed'.tr,
      'INVALID_PAYLOAD' => 'success_lab_study_complement_required'.tr,
      _ => 'success_lab_study_error_body'.tr,
    };
  }
}

class _BusyStudy extends StatelessWidget {
  const _BusyStudy({required this.label, this.progress});

  final String label;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.page),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progress),
            const SizedBox(height: KpbSpacing.md),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
