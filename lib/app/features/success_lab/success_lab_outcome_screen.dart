import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_outcome_controller.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';
import 'widgets/success_lab_outcome_widgets.dart';

class SuccessLabOutcomeScreen extends StatefulWidget {
  const SuccessLabOutcomeScreen({
    super.key,
    required this.workspaceId,
    this.controller,
  });

  final String workspaceId;
  final SuccessLabOutcomeController? controller;

  @override
  State<SuccessLabOutcomeScreen> createState() =>
      _SuccessLabOutcomeScreenState();
}

class _SuccessLabOutcomeScreenState extends State<SuccessLabOutcomeScreen> {
  SuccessLabOutcomeController? _controller;
  bool _ownsController = false;
  final _admissionIssuer = TextEditingController();
  final _fundingIssuer = TextEditingController();
  final _fundingAmount = TextEditingController();
  final _fundingCurrency = TextEditingController();
  SuccessLabAdmissionDecision _admission = SuccessLabAdmissionDecision.admitted;
  SuccessLabFundingDecision _funding = SuccessLabFundingDecision.pending;
  DateTime _admissionReceivedAt = DateTime.now();
  DateTime _fundingReceivedAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    if (_controller?.phase == SuccessLabOutcomePhase.initial) {
      unawaited(_controller!.load(language: Get.locale?.languageCode ?? 'fr'));
    }
  }

  SuccessLabOutcomeController? _buildController() {
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
    return SuccessLabOutcomeController(
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
    _admissionIssuer.dispose();
    _fundingIssuer.dispose();
    _fundingAmount.dispose();
    _fundingCurrency.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final phase = controller?.phase;
    final networkState = switch (phase) {
      SuccessLabOutcomePhase.offline => SuccessLabNetworkUiState.offline,
      SuccessLabOutcomePhase.initial ||
      SuccessLabOutcomePhase.loading =>
        SuccessLabNetworkUiState.busy,
      _ when controller?.isBusy == true => SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(title: Text('success_lab_outcome_title'.tr)),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: phase == null
            ? 'success_lab_outcome_consent_loading'.tr
            : _busyLabel(phase),
        ensureScrollable: controller == null ||
            phase == SuccessLabOutcomePhase.initial ||
            phase == SuccessLabOutcomePhase.loading ||
            phase == SuccessLabOutcomePhase.offline ||
            phase == SuccessLabOutcomePhase.unavailable,
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

  Widget _buildState(SuccessLabOutcomeController controller) {
    if (controller.phase == SuccessLabOutcomePhase.initial ||
        controller.phase == SuccessLabOutcomePhase.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.phase == SuccessLabOutcomePhase.offline) {
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
    if (controller.phase == SuccessLabOutcomePhase.unavailable) {
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
                'success_lab_outcome_intro_title'.tr,
                style: KpbTextStyles.title.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.xs),
              Text(
                'success_lab_outcome_intro_body'.tr,
                style: KpbTextStyles.body.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
            ],
          ),
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
            value: controller.phase == SuccessLabOutcomePhase.uploading &&
                    controller.uploadProgress > 0
                ? controller.uploadProgress
                : null,
          ),
          const SizedBox(height: KpbSpacing.xs),
          Semantics(
              liveRegion: true, child: Text(_busyLabel(controller.phase))),
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
        const SizedBox(height: KpbSpacing.xl),
        _sectionTitle('success_lab_outcome_current_admission'.tr),
        const SizedBox(height: KpbSpacing.md),
        if (controller.history.currentAdmission == null)
          KpbCard(child: Text('success_lab_outcome_no_admission'.tr))
        else
          _admissionRecordCard(
            controller,
            controller.history.currentAdmission!,
          ),
        const SizedBox(height: KpbSpacing.md),
        _admissionForm(controller),
        const SizedBox(height: KpbSpacing.xl),
        _sectionTitle('success_lab_outcome_current_funding'.tr),
        const SizedBox(height: KpbSpacing.md),
        if (controller.history.currentFunding == null)
          KpbCard(child: Text('success_lab_outcome_no_funding'.tr))
        else
          _fundingRecordCard(controller, controller.history.currentFunding!),
        const SizedBox(height: KpbSpacing.md),
        _fundingForm(controller),
        const SizedBox(height: KpbSpacing.xl),
        _sectionTitle('success_lab_outcome_history'.tr),
        const SizedBox(height: KpbSpacing.md),
        ...controller.history.admissions
            .where((record) => !record.isCurrent)
            .map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: KpbSpacing.md),
                child: _admissionRecordCard(controller, record),
              ),
            ),
        ...controller.history.funding.where((record) => !record.isCurrent).map(
              (record) => Padding(
                padding: const EdgeInsets.only(bottom: KpbSpacing.md),
                child: _fundingRecordCard(controller, record),
              ),
            ),
        if (!controller.history.admissions.any((record) => !record.isCurrent) &&
            !controller.history.funding.any((record) => !record.isCurrent))
          KpbCard(child: Text('success_lab_outcome_history_empty'.tr)),
      ],
    );
  }

  Widget _admissionForm(SuccessLabOutcomeController controller) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.history.currentAdmission == null
                ? 'success_lab_outcome_declare_admission'.tr
                : 'success_lab_outcome_update_admission'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          TextField(
            key: const ValueKey<String>('success-lab-admission-issuer'),
            controller: _admissionIssuer,
            enabled: !controller.isBusy,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'success_lab_outcome_issuer'.tr,
              helperText: 'success_lab_outcome_issuer_helper'.tr,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          DropdownButtonFormField<SuccessLabAdmissionDecision>(
            isExpanded: true,
            initialValue: _admission,
            decoration: InputDecoration(
              labelText: 'success_lab_outcome_admission_decision'.tr,
            ),
            items: SuccessLabAdmissionDecision.values
                .where((value) => value != SuccessLabAdmissionDecision.unknown)
                .map(
                  (value) => DropdownMenuItem<SuccessLabAdmissionDecision>(
                    value: value,
                    child: Text(
                      _admissionLabel(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: controller.isBusy
                ? null
                : (value) => setState(() => _admission = value ?? _admission),
          ),
          const SizedBox(height: KpbSpacing.md),
          _dateChooser(
            label: 'success_lab_outcome_received_date'.tr,
            value: _admissionReceivedAt,
            enabled: !controller.isBusy,
            onChanged: (value) => setState(() => _admissionReceivedAt = value),
          ),
          const SizedBox(height: KpbSpacing.md),
          SuccessLabEvidencePicker(
            fileName: controller.admissionFileName,
            onPressed: controller.isBusy
                ? null
                : () => _pickAdmissionEvidence(controller),
          ),
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            key: const ValueKey<String>('success-lab-declare-admission'),
            label: 'success_lab_outcome_save_admission'.tr,
            icon: Icons.fact_check_outlined,
            fullWidth: true,
            onPressed: controller.isBusy ||
                    _admissionIssuer.text.trim().isEmpty ||
                    controller.admissionFilePath == null ||
                    !controller.consentAccepted
                ? null
                : () => unawaited(
                      controller.declareAdmission(
                        issuedByName: _admissionIssuer.text,
                        decision: _admission,
                        receivedAt: _admissionReceivedAt,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _fundingForm(SuccessLabOutcomeController controller) {
    final amountAllowed = _funding == SuccessLabFundingDecision.full ||
        _funding == SuccessLabFundingDecision.partial;
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            controller.history.currentFunding == null
                ? 'success_lab_outcome_declare_funding'.tr
                : 'success_lab_outcome_update_funding'.tr,
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          TextField(
            key: const ValueKey<String>('success-lab-funding-issuer'),
            controller: _fundingIssuer,
            enabled: !controller.isBusy,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'success_lab_outcome_issuer'.tr,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          DropdownButtonFormField<SuccessLabFundingDecision>(
            isExpanded: true,
            initialValue: _funding,
            decoration: InputDecoration(
              labelText: 'success_lab_outcome_funding_decision'.tr,
            ),
            items: SuccessLabFundingDecision.values
                .where((value) => value != SuccessLabFundingDecision.unknown)
                .map(
                  (value) => DropdownMenuItem<SuccessLabFundingDecision>(
                    value: value,
                    child: Text(
                      _fundingLabel(value),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(growable: false),
            onChanged: controller.isBusy
                ? null
                : (value) {
                    setState(() {
                      _funding = value ?? _funding;
                      if (_funding != SuccessLabFundingDecision.full &&
                          _funding != SuccessLabFundingDecision.partial) {
                        _fundingAmount.clear();
                        _fundingCurrency.clear();
                      }
                    });
                  },
          ),
          if (amountAllowed) ...[
            const SizedBox(height: KpbSpacing.md),
            TextField(
              controller: _fundingAmount,
              enabled: !controller.isBusy,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                labelText: 'success_lab_outcome_amount_minor'.tr,
                helperText: 'success_lab_outcome_amount_optional'.tr,
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            TextField(
              controller: _fundingCurrency,
              enabled: !controller.isBusy,
              maxLength: 3,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[A-Za-z]')),
              ],
              decoration: InputDecoration(
                labelText: 'success_lab_outcome_currency'.tr,
                hintText: 'EUR',
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          _dateChooser(
            label: 'success_lab_outcome_received_date'.tr,
            value: _fundingReceivedAt,
            enabled: !controller.isBusy,
            onChanged: (value) => setState(() => _fundingReceivedAt = value),
          ),
          const SizedBox(height: KpbSpacing.md),
          SuccessLabEvidencePicker(
            fileName: controller.fundingFileName,
            onPressed: controller.isBusy
                ? null
                : () => _pickFundingEvidence(controller),
          ),
          const SizedBox(height: KpbSpacing.md),
          KpbButton(
            key: const ValueKey<String>('success-lab-declare-funding'),
            label: 'success_lab_outcome_save_funding'.tr,
            icon: Icons.account_balance_wallet_outlined,
            fullWidth: true,
            onPressed: controller.isBusy ||
                    _fundingIssuer.text.trim().isEmpty ||
                    controller.fundingFilePath == null ||
                    !controller.consentAccepted
                ? null
                : () => unawaited(
                      controller.declareFunding(
                        issuedByName: _fundingIssuer.text,
                        decision: _funding,
                        receivedAt: _fundingReceivedAt,
                        fundingAmountMinor: _fundingAmount.text,
                        fundingCurrency: _fundingCurrency.text,
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Widget _admissionRecordCard(
    SuccessLabOutcomeController controller,
    SuccessLabAdmissionDecisionRecord record,
  ) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _admissionLabel(record.decision),
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text('${record.issuedByName} · ${_date(record.receivedAt)}'),
          const SizedBox(height: KpbSpacing.sm),
          SuccessLabVerificationBadge(
            status: record.verificationStatus,
            notes: record.verificationNotes,
          ),
          if (record.verificationNotes != null) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(record.verificationNotes!),
          ],
          if (record.isCurrent &&
              record.verificationStatus ==
                  SuccessLabEvidenceVerificationStatus.needsInformation) ...[
            const SizedBox(height: KpbSpacing.sm),
            KpbButton(
              label: 'success_lab_outcome_add_complement'.tr,
              icon: Icons.add_link_rounded,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              onPressed: controller.isBusy
                  ? null
                  : () => _addAdmissionComplement(controller, record),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fundingRecordCard(
    SuccessLabOutcomeController controller,
    SuccessLabFundingDecisionRecord record,
  ) {
    final amount = record.fundingAmountMinor == null
        ? ''
        : ' · ${record.fundingAmountMinor} ${record.fundingCurrency ?? ''}';
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_fundingLabel(record.decision)}$amount',
            style: KpbTextStyles.titleMd.copyWith(
              color: context.kpb.textPrimary,
            ),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Text('${record.issuedByName} · ${_date(record.receivedAt)}'),
          const SizedBox(height: KpbSpacing.sm),
          SuccessLabVerificationBadge(
            status: record.verificationStatus,
            notes: record.verificationNotes,
          ),
          if (record.verificationNotes != null) ...[
            const SizedBox(height: KpbSpacing.xs),
            Text(record.verificationNotes!),
          ],
          if (record.isCurrent &&
              record.verificationStatus ==
                  SuccessLabEvidenceVerificationStatus.needsInformation) ...[
            const SizedBox(height: KpbSpacing.sm),
            KpbButton(
              label: 'success_lab_outcome_add_complement'.tr,
              icon: Icons.add_link_rounded,
              variant: KpbButtonVariant.secondary,
              fullWidth: true,
              onPressed: controller.isBusy
                  ? null
                  : () => _addFundingComplement(controller, record),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dateChooser({
    required String label,
    required DateTime value,
    required bool enabled,
    required ValueChanged<DateTime> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KpbTextStyles.label),
        const SizedBox(height: KpbSpacing.xs),
        Text(_date(value)),
        Text(
          'success_lab_outcome_device_timezone'.trParams(
            <String, String>{
              'zone': successLabDeviceTimezoneLabel(value.toLocal()),
            },
          ),
          style:
              KpbTextStyles.bodySm.copyWith(color: context.kpb.textSecondary),
        ),
        const SizedBox(height: KpbSpacing.sm),
        KpbButton(
          label: 'success_lab_outcome_choose_date'.tr,
          icon: Icons.calendar_today_outlined,
          variant: KpbButtonVariant.secondary,
          onPressed: enabled
              ? () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: value,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    onChanged(DateTime(
                      picked.year,
                      picked.month,
                      picked.day,
                      value.hour,
                      value.minute,
                    ));
                  }
                }
              : null,
        ),
      ],
    );
  }

  Widget _sectionTitle(String value) => Text(
        value,
        style: KpbTextStyles.title.copyWith(color: context.kpb.textPrimary),
      );

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${MaterialLocalizations.of(context).formatFullDate(local)} · '
        '${successLabDeviceTimezoneLabel(local)}';
  }

  Future<void> _pickAdmissionEvidence(
    SuccessLabOutcomeController controller,
  ) async {
    final file = await _pickFile();
    if (file != null) {
      controller.selectAdmissionEvidence(path: file.$1, name: file.$2);
    }
  }

  Future<void> _pickFundingEvidence(
    SuccessLabOutcomeController controller,
  ) async {
    final file = await _pickFile();
    if (file != null) {
      controller.selectFundingEvidence(path: file.$1, name: file.$2);
    }
  }

  Future<void> _addAdmissionComplement(
    SuccessLabOutcomeController controller,
    SuccessLabAdmissionDecisionRecord record,
  ) async {
    final file = await _pickFile();
    if (file == null) return;
    await controller.attachEvidence(
      outcomeType: 'admission',
      outcomeId: record.id,
      lockVersion: record.lockVersion,
      kind: SuccessLabOutcomeEvidenceKind.other,
      filePath: file.$1,
      verificationStatus: record.verificationStatus,
    );
  }

  Future<void> _addFundingComplement(
    SuccessLabOutcomeController controller,
    SuccessLabFundingDecisionRecord record,
  ) async {
    final file = await _pickFile();
    if (file == null) return;
    await controller.attachEvidence(
      outcomeType: 'funding',
      outcomeId: record.id,
      lockVersion: record.lockVersion,
      kind: SuccessLabOutcomeEvidenceKind.other,
      filePath: file.$1,
      verificationStatus: record.verificationStatus,
    );
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

  String _admissionLabel(SuccessLabAdmissionDecision value) {
    return switch (value) {
      SuccessLabAdmissionDecision.admitted =>
        'success_lab_admission_admitted'.tr,
      SuccessLabAdmissionDecision.rejected =>
        'success_lab_admission_rejected'.tr,
      SuccessLabAdmissionDecision.waitlisted =>
        'success_lab_admission_waitlisted'.tr,
      SuccessLabAdmissionDecision.deferred =>
        'success_lab_admission_deferred'.tr,
      SuccessLabAdmissionDecision.withdrawn =>
        'success_lab_admission_withdrawn'.tr,
      SuccessLabAdmissionDecision.unknown => 'success_lab_outcome_unknown'.tr,
    };
  }

  String _fundingLabel(SuccessLabFundingDecision value) {
    return switch (value) {
      SuccessLabFundingDecision.full => 'success_lab_funding_full'.tr,
      SuccessLabFundingDecision.partial => 'success_lab_funding_partial'.tr,
      SuccessLabFundingDecision.none => 'success_lab_funding_none'.tr,
      SuccessLabFundingDecision.pending => 'success_lab_funding_pending'.tr,
      SuccessLabFundingDecision.notApplicable =>
        'success_lab_funding_not_applicable'.tr,
      SuccessLabFundingDecision.unknown => 'success_lab_outcome_unknown'.tr,
    };
  }

  String _busyLabel(SuccessLabOutcomePhase phase) {
    return switch (phase) {
      SuccessLabOutcomePhase.grantingConsent =>
        'success_lab_outcome_granting_consent'.tr,
      SuccessLabOutcomePhase.uploading => 'success_lab_outcome_uploading'.tr,
      SuccessLabOutcomePhase.attachingEvidence =>
        'success_lab_outcome_attaching'.tr,
      SuccessLabOutcomePhase.submittingAdmission =>
        'success_lab_outcome_saving_admission'.tr,
      _ => 'success_lab_outcome_saving_funding'.tr,
    };
  }

  String _failureMessage(SuccessLabFailure? failure) {
    return switch (failure?.code) {
      'GUARDIAN_CONSENT_REQUIRED' => 'success_lab_outcome_guardian_required'.tr,
      'OUTCOME_EVIDENCE_REQUIRED' => 'success_lab_outcome_evidence_required'.tr,
      'EVIDENCE_SCAN_PENDING' => 'success_lab_outcome_scan_pending'.tr,
      'EVIDENCE_REJECTED' => 'success_lab_outcome_evidence_rejected'.tr,
      'OUTCOME_ALREADY_SUPERSEDED' => 'success_lab_outcome_superseded'.tr,
      'VERSION_CONFLICT' => 'success_lab_outcome_changed'.tr,
      'INVALID_FUNDING_AMOUNT' => 'success_lab_outcome_invalid_amount'.tr,
      'ARTIFACT_TOO_LARGE' => 'success_lab_outcome_file_too_large'.tr,
      'ARTIFACT_KIND_NOT_ALLOWED' => 'success_lab_outcome_file_not_allowed'.tr,
      _ => 'success_lab_outcome_error_body'.tr,
    };
  }
}
