// Conseiller / Commercial surface (App-engagement handoff · Commercial App.dc.html).
//
// A 3-tab surface for a KPB counsellor: Leads WhatsApp / Dossiers / Performance,
// plus a pushed lead-detail screen. Rebuilt in the handoff's navy #0F172A +
// blue #2563EB system.
//
// Binds the REAL commercial data already exposed by _CommercialMixin
// (CommercialLead + CommercialStats). Fields the backend doesn't provide (the
// verbatim WhatsApp message, per-doc review, 10-step progress) are omitted —
// the surface shows only real lead data + honest empty states. The counsellor
// replies on WhatsApp and converts a lead via the existing lead-tag endpoint.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/utils/whatsapp_utils.dart';

class _C {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFDBEAFE);
  static const green = Color(0xFF16A34A);
  static const greenSoft = Color(0xFFDCFCE7);
  static const sky = Color(0xFF0EA5E9);
  static const skySoft = Color(0xFFE0F2FE);
  static const cyan = Color(0xFF38BDF8);
  static const amber = Color(0xFFB45309);
  static const amberSoft = Color(0xFFFEF3C7);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEE2E2);
  static const whatsapp = Color(0xFF25D366);
  static const page = Color(0xFFF8FAFC);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const ink = Color(0xFF0F172A);
  static const border = Color(0xFFE2E8F0);
  static const track = Color(0xFFF1F5F9);

  static const _avatars = [
    Color(0xFF2563EB),
    Color(0xFF16A34A),
    Color(0xFF6366F1),
    Color(0xFFB45309),
    Color(0xFF0EA5E9),
    Color(0xFFDC2626),
  ];
  static Color avatar(String seed) {
    var h = 0;
    for (final ch in seed.codeUnits) {
      h = (h * 31 + ch) & 0x7fffffff;
    }
    return _avatars[h % _avatars.length];
  }
}

String _initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '•';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// Relative age from a timestamp ("il y a 25 min" / "il y a 2 h" / "il y a 3 j").
String _age(DateTime dt) {
  final d = DateTime.now().difference(dt);
  if (d.inMinutes < 60) {
    return 'commercial_age_min'.trParams({'n': '${d.inMinutes.clamp(1, 59)}'});
  }
  if (d.inHours < 24) {
    return 'commercial_age_hour'.trParams({'n': '${d.inHours}'});
  }
  return 'commercial_age_day'.trParams({'n': '${d.inDays}'});
}

/// A lead's tag → chip label + colors + whether it counts as "hot" (needs reply).
class _TagStyle {
  const _TagStyle(this.label, this.bg, this.fg, this.darkBg, this.darkFg);
  final String label;
  final Color bg;
  final Color fg;
  final Color darkBg;
  final Color darkFg;
}

_TagStyle _tagStyle(String? tag) {
  switch (tag) {
    case 'converted':
      return const _TagStyle('commercial_tag_converted', _C.greenSoft, _C.green,
          Color(0x4D16A34A), Color(0xFF4ADE80));
    case 'qualified':
      return const _TagStyle('commercial_tag_qualified', _C.skySoft, _C.sky,
          Color(0x380EA5E9), Color(0xFFBAE6FD));
    default: // 'new' / null → needs a first reply
      return const _TagStyle('commercial_tag_new', _C.redSoft, _C.red,
          Color(0x40DC2626), Color(0xFFFCA5A5));
  }
}

bool _needsReply(CommercialLead l) => l.leadTag == null || l.leadTag == 'new';

class CommercialSurfaceScreen extends StatefulWidget {
  const CommercialSurfaceScreen({super.key});

  @override
  State<CommercialSurfaceScreen> createState() =>
      _CommercialSurfaceScreenState();
}

