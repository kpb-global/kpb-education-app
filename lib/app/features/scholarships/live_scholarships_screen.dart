import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';

const _flagMap = <String, String>{
  'Japan': '🇯🇵',
  'Japon': '🇯🇵',
  'France': '🇫🇷',
  'Germany': '🇩🇪',
  'Allemagne': '🇩🇪',
  'United States': '🇺🇸',
  'États-Unis': '🇺🇸',
  'USA': '🇺🇸',
  'Canada': '🇨🇦',
  'United Kingdom': '🇬🇧',
  'Royaume-Uni': '🇬🇧',
  'UK': '🇬🇧',
  'Australia': '🇦🇺',
  'Australie': '🇦🇺',
  'China': '🇨🇳',
  'Chine': '🇨🇳',
  'South Korea': '🇰🇷',
  'Corée du Sud': '🇰🇷',
  'Turkey': '🇹🇷',
  'Turquie': '🇹🇷',
  'Italy': '🇮🇹',
  'Italie': '🇮🇹',
  'Spain': '🇪🇸',
  'Espagne': '🇪🇸',
  'Morocco': '🇲🇦',
  'Maroc': '🇲🇦',
  'Tunisia': '🇹🇳',
  'Tunisie': '🇹🇳',
  'Switzerland': '🇨🇭',
  'Suisse': '🇨🇭',
  'Belgium': '🇧🇪',
  'Belgique': '🇧🇪',
  'Netherlands': '🇳🇱',
  'Pays-Bas': '🇳🇱',
  'Sweden': '🇸🇪',
  'Suède': '🇸🇪',
  'Senegal': '🇸🇳',
  'Sénégal': '🇸🇳',
  'International': '🌍',
};

String _flag(String country) => _flagMap[country] ?? '🌍';

/// Live scholarship index screen — fetches from the scraped /scholarships API.
/// Displays scholarships filtered and ranked by the user's profile.
class LiveScholarshipsScreen extends StatefulWidget {
  const LiveScholarshipsScreen({super.key});

  @override
  State<LiveScholarshipsScreen> createState() => _LiveScholarshipsScreenState();
}

