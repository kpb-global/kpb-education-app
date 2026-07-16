import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/services/document_upload_service.dart';
import '../services/service_packages_screen.dart';
import '../tools/interview_simulator_screen.dart';
import 'case_status_timeline.dart';
import 'post_decision_screen.dart';
import 'case_timeline_definition.dart';
import 'document_review_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "Dossier" / Application screen).
// Local to this file — same per-file pattern as the other restyled Student
// surfaces (#110–116). Visual only; all case logic is preserved.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const body = Color(0xFF334155);
  static const bodyBlue = Color(0xFF1E40AF);
  static const border = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);
  static const lineSoft = Color(0xFFF8FAFC);
  static const page = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFEFF6FF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFDCFCE7);
  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEE2E2);
  static const whatsapp = Color(0xFF25D366);
  // rgba(15,23,42,0.04) — soft card shadow from the handoff.
  static const cardShadow = Color(0x0A0F172A);
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
];

// Best-effort flag: the case model has no country field, so we only show a flag
// when a known country name actually appears in the case title/context — never
// a fabricated one. Falls back to a neutral folder glyph otherwise.
const _flagMap = <String, String>{
  'japon': '🇯🇵',
  'japan': '🇯🇵',
  'france': '🇫🇷',
  'allemagne': '🇩🇪',
  'germany': '🇩🇪',
  'états-unis': '🇺🇸',
  'etats-unis': '🇺🇸',
  'united states': '🇺🇸',
  'usa': '🇺🇸',
  'canada': '🇨🇦',
  'royaume-uni': '🇬🇧',
  'united kingdom': '🇬🇧',
  'australie': '🇦🇺',
  'australia': '🇦🇺',
  'chine': '🇨🇳',
  'china': '🇨🇳',
  'corée du sud': '🇰🇷',
  'south korea': '🇰🇷',
  'turquie': '🇹🇷',
  'turkey': '🇹🇷',
  'italie': '🇮🇹',
  'italy': '🇮🇹',
  'espagne': '🇪🇸',
  'spain': '🇪🇸',
  'maroc': '🇲🇦',
  'morocco': '🇲🇦',
  'tunisie': '🇹🇳',
  'tunisia': '🇹🇳',
  'suisse': '🇨🇭',
  'switzerland': '🇨🇭',
  'belgique': '🇧🇪',
  'belgium': '🇧🇪',
  'sénégal': '🇸🇳',
  'senegal': '🇸🇳',
};

String? _dossierFlag(String text) {
  final lower = text.toLowerCase();
  for (final entry in _flagMap.entries) {
    if (lower.contains(entry.key)) return entry.value;
  }
  return null;
}

IconData _caseTypeIcon(CaseType type) {
  switch (type) {
    case CaseType.consultation:
      return Icons.support_agent_rounded;
    case CaseType.applicationSupport:
      return Icons.folder_copy_rounded;
    case CaseType.scholarshipSupport:
      return Icons.workspace_premium_rounded;
    case CaseType.housingSupport:
      return Icons.home_rounded;
    case CaseType.mentorship:
      return Icons.psychology_rounded;
  }
}

