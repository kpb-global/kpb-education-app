import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/navigation/app_boot_screen.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/skeleton.dart';
import 'case_composer_sheet.dart';
import 'case_detail_screen.dart';
import 'case_timeline_definition.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "Demandes" / case list).
// Local to this file — same per-file pattern as the other restyled Student
// surfaces (#110–116). Visual only; all case logic is preserved.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);
  static const page = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFEFF6FF);
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFDCFCE7);
  static const amber = Color(0xFFB45309);
  static const amberBg = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEE2E2);
  // rgba(15,23,42,0.04) — soft card shadow from the handoff.
  static const cardShadow = Color(0x0A0F172A);
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
];

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

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  CaseType? _selectedType;

  void _openComposer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.consultation,
        title: 'new_case'.tr,
        contextLabel: 'KPB Education',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        // Guest mode: dossiers require a signed-in profile. Show an explicit
        // sign-in prompt rather than a blank-empty-state that the user can't
        // act on (Submit would silently fail).
        if (controller.isGuestMode || controller.profile == null) {
          return const _GuestCasesPrompt();
        }

        if (controller.isSyncing && controller.cases.isEmpty) {
          return const CasesScreenSkeleton();
        }

        if (controller.syncError != null && controller.cases.isEmpty) {
          return KpbErrorState(onRetry: controller.pullToRefresh);
        }

        final items = controller.casesByType(_selectedType);

        final Widget body = KpbRefresh(
          onRefresh: controller.pullToRefresh,
          child: CustomScrollView(
            slivers: [
              // ── Header ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'nav_cases'.tr,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: _Palette.navy,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'cases_count'
                                  .trParams({'count': '${items.length}'}),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: _Palette.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _Palette.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('new_case'.tr),
                        onPressed: () => _openComposer(context),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filtres ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _FilterChip(
                        label: 'cases_filter_all'.tr,
                        selected: _selectedType == null,
                        onTap: () => setState(() => _selectedType = null),
                      ),
                      const SizedBox(width: 8),
                      ...CaseType.values.map((type) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _FilterChip(
                            label: _typeLabel(type),
                            selected: _selectedType == type,
                            onTap: () => setState(() => _selectedType = type),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 14)),

              // ── Liste ─────────────────────────────────────────────────
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: KpbEmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'no_cases'.tr,
                    subtitle: 'case_empty_hint'.tr,
                    action: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: _Palette.blue),
                      onPressed: () => _openComposer(context),
                      child: Text('create_case'.tr),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _CaseCard(
                        item: items[index],
                        controller: controller,
                      );
                    },
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        );

        // Guard against being laid out with unbounded width (e.g. while
        // offstage beneath the Overlay theater during boot), which makes the
        // header Row's button measurement assert. Capping maxWidth is a no-op
        // during normal onstage layout since the parent is already narrower.
        final mqWidth = MediaQuery.maybeOf(context)?.size.width ?? 0;
        final safeWidth = (mqWidth.isFinite && mqWidth > 0) ? mqWidth : 400.0;
        return ColoredBox(
          color: _Palette.page,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: safeWidth),
            child: body,
          ),
        );
      },
    );
  }

  String _typeLabel(CaseType type) {
    switch (type) {
      case CaseType.consultation:
        return 'case_type_filter_consultation'.tr;
      case CaseType.applicationSupport:
        return 'case_type_filter_application'.tr;
      case CaseType.scholarshipSupport:
        return 'case_type_scholarship'.tr;
      case CaseType.housingSupport:
        return 'case_type_housing'.tr;
      case CaseType.mentorship:
        return 'case_type_filter_mentorship'.tr;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Case card
// ─────────────────────────────────────────────────────────────────────────────
class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final pill = _statusPill(item.status);
    final date =
        DateFormat('dd MMM yyyy', controller.localeCode).format(item.updatedAt);
    final unread = controller.unreadMessagesForCase(item.id);
    final progress = caseTimelineProgress(item.status);
    final pct = (progress * 100).round();
    final title = controller.resolve(item.title);
    final flag =
        _dossierFlag('$title ${controller.resolve(item.contextLabel)}');
    final action = _contextualAction(item.status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Get.to(() => CaseDetailScreen(caseId: item.id)),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _Palette.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _Palette.border),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Leading(flag: flag, type: item.type, color: pill.fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: _Palette.navy,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.resolve(item.nextStepTitle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _Palette.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusPill(label: pill.label, bg: pill.bg, fg: pill.fg),
                      if (unread > 0) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _Palette.red,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            unread == 1
                                ? 'cases_new_message_badge'.tr
                                : 'cases_new_messages_badge'
                                    .trParams({'count': '$unread'}),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Progress (real, status-driven) ──
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        backgroundColor: _Palette.line,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_Palette.blue),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$pct%',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: _Palette.slate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Meta row ──
              Row(
                children: [
                  const Icon(Icons.tag_rounded,
                      size: 13, color: _Palette.slate400),
                  const SizedBox(width: 3),
                  Text(
                    item.referenceCode,
                    style:
                        const TextStyle(fontSize: 11, color: _Palette.slate400),
                  ),
                  const SizedBox(width: 10),
                  const Icon(Icons.access_time_rounded,
                      size: 13, color: _Palette.slate400),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'updated_on'.trParams({'date': date}),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: _Palette.slate400),
                    ),
                  ),
                  if (item.messages.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    const Icon(Icons.chat_bubble_outline_rounded,
                        size: 13, color: _Palette.slate400),
                    const SizedBox(width: 4),
                    Text(
                      '${item.messages.length}',
                      style: const TextStyle(
                          fontSize: 11, color: _Palette.slate400),
                    ),
                  ],
                ],
              ),

              // ── Contextual action button (status-driven) ──
              if (action != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: pill.fg,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    onPressed: () =>
                        Get.to(() => CaseDetailScreen(caseId: item.id)),
                    child: Text(action),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _contextualAction(CaseStatus status) {
    switch (status) {
      case CaseStatus.documentsNeeded:
        return 'cases_action_send_documents'.tr;
      case CaseStatus.awaitingPayment:
        return 'cases_action_chat_advisor'.tr;
      case CaseStatus.awaitingStudent:
        return 'cases_action_reply_advisor'.tr;
      case CaseStatus.scheduled:
        return 'cases_action_view_appointment'.tr;
      default:
        return null;
    }
  }
}

