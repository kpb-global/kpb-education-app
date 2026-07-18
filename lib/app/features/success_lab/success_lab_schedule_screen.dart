import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/controllers/success_lab_schedule_controller.dart';
import '../../core/models/success_lab.dart';
import '../../core/repositories/success_lab_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/ui/kpb_components.dart';
import 'widgets/success_lab_accessibility.dart';

class SuccessLabScheduleScreen extends StatefulWidget {
  const SuccessLabScheduleScreen({
    super.key,
    required this.workspaceId,
    this.controller,
  });

  final String workspaceId;
  final SuccessLabScheduleController? controller;

  @override
  State<SuccessLabScheduleScreen> createState() =>
      _SuccessLabScheduleScreenState();
}

class _SuccessLabScheduleScreenState extends State<SuccessLabScheduleScreen> {
  SuccessLabScheduleController? _controller;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? _buildController();
    _ownsController = widget.controller == null && _controller != null;
    _controller?.addListener(_onChanged);
    if (_controller?.phase == SuccessLabSchedulePhase.initial) {
      unawaited(_controller!.load());
    }
  }

  SuccessLabScheduleController? _buildController() {
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
    return SuccessLabScheduleController(
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
    final phase = controller?.phase;
    final networkState = switch (phase) {
      SuccessLabSchedulePhase.offline => SuccessLabNetworkUiState.offline,
      SuccessLabSchedulePhase.initial ||
      SuccessLabSchedulePhase.loading ||
      SuccessLabSchedulePhase.booking =>
        SuccessLabNetworkUiState.busy,
      _ => SuccessLabNetworkUiState.stable,
    };
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(title: Text('success_lab_schedule_title'.tr)),
      body: SuccessLabAccessibleBody(
        networkState: networkState,
        busyLabel: phase == SuccessLabSchedulePhase.booking
            ? 'success_lab_schedule_booking'.tr
            : 'success_lab_schedule_waiting_body'.tr,
        ensureScrollable: controller == null ||
            switch (phase) {
              SuccessLabSchedulePhase.ready ||
              SuccessLabSchedulePhase.booked =>
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

  Widget _buildState(SuccessLabScheduleController controller) {
    switch (controller.phase) {
      case SuccessLabSchedulePhase.initial:
      case SuccessLabSchedulePhase.loading:
        return const Center(child: CircularProgressIndicator());
      case SuccessLabSchedulePhase.booking:
        return _BusySchedule(label: 'success_lab_schedule_booking'.tr);
      case SuccessLabSchedulePhase.ready:
        return _buildOffers(controller);
      case SuccessLabSchedulePhase.empty:
        return KpbEmptyState(
          icon: Icons.event_busy_outlined,
          title: 'success_lab_schedule_empty_title'.tr,
          subtitle: 'success_lab_schedule_empty_body'.tr,
          action: KpbButton(
            label: 'retry'.tr,
            onPressed: controller.load,
          ),
        );
      case SuccessLabSchedulePhase.waiting:
        return KpbEmptyState(
          icon: Icons.hourglass_top_rounded,
          title: 'success_lab_schedule_waiting_title'.tr,
          subtitle: 'success_lab_schedule_waiting_body'.tr,
          action: KpbButton(
            label: 'retry'.tr,
            onPressed: controller.load,
          ),
        );
      case SuccessLabSchedulePhase.booked:
        return _buildBooked(controller.bookingResult?.appointment);
      case SuccessLabSchedulePhase.noRequest:
        return KpbEmptyState(
          icon: Icons.assignment_outlined,
          title: 'success_lab_schedule_no_request_title'.tr,
          subtitle: 'success_lab_schedule_no_request_body'.tr,
        );
      case SuccessLabSchedulePhase.offline:
        return KpbEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'success_lab_offline_title'.tr,
          subtitle: 'success_lab_schedule_online_required'.tr,
          action: KpbButton(label: 'retry'.tr, onPressed: controller.load),
        );
      case SuccessLabSchedulePhase.unavailable:
        return KpbEmptyState(
          icon: Icons.event_busy_outlined,
          title: 'success_lab_study_unavailable_title'.tr,
          subtitle: 'success_lab_study_unavailable'.tr,
        );
      case SuccessLabSchedulePhase.error:
        return KpbErrorState(
          title: 'success_lab_schedule_error_title'.tr,
          subtitle: _errorMessage(controller.failure),
          onRetry: controller.load,
        );
    }
  }

  Widget _buildOffers(SuccessLabScheduleController controller) {
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
                'success_lab_schedule_choose_title'.tr,
                style: KpbTextStyles.title.copyWith(
                  color: context.kpb.textPrimary,
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                'success_lab_schedule_choose_body'.tr,
                style: KpbTextStyles.body.copyWith(
                  color: context.kpb.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
        RadioGroup<String>(
          groupValue: controller.selectedOfferId,
          onChanged: (value) {
            if (value != null) controller.selectOffer(value);
          },
          child: Column(
            children: controller.offers
                .map(
                  (offer) => Padding(
                    padding: const EdgeInsets.only(bottom: KpbSpacing.sm),
                    child: KpbCard(
                      padding: EdgeInsets.zero,
                      child: Material(
                        type: MaterialType.transparency,
                        child: RadioListTile<String>(
                          key: ValueKey<String>(
                            'success-lab-slot-${offer.slotOfferId}',
                          ),
                          value: offer.slotOfferId,
                          title: Text(_localizedRange(context, offer)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: KpbSpacing.xs),
                            child: Text(
                              'success_lab_schedule_offer_details'.trParams(
                                <String, String>{
                                  'name': offer.counsellorName,
                                  'zone': offer.timezone,
                                  'deviceZone': _deviceTimezoneLabel(
                                    offer.startsAt.toLocal(),
                                  ),
                                },
                              ),
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: KpbSpacing.sm,
                            vertical: KpbSpacing.xs,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
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
          key: const ValueKey<String>('success-lab-confirm-slot'),
          label: 'success_lab_schedule_confirm_action'.tr,
          icon: Icons.event_available_rounded,
          fullWidth: true,
          onPressed: controller.selectedOffer == null
              ? null
              : () => unawaited(_confirmBooking(controller)),
        ),
      ],
    );
  }

  Widget _buildBooked(SuccessLabStudyReviewAppointment? appointment) {
    final details = appointment == null
        ? 'success_lab_schedule_booked_recovered_body'.tr
        : 'success_lab_schedule_booked_body'.trParams(
            <String, String>{
              'date': _localizedAppointment(context, appointment),
              'zone': appointment.timezone,
              'deviceZone': _deviceTimezoneLabel(
                appointment.startsAt.toLocal(),
              ),
            },
          );
    return KpbEmptyState(
      icon: Icons.event_available_rounded,
      title: 'success_lab_schedule_booked_title'.tr,
      subtitle: details,
    );
  }

  Future<void> _confirmBooking(
    SuccessLabScheduleController controller,
  ) async {
    final offer = controller.selectedOffer;
    if (offer == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('success_lab_schedule_confirm_title'.tr),
        content: Text(
          'success_lab_schedule_confirm_body'.trParams(
            <String, String>{
              'date': _localizedRange(context, offer),
              'name': offer.counsellorName,
              'zone': offer.timezone,
              'deviceZone': _deviceTimezoneLabel(
                offer.startsAt.toLocal(),
              ),
            },
          ),
        ),
        actions: [
          KpbButton(
            label: 'cancel'.tr,
            variant: KpbButtonVariant.tertiary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          KpbButton(
            label: 'success_lab_schedule_confirm_action'.tr,
            icon: Icons.event_available_rounded,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await controller.bookSelectedOffer();
    }
  }

  String _localizedRange(
    BuildContext context,
    SuccessLabStudyReviewSlotOffer offer,
  ) {
    final localizations = MaterialLocalizations.of(context);
    final start = offer.startsAt.toLocal();
    final end = offer.endsAt.toLocal();
    final date = localizations.formatFullDate(start);
    final from = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start));
    final to = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end));
    return '$date · $from–$to';
  }

  String _localizedAppointment(
    BuildContext context,
    SuccessLabStudyReviewAppointment appointment,
  ) {
    final localizations = MaterialLocalizations.of(context);
    final start = appointment.startsAt.toLocal();
    final end = appointment.endsAt.toLocal();
    return '${localizations.formatFullDate(start)} · '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start))}–'
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end))}';
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

  String _errorMessage(SuccessLabFailure? failure) {
    return switch (failure?.code) {
      'SLOT_OFFER_EXPIRED' => 'success_lab_schedule_expired'.tr,
      'SLOT_TAKEN' => 'success_lab_schedule_taken'.tr,
      'VERSION_CONFLICT' => 'success_lab_schedule_changed'.tr,
      'NO_SLOT_OFFERED' => 'success_lab_schedule_no_offer'.tr,
      'REVIEW_REQUEST_NOT_TRIAGED' => 'success_lab_schedule_waiting_body'.tr,
      'IDEMPOTENCY_IN_PROGRESS' => 'success_lab_schedule_retry'.tr,
      _ => 'success_lab_schedule_error_body'.tr,
    };
  }
}

class _BusySchedule extends StatelessWidget {
  const _BusySchedule({required this.label});

  final String label;

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
            Semantics(liveRegion: true, child: Text(label)),
          ],
        ),
      ),
    );
  }
}