Future<void> _openWhatsapp({
  String? prefill,
  String? advisorName,
}) async {
  // Gate every case hand-off behind the verified-advisor card so an impostor
  // number is obvious before the user leaves the app. No `phone:` on purpose:
  // case hand-offs always target the official KPB line, never a counsellor's
  // personal number (anti-fraud, Item 12).
  await showVerifiedAdvisorThenWhatsApp(
    advisorName: advisorName,
    prefill: prefill,
    source: 'case_detail',
    contextType: 'case',
  );
}

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  AppController get _ctrl => Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.markCaseMessagesRead(widget.caseId);
      if (AppConfig.enableRemoteSync) {
        _ctrl.connectCaseDetailSocket(widget.caseId);
      }
    });
  }

  @override
  void dispose() {
    _ctrl.disconnectCaseDetailSocket();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _promptUpload(String caseId, DocumentRequest doc) async {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: Text('case_upload_take_photo'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await DocumentUploadService.captureFromCamera();
                  if (file != null) {
                    _ctrl.uploadDocument(caseId, doc.id, file.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: Text('case_upload_from_gallery'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  final file = await DocumentUploadService.pickFromGallery();
                  if (file != null) {
                    _ctrl.uploadDocument(caseId, doc.id, file.path);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded),
                title: Text('case_upload_pick_pdf'.tr),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final file = await DocumentUploadService.pickPdf();
                    if (file != null) {
                      _ctrl.uploadDocument(caseId, doc.id, file.path);
                    }
                  } catch (e) {
                    Get.snackbar(
                      'common_error'.tr,
                      e.toString(),
                      snackPosition: SnackPosition.BOTTOM,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Admission-milestone review (KPB-75): rate the counsellor 1–5 + optional
  /// testimonial → POST to the moderation queue. Marked handled either way so
  /// it is asked at most once.
  Future<void> _promptReview(StudentCase c) async {
    final counsellorId = c.counsellorId;
    if (counsellorId == null) return;
    final textCtrl = TextEditingController();
    var rating = 5;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: const EdgeInsets.all(KpbSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('review_prompt_title'.tr, style: KpbTextStyles.title),
                const SizedBox(height: 4),
                Text('review_prompt_sheet_body'.tr,
                    style: KpbTextStyles.bodySm),
                const SizedBox(height: KpbSpacing.md),
                Row(
                  children: List.generate(
                    5,
                    (i) => IconButton(
                      tooltip: 'a11y_rate'.tr,
                      icon: Icon(
                        i < rating
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: KpbColors.gold,
                        size: 32,
                      ),
                      onPressed: () => setSheet(() => rating = i + 1),
                    ),
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
                TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: 'review_prompt_hint'.tr),
                ),
                const SizedBox(height: KpbSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text('review_prompt_submit'.tr),
                  ),
                ),
                const SizedBox(height: KpbSpacing.sm),
              ],
            ),
          ),
        ),
      ),
    );

    if (submitted == true) {
      try {
        await _ctrl.apiClient.submitCounsellorReview(
          counsellorId: counsellorId,
          rating: rating,
          body: textCtrl.text.trim(),
          reviewerName: _ctrl.profile?.fullName ?? 'KPB',
          caseId: c.id,
        );
        Get.snackbar('review_prompt_title'.tr, 'review_prompt_thanks'.tr,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12));
      } catch (_) {
        Get.snackbar('review_prompt_title'.tr, 'review_prompt_error'.tr,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12));
      }
    }
    textCtrl.dispose();
    // Asked once — don't re-prompt whether or not they submitted.
    if (mounted) setState(() => _ctrl.markCaseReviewed(c.id));
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (_) {
        // The case can disappear from the list mid-session (e.g. its local id
        // is swapped for the server id after a remote create), so look it up
        // null-safely instead of crashing with a StateError.
        final c = _ctrl.cases.firstWhereOrNull((e) => e.id == widget.caseId);
        if (c == null) {
          return Scaffold(
            backgroundColor: _Palette.page,
            appBar: AppBar(
              backgroundColor: _Palette.page,
              surfaceTintColor: _Palette.page,
              elevation: 0,
              title: Text('case_not_found_title'.tr),
              leading: IconButton(
                tooltip: 'a11y_back'.tr,
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Get.back(),
              ),
            ),
            body: KpbEmptyState(
              icon: Icons.folder_off_outlined,
              title: 'case_not_found_body_title'.tr,
              subtitle: 'case_not_found_subtitle'.tr,
              actionLabel: 'case_not_found_action'.tr,
              onAction: () {
                _ctrl.goToTab(StudentShellTab.cases);
                if (Get.key.currentState?.canPop() ?? false) {
                  Get.back();
                }
              },
            ),
          );
        }

        final steps = buildCaseTimelineSteps(
          currentStatus: c.status,
          events: c.timeline,
          assignedAdvisorName: c.assignedAdvisorName,
        );
        final progress = caseTimelineProgress(c.status);

        final docs = c.documentRequests;
        final docsDone = docs.where((d) => d.isProvided).length;

        return Scaffold(
          backgroundColor: _Palette.page,
          body: SafeArea(
            bottom: false,
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
              children: [
                // ── Header : back · flag · institution · program · ring ──────
                _DossierHeader(
                  ctrl: _ctrl,
                  studentCase: c,
                  progress: progress,
                ),
                const SizedBox(height: 14),

                // ── Decision received → honest "plan B" surface ──────────────
                // Real entry point for the post-decision screen (Notifications
                // isn't built yet): only when the case is genuinely rejected.
                if (c.status == CaseStatus.rejected) ...[
                  _NavCard(
                    icon: Icons.flag_rounded,
                    iconColor: _Palette.red,
                    iconBg: _Palette.redBg,
                    title: 'post_decision_entry_title'.tr,
                    subtitle: 'post_decision_entry_subtitle'.tr,
                    onTap: () => Get.to(() => PostDecisionScreen(caseId: c.id)),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Admission-milestone review prompt (KPB-75) ───────────────
                if (c.status == CaseStatus.completed &&
                    c.counsellorId != null &&
                    !_ctrl.hasReviewedCase(c.id)) ...[
                  _ReviewPromptCard(
                    onLater: () => setState(() => _ctrl.markCaseReviewed(c.id)),
                    onReview: () => _promptReview(c),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Offline banner ───────────────────────────────────────────
                if (!ConnectivityService.instance.isOnline) ...[
                  const _OfflineBanner(),
                  const SizedBox(height: 14),
                ],

                // ── Next step (real: c.nextStep*) ────────────────────────────
                _NextStepCard(
                  label: 'next_step'.tr,
                  title: _ctrl.resolve(c.nextStepTitle),
                  description: _ctrl.resolve(c.nextStepDescription),
                ),
                const SizedBox(height: 14),

                // ── Step checklist (status-driven, real timeline) ────────────
                _SectionLabel('case_steps_heading'.tr),
                const SizedBox(height: 8),
                CaseStatusTimeline(steps: steps),
                const SizedBox(height: 14),

                // ── Photo / PDF tip (honest: app compresses, no OCR/scan) ────
                _InfoTip(
                  icon: Icons.photo_camera_rounded,
                  text: 'case_document_photo_tip'.tr,
                ),
                const SizedBox(height: 14),

                // ── Interview simulator (existing tool) ──────────────────────
                _NavCard(
                  icon: Icons.mic_rounded,
                  iconColor: _Palette.amber,
                  iconBg: _Palette.amberBg,
                  title: 'case_interview_sim_title'.tr,
                  subtitle: 'case_interview_sim_subtitle'.tr,
                  onTap: () => Get.to(() => const InterviewSimulatorScreen()),
                ),
                const SizedBox(height: 14),

                // ── Documents ────────────────────────────────────────────────
                if (docs.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _SectionLabel('case_section_documents'.tr),
                      ),
                      Text(
                        'home_case_documents_ratio'.trParams(
                            {'done': '$docsDone', 'total': '${docs.length}'}),
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: _Palette.slate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _DocumentsCard(
                    docs: docs,
                    ctrl: _ctrl,
                    onUpload: (doc) => _promptUpload(c.id, doc),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── AI document review (existing tool) ───────────────────────
                _NavCard(
                  icon: Icons.auto_awesome_rounded,
                  iconColor: _Palette.blue,
                  iconBg: _Palette.chipBg,
                  title: 'case_ai_review_cta'.tr,
                  subtitle: 'case_ai_review_subtitle'.tr,
                  onTap: () => Get.to(() => const DocumentReviewScreen()),
                ),
                const SizedBox(height: 14),

                // ── Advisor ──────────────────────────────────────────────────
                if (c.assignedAdvisorName != null) ...[
                  _AdvisorCard(
                    name: c.assignedAdvisorName!,
                    onWhatsapp: () => _openWhatsapp(
                      advisorName: c.assignedAdvisorName,
                      prefill: c.isReferenceProvisional
                          ? 'case_whatsapp_advisor_prefill_provisional'
                              .trParams({'title': _ctrl.resolve(c.title)})
                          : 'case_whatsapp_advisor_prefill'
                              .trParams({'reference': c.referenceCode}),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── WhatsApp CTA (official KPB line; verified-advisor gate) ───
                _GreenWhatsAppCta(
                  onTap: () => _openWhatsapp(
                    advisorName: c.assignedAdvisorName,
                    prefill: c.isReferenceProvisional
                        ? 'case_whatsapp_continue_prefill_provisional'
                            .trParams({'title': _ctrl.resolve(c.title)})
                        : 'case_whatsapp_continue_prefill'
                            .trParams({'reference': c.referenceCode}),
                  ),
                ),
                const SizedBox(height: 10),
                const KpbAntiFraudNotice(source: 'case_detail'),
                const SizedBox(height: 14),

                // ── Prepare application package ──────────────────────────────
                _NavCard(
                  icon: Icons.assignment_turned_in_rounded,
                  iconColor: _Palette.blue,
                  iconBg: _Palette.chipBg,
                  title: 'case_prepare_package_title'.tr,
                  subtitle: 'case_prepare_package_subtitle'.tr,
                  onTap: () => Get.to(
                    () => ServicePackagesScreen(
                      caseId: c.id,
                      caseReference: c.referenceCode,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Share with a parent (opt-in, per case) ───────────────────
                _ParentShareCard(
                  value: c.parentCanView,
                  onChanged: (v) => _ctrl.setCaseParentVisibility(c.id, v),
                ),
                const SizedBox(height: 14),

                // ── History ──────────────────────────────────────────────────
                if (c.timeline.isNotEmpty) ...[
                  _SectionLabel('case_section_history'.tr),
                  const SizedBox(height: 8),
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: c.timeline.asMap().entries.map((e) {
                        return _TimelineItem(
                          event: e.value,
                          isLast: e.key == c.timeline.length - 1,
                          ctrl: _ctrl,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Messages ─────────────────────────────────────────────────
                _SectionLabel(
                  '${'case_section_messages'.tr}${c.messages.isNotEmpty ? ' (${c.messages.length})' : ''}${_ctrl.unreadMessagesForCase(c.id) > 0 ? ' · ${_ctrl.unreadMessagesForCase(c.id)} ${'case_unread_suffix'.tr}' : ''}',
                ),
                const SizedBox(height: 8),
                if (c.messages.isEmpty)
                  Container(
                    decoration: _cardDecoration(),
                    padding: const EdgeInsets.all(16),
                    child: KpbEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'no_messages'.tr,
                      subtitle: 'send_message_hint'.tr,
                    ),
                  )
                else
                  Column(
                    children: c.messages
                        .map((msg) => _MessageBubble(msg: msg, ctrl: _ctrl))
                        .toList(),
                  ),
                const SizedBox(height: 8),

                // ── Typing indicator ─────────────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _ctrl.isCaseAdvisorTyping
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            key: const ValueKey('typing'),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: _Palette.card,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                                bottomLeft: Radius.circular(4),
                              ),
                              border: Border.all(color: _Palette.border),
                              boxShadow: _cardShadow,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                _TypingDot(delay: Duration.zero),
                                SizedBox(width: 4),
                                _TypingDot(delay: Duration(milliseconds: 200)),
                                SizedBox(width: 4),
                                _TypingDot(delay: Duration(milliseconds: 400)),
                              ],
                            ),
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('no-typing')),
                ),

                // ── Message input ────────────────────────────────────────────
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _Palette.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _Palette.border),
                    boxShadow: _cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'message_input_hint'.tr,
                            hintStyle:
                                const TextStyle(color: _Palette.slate400),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                          ),
                          onChanged: (value) {
                            _ctrl.sendCaseTyping(c.id, value.isNotEmpty);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        button: true,
                        label: 'a11y_send_message'.tr,
                        child: GestureDetector(
                          onTap: () {
                            final text = _messageController.text.trim();
                            if (text.isEmpty) return;
                            _ctrl.addCaseMessage(c.id, text);
                            _messageController.clear();
                          },
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: _Palette.blue,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.send_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

BoxDecoration _cardDecoration() => BoxDecoration(
      color: _Palette.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _Palette.border),
      boxShadow: _cardShadow,
    );

({String label, Color bg, Color fg}) _statusPill(CaseStatus status) {
  switch (status) {
    case CaseStatus.submitted:
      return (
        label: 'status_submitted'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.underReview:
      return (
        label: 'status_under_review'.tr,
        bg: _Palette.amberBg,
        fg: _Palette.amber
      );
    case CaseStatus.documentsNeeded:
      return (
        label: 'status_documents_needed'.tr,
        bg: _Palette.amberBg,
        fg: _Palette.amber
      );
    case CaseStatus.counselorAssigned:
      return (
        label: 'status_counselor_assigned'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.awaitingStudent:
      return (
        label: 'status_awaiting_student'.tr,
        bg: _Palette.redBg,
        fg: _Palette.red
      );
    case CaseStatus.scheduled:
      return (
        label: 'status_scheduled'.tr,
        bg: _Palette.greenBg,
        fg: _Palette.green
      );
    case CaseStatus.inProgress:
      return (
        label: 'status_in_progress'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.applicationSubmitted:
      return (
        label: 'status_application_submitted'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.waitingDecision:
      return (
        label: 'status_waiting_decision'.tr,
        bg: _Palette.amberBg,
        fg: _Palette.amber
      );
    case CaseStatus.awaitingPayment:
      return (
        label: 'status_awaiting_payment'.tr,
        bg: _Palette.redBg,
        fg: _Palette.red
      );
    case CaseStatus.completed:
      return (
        label: 'status_completed'.tr,
        bg: _Palette.greenBg,
        fg: _Palette.green
      );
    case CaseStatus.rejected:
      return (
        label: 'status_rejected'.tr,
        bg: _Palette.redBg,
        fg: _Palette.red
      );
    case CaseStatus.cancelled:
      return (
        label: 'status_cancelled'.tr,
        bg: _Palette.line,
        fg: _Palette.slate
      );
    case CaseStatus.draft:
      return (label: 'status_draft'.tr, bg: _Palette.line, fg: _Palette.slate);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header — back · flag · institution · program · progress ring
// ─────────────────────────────────────────────────────────────────────────────
class _DossierHeader extends StatelessWidget {
  const _DossierHeader({
    required this.ctrl,
    required this.studentCase,
    required this.progress,
  });

  final AppController ctrl;
  final StudentCase studentCase;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = studentCase;
    final title = ctrl.resolve(c.title);
    final contextLabel = ctrl.resolve(c.contextLabel);
    final flag = _dossierFlag('$title $contextLabel');
    final pill = _statusPill(c.status);
    final pct = (progress * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _Palette.card,
                  shape: BoxShape.circle,
                  border: Border.all(color: _Palette.border),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    size: 19, color: _Palette.navy),
              ),
            ),
            const SizedBox(width: 10),
            if (flag != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(flag, style: const TextStyle(fontSize: 24)),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _Palette.chipBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(_caseTypeIcon(c.type), size: 18, color: _Palette.blue),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: _Palette.navy,
                      height: 1.2,
                    ),
                  ),
                  if (contextLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contextLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(fontSize: 11, color: _Palette.slate),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _ProgressRing(value: progress, pct: pct),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: pill.bg,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                pill.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: pill.fg,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                c.referenceCode,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _Palette.slate400,
                ),
              ),
            ),
            if (c.isReferenceProvisional) ...[
              const SizedBox(width: 6),
              Text(
                'case_reference_provisional'.tr,
                style:
                    const TextStyle(fontSize: 10.5, color: _Palette.slate400),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value, required this.pct});
  final double value;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: CustomPaint(
        painter: _RingPainter(value),
        child: Center(
          child: Text(
            '$pct%',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: _Palette.navy,
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value);
  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 5.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final track = Paint()
      ..color = _Palette.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, 2 * math.pi, false, track);
    if (value > 0) {
      final prog = Paint()
        ..color = _Palette.blue
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, -math.pi / 2, 2 * math.pi * value.clamp(0.0, 1.0), false, prog);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Next step
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.label,
    required this.title,
    required this.description,
  });

  final String label;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.chipBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _Palette.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_right_alt_rounded,
                color: _Palette.blue, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _Palette.blue,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _Palette.navy,
                  ),
                ),
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: _Palette.body,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blue info tip
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTip extends StatelessWidget {
  const _InfoTip({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.chipBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.chipBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: _Palette.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: _Palette.bodyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
        color: _Palette.navy,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Navigation card (interview simulator · AI review · prepare package)
// ─────────────────────────────────────────────────────────────────────────────
class _NavCard extends StatelessWidget {
  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: _cardDecoration(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _Palette.navy,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: _Palette.slate),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advisor card
// ─────────────────────────────────────────────────────────────────────────────
class _AdvisorCard extends StatelessWidget {
  const _AdvisorCard({required this.name, required this.onWhatsapp});
  final String name;
  final VoidCallback onWhatsapp;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _Palette.chipBg,
              shape: BoxShape.circle,
            ),
            child: Text(
              (name.isNotEmpty ? name[0] : 'K').toUpperCase(),
              style: const TextStyle(
                color: _Palette.blue,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _Palette.navy,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'case_advisor_role'.tr,
                  style: const TextStyle(fontSize: 11.5, color: _Palette.slate),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'a11y_whatsapp_advisor'.tr,
            child: GestureDetector(
              onTap: onWhatsapp,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _Palette.whatsapp.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.chat_rounded,
                    color: _Palette.whatsapp, size: 19),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Documents card
// ─────────────────────────────────────────────────────────────────────────────
class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({
    required this.docs,
    required this.ctrl,
    required this.onUpload,
  });

  final List<DocumentRequest> docs;
  final AppController ctrl;
  final void Function(DocumentRequest) onUpload;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          for (var i = 0; i < docs.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                border: i == docs.length - 1
                    ? null
                    : const Border(
                        bottom: BorderSide(color: _Palette.lineSoft)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: docs[i].isProvided
                          ? _Palette.greenBg
                          : _Palette.amberBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      docs[i].isProvided
                          ? Icons.check_circle_rounded
                          : Icons.upload_file_rounded,
                      size: 18,
                      color:
                          docs[i].isProvided ? _Palette.green : _Palette.amber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      ctrl.resolve(docs[i].title),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: _Palette.navy,
                      ),
                    ),
                  ),
                  if (!docs[i].isProvided)
                    GestureDetector(
                      onTap: () => onUpload(docs[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _Palette.chipBg,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'case_document_send'.tr,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _Palette.blue,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: _Palette.greenBg,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        'case_document_received'.tr,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: _Palette.green,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Parent-share toggle
// ─────────────────────────────────────────────────────────────────────────────
class _ParentShareCard extends StatelessWidget {
  const _ParentShareCard({required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _Palette.amberBg,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.family_restroom_rounded,
                size: 20, color: _Palette.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'parent_share_case_title'.tr,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _Palette.navy,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'parent_share_case_subtitle'.tr,
                  style: const TextStyle(fontSize: 11, color: _Palette.slate),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Review prompt card (KPB-75)
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewPromptCard extends StatelessWidget {
  const _ReviewPromptCard({required this.onLater, required this.onReview});
  final VoidCallback onLater;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.star_rounded, color: KpbColors.gold, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'review_prompt_title'.tr,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _Palette.navy,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('review_prompt_body'.tr,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.45, color: _Palette.body)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onLater,
                  child: Text('review_prompt_later'.tr),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _Palette.blue),
                  onPressed: onReview,
                  child: Text('review_prompt_cta'.tr),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Offline banner
// ─────────────────────────────────────────────────────────────────────────────
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: _Palette.amberBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: _Palette.amber, size: 16),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'offline_cache_notice'.tr,
              style: const TextStyle(
                color: _Palette.amber,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg, required this.ctrl});
  final CaseMessage msg;
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final isStudent = msg.senderRole == 'student';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isStudent ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isStudent) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: _Palette.chipBg,
              child: Text(
                msg.senderName.isNotEmpty
                    ? msg.senderName[0].toUpperCase()
                    : 'K',
                style: const TextStyle(
                  color: _Palette.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isStudent ? _Palette.blue : _Palette.card,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isStudent ? 16 : 4),
                  bottomRight: Radius.circular(isStudent ? 4 : 16),
                ),
                border: isStudent ? null : Border.all(color: _Palette.border),
                boxShadow: _cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ctrl.resolve(msg.body),
                    style: TextStyle(
                      fontSize: 14,
                      color: isStudent ? Colors.white : _Palette.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('HH:mm', ctrl.localeCode).format(msg.createdAt),
                    style: TextStyle(
                      fontSize: 10,
                      color: isStudent ? Colors.white54 : _Palette.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isStudent) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History timeline item
// ─────────────────────────────────────────────────────────────────────────────
class _TimelineItem extends StatelessWidget {
  const _TimelineItem({
    required this.event,
    required this.isLast,
    required this.ctrl,
  });

  final CaseTimelineEvent event;
  final bool isLast;
  final AppController ctrl;

  @override
  Widget build(BuildContext context) {
    final date =
        DateFormat('dd MMM yyyy', ctrl.localeCode).format(event.createdAt);
    final dotColor = _dotColor(event.status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: dotColor.withValues(alpha: 0.3), blurRadius: 4),
                  ],
                ),
              ),
              if (!isLast)
                Container(width: 2, height: 40, color: _Palette.line),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctrl.resolve(event.title),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _Palette.navy,
                  ),
                ),
                const SizedBox(height: 2),
                Text(date,
                    style:
                        const TextStyle(fontSize: 11.5, color: _Palette.slate)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _dotColor(CaseStatus status) {
    switch (status) {
      case CaseStatus.submitted:
      case CaseStatus.counselorAssigned:
      case CaseStatus.scheduled:
      case CaseStatus.inProgress:
      case CaseStatus.applicationSubmitted:
        return _Palette.blue;
      case CaseStatus.underReview:
      case CaseStatus.waitingDecision:
      case CaseStatus.documentsNeeded:
      case CaseStatus.awaitingPayment:
        return _Palette.amber;
      case CaseStatus.awaitingStudent:
      case CaseStatus.rejected:
        return _Palette.red;
      case CaseStatus.completed:
        return _Palette.green;
      case CaseStatus.cancelled:
      case CaseStatus.draft:
        return _Palette.slate400;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WhatsApp CTA — "Contact a KPB counselor" (official KPB line only)
// ─────────────────────────────────────────────────────────────────────────────
class _GreenWhatsAppCta extends StatelessWidget {
  const _GreenWhatsAppCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'case_continue_whatsapp'.tr,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: _Palette.whatsapp,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _Palette.whatsapp.withValues(alpha: 0.3),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                'case_continue_whatsapp'.tr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated bouncing dot for the typing indicator.
class _TypingDot extends StatefulWidget {
  const _TypingDot({required this.delay});
  final Duration delay;

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _anim = Tween<double>(begin: 0, end: -6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    Future.delayed(widget.delay, () {
      if (mounted) _ctrl.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _anim.value),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(
            color: _Palette.slate400,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