class _Leading extends StatelessWidget {
  const _Leading({required this.flag, required this.type, required this.color});
  final String? flag;
  final CaseType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: flag != null ? _Palette.line : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: flag != null
          ? Text(flag!, style: const TextStyle(fontSize: 22))
          : Icon(_typeIcon(type), color: color, size: 22),
    );
  }

  IconData _typeIcon(CaseType type) {
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
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: fg,
        ),
      ),
    );
  }
}

({String label, Color bg, Color fg}) _statusPill(CaseStatus status) {
  switch (status) {
    case CaseStatus.submitted:
      return (
        label: 'case_status_short_submitted'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.underReview:
      return (
        label: 'case_timeline_status_under_review'.tr,
        bg: _Palette.amberBg,
        fg: _Palette.amber
      );
    case CaseStatus.documentsNeeded:
      return (
        label: 'case_section_documents'.tr,
        bg: _Palette.amberBg,
        fg: _Palette.amber
      );
    case CaseStatus.counselorAssigned:
      return (
        label: 'case_status_short_counselor'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.awaitingStudent:
      return (
        label: 'case_status_short_action_required'.tr,
        bg: _Palette.redBg,
        fg: _Palette.red
      );
    case CaseStatus.scheduled:
      return (
        label: 'case_status_short_scheduled'.tr,
        bg: _Palette.greenBg,
        fg: _Palette.green
      );
    case CaseStatus.inProgress:
      return (
        label: 'case_timeline_status_in_progress'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.applicationSubmitted:
      return (
        label: 'case_status_short_application_submitted'.tr,
        bg: _Palette.chipBg,
        fg: _Palette.blue
      );
    case CaseStatus.waitingDecision:
      return (
        label: 'case_stepper_decision_title'.tr,
        bg: _Palette.amberBg,
        fg: _Palette.amber
      );
    case CaseStatus.awaitingPayment:
      return (
        label: 'case_status_short_payment'.tr,
        bg: _Palette.redBg,
        fg: _Palette.red
      );
    case CaseStatus.completed:
      return (
        label: 'case_status_short_completed'.tr,
        bg: _Palette.greenBg,
        fg: _Palette.green
      );
    case CaseStatus.rejected:
      return (
        label: 'case_status_short_rejected'.tr,
        bg: _Palette.redBg,
        fg: _Palette.red
      );
    case CaseStatus.cancelled:
      return (
        label: 'case_status_short_cancelled'.tr,
        bg: _Palette.line,
        fg: _Palette.slate
      );
    case CaseStatus.draft:
      return (
        label: 'case_status_short_draft'.tr,
        bg: _Palette.line,
        fg: _Palette.slate
      );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: selected ? _Palette.blue : _Palette.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? _Palette.blue : _Palette.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : _Palette.slate,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Guest prompt — dossiers require a signed-in profile.
// ─────────────────────────────────────────────────────────────────────────────
class _GuestCasesPrompt extends StatelessWidget {
  const _GuestCasesPrompt();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _Palette.page,
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: _Palette.page,
            surfaceTintColor: _Palette.page,
            elevation: 0,
            title: Text(
              'nav_cases'.tr,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: _Palette.navy,
              ),
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _Palette.chipBg,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.folder_open_rounded,
                        size: 38, color: _Palette.blue),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'guest_cases_title'.tr,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: _Palette.navy,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'guest_cases_body'.tr,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: _Palette.slate, height: 1.45, fontSize: 13.5),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _Palette.blue,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.login_rounded),
                    label: Text('guest_case_gate_cta'.tr),
                    onPressed: () => Get.offAll(() => const AppBootScreen()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
