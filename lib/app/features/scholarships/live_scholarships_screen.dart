import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';
import 'widgets/application_steps_timeline.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "Scholarships" / "Fiche bourse").
// Local to this file — same pattern as Home / Onboarding / Comparateur (#110–115).
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const body = Color(0xFF334155);
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
  static const amberSolid = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEE2E2);
  // rgba(15,23,42,0.04) — soft card shadow from the handoff.
  static const cardShadow = Color(0x0A0F172A);
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
];

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

// ── Real-data helpers ──────────────────────────────────────────────────────

/// Countdown badge derived from the REAL [LiveScholarshipModel.deadlineAt].
/// Returns null when the scholarship has no parsed date — the UI then shows a
/// neutral label rather than a fabricated countdown.
class _DeadlineBadge {
  const _DeadlineBadge(this.text, this.bg, this.fg, {this.soon = false});
  final String text;
  final Color bg;
  final Color fg;
  final bool soon;
}

_DeadlineBadge? _deadlineBadge(LiveScholarshipModel s) {
  final at = s.deadlineAt;
  if (at == null) return null;
  final days = at.difference(DateTime.now()).inDays;
  if (days < 0) {
    return _DeadlineBadge(
        'live_scholarships_deadline_closed'.tr, _Palette.line, _Palette.slate);
  }
  final text = 'D-$days';
  if (days <= 7) {
    return _DeadlineBadge(text, _Palette.redBg, _Palette.red, soon: true);
  }
  if (days <= 30) {
    return _DeadlineBadge(text, _Palette.amberBg, _Palette.amber,
        soon: days <= 14);
  }
  return _DeadlineBadge(text, _Palette.chipBg, _Palette.blue);
}

/// Color-coded funding chip — bound to the real [fundingType].
(Color, Color, String) _fundingChip(LiveScholarshipModel s) {
  if (s.isFullyFunded) {
    return (
      _Palette.greenBg,
      _Palette.green,
      'live_scholarships_fully_funded'.tr
    );
  }
  if (s.isPartiallyFunded) {
    return (
      _Palette.amberBg,
      _Palette.amber,
      'live_scholarships_partially_funded'.tr
    );
  }
  return (
    _Palette.line,
    _Palette.slate,
    'live_scholarships_funding_unknown'.tr
  );
}

/// Color-coded application-requirement chip — bound to the real
/// [applicationRequirement] (there is no per-scholarship eligibility verdict to
/// bind, so we surface this real categorical instead of inventing one).
(Color, Color, String) _requirementChip(LiveScholarshipModel s) {
  if (s.isAutomaticAdmission) {
    return (
      _Palette.greenBg,
      _Palette.green,
      'live_scholarships_requirement_automatic'.tr
    );
  }
  return (
    _Palette.chipBg,
    _Palette.blue,
    'live_scholarships_requirement_separate_application'.tr
  );
}

Future<void> _launchUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri != null && await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Live scholarship index screen — fetches from the scraped /scholarships API.
/// Displays scholarships filtered and ranked by the user's profile.
class LiveScholarshipsScreen extends StatefulWidget {
  /// Optional [apiClient] for tests; production uses [AppApiClient] when null.
  const LiveScholarshipsScreen({super.key, this.apiClient});

