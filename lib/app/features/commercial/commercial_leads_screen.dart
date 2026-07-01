import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_detail_screen.dart';

Map<String, String> get _leadTagLabels => <String, String>{
      'qualified': 'lead_tag_qualified'.tr,
      'not_qualified': 'lead_tag_not_qualified'.tr,
      'awaiting_payment': 'lead_tag_awaiting_payment'.tr,
      'converted': 'lead_tag_converted'.tr,
      'lost': 'lead_tag_lost'.tr,
      'to_follow_up': 'lead_tag_to_follow_up'.tr,
    };

Color _tagColor(String? tag) {
  switch (tag) {
    case 'qualified':
    case 'converted':
      return KpbColors.success;
    case 'not_qualified':
    case 'lost':
      return KpbColors.error;
    case 'awaiting_payment':
    case 'to_follow_up':
      return KpbColors.warning;
    default:
      return KpbColors.gray400;
  }
}

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 60) {
    return 'time_ago_minutes'.trParams({'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'time_ago_hours'.trParams({'n': '${diff.inHours}'});
  }
  if (diff.inDays < 7) {
    return 'time_ago_days'.trParams({'n': '${diff.inDays}'});
  }
  if (diff.inDays < 30) {
    return 'time_ago_weeks'.trParams({'n': '${(diff.inDays / 7).floor()}'});
  }
  return 'time_ago_months'.trParams({'n': '${(diff.inDays / 30).floor()}'});
}

/// Vue commerciale — inbox leads (M9).
class CommercialLeadsScreen extends StatefulWidget {
  const CommercialLeadsScreen({super.key});

  @override
  State<CommercialLeadsScreen> createState() => _CommercialLeadsScreenState();
}

class _CommercialLeadsScreenState extends State<CommercialLeadsScreen> {
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Get.find<AppController>().fetchCommercialLeads();
    });
  }

  Future<void> _refresh() async {
    await Get.find<AppController>().fetchCommercialLeads();
  }

  /// Filter client-side so the shared `commercialLeads` list stays intact for
  /// the Conversations tab (which reads the same list). Mirrors the backend
  /// filter semantics in `CommercialService.listLeads`.
  List<CommercialLead> _applyFilter(List<CommercialLead> leads) {
    switch (_filter) {
      case 'new':
        return leads
            .where((l) =>
                l.status == 'submitted' || l.status == 'counselor_assigned')
            .toList();
      case 'today':
        final start = DateTime.now();
        final midnight = DateTime(start.year, start.month, start.day);
        return leads.where((l) => !l.createdAt.isBefore(midnight)).toList();
      case 'qualified':
        return leads.where((l) => l.leadTag == 'qualified').toList();
      default:
        return leads;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final leads = _applyFilter(controller.commercialLeads);

        return Scaffold(
          appBar: AppBar(
            title: Text('nav_commercial_leads'.tr),
            actions: [
              IconButton(
                onPressed:
                    controller.isLoadingCommercialLeads ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'refresh'.tr,
              ),
            ],
          ),
          body: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.pagePad,
                  KpbSpacing.sm,
                  KpbSpacing.pagePad,
                  0,
                ),
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'leads_filter_all'.tr,
                      selected: _filter == 'all',
                      onTap: () => _setFilter('all'),
                    ),
                    _FilterChip(
                      label: 'leads_filter_new'.tr,
                      selected: _filter == 'new',
                      onTap: () => _setFilter('new'),
                    ),
                    _FilterChip(
                      label: 'leads_filter_today'.tr,
                      selected: _filter == 'today',
                      onTap: () => _setFilter('today'),
                    ),
                    _FilterChip(
                      label: 'leads_filter_qualified'.tr,
                      selected: _filter == 'qualified',
                      onTap: () => _setFilter('qualified'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: controller.isLoadingCommercialLeads && leads.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : controller.commercialLeadsError != null && leads.isEmpty
                        ? KpbEmptyState(
                            icon: Icons.cloud_off_outlined,
                            title: 'loading_error_title'.tr,
                            subtitle: controller.commercialLeadsError!,
                            actionLabel: 'retry'.tr,
                            onAction: _refresh,
                          )
                        : leads.isEmpty
                            ? KpbEmptyState(
                                icon: Icons.inbox_outlined,
                                title: 'commercial_no_leads_title'.tr,
                                subtitle: 'commercial_no_leads_body'.tr,
                              )
                            : RefreshIndicator(
                                onRefresh: _refresh,
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    KpbSpacing.pagePad,
                                    KpbSpacing.pagePad,
                                    KpbSpacing.pagePad,
                                    100, // clear the floating nav bar
                                  ),
                                  itemCount: leads.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 10),
                                  itemBuilder: (context, index) {
                                    return _LeadCard(
                                      lead: leads[index],
                                      controller: controller,
                                    );
                                  },
                                ),
                              ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _setFilter(String filter) {
    // Pure client-side filter — no refetch, instant, and decoupled from the
    // Conversations tab which shares the same underlying list.
    setState(() => _filter = filter);
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({
    required this.lead,
    required this.controller,
  });

  final CommercialLead lead;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final tagLabel = _leadTagLabels[lead.leadTag] ?? 'lead_tag_none'.tr;
    final tagColor = _tagColor(lead.leadTag);
    final anciennete = _relativeTime(lead.createdAt);

    return KpbCard(
      child: InkWell(
        borderRadius: KpbRadius.lgBr,
        onTap: () => Get.to(() => CaseDetailScreen(caseId: lead.id)),
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header : titre + badge tag ─────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar initiales
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: KpbColors.blue.withValues(alpha: 0.12),
                    child: Text(
                      lead.studentName.isNotEmpty
                          ? lead.studentName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: KpbColors.blue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(lead.studentName, style: KpbTextStyles.titleMd),
                        if (lead.studentLevel != null)
                          Text(lead.studentLevel!,
                              style: KpbTextStyles.caption),
                      ],
                    ),
                  ),
                  KpbBadge(label: tagLabel, color: tagColor, small: true),
                ],
              ),
              const SizedBox(height: 8),

              // ── Titre de la demande ────────────────────────────────
              Text(lead.title, style: KpbTextStyles.body),

              // ── Ref + ancienneté ───────────────────────────────────
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    lead.referenceCode,
                    style:
                        TextStyle(fontSize: 11, color: context.kpb.textMuted),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time_rounded,
                      size: 12, color: context.kpb.textMuted),
                  const SizedBox(width: 3),
                  Text(
                    anciennete,
                    style:
                        TextStyle(fontSize: 11, color: context.kpb.textMuted),
                  ),
                ],
              ),

              // ── Motif ─────────────────────────────────────────────
              if (lead.discussionMotive != null &&
                  lead.discussionMotive!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'lead_motive_prefix'
                      .trParams({'motive': '${lead.discussionMotive}'}),
                  style: KpbTextStyles.caption,
                ),
              ],

              // ── Changer le statut (bottom sheet, désencombre la carte) ──
              const SizedBox(height: KpbSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => _showTagSheet(context),
                  icon: const Icon(Icons.label_outline_rounded, size: 16),
                  label: Text('lead_change_status'.tr),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: tagColor,
                    side: BorderSide(color: tagColor.withValues(alpha: 0.4)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTagSheet(BuildContext context) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => _LeadTagSheet(currentTag: lead.leadTag),
    );
    if (selected == null || selected == lead.leadTag) return;
    try {
      await controller.updateCommercialLeadTag(lead.id, leadTag: selected);
    } catch (_) {
      Get.snackbar(
        'error'.tr,
        'lead_status_update_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }
}

/// Bottom sheet for changing a lead's status — one color-coded row per tag.
class _LeadTagSheet extends StatelessWidget {
  const _LeadTagSheet({required this.currentTag});

  final String? currentTag;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              KpbSpacing.lg,
              0,
              KpbSpacing.lg,
              KpbSpacing.sm,
            ),
            child: Text('lead_status_sheet_title'.tr,
                style: KpbTextStyles.titleLg),
          ),
          ..._leadTagLabels.entries.map((entry) {
            final color = _tagColor(entry.key);
            final isActive = entry.key == currentTag;
            return ListTile(
              leading: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              title: Text(
                entry.value,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? color : null,
                ),
              ),
              trailing:
                  isActive ? Icon(Icons.check_rounded, color: color) : null,
              onTap: () => Navigator.of(context).pop(entry.key),
            );
          }),
          const SizedBox(height: KpbSpacing.sm),
        ],
      ),
    );
  }
}
