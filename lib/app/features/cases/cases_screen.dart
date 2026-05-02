import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
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
        if (controller.isSyncing && controller.cases.isEmpty) {
          return const CasesScreenSkeleton();
        }

        if (controller.syncError != null && controller.cases.isEmpty) {
          return KpbErrorState(onRetry: controller.refresh);
        }

        final items = controller.casesByType(_selectedType);

        return KpbRefresh(
          onRefresh: controller.refresh,
          child: CustomScrollView(
          slivers: [
            // ── Header ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.pagePad, KpbSpacing.lg,
                  KpbSpacing.pagePad, KpbSpacing.md,
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
                            '${items.length} dossier${items.length > 1 ? 's' : ''}',
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
                      label: 'Tous',
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
      },
    );
  }

  String _typeLabel(CaseType type) {
    switch (type) {
      case CaseType.consultation: return 'Consultation';
      case CaseType.applicationSupport: return 'Candidature';
      case CaseType.scholarshipSupport: return 'Bourse';
      case CaseType.housingSupport: return 'Logement';
      case CaseType.mentorship: return 'Mentorat';
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
    final date = DateFormat('dd MMM yyyy', controller.localeCode)
        .format(item.updatedAt);

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
              Text('Mis à jour $date', style: KpbTextStyles.caption),
              if (item.messages.isNotEmpty) ...[
                const SizedBox(width: 10),
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 14, color: context.kpb.textMuted),
                const SizedBox(width: 4),
                Text(
                  '${item.messages.length} message${item.messages.length > 1 ? 's' : ''}',
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
                  padding:
                      const EdgeInsets.symmetric(vertical: 10),
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
        return '📎 Envoyer mes documents';
      case CaseStatus.awaitingPayment:
        return '💳 Procéder au paiement';
      case CaseStatus.awaitingStudent:
        return '✉️ Répondre au conseiller';
      case CaseStatus.scheduled:
        return '📅 Voir mon rendez-vous';
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
      case CaseType.consultation: return Icons.support_agent_outlined;
      case CaseType.applicationSupport: return Icons.folder_copy_outlined;
      case CaseType.scholarshipSupport: return Icons.workspace_premium_outlined;
      case CaseType.housingSupport: return Icons.home_outlined;
      case CaseType.mentorship: return Icons.psychology_outlined;
    }
  }

  ({String label, Color color}) _statusInfo(BuildContext context, CaseStatus status) {
    switch (status) {
      case CaseStatus.submitted:
        return (label: 'Envoyé', color: KpbColors.sky);
      case CaseStatus.underReview:
        return (label: 'En revue', color: KpbColors.gold);
      case CaseStatus.documentsNeeded:
        return (label: 'Documents', color: KpbColors.warning);
      case CaseStatus.counselorAssigned:
        return (label: 'Conseiller', color: KpbColors.blue);
      case CaseStatus.awaitingStudent:
        return (label: 'Action requise', color: KpbColors.error);
      case CaseStatus.scheduled:
        return (label: 'Planifié', color: KpbColors.blue);
      case CaseStatus.inProgress:
        return (label: 'En cours', color: KpbColors.blue);
      case CaseStatus.applicationSubmitted:
        return (label: 'Soumis', color: KpbColors.blueMid);
      case CaseStatus.waitingDecision:
        return (label: 'Décision', color: KpbColors.gold);
      case CaseStatus.awaitingPayment:
        return (label: 'Paiement', color: KpbColors.warning);
      case CaseStatus.completed:
        return (label: 'Terminé', color: KpbColors.success);
      case CaseStatus.rejected:
        return (label: 'Refusé', color: KpbColors.error);
      case CaseStatus.cancelled:
        return (label: 'Annulé', color: context.kpb.gray500);
      default:
        return (label: 'Brouillon', color: context.kpb.gray400);
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
