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

class CasesScreen extends StatefulWidget {
  const CasesScreen({super.key});

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  CaseType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        // Guest mode: dossiers require a signed-in profile. Show an explicit
        // sign-in prompt rather than a blank-empty-state that the user can't
        // act on (Submit would silently fail).
        if (controller.isGuestMode || controller.profile == null) {
          return _GuestCasesPrompt();
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
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    KpbSpacing.lg,
                    KpbSpacing.pagePad,
                    KpbSpacing.md,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('nav_cases'.tr, style: KpbTextStyles.headline),
                            const SizedBox(height: 3),
                            Text(
                              'cases_count'
                                  .trParams({'count': '${items.length}'}),
                              style: KpbTextStyles.bodySm,
                            ),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: Text('new_case'.tr),
                        onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => CaseComposerSheet(
                            caseType: CaseType.consultation,
                            title: 'new_case'.tr,
                            contextLabel: 'KPB Education',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Filtres ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad,
                    ),
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
              const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.md)),

              // ── Liste ─────────────────────────────────────────────────
              if (items.isEmpty)
                SliverFillRemaining(
                  child: KpbEmptyState(
                    icon: Icons.folder_open_outlined,
                    title: 'no_cases'.tr,
                    subtitle: 'case_empty_hint'.tr,
                    action: FilledButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CaseComposerSheet(
                          caseType: CaseType.consultation,
                          title: 'new_case'.tr,
                          contextLabel: 'KPB Education',
                        ),
                      ),
                      child: Text('create_case'.tr),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: KpbSpacing.pagePad,
                  ),
                  sliver: SliverList.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KpbSpacing.sm),
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
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: safeWidth),
          child: body,
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
// Case Card
// ─────────────────────────────────────────────────────────────────────────────
class _CaseCard extends StatelessWidget {
  const _CaseCard({required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(context, item.status);
    final date =
        DateFormat('dd MMM yyyy', controller.localeCode).format(item.updatedAt);
    final unread = controller.unreadMessagesForCase(item.id);

    return KpbCard(
      onTap: () => Get.to(() => CaseDetailScreen(caseId: item.id)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusInfo.color.withValues(alpha: 0.12),
                  borderRadius: KpbRadius.mdBr,
                ),
                child: Icon(
                  _typeIcon(item.type),
                  color: statusInfo.color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      controller.resolve(item.title),
                      style: KpbTextStyles.titleMd,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(item.referenceCode, style: KpbTextStyles.caption),
                  ],
                ),
              ),
              KpbBadge(
                label: statusInfo.label,
                color: statusInfo.color,
                small: true,
              ),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: KpbColors.error,
                    borderRadius: KpbRadius.pillBr,
                  ),
                  child: Text(
                    unread == 1
                        ? 'cases_new_message_badge'.tr
                        : 'cases_new_messages_badge'
                            .trParams({'count': '$unread'}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          const KpbDivider(),
          const SizedBox(height: 10),

          // ── Prochaine étape ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.arrow_right_alt_rounded,
                  size: 18, color: KpbColors.blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  controller.resolve(item.nextStepTitle),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.kpb.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.access_time_rounded,
                  size: 14, color: context.kpb.textMuted),
              const SizedBox(width: 4),
              Text('updated_on'.trParams({'date': date}),
                  style: KpbTextStyles.caption),
              if (item.messages.isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 14, color: context.kpb.textMuted),
                const SizedBox(width: 4),
                Text(
                  'cases_messages_count'
                      .trParams({'count': '${item.messages.length}'}),
                  style: KpbTextStyles.caption,
                ),
              ],
            ],
          ),

          // ── Contextual action button (status-driven) ──
          if (_contextualAction(item.status) != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _contextualActionColor(item.status),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: () =>
                    Get.to(() => CaseDetailScreen(caseId: item.id)),
                child: Text(_contextualAction(item.status)!),
              ),
            ),
          ],
        ],
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

  Color _contextualActionColor(CaseStatus status) {
    switch (status) {
      case CaseStatus.documentsNeeded:
        return KpbColors.warning;
      case CaseStatus.awaitingPayment:
        return KpbColors.blue;
      case CaseStatus.awaitingStudent:
        return KpbColors.sky;
      case CaseStatus.scheduled:
        return KpbColors.success;
      default:
        return KpbColors.blue;
    }
  }

  IconData _typeIcon(CaseType type) {
    switch (type) {
      case CaseType.consultation:
        return Icons.support_agent_outlined;
      case CaseType.applicationSupport:
        return Icons.folder_copy_outlined;
      case CaseType.scholarshipSupport:
        return Icons.workspace_premium_outlined;
      case CaseType.housingSupport:
        return Icons.home_outlined;
      case CaseType.mentorship:
        return Icons.psychology_outlined;
    }
  }

  ({String label, Color color}) _statusInfo(
      BuildContext context, CaseStatus status) {
    switch (status) {
      case CaseStatus.submitted:
        return (label: 'case_status_short_submitted'.tr, color: KpbColors.sky);
      case CaseStatus.underReview:
        return (
          label: 'case_timeline_status_under_review'.tr,
          color: KpbColors.gold
        );
      case CaseStatus.documentsNeeded:
        return (label: 'case_section_documents'.tr, color: KpbColors.warning);
      case CaseStatus.counselorAssigned:
        return (label: 'case_status_short_counselor'.tr, color: KpbColors.blue);
      case CaseStatus.awaitingStudent:
        return (
          label: 'case_status_short_action_required'.tr,
          color: KpbColors.error
        );
      case CaseStatus.scheduled:
        return (label: 'case_status_short_scheduled'.tr, color: KpbColors.blue);
      case CaseStatus.inProgress:
        return (
          label: 'case_timeline_status_in_progress'.tr,
          color: KpbColors.blue
        );
      case CaseStatus.applicationSubmitted:
        return (
          label: 'case_status_short_application_submitted'.tr,
          color: KpbColors.blueMid
        );
      case CaseStatus.waitingDecision:
        return (label: 'case_stepper_decision_title'.tr, color: KpbColors.gold);
      case CaseStatus.awaitingPayment:
        return (
          label: 'case_status_short_payment'.tr,
          color: KpbColors.warning
        );
      case CaseStatus.completed:
        return (
          label: 'case_status_short_completed'.tr,
          color: KpbColors.success
        );
      case CaseStatus.rejected:
        return (label: 'case_status_short_rejected'.tr, color: KpbColors.error);
      case CaseStatus.cancelled:
        return (
          label: 'case_status_short_cancelled'.tr,
          color: context.kpb.gray500
        );
      default:
        return (
          label: 'case_status_short_draft'.tr,
          color: context.kpb.gray400
        );
    }
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? KpbColors.blue : context.kpb.cardBg,
          borderRadius: KpbRadius.pillBr,
          boxShadow: selected ? KpbShadow.soft : KpbShadow.card,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : context.kpb.textSecondary,
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
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: context.kpb.pageBg,
          title: Text('nav_cases'.tr, style: KpbTextStyles.headline),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(KpbSpacing.pagePad),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_open_outlined,
                    size: 64, color: context.kpb.gray300),
                const SizedBox(height: KpbSpacing.lg),
                Text('guest_cases_title'.tr,
                    style: KpbTextStyles.headline, textAlign: TextAlign.center),
                const SizedBox(height: KpbSpacing.sm),
                Text(
                  'guest_cases_body'.tr,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.kpb.textMuted, height: 1.4),
                ),
                const SizedBox(height: KpbSpacing.xl),
                FilledButton.icon(
                  icon: const Icon(Icons.login_rounded),
                  label: Text('guest_case_gate_cta'.tr),
                  onPressed: () => Get.offAll(() => const AppBootScreen()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