class _LiveScholarshipsScreenState extends State<LiveScholarshipsScreen> {
  List<LiveScholarshipModel> _items = [];
  bool _loading = true;
  String? _error;
  String _fundingFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final controller = Get.find<AppController>();
      final profile = controller.profile;
      final lang = profile?.preferredLanguage ?? 'fr';
      final client = AppApiClient();
      final raw = await client.fetchLiveScholarships(
        lang: lang,
        level: profile?.targetLevel,
        fieldIds: profile?.fieldIds,
        fundingType: _fundingFilter == 'all' ? null : _fundingFilter,
      );
      final items = raw
          .cast<Map<String, dynamic>>()
          .map(LiveScholarshipModel.fromJson)
          .toList();
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = KpbColors.blue;

    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      body: SafeArea(
        child: KpbRefresh(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              // ── App Bar ────────────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: context.kpb.pageBg,
                automaticallyImplyLeading: false,
                leading: Navigator.canPop(context)
                    ? IconButton(
                        tooltip: 'a11y_back'.tr,
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20, color: context.kpb.textPrimary),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: Text(
                  'scholarships_title'.tr,
                  style: KpbTextStyles.headline
                      .copyWith(color: context.kpb.textPrimary),
                ),
                actions: [
                  IconButton(
                    tooltip: 'a11y_refresh'.tr,
                    icon: Icon(Icons.refresh_rounded,
                        color: context.kpb.textSecondary),
                    onPressed: _load,
                  ),
                ],
              ),

              // ── Header ─────────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'recommended_opportunities'.tr,
                        style: KpbTextStyles.titleLg
                            .copyWith(color: context.kpb.textPrimary),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'ranked_by_profile'.tr,
                        style: KpbTextStyles.body
                            .copyWith(color: context.kpb.textSecondary),
                      ),
                      const SizedBox(height: KpbSpacing.md),
                      // Funding filter chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'live_scholarships_filter_all'.tr,
                              active: _fundingFilter == 'all',
                              accent: accent,
                              onTap: () => setState(() {
                                _fundingFilter = 'all';
                                _load();
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'live_scholarships_filter_fully_funded'.tr,
                              active: _fundingFilter == 'fully_funded',
                              accent: accent,
                              onTap: () => setState(() {
                                _fundingFilter = 'fully_funded';
                                _load();
                              }),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'live_scholarships_filter_partially_funded'
                                  .tr,
                              active: _fundingFilter == 'partially_funded',
                              accent: accent,
                              onTap: () => setState(() {
                                _fundingFilter = 'partially_funded';
                                _load();
                              }),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ────────────────────────────────────────────────────
              if (_loading)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      _buildShimmerCard,
                      childCount: 5,
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: KpbEmptyState(
                      icon: Icons.wifi_off_rounded,
                      title: 'live_scholarships_connection_error_title'.tr,
                      subtitle:
                          'live_scholarships_connection_error_subtitle'.tr,
                      action: KpbButton(
                        text: 'retry'.tr,
                        onPressed: _load,
                        bgColor: accent,
                      ),
                    ),
                  ),
                )
              else if (_items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: KpbEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'live_scholarships_empty_title'.tr,
                      subtitle: 'live_scholarships_empty_subtitle'.tr,
                    ),
                  ),
                )
              else ...[
                // Result count
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, 0,
                        KpbSpacing.pagePad, KpbSpacing.md),
                    child: Text(
                      'live_scholarships_result_count'
                          .trParams({'count': '${_items.length}'}),
                      style: KpbTextStyles.caption
                          .copyWith(color: context.kpb.textMuted),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final s = _items[index];
                        return StaggeredSlide(
                          index: index,
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: KpbSpacing.md),
                            child: _LiveScholarshipCard(
                              scholarship: s,
                              accent: accent,
                              onTap: () => _openDetail(context, s, accent),
                            ),
                          ),
                        );
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }

  /// Shimmer placeholder card for the loading state.
  static Widget _buildShimmerCard(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.md),
      child: _ShimmerCard(delay: index * 70),
    );
  }

  void _openDetail(BuildContext context, LiveScholarshipModel s, Color accent) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.80,
        maxChildSize: 0.97,
        builder: (_, sc) => _LiveScholarshipDetail(
          scholarship: s,
          accent: accent,
          scrollController: sc,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List card
// ─────────────────────────────────────────────────────────────────────────────
class _LiveScholarshipCard extends StatelessWidget {
  const _LiveScholarshipCard({
    required this.scholarship,
    required this.accent,
    required this.onTap,
  });

  final LiveScholarshipModel scholarship;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final fundingColor = s.isFullyFunded
        ? KpbColors.success
        : s.isPartiallyFunded
            ? KpbColors.warning
            : context.kpb.gray400;
    final fundingLabel = s.isFullyFunded
        ? 'live_scholarships_fully_funded'.tr
        : s.isPartiallyFunded
            ? 'live_scholarships_partially_funded'.tr
            : 'live_scholarships_funding_unknown'.tr;

    return KpbCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Country flag avatar
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: context.kpb.surfaceBg,
                  borderRadius: KpbRadius.mdBr,
                  border: Border.all(color: context.kpb.gray100),
                ),
                child: Center(
                  child: Text(
                    _flag(s.countryName),
                    style: const TextStyle(fontSize: 26),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.countryName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: accent,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.title,
                      style: KpbTextStyles.titleMd.copyWith(
                          color: context.kpb.textPrimary, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Match score
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AdmissionMeter(
                      score: s.matchScore, size: 34, strokeWidth: 3.5),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Funding badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: fundingColor.withValues(alpha: 0.12),
                  borderRadius: KpbRadius.pillBr,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.isFullyFunded
                          ? Icons.verified_rounded
                          : Icons.payments_outlined,
                      size: 13,
                      color: fundingColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      fundingLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: fundingColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (s.deadlineLabel.isNotEmpty)
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined,
                          size: 13, color: context.kpb.gray400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          s.deadlineLabel,
                          style: KpbTextStyles.caption
                              .copyWith(color: context.kpb.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
// Detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
class _LiveScholarshipDetail extends StatelessWidget {
  const _LiveScholarshipDetail({
    required this.scholarship,
    required this.accent,
    required this.scrollController,
  });

  final LiveScholarshipModel scholarship;
  final Color accent;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final fundingColor = s.isFullyFunded
        ? KpbColors.success
        : s.isPartiallyFunded
            ? KpbColors.warning
            : context.kpb.gray400;
    final fundingLabel = s.isFullyFunded
        ? 'live_scholarships_fully_funded'.tr
        : s.isPartiallyFunded
            ? 'live_scholarships_partially_funded'.tr
            : 'live_scholarships_funding_unspecified'.tr;

    return Container(
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
        children: [
          const SizedBox(height: KpbSpacing.md),
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: context.kpb.gray200,
                borderRadius: KpbRadius.pillBr,
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.xl),

          // ── Header ───────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: context.kpb.surfaceBg,
                  borderRadius: KpbRadius.lgBr,
                  border: Border.all(color: context.kpb.gray100),
                ),
                child: Center(
                  child: Text(
                    _flag(s.countryName),
                    style: const TextStyle(fontSize: 30),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    KpbBadge(
                      label: s.countryName.toUpperCase(),
                      color: accent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.title,
                      style: KpbTextStyles.displaySm.copyWith(
                          color: context.kpb.textPrimary, height: 1.1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.lg),

          // ── Funding badge ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: fundingColor.withValues(alpha: 0.1),
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: fundingColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  s.isFullyFunded
                      ? Icons.verified_rounded
                      : Icons.payments_rounded,
                  size: 18,
                  color: fundingColor,
                ),
                const SizedBox(width: 8),
                Text(
                  fundingLabel,
                  style: TextStyle(
                    color: fundingColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.md),

          // ── Key info rows ─────────────────────────────────────────────────
          _InfoRow(
            icon: Icons.school_outlined,
            label: 'live_scholarships_level_label'.tr,
            value:
                s.level.isEmpty ? 'live_scholarships_all_levels'.tr : s.level,
            accent: accent,
          ),
          _InfoRow(
            icon: Icons.event_outlined,
            label: 'live_scholarships_deadline_label'.tr,
            value: s.deadlineLabel.isEmpty
                ? 'live_scholarships_see_official_site'.tr
                : s.deadlineLabel,
            accent: accent,
          ),
          const SizedBox(height: KpbSpacing.xl),

          // ── Match score banner ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(KpbSpacing.lg),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.08),
              borderRadius: KpbRadius.xlBr,
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                AdmissionMeter(score: s.matchScore, size: 52, strokeWidth: 5),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'profile_compatibility'.tr,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.matchScore >= 70
                            ? 'live_scholarships_match_excellent'.tr
                            : s.matchScore >= 40
                                ? 'live_scholarships_match_compatible'.tr
                                : 'live_scholarships_match_partial'.tr,
                        style: TextStyle(
                          color: context.kpb.textSecondary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.xl),

          // ── Description ───────────────────────────────────────────────────
          if (s.description.isNotEmpty) ...[
            _SectionHeader(
                label: 'live_scholarships_section_description'.tr,
                icon: Icons.info_outline_rounded),
            const SizedBox(height: 10),
            Text(
              s.description,
              style: KpbTextStyles.body
                  .copyWith(color: context.kpb.textSecondary, height: 1.6),
            ),
            const SizedBox(height: KpbSpacing.xl),
          ],

          // ── Advantages ────────────────────────────────────────────────────
          if (s.advantages.isNotEmpty) ...[
            _SectionHeader(
                label: 'live_scholarships_section_advantages'.tr,
                icon: Icons.star_outline_rounded),
            const SizedBox(height: 10),
            ...s.advantages
                .map((a) => _BulletItem(text: a, color: KpbColors.success)),
            const SizedBox(height: KpbSpacing.xl),
          ],

          // ── Eligibility ───────────────────────────────────────────────────
          if (s.eligibility.isNotEmpty) ...[
            _SectionHeader(
                label: 'live_scholarships_section_eligibility'.tr,
                icon: Icons.checklist_rounded),
            const SizedBox(height: 10),
            ...s.eligibility.map((e) => _BulletItem(text: e, color: accent)),
            const SizedBox(height: KpbSpacing.xl),
          ],

          // ── CTAs ──────────────────────────────────────────────────────────
          // Primary: Apply with KPB
          KpbButton(
            text: 'live_scholarships_apply_with_kpb'.tr,
            onPressed: () {
              Navigator.pop(context);
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CaseComposerSheet(
                  caseType: CaseType.scholarshipSupport,
                  title: s.title,
                  contextLabel: s.countryName,
                ),
              );
            },
            bgColor: accent,
            icon: Icons.rocket_launch_rounded,
          ),
          const SizedBox(height: KpbSpacing.md),
          // Secondary: Go to official page
          if (s.applicationUrl.isNotEmpty)
            GestureDetector(
              onTap: () async {
                final uri = Uri.tryParse(s.applicationUrl);
                if (uri != null && await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: context.kpb.gray200),
                  borderRadius: KpbRadius.lgBr,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.open_in_new_rounded,
                        size: 18, color: context.kpb.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'live_scholarships_view_official_application'.tr,
                      style: KpbTextStyles.body.copyWith(
                        color: context.kpb.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: KpbSpacing.xxl),
        ],
      ),
    );
  }
}

// ── Small helper widgets ──────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? accent : context.kpb.surfaceBg,
          borderRadius: KpbRadius.pillBr,
          border: Border.all(
            color: active ? accent : context.kpb.gray200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : context.kpb.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.icon});
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: context.kpb.textPrimary),
        const SizedBox(width: 8),
        Text(
          label,
          style: KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: 12),
          Text('$label : ',
              style: KpbTextStyles.body.copyWith(color: context.kpb.textMuted)),
          Expanded(
            child: Text(
              value,
              style: KpbTextStyles.body.copyWith(
                fontWeight: FontWeight.w700,
                color: context.kpb.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(Icons.check_circle_rounded, size: 18, color: color),
          ),
          Expanded(
            child: Text(
              text,
              style: KpbTextStyles.body.copyWith(
                color: context.kpb.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer skeleton card shown while scholarships are loading
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard({this.delay = 0});
  final int delay;

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    Future.delayed(Duration(milliseconds: widget.delay), () {
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
    final base = context.kpb.surfaceBg;
    final shimmer = context.kpb.gray200;
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final color = Color.lerp(base, shimmer, _anim.value)!;
        return Container(
          height: 120,
          decoration: BoxDecoration(
            color: color,
            borderRadius: KpbRadius.lgBr,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Color.lerp(shimmer, base, _anim.value),
                      borderRadius: KpbRadius.mdBr,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 10,
                          width: 60,
                          decoration: BoxDecoration(
                            color: Color.lerp(shimmer, base, _anim.value),
                            borderRadius: KpbRadius.pillBr,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 14,
                          decoration: BoxDecoration(
                            color: Color.lerp(shimmer, base, _anim.value),
                            borderRadius: KpbRadius.pillBr,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          height: 14,
                          width: 180,
                          decoration: BoxDecoration(
                            color: Color.lerp(shimmer, base, _anim.value),
                            borderRadius: KpbRadius.pillBr,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