class _CommercialSurfaceScreenState extends State<CommercialSurfaceScreen> {
  final _ctrl = Get.find<AppController>();
  int _tab = 0;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.fetchCommercialLeads();
      _ctrl.fetchCommercialStats();
    });
  }

  Future<void> _refresh() async {
    await _ctrl.fetchCommercialLeads();
    await _ctrl.fetchCommercialStats();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.page,
      body: GetBuilder<AppController>(
        builder: (c) {
          final leads = c.commercialLeads;
          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: SingleChildScrollView(
                    key: PageStorageKey<int>(_tab),
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: switch (_tab) {
                      1 => _CasesTab(
                          leads: leads
                              .where((l) => !_needsReply(l))
                              .toList(growable: false),
                          loading: c.isLoadingCommercialLeads,
                          onOpen: _openLead),
                      2 => _PerformanceTab(
                          advisorName: c.profile?.fullName ?? 'Conseiller',
                          stats: c.commercialStats,
                          leads: leads),
                      _ => _LeadsTab(
                          leads: leads,
                          filter: _filter,
                          loading: c.isLoadingCommercialLeads,
                          error: c.commercialLeadsError,
                          onFilter: (f) => setState(() => _filter = f),
                          onOpen: _openLead,
                          onRetry: _refresh),
                    },
                  ),
                ),
              ),
              _BottomNav(
                current: _tab,
                newCount: leads.where(_needsReply).length,
                onTap: (i) => setState(() => _tab = i),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openLead(CommercialLead lead) {
    Get.to(() => CommercialLeadDetailScreen(lead: lead));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Leads WhatsApp
// ─────────────────────────────────────────────────────────────────────────────

class _LeadsTab extends StatelessWidget {
  const _LeadsTab({
    required this.leads,
    required this.filter,
    required this.loading,
    required this.error,
    required this.onFilter,
    required this.onOpen,
    required this.onRetry,
  });
  final List<CommercialLead> leads;
  final String filter;
  final bool loading;
  final String? error;
  final ValueChanged<String> onFilter;
  final void Function(CommercialLead) onOpen;
  final Future<void> Function() onRetry;

  int _count(String f) => switch (f) {
        'new' => leads.where(_needsReply).length,
        'qualified' => leads.where((l) => l.leadTag == 'qualified').length,
        'converted' => leads.where((l) => l.leadTag == 'converted').length,
        _ => leads.length,
      };

  List<CommercialLead> get _filtered => switch (filter) {
        'new' => leads.where(_needsReply).toList(),
        'qualified' => leads.where((l) => l.leadTag == 'qualified').toList(),
        'converted' => leads.where((l) => l.leadTag == 'converted').toList(),
        _ => leads,
      };

  @override
  Widget build(BuildContext context) {
    final newCount = _count('new');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('commercial_leads_title'.tr,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 2),
          Text('commercial_leads_sub'.trParams({'n': '$newCount'}),
              style: const TextStyle(fontSize: 11.5, color: _C.slate)),
          const SizedBox(height: 12),
          // SLA banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: _C.amberSoft,
              border: Border.all(color: const Color(0xFFFDE68A)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 17, color: _C.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('commercial_sla'.trParams({'n': '$newCount'}),
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF92400E))),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Filter chips
          SizedBox(
            height: 34,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in const [
                  'all',
                  'new',
                  'qualified',
                  'converted'
                ]) ...[
                  _FilterChip(
                    label: '${'commercial_filter_$f'.tr} (${_count(f)})',
                    selected: filter == f,
                    onTap: () => onFilter(f),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loading && leads.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (error != null && leads.isEmpty)
            _ErrorState(message: error!, onRetry: onRetry)
          else if (_filtered.isEmpty)
            _EmptyHint(
                icon: Icons.inbox_outlined, textKey: 'commercial_leads_empty')
          else
            for (final l in _filtered) ...[
              _LeadCard(lead: l, onTap: () => onOpen(l)),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  const _LeadCard({required this.lead, required this.onTap});
  final CommercialLead lead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = _tagStyle(lead.leadTag);
    final hot = _needsReply(lead);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _C.avatar(lead.studentName),
                      shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Text(_initials(lead.studentName),
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800)),
                ),
                if (lead.unreadMessages > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: _C.red,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text('${lead.unreadMessages}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.studentName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: _C.ink)),
                  if ((lead.studentLevel ?? lead.title).isNotEmpty)
                    Text(lead.studentLevel ?? lead.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: _C.slate)),
                  const SizedBox(height: 3),
                  Text(_age(lead.updatedAt),
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: hot ? _C.red : _C.slate400)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: s.bg, borderRadius: BorderRadius.circular(100)),
              child: Text(s.label.tr,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w800, color: s.fg)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Lead detail (pushed)
// ─────────────────────────────────────────────────────────────────────────────

class CommercialLeadDetailScreen extends StatefulWidget {
  const CommercialLeadDetailScreen({super.key, required this.lead});
  final CommercialLead lead;

  @override
  State<CommercialLeadDetailScreen> createState() =>
      _CommercialLeadDetailScreenState();
}

class _CommercialLeadDetailScreenState
    extends State<CommercialLeadDetailScreen> {
  final _ctrl = Get.find<AppController>();
  late String _tag = widget.lead.leadTag ?? 'new';
  bool _converting = false;

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: _C.navy,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _convert() async {
    if (_tag == 'converted' || _converting) return;
    setState(() => _converting = true);
    try {
      await _ctrl.updateCommercialLeadTag(widget.lead.id, leadTag: 'converted');
      if (!mounted) return;
      setState(() => _tag = 'converted');
      _toast('commercial_converted_toast'
          .trParams({'name': widget.lead.studentName}));
    } catch (_) {
      _toast('commercial_convert_error'.tr);
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  void _replyWhatsApp() {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill:
          'commercial_wa_reply'.trParams({'name': widget.lead.studentName}),
      source: 'commercial_surface',
      contextType: 'commercial_reply',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lead = widget.lead;
    final s = _tagStyle(_tag);
    final profil = <({String k, String v})>[
      if ((lead.studentLevel ?? '').isNotEmpty)
        (k: 'commercial_field_level'.tr, v: lead.studentLevel!),
      if (lead.referenceCode.isNotEmpty)
        (k: 'commercial_field_ref'.tr, v: lead.referenceCode),
      if (lead.title.isNotEmpty) (k: 'commercial_field_case'.tr, v: lead.title),
      (k: 'commercial_field_status'.tr, v: _caseStatusLabel(lead.status)),
    ];

    return Scaffold(
      backgroundColor: _C.page,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Navy header
          Container(
            color: _C.navy,
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 10, 16, 18),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Get.back<void>(),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            shape: BoxShape.circle),
                        child: const Icon(Icons.arrow_back,
                            size: 19, color: Colors.white),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                          color: s.darkBg,
                          borderRadius: BorderRadius.circular(100)),
                      child: Text(s.label.tr,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: s.darkFg)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                          color: _C.avatar(lead.studentName),
                          shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(_initials(lead.studentName),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(lead.studentName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          if (lead.title.isNotEmpty)
                            Text(lead.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _C.slate400, fontSize: 11.5)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      flex: 13,
                      child: GestureDetector(
                        onTap: _replyWhatsApp,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                              color: _C.whatsapp,
                              borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.chat,
                                  size: 16, color: Colors.white),
                              const SizedBox(width: 6),
                              Text('commercial_reply_wa'.tr,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 10,
                      child: GestureDetector(
                        onTap: _convert,
                        child: Container(
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (_converting)
                                const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              else ...[
                                Icon(
                                    _tag == 'converted'
                                        ? Icons.check_circle
                                        : Icons.workspace_premium,
                                    size: 15,
                                    color: const Color(0xFF4ADE80)),
                                const SizedBox(width: 6),
                                Text(
                                    _tag == 'converted'
                                        ? 'commercial_signed'.tr
                                        : 'commercial_mark_signed'.tr,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: _C.border),
                        borderRadius: BorderRadius.circular(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('commercial_profile_title'.tr,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: _C.ink)),
                        const SizedBox(height: 10),
                        for (final p in profil)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.k,
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        color: _C.slate400)),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(p.v,
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: _C.ink)),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  if ((lead.discussionMotive ?? '').isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                          color: _C.amberSoft,
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.flag_rounded,
                              size: 15, color: _C.amber),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(lead.discussionMotive!,
                                style: const TextStyle(
                                    fontSize: 11,
                                    height: 1.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Dossiers (active leads: qualified / converted)
// ─────────────────────────────────────────────────────────────────────────────

class _CasesTab extends StatelessWidget {
  const _CasesTab({
    required this.leads,
    required this.loading,
    required this.onOpen,
  });
  final List<CommercialLead> leads;
  final bool loading;
  final void Function(CommercialLead) onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('commercial_cases_title'.tr,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _C.ink)),
          const SizedBox(height: 2),
          Text('commercial_cases_sub'.trParams({'n': '${leads.length}'}),
              style: const TextStyle(fontSize: 11.5, color: _C.slate)),
          const SizedBox(height: 14),
          if (loading && leads.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (leads.isEmpty)
            _EmptyHint(
                icon: Icons.folder_open_outlined,
                textKey: 'commercial_cases_empty')
          else
            for (final l in leads) ...[
              GestureDetector(
                onTap: () => onOpen(l),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: _C.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            color: _C.avatar(l.studentName),
                            shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(_initials(l.studentName),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.studentName,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _C.ink)),
                            if (l.title.isNotEmpty)
                              Text(l.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11, color: _C.slate)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: _C.blueSoft,
                            borderRadius: BorderRadius.circular(100)),
                        child: Text(_caseStatusLabel(l.status),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: _C.blue)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Performance
// ─────────────────────────────────────────────────────────────────────────────

class _PerformanceTab extends StatelessWidget {
  const _PerformanceTab({
    required this.advisorName,
    required this.stats,
    required this.leads,
  });
  final String advisorName;
  final CommercialStats stats;
  final List<CommercialLead> leads;

  @override
  Widget build(BuildContext context) {
    // Real breakdown by lead tag, computed from the fetched leads.
    final byTag = <String, int>{};
    for (final l in leads) {
      final t = l.leadTag ?? 'new';
      byTag[t] = (byTag[t] ?? 0) + 1;
    }
    final total = leads.isEmpty ? 1 : leads.length;
    final order = ['new', 'qualified', 'converted']
        .where((t) => (byTag[t] ?? 0) > 0)
        .toList();

    final avg = stats.avgFirstResponseMinutes;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration:
                    const BoxDecoration(color: _C.navy, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(_initials(advisorName),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(advisorName,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: _C.ink)),
                    Text('commercial_perf_role'.tr,
                        style:
                            const TextStyle(fontSize: 11.5, color: _C.slate)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      value: '${stats.totalLeads}',
                      label: 'commercial_stat_total'.tr,
                      color: _C.ink)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(
                      value: '${stats.convertedLast30Days}',
                      label: 'commercial_stat_converted'.tr,
                      color: _C.green)),
              const SizedBox(width: 8),
              Expanded(
                  child: _StatCard(
                      value: avg == null ? '—' : _fmtDuration(avg),
                      label: 'commercial_stat_response'.tr,
                      color: _C.blue)),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: _C.border),
                borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('commercial_perf_breakdown'.tr,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _C.ink)),
                const SizedBox(height: 12),
                if (order.isEmpty)
                  Text('commercial_perf_empty'.tr,
                      style: const TextStyle(fontSize: 12, color: _C.slate))
                else
                  for (final t in order) ...[
                    _BreakdownRow(
                      label: 'commercial_tag_$t'.tr,
                      count: byTag[t]!,
                      ratio: byTag[t]! / total,
                    ),
                    if (t != order.last) const SizedBox(height: 10),
                  ],
                const SizedBox(height: 10),
                Text('commercial_perf_note'.tr,
                    style: const TextStyle(
                        fontSize: 10.5, height: 1.5, color: _C.slate400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    return '$h h';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: _C.border),
          borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 3),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: _C.slate400)),
        ],
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow(
      {required this.label, required this.count, required this.ratio});
  final String label;
  final int count;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _C.ink)),
            ),
            Text('$count',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _C.slate)),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: ratio.clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: _C.track,
            valueColor: const AlwaysStoppedAnimation(_C.cyan),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

String _caseStatusLabel(String status) {
  final key = 'case_status_$status';
  final label = key.tr;
  return label == key ? status : label;
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFEFF6FF) : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? _C.blue : _C.border, width: 1.5),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: selected ? _C.blue : _C.slate)),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.icon, required this.textKey});
  final IconData icon;
  final String textKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(icon, size: 34, color: _C.slate400),
          const SizedBox(height: 10),
          Text(textKey.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _C.slate)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.wifi_off_rounded, size: 40, color: _C.slate400),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => onRetry(),
            icon: const Icon(Icons.refresh_rounded),
            label: Text('retry'.tr),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav(
      {required this.current, required this.newCount, required this.onTap});
  final int current;
  final int newCount;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (icon: Icons.chat_rounded, key: 'commercial_nav_leads', badge: newCount),
      (icon: Icons.folder_copy_rounded, key: 'commercial_nav_cases', badge: 0),
      (icon: Icons.insights_rounded, key: 'commercial_nav_perf', badge: 0),
    ];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _C.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          4, 6, 4, 10 + MediaQuery.of(context).padding.bottom * 0.5),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 52,
                          height: 28,
                          decoration: BoxDecoration(
                            color:
                                current == i ? _C.blueSoft : Colors.transparent,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Icon(items[i].icon,
                              size: 20,
                              color: current == i ? _C.blue : _C.slate400),
                        ),
                        if (items[i].badge > 0 && current != i)
                          Positioned(
                            right: 6,
                            top: -3,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                  color: _C.red,
                                  borderRadius: BorderRadius.circular(9)),
                              child: Text('${items[i].badge}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(items[i].key.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: current == i
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: current == i ? _C.blue : _C.slate400)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
