import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/skeleton_loader.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/services/document_upload_service.dart';
import 'case_timeline_stepper.dart';

// Fallback group link used when the case has no assigned advisor yet.
const _kKpbWhatsappGroup = 'https://chat.whatsapp.com/KPBEducation';

Future<void> _openWhatsapp({String? phone, String? prefill}) async {
  final Uri uri;
  if (phone != null && phone.isNotEmpty) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final normalized = cleaned.startsWith('+') ? cleaned.substring(1) : cleaned;
    final query = prefill != null && prefill.isNotEmpty
        ? '?text=${Uri.encodeComponent(prefill)}'
        : '';
    uri = Uri.parse('https://wa.me/$normalized$query');
  } else {
    uri = Uri.parse(_kKpbWhatsappGroup);
  }
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    Get.snackbar(
      'WhatsApp',
      "Impossible d'ouvrir WhatsApp. Vérifie que l'app est installée.",
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 3),
    );
  }
}

Future<void> _callPhone(String phone) async {
  final uri = Uri(scheme: 'tel', path: phone);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
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
  void dispose() {
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
                title: const Text('Prendre une photo'),
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
                title: const Text('Choisir de la galerie'),
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
                title: const Text('Choisir un fichier (PDF)'),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final file = await DocumentUploadService.pickPdf();
                    if (file != null) {
                      _ctrl.uploadDocument(caseId, doc.id, file.path);
                    }
                  } catch (e) {
                    Get.snackbar(
                      'Erreur',
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

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (_) {
        // The case can disappear from the list mid-session (e.g. its local id
        // is swapped for the server id after a remote create), so look it up
        // null-safely instead of crashing with a StateError.
        final matches = _ctrl.cases.where((e) => e.id == widget.caseId);
        if (matches.isEmpty) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            appBar: AppBar(backgroundColor: context.kpb.pageBg, elevation: 0),
            body: Center(
              child: Text(
                'case_not_found'.tr,
                style: KpbTextStyles.bodySm,
              ),
            ),
          );
        }
        final c = matches.first;
        final statusInfo = _statusInfo(c.status);

        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          body: NestedScrollView(
            controller: _scrollController,
            headerSliverBuilder: (ctx, _) => [
              SliverAppBar(
                expandedHeight: 140,
                pinned: true,
                leading: GestureDetector(
                  onTap: () => Get.back(),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.arrow_back_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: KpbColors.heroGradient,
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            KpbBadge(
                              label: statusInfo.label,
                              color: statusInfo.color,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              c.referenceCode,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _ctrl.resolve(c.title),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  collapseMode: CollapseMode.pin,
                ),
              ),
            ],
            body: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                // ── Offline Banner ───────────────────────────────────────────
                if (!ConnectivityService.instance.isOnline)
                  Container(
                    width: double.infinity,
                    color: KpbColors.warning.withValues(alpha: 0.1),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: KpbColors.warning, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Mode hors ligne. Affichage des données en cache.',
                          style: TextStyle(color: KpbColors.warning, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                
                Padding(
                  padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, KpbSpacing.md, KpbSpacing.pagePad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_ctrl.isSyncing && _ctrl.cases.isEmpty) ...[
                        SkeletonLoader.card(height: 120),
                        const SizedBox(height: 16),
                        SkeletonLoader.card(height: 200),
                        const SizedBox(height: 16),
                        SkeletonLoader.card(height: 150),
                      ] else ...[
                        // ── Prochaine étape ──────────────────────────────────────────
                KpbCard(
                  color: KpbColors.blue.withValues(alpha: 0.06),
                  border: Border.all(
                      color: KpbColors.blue.withValues(alpha: 0.15)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: KpbColors.blue.withValues(alpha: 0.12),
                          borderRadius: KpbRadius.mdBr,
                        ),
                        child: const Icon(Icons.arrow_right_alt_rounded,
                            color: KpbColors.blue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Prochaine étape',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: KpbColors.blue,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _ctrl.resolve(c.nextStepTitle),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.kpb.textPrimary,
                              ),
                            ),
                            if (c.nextStepDescription.fr.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                _ctrl.resolve(c.nextStepDescription),
                                style: KpbTextStyles.bodySm,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: KpbSpacing.md),
                
                // ── Stepper visuel ───────────────────────────────────────────
                CaseTimelineStepper(currentStatus: c.status),
                const SizedBox(height: KpbSpacing.md),

                // ── Conseiller ───────────────────────────────────────────────
                if (c.assignedAdvisorName != null)
                  KpbCard(
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              KpbColors.sky.withValues(alpha: 0.15),
                          child: Text(
                            (c.assignedAdvisorName ?? 'K')[0].toUpperCase(),
                            style: const TextStyle(
                              color: KpbColors.sky,
                              fontWeight: FontWeight.w700,
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
                                c.assignedAdvisorName ?? 'KPB Team',
                                style: KpbTextStyles.titleMd,
                              ),
                              Text(
                                'Conseiller KPB Education',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.kpb.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (c.advisorWhatsapp != null)
                          _AdvisorAction(
                            icon: Icons.chat_rounded,
                            color: KpbColors.success,
                            onTap: () => _openWhatsapp(
                              phone: c.advisorWhatsapp,
                              prefill:
                                  'Bonjour, je reviens vers toi au sujet du dossier ${c.referenceCode}.',
                            ),
                          ),
                        if (c.advisorPhone != null) ...[
                          const SizedBox(width: 8),
                          _AdvisorAction(
                            icon: Icons.call_rounded,
                            color: KpbColors.blue,
                            onTap: () => _callPhone(c.advisorPhone!),
                          ),
                        ],
                      ],
                    ),
                  ),
                if (c.assignedAdvisorName != null)
                  const SizedBox(height: KpbSpacing.sm),

                // ── WhatsApp CTA ─────────────────────────────────────────────
                // Students trust WhatsApp more than the in-app inbox; make it
                // the primary channel. Falls back to the KPB group link if no
                // advisor is assigned yet.
                _WhatsappContinueButton(
                  onTap: () => _openWhatsapp(
                    phone: c.advisorWhatsapp,
                    prefill:
                        'Bonjour KPB, je souhaite continuer sur le dossier ${c.referenceCode}.',
                  ),
                  hasAdvisor: c.advisorWhatsapp != null,
                ),
                const SizedBox(height: KpbSpacing.md),

                // ── Documents ────────────────────────────────────────────────
                if (c.documentRequests.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Documents',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: KpbSpacing.sm),
                  KpbCard(
                    child: Column(
                      children: c.documentRequests.asMap().entries.map((e) {
                        final i = e.key;
                        final doc = e.value;
                        return Column(
                          children: [
                            if (i > 0) const KpbDivider(),
                            Padding(
                              padding: EdgeInsets.only(
                                  top: i > 0 ? KpbSpacing.sm : 0,
                                  bottom: i < c.documentRequests.length - 1
                                      ? KpbSpacing.sm
                                      : 0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: doc.isProvided
                                          ? KpbColors.success
                                              .withValues(alpha: 0.1)
                                          : KpbColors.warning
                                              .withValues(alpha: 0.1),
                                      borderRadius: KpbRadius.smBr,
                                    ),
                                    child: Icon(
                                      doc.isProvided
                                          ? Icons.check_circle_rounded
                                          : Icons.upload_file_rounded,
                                      size: 18,
                                      color: doc.isProvided
                                          ? KpbColors.success
                                          : KpbColors.warning,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      _ctrl.resolve(doc.title),
                                      style: KpbTextStyles.body,
                                    ),
                                  ),
                                  if (!doc.isProvided)
                                    GestureDetector(
                                      onTap: () => _promptUpload(c.id, doc),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: KpbColors.blue
                                              .withValues(alpha: 0.1),
                                          borderRadius: KpbRadius.pillBr,
                                        ),
                                        child: const Text(
                                          'Envoyer',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: KpbColors.blue,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    const KpbBadge(
                                        label: '✓ Reçu',
                                        color: KpbColors.success),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.md),
                ],

                // ── Timeline ────────────────────────────────────────────────
                if (c.timeline.isNotEmpty) ...[
                  const SectionHeader(title: 'Historique', padding: EdgeInsets.zero),
                  const SizedBox(height: KpbSpacing.sm),
                  KpbCard(
                    child: Column(
                      children: c.timeline.asMap().entries.map((e) {
                        final i = e.key;
                        final event = e.value;
                        final isLast = i == c.timeline.length - 1;
                        return _TimelineItem(
                          event: event,
                          isLast: isLast,
                          ctrl: _ctrl,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.md),
                ],

                // ── Messages ─────────────────────────────────────────────────
                SectionHeader(
                  title:
                      'Messages${c.messages.isNotEmpty ? ' (${c.messages.length})' : ''}',
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: KpbSpacing.sm),
                if (c.messages.isEmpty)
                  const KpbCard(
                    child: KpbEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: 'no_messages',
                      subtitle: 'send_message_hint',
                    ),
                  )
                else
                  Column(
                    children: c.messages.map((msg) {
                      final isStudent = msg.senderRole == 'student';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          mainAxisAlignment: isStudent
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (!isStudent) ...[
                              CircleAvatar(
                                radius: 14,
                                backgroundColor:
                                    KpbColors.sky.withValues(alpha: 0.15),
                                child: Text(
                                  msg.senderName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: KpbColors.sky,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isStudent
                                      ? KpbColors.blue
                                      : context.kpb.cardBg,
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: isStudent
                                        ? const Radius.circular(16)
                                        : const Radius.circular(4),
                                    bottomRight: isStudent
                                        ? const Radius.circular(4)
                                        : const Radius.circular(16),
                                  ),
                                  boxShadow: KpbShadow.card,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _ctrl.resolve(msg.body),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isStudent
                                            ? Colors.white
                                            : context.kpb.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('HH:mm', _ctrl.localeCode)
                                          .format(msg.createdAt),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isStudent
                                            ? Colors.white54
                                            : context.kpb.textMuted,
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
                    }).toList(),
                  ),
                const SizedBox(height: KpbSpacing.md),

                // ── Input message ────────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: context.kpb.cardBg,
                    borderRadius: KpbRadius.xlBr,
                    boxShadow: KpbShadow.float,
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
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
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
                            color: KpbColors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
                ],
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

  ({String label, Color color}) _statusInfo(CaseStatus status) {
    switch (status) {
      case CaseStatus.submitted:
        return (label: 'status_submitted'.tr, color: KpbColors.sky);
      case CaseStatus.underReview:
        return (label: 'status_under_review'.tr, color: KpbColors.gold);
      case CaseStatus.documentsNeeded:
        return (label: 'status_documents_needed'.tr, color: KpbColors.warning);
      case CaseStatus.counselorAssigned:
        return (label: 'status_counselor_assigned'.tr, color: KpbColors.blue);
      case CaseStatus.awaitingStudent:
        return (label: 'status_awaiting_student'.tr, color: KpbColors.error);
      case CaseStatus.scheduled:
        return (label: 'status_scheduled'.tr, color: KpbColors.blue);
      case CaseStatus.inProgress:
        return (label: 'status_in_progress'.tr, color: KpbColors.blue);
      case CaseStatus.applicationSubmitted:
        return (label: 'status_application_submitted'.tr, color: KpbColors.blueMid);
      case CaseStatus.waitingDecision:
        return (label: 'status_waiting_decision'.tr, color: KpbColors.gold);
      case CaseStatus.awaitingPayment:
        return (label: 'status_awaiting_payment'.tr, color: KpbColors.warning);
      case CaseStatus.completed:
        return (label: 'status_completed'.tr, color: KpbColors.success);
      case CaseStatus.rejected:
        return (label: 'status_rejected'.tr, color: KpbColors.error);
      case CaseStatus.cancelled:
        return (label: 'status_cancelled'.tr, color: context.kpb.gray500);
      default:
        return (label: 'status_draft'.tr, color: context.kpb.gray400);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline item
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
    final dotColor = _dotColor(context, event.status);

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
                      color: dotColor.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: context.kpb.gray100,
                ),
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
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.kpb.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(date, style: KpbTextStyles.caption),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _dotColor(BuildContext context, CaseStatus status) {
    switch (status) {
      case CaseStatus.submitted:
        return KpbColors.sky;
      case CaseStatus.underReview:
      case CaseStatus.waitingDecision:
        return KpbColors.gold;
      case CaseStatus.documentsNeeded:
      case CaseStatus.awaitingPayment:
        return KpbColors.warning;
      case CaseStatus.counselorAssigned:
      case CaseStatus.scheduled:
      case CaseStatus.inProgress:
        return KpbColors.blue;
      case CaseStatus.applicationSubmitted:
        return KpbColors.blueMid;
      case CaseStatus.awaitingStudent:
      case CaseStatus.rejected:
        return KpbColors.error;
      case CaseStatus.completed:
        return KpbColors.success;
      default:
        return context.kpb.gray300;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Advisor action button
// ─────────────────────────────────────────────────────────────────────────────
class _WhatsappContinueButton extends StatelessWidget {
  const _WhatsappContinueButton({
    required this.onTap,
    required this.hasAdvisor,
  });

  final VoidCallback onTap;
  final bool hasAdvisor;

  @override
  Widget build(BuildContext context) {
    final locale = Get.locale?.languageCode ?? 'fr';
    final label = locale == 'en' ? 'Continue on WhatsApp' : 'Continuer sur WhatsApp';
    final subtitle = hasAdvisor
        ? (locale == 'en'
            ? 'Chat directly with your KPB advisor.'
            : 'Discute directement avec ton conseiller KPB.')
        : (locale == 'en'
            ? 'Join the KPB group while we assign your advisor.'
            : 'Rejoins le groupe KPB en attendant ton conseiller.');

    return Material(
      color: KpbColors.success.withValues(alpha: 0.08),
      borderRadius: KpbRadius.lgBr,
      child: InkWell(
        onTap: onTap,
        borderRadius: KpbRadius.lgBr,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: KpbRadius.lgBr,
            border: Border.all(
              color: KpbColors.success.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: KpbColors.success,
                  borderRadius: KpbRadius.mdBr,
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: KpbColors.success,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: KpbTextStyles.caption,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.open_in_new_rounded,
                color: KpbColors.success,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdvisorAction extends StatelessWidget {
  const _AdvisorAction({
    required this.icon,
    required this.color,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: KpbRadius.mdBr,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: KpbRadius.mdBr,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
