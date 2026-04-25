import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';

const _frMonths = <String, int>{
  'janvier': 1,
  'février': 2,
  'mars': 3,
  'avril': 4,
  'mai': 5,
  'juin': 6,
  'juillet': 7,
  'août': 8,
  'septembre': 9,
  'octobre': 10,
  'novembre': 11,
  'décembre': 12,
};

const _monthNames = <int, String>{
  1: 'Janvier', 2: 'Février', 3: 'Mars', 4: 'Avril',
  5: 'Mai', 6: 'Juin', 7: 'Juillet', 8: 'Août',
  9: 'Septembre', 10: 'Octobre', 11: 'Novembre', 12: 'Décembre',
};

const _flags = <String, String>{
  'usa': '🇺🇸', 'canada': '🇨🇦', 'france': '🇫🇷', 'uk': '🇬🇧',
  'morocco': '🇲🇦', 'turkey': '🇹🇷', 'germany': '🇩🇪', 'spain': '🇪🇸',
  'china': '🇨🇳', 'belgium': '🇧🇪', 'italy': '🇮🇹', 'portugal': '🇵🇹',
};

DateTime? _parseDeadline(String text) {
  final lower = text.toLowerCase();
  final match = RegExp(r'(\d{1,2})\s+(\w+)\s+(\d{4})').firstMatch(lower);
  if (match == null) return null;
  final day = int.tryParse(match.group(1)!);
  final month = _frMonths[match.group(2)!];
  final year = int.tryParse(match.group(3)!);
  if (day == null || month == null || year == null) return null;
  return DateTime(year, month, day);
}

class _DeadlineEntry {
  const _DeadlineEntry({
    required this.scholarship,
    required this.deadline,
    required this.isSaved,
  });
  final ScholarshipModel scholarship;
  final DateTime? deadline;
  final bool isSaved;
}

enum _DeadlineFilter { all, saved, upcoming }

class DeadlineCalendarScreen extends StatefulWidget {
  const DeadlineCalendarScreen({super.key});

  @override
  State<DeadlineCalendarScreen> createState() => _DeadlineCalendarScreenState();
}

