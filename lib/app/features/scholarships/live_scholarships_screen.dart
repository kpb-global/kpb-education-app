import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/repositories/app_api_client.dart';
import '../../core/ui/kpb_components.dart';
import 'scholarship_detail_screen.dart';
import 'scholarship_guide_info_screen.dart';
import 'scholarships_controller.dart';
import 'widgets/scholarship_alert_button.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · "Scholarships" / "Fiche bourse").
// Local to this file — same pattern as Home / Onboarding / Comparateur (#110–115).
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
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

String _shortDate(DateTime date) {
  final local = date.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

(String, Color, Color)? _cyclePill(LiveScholarshipModel scholarship) {
  final cycle = scholarship.currentCycle;
  if (cycle == null) return null;
  if (cycle.isOpen) {
    final closing = cycle.closesAt ?? cycle.estimatedCloseAt;
    if (closing != null && closing.isBefore(DateTime.now())) {
      return (
        'live_scholarships_deadline_closed'.tr,
        _Palette.line,
        _Palette.slate,
      );
    }
    return (
      'live_scholarships_open_now'.tr,
      _Palette.greenBg,
      _Palette.green,
    );
  }
  final estimatedOpen = cycle.estimatedOpenAt ?? cycle.opensAt;
  final estimatedClose = cycle.estimatedCloseAt ?? cycle.closesAt;
  if (estimatedOpen != null && estimatedClose != null) {
    return (
      'live_scholarships_period_estimated'.trParams({
        'open': _shortDate(estimatedOpen),
        'close': _shortDate(estimatedClose),
      }),
      _Palette.amberBg,
      _Palette.amber,
    );
  }
  if (estimatedOpen != null) {
    return (
      'live_scholarships_open_estimated'
          .trParams({'date': _shortDate(estimatedOpen)}),
      _Palette.amberBg,
      _Palette.amber,
    );
  }
  return null;
}

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
  late final ScholarshipsController _scholarshipsController;
  final ScrollController _paginationController = ScrollController();

  List<LiveScholarshipModel> get _items => _scholarshipsController.items;
  bool get _loading => _scholarshipsController.loading;
  String? get _error => _scholarshipsController.error;
  String get _fundingFilter => _scholarshipsController.fundingFilter;
  Set<String> get _alertedScholarshipIds =>
      _scholarshipsController.alertedScholarshipIds;

  @override
  void initState() {
    super.initState();
    final appController = Get.find<AppController>();
    final profile = appController.profile;
    _scholarshipsController = ScholarshipsController(
      apiClient: widget.apiClient ?? appController.apiClient,
      lang: profile?.preferredLanguage == 'en' ? 'en' : 'fr',
      level: profile?.targetLevel,
      fieldIds: profile?.fieldIds,
    )..addListener(_onScholarshipsChanged);
    _paginationController.addListener(_onScroll);
    _scholarshipsController.loadInitial();
  }

  void _onScholarshipsChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_paginationController.hasClients) return;
    if (_paginationController.position.extentAfter < 500) {
      _scholarshipsController.loadMore();
    }
  }

  Future<void> _load() => _scholarshipsController.loadInitial();

  @override
  void dispose() {
    _paginationController
      ..removeListener(_onScroll)
      ..dispose();
    _scholarshipsController
      ..removeListener(_onScholarshipsChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Palette.page,
      body: SafeArea(
        child: KpbRefresh(
          onRefresh: _load,
          child: CustomScrollView(
            controller: _paginationController,
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  child: _GuidePromoCard(
                    onTap: () =>
                        Get.to(() => const ScholarshipGuideInfoScreen()),
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
                              alertEnabled:
                                  _alertedScholarshipIds.contains(s.id),
                              apiClient: widget.apiClient,
                              onAlertChanged: (enabled) =>
                                  _setAlertState(s.id, enabled),
                              onTap: () => _openDetail(context, s),
                            ),
                          ),
                        );
                      },
                      childCount: _items.length,
                    ),
                  ),
                ),
                if (_scholarshipsController.loadingMore)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
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
    _scholarshipsController.changeFundingFilter(value);
  }

  static Widget _buildShimmerCard(BuildContext context, int index) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _ShimmerCard(delay: index * 70),
    );
  }

  void _openDetail(BuildContext context, LiveScholarshipModel s) {
    Get.to(
      () => ScholarshipDetailScreen(
        scholarshipId: s.id,
        initialScholarship: s,
        initialAlertEnabled: _alertedScholarshipIds.contains(s.id),
        apiClient: widget.apiClient,
        onAlertChanged: (enabled) => _setAlertState(s.id, enabled),
      ),
      routeName: AppRoutes.scholarshipDetailPath(s.id),
    );
  }

  void _setAlertState(String scholarshipId, bool enabled) {
    _scholarshipsController.setAlertState(scholarshipId, enabled);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// List row (handoff "Scholarships")
// ─────────────────────────────────────────────────────────────────────────────
class _LiveScholarshipCard extends StatelessWidget {
  const _LiveScholarshipCard({
    required this.scholarship,
    required this.alertEnabled,
    required this.onAlertChanged,
    required this.onTap,
    this.apiClient,
  });

  final LiveScholarshipModel scholarship;
  final bool alertEnabled;
  final ValueChanged<bool> onAlertChanged;
  final VoidCallback onTap;
  final AppApiClient? apiClient;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final deadline = _deadlineBadge(s);
    final (fundBg, fundFg, fundLabel) = _fundingChip(s);
    final cycle = _cyclePill(s);
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
                        if (cycle != null) _pill(cycle.$1, cycle.$2, cycle.$3),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ScholarshipAlertButton(
                scholarshipId: s.id,
                scholarshipTitle: s.title,
                initialEnabled: alertEnabled,
                apiClient: apiClient,
                onChanged: onAlertChanged,
                compact: true,
              ),
            ],
          ),
        ),
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

class _GuidePromoCard extends StatelessWidget {
  const _GuidePromoCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('scholarship_guide_promo'),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEFF6FF), Color(0xFFFFFFFF)],
        ),
        border: Border.all(color: _Palette.chipBorder),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 52,
            decoration: BoxDecoration(
              color: _Palette.blue,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.auto_stories_rounded,
                color: Colors.white, size: 23),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'scholarship_guide_short_title'.tr,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _Palette.navy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'scholarship_guide_promo_body'.tr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    height: 1.4,
                    color: _Palette.slate,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            child: Text('scholarship_guide_learn_more'.tr),
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