  final AppApiClient? apiClient;

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
      final client = widget.apiClient ?? AppApiClient();
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
    return Scaffold(
      backgroundColor: _Palette.page,
      body: SafeArea(
        child: KpbRefresh(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              // ── App bar ────────────────────────────────────────────────────
              SliverAppBar(
                floating: true,
                snap: true,
                backgroundColor: _Palette.page,
                surfaceTintColor: _Palette.page,
                elevation: 0,
                automaticallyImplyLeading: false,
                leading: Navigator.canPop(context)
                    ? IconButton(
                        tooltip: 'a11y_back'.tr,
                        icon: const Icon(Icons.arrow_back_rounded,
                            size: 20, color: _Palette.navy),
                        onPressed: () => Navigator.pop(context),
                      )
                    : null,
                title: Text(
                  'scholarships_title'.tr,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: _Palette.navy,
                  ),
                ),
                actions: [
                  IconButton(
                    tooltip: 'a11y_refresh'.tr,
                    icon: const Icon(Icons.refresh_rounded,
                        color: _Palette.slate),
                    onPressed: _load,
                  ),
                ],
              ),

              // ── Sub-header + filters ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'scholarships_sorted_hint'.tr,
                        style: const TextStyle(
                            fontSize: 11.5, color: _Palette.slate, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FilterChip(
                              label: 'live_scholarships_filter_all'.tr,
                              active: _fundingFilter == 'all',
                              onTap: () => _applyFilter('all'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'live_scholarships_filter_fully_funded'.tr,
                              active: _fundingFilter == 'fully_funded',
                              onTap: () => _applyFilter('fully_funded'),
                            ),
                            const SizedBox(width: 8),
                            _FilterChip(
                              label: 'live_scholarships_filter_partially_funded'
                                  .tr,
                              active: _fundingFilter == 'partially_funded',
                              onTap: () => _applyFilter('partially_funded'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Content ──────────────────────────────────────────────────────
              if (_loading)
                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
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
                        bgColor: _Palette.blue,
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
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      'live_scholarships_result_count'
                          .trParams({'count': '${_items.length}'}),
                      style: const TextStyle(
                          fontSize: 11, color: _Palette.slate400),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final s = _items[index];
                        return StaggeredSlide(
                          index: index,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LiveScholarshipCard(
                              scholarship: s,
                              onTap: () => _openDetail(context, s),
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

  void _applyFilter(String value) {
    setState(() {
      _fundingFilter = value;
      _load();
    });
  }

  static Widget _buildShimmerCard(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ShimmerCard(delay: index * 70),
    );
  }

  void _openDetail(BuildContext context, LiveScholarshipModel s) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.97,
        builder: (_, sc) =>
            _LiveScholarshipDetail(scholarship: s, scrollController: sc),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List row (handoff "Scholarships")
// ─────────────────────────────────────────────────────────────────────────────
class _LiveScholarshipCard extends StatelessWidget {
  const _LiveScholarshipCard({required this.scholarship, required this.onTap});

  final LiveScholarshipModel scholarship;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final deadline = _deadlineBadge(s);
    final (fundBg, fundFg, fundLabel) = _fundingChip(s);
    final subtitle =
        s.level.isEmpty ? s.countryName : '${s.countryName} · ${s.level}';

    return Material(
      color: _Palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _Palette.card,
            border: Border.all(color: _Palette.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_flag(s.countryName), style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _Palette.navy,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style:
                          const TextStyle(fontSize: 11, color: _Palette.slate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (deadline != null)
                          _pill(deadline.text, deadline.bg, deadline.fg)
                        else
                          _pill(
                            s.deadlineLabel.isEmpty
                                ? 'live_scholarships_no_deadline'.tr
                                : s.deadlineLabel,
                            _Palette.line,
                            _Palette.slate,
                          ),
                        if (deadline?.soon ?? false)
                          _pill('live_scholarships_deadline_soon'.tr,
                              _Palette.amberSolid, Colors.white),
                        _pill(fundLabel, fundBg, fundFg),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SaveButton(scholarship: s, size: 34),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sheet (handoff "Fiche bourse")
// ─────────────────────────────────────────────────────────────────────────────
class _LiveScholarshipDetail extends StatelessWidget {
  const _LiveScholarshipDetail({
    required this.scholarship,
    required this.scrollController,
  });

  final LiveScholarshipModel scholarship;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final deadline = _deadlineBadge(s);
    final (_, fundFg, fundLabel) = _fundingChip(s);
    final (reqBg, reqFg, reqLabel) = _requirementChip(s);

    final deadlineValue = deadline != null
        ? deadline.text
        : (s.deadlineLabel.isEmpty
            ? 'live_scholarships_see_official_site'.tr
            : s.deadlineLabel);
    final deadlineColor = deadline?.fg ?? _Palette.slate;

    return Container(
      decoration: const BoxDecoration(
        color: _Palette.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: _Palette.border,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // ── Header ───────────────────────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(_flag(s.countryName), style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: _Palette.navy,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.countryName,
                      style:
                          const TextStyle(fontSize: 11, color: _Palette.slate),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _SaveButton(scholarship: s, size: 38),
            ],
          ),
          const SizedBox(height: 14),

          // ── AMOUNT / DEADLINE grid ─────────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'live_scholarships_funding_tile'.tr,
                    value: fundLabel,
                    valueColor: fundFg,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatTile(
                    label: 'live_scholarships_deadline_label'.tr,
                    value: deadlineValue,
                    valueColor: deadlineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Requirement chip + level + "why" ───────────────────────────────
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _Palette.card,
              border: Border.all(color: _Palette.border),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _cardShadow,
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _pill(reqLabel, reqBg, reqFg, big: true),
                    if (s.level.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          s.level,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _Palette.navy,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
                if (s.description.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    s.description,
                    style: const TextStyle(
                        fontSize: 12, height: 1.6, color: _Palette.body),
                  ),
                ],
              ],
            ),
          ),

          // ── Benefits ───────────────────────────────────────────────────────
          if (s.advantages.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionCard(
              title: 'live_scholarships_section_advantages'.tr,
              children: s.advantages
                  .map((a) => _BulletItem(text: a, color: _Palette.green))
                  .toList(),
            ),
          ],

          // ── Eligibility criteria (real list, not a verdict) ────────────────
          if (s.eligibility.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionCard(
              title: 'live_scholarships_section_eligibility'.tr,
              children: s.eligibility
                  .map((e) => _BulletItem(text: e, color: _Palette.blue))
                  .toList(),
            ),
          ],

          // ── How to apply ───────────────────────────────────────────────────
          if (s.applicationSteps.isNotEmpty) ...[
            const SizedBox(height: 10),
            _SectionCard(
              title: 'live_scholarships_section_application_steps'.tr,
              children: [
                ApplicationStepsTimeline(
                    steps: s.applicationSteps, accent: _Palette.blue),
              ],
            ),
          ],

          const SizedBox(height: 16),

          // ── CTAs ───────────────────────────────────────────────────────────
          if (s.applicationUrl.isNotEmpty) ...[
            _PrimaryButton(
              label: 'live_scholarships_official_form'.tr,
              icon: Icons.open_in_new_rounded,
              onTap: () => _launchUrl(s.applicationUrl),
            ),
            const SizedBox(height: 10),
          ],
          _SecondaryButton(
            label: 'live_scholarships_apply_with_kpb'.tr,
            onTap: () {
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
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ─────────────────────────────────────────────────────

Widget _pill(String text, Color bg, Color fg, {bool big = false}) {
  return Container(
    padding:
        EdgeInsets.symmetric(horizontal: big ? 10 : 8, vertical: big ? 3 : 2),
    decoration:
        BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
    child: Text(
      text,
      style: TextStyle(
        fontSize: big ? 10.5 : 9.5,
        fontWeight: FontWeight.w800,
        color: fg,
      ),
    ),
  );
}

/// Round trailing toggle. The handoff shows a "bell" push-reminder toggle here,
/// but no per-scholarship reminder mechanism exists in the app (OneSignal only
/// carries global user tags), so we bind this slot to the REAL, persisted
/// save/bookmark action instead of rendering a fake reminder toggle.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.scholarship, required this.size});

  final LiveScholarshipModel scholarship;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final saved =
            controller.isSaved(SavedItemType.scholarship, scholarship.id);
        return Semantics(
          button: true,
          label: 'a11y_save'.tr,
          child: Material(
            color: saved ? _Palette.chipBg : _Palette.card,
            shape: CircleBorder(
              side: BorderSide(
                  color: saved ? _Palette.chipBorder : _Palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => controller.toggleSaved(
                  SavedItemType.scholarship, scholarship.id),
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_outline_rounded,
                  size: size * 0.52,
                  color: saved ? _Palette.blue : _Palette.slate400,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _Palette.blue : _Palette.card,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: active ? _Palette.blue : _Palette.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _Palette.slate,
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
  });
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.card,
        border: Border.all(color: _Palette.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: _Palette.slate400,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _Palette.card,
        border: Border.all(color: _Palette.border),
        borderRadius: BorderRadius.circular(16),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: _Palette.navy,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
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
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1, right: 10),
            child: Icon(Icons.check_circle_rounded, size: 17, color: color),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12.5, height: 1.5, color: _Palette.body),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _Palette.blue,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
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

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _Palette.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: _Palette.card,
            border: Border.all(color: _Palette.border),
            borderRadius: BorderRadius.circular(16),
          ),
          child: SizedBox(
            height: 50,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: _Palette.navy,
                ),
              ),
            ),
          ),
        ),
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
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) {
        final block =
            Color.lerp(_Palette.lineSoft, _Palette.border, _anim.value)!;
        return Container(
          height: 92,
          decoration: BoxDecoration(
            color: _Palette.card,
            border: Border.all(color: _Palette.border),
            borderRadius: BorderRadius.circular(16),
            boxShadow: _cardShadow,
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: block,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 10,
                      width: 140,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 90,
                      decoration: BoxDecoration(
                        color: block,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: block, shape: BoxShape.circle),
              ),
            ],
          ),
        );
      },
    );
  }
}