class _DeadlineCalendarScreenState extends State<DeadlineCalendarScreen> {
  _DeadlineFilter _filter = _DeadlineFilter.all;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        backgroundColor: context.kpb.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.kpb.textPrimary),
          onPressed: () => Get.back(),
        ),
        title: Text(
          'Calendrier deadlines',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: context.kpb.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: GetBuilder<AppController>(
        builder: (_) {
          final savedIds = controller.savedItems
              .where((e) => e.type == SavedItemType.scholarship)
              .map((e) => e.itemId)
              .toSet();

          // Build deadline entries
          final entries = controller.scholarships.map((s) {
            final labelText = controller.resolve(s.deadlineLabel);
            return _DeadlineEntry(
              scholarship: s,
              deadline: _parseDeadline(labelText),
              isSaved: savedIds.contains(s.id),
            );
          }).toList();

          // Apply filter
          List<_DeadlineEntry> filtered;
          switch (_filter) {
            case _DeadlineFilter.saved:
              filtered = entries.where((e) => e.isSaved).toList();
            case _DeadlineFilter.upcoming:
              filtered = entries
                  .where((e) => e.deadline != null && e.deadline!.isAfter(now))
                  .toList();
            case _DeadlineFilter.all:
              filtered = entries;
          }

          // Sort: entries with parsed dates first (by date), then undated ones
          filtered.sort((a, b) {
            if (a.deadline == null && b.deadline == null) return 0;
            if (a.deadline == null) return 1;
            if (b.deadline == null) return -1;
            return a.deadline!.compareTo(b.deadline!);
          });

          // Group by month+year
          final Map<String, List<_DeadlineEntry>> grouped = {};
          for (final entry in filtered) {
            final key = entry.deadline != null
                ? '${_monthNames[entry.deadline!.month]} ${entry.deadline!.year}'
                : 'Date non précisée';
            grouped.putIfAbsent(key, () => []).add(entry);
          }

          final stats = _buildStats(entries, now);

          return CustomScrollView(
            slivers: [
              // ── Stats banner ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    KpbSpacing.lg,
                    KpbSpacing.pagePad,
                    KpbSpacing.sm,
                  ),
                  child: _StatsBanner(stats: stats),
                ),
              ),

              // ── Filter chips ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad, KpbSpacing.sm, KpbSpacing.pagePad, 0),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'Toutes',
                        active: _filter == _DeadlineFilter.all,
                        onTap: () => setState(() => _filter = _DeadlineFilter.all),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Sauvegardées',
                        active: _filter == _DeadlineFilter.saved,
                        onTap: () => setState(() => _filter = _DeadlineFilter.saved),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'À venir',
                        active: _filter == _DeadlineFilter.upcoming,
                        onTap: () => setState(() => _filter = _DeadlineFilter.upcoming),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Empty state ─────────────────────────────────────────────
              if (filtered.isEmpty)
                const SliverFillRemaining(
                  child: KpbEmptyState(
                    icon: Icons.event_busy_outlined,
                    title: 'Aucune deadline',
                    subtitle: 'Sauvegardez des bourses pour les suivre ici.',
                  ),
                )
              else
                // ── Timeline ─────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    KpbSpacing.md,
                    KpbSpacing.pagePad,
                    100,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final keys = grouped.keys.toList();
                        final key = keys[index];
                        final groupEntries = grouped[key]!;
                        return _MonthGroup(
                          monthLabel: key,
                          entries: groupEntries,
                          controller: controller,
                          now: now,
                        );
                      },
                      childCount: grouped.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Map<String, int> _buildStats(List<_DeadlineEntry> entries, DateTime now) {
    final upcoming = entries.where((e) =>
        e.deadline != null && e.deadline!.isAfter(now)).length;
    final urgent = entries.where((e) =>
        e.deadline != null &&
        e.deadline!.isAfter(now) &&
        e.deadline!.difference(now).inDays <= 30).length;
    final expired = entries.where((e) =>
        e.deadline != null && e.deadline!.isBefore(now)).length;
    return {'upcoming': upcoming, 'urgent': urgent, 'expired': expired};
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats banner
// ─────────────────────────────────────────────────────────────────────────────
class _StatsBanner extends StatelessWidget {
  const _StatsBanner({required this.stats});
  final Map<String, int> stats;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      padding: const EdgeInsets.all(KpbSpacing.md),
      child: Row(
        children: [
          _StatItem(
            count: stats['upcoming']!,
            label: 'À venir',
            color: KpbColors.blue,
            icon: Icons.upcoming_outlined,
          ),
          _StatDivider(),
          _StatItem(
            count: stats['urgent']!,
            label: '≤ 30 jours',
            color: KpbColors.warning,
            icon: Icons.timer_outlined,
          ),
          _StatDivider(),
          _StatItem(
            count: stats['expired']!,
            label: 'Passées',
            color: context.kpb.gray400,
            icon: Icons.event_busy_outlined,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.count,
    required this.label,
    required this.color,
    required this.icon,
  });
  final int count;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label, style: KpbTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 48,
      color: context.kpb.gray100,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Filter chip
// ─────────────────────────────────────────────────────────────────────────────
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? KpbColors.blue : context.kpb.cardBg,
          borderRadius: KpbRadius.pillBr,
          boxShadow: active ? null : KpbShadow.soft,
          border: active
              ? null
              : Border.all(color: context.kpb.gray200),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : context.kpb.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Month group
// ─────────────────────────────────────────────────────────────────────────────
class _MonthGroup extends StatelessWidget {
  const _MonthGroup({
    required this.monthLabel,
    required this.entries,
    required this.controller,
    required this.now,
  });
  final String monthLabel;
  final List<_DeadlineEntry> entries;
  final AppController controller;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.only(bottom: KpbSpacing.sm, top: KpbSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: const BoxDecoration(
                  color: KpbColors.blue,
                  borderRadius: KpbRadius.pillBr,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                monthLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.kpb.textSecondary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: context.kpb.surfaceBg,
                  borderRadius: KpbRadius.pillBr,
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: context.kpb.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
        KpbCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: entries.asMap().entries.map((e) {
              final i = e.key;
              return Column(
                children: [
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 16,
                      endIndent: 16,
                      color: context.kpb.gray100,
                    ),
                  _DeadlineTile(
                    entry: e.value,
                    controller: controller,
                    now: now,
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deadline tile
// ─────────────────────────────────────────────────────────────────────────────
class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({
    required this.entry,
    required this.controller,
    required this.now,
  });
  final _DeadlineEntry entry;
  final AppController controller;
  final DateTime now;

  _DeadlineStatus get _status {
    final d = entry.deadline;
    if (d == null) return _DeadlineStatus.unknown;
    if (d.isBefore(now)) return _DeadlineStatus.expired;
    if (d.difference(now).inDays <= 30) return _DeadlineStatus.urgent;
    return _DeadlineStatus.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    final scholarship = entry.scholarship;
    final name = controller.resolve(scholarship.name);
    final funding = controller.resolve(scholarship.typeOfFunding);
    final deadlineText = controller.resolve(scholarship.deadlineLabel);
    final status = _status;

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CaseComposerSheet(
          caseType: CaseType.scholarshipSupport,
          title: name,
          contextLabel: funding,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: KpbSpacing.md, vertical: 12),
        child: Row(
          children: [
            // Status indicator
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: status.bgColor(context),
                borderRadius: KpbRadius.mdBr,
              ),
              child: Center(
                child: Text(
                  _flags[scholarship.countryId] ?? '🌍',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: KpbTextStyles.titleMd, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(funding, style: KpbTextStyles.caption, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.bgColor(context),
                    borderRadius: KpbRadius.pillBr,
                  ),
                  child: Text(
                    status.label(entry.deadline, now),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: status.textColor(context),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  deadlineText,
                  style: KpbTextStyles.caption,
                  maxLines: 1,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Deadline status
// ─────────────────────────────────────────────────────────────────────────────
enum _DeadlineStatus { expired, urgent, upcoming, unknown }

extension _DeadlineStatusExt on _DeadlineStatus {
  Color bgColor(BuildContext context) {
    switch (this) {
      case _DeadlineStatus.expired:
        return context.kpb.gray100;
      case _DeadlineStatus.urgent:
        return KpbColors.warningLight;
      case _DeadlineStatus.upcoming:
        return KpbColors.skyLight;
      case _DeadlineStatus.unknown:
        return KpbColors.bgMuted;
    }
  }

  Color textColor(BuildContext context) {
    switch (this) {
      case _DeadlineStatus.expired:
        return context.kpb.gray400;
      case _DeadlineStatus.urgent:
        return KpbColors.warning;
      case _DeadlineStatus.upcoming:
        return KpbColors.blue;
      case _DeadlineStatus.unknown:
        return context.kpb.textMuted;
    }
  }

  String label(DateTime? deadline, DateTime now) {
    switch (this) {
      case _DeadlineStatus.expired:
        return 'Passée';
      case _DeadlineStatus.urgent:
        final days = deadline!.difference(now).inDays;
        return days == 0 ? 'Aujourd\'hui' : '$days j';
      case _DeadlineStatus.upcoming:
        return 'À venir';
      case _DeadlineStatus.unknown:
        return '?';
    }
  }
}
