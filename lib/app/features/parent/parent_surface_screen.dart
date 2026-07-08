// Parent surface (App-engagement handoff · Parent App.dc.html).
//
// A 4-tab read-only surface for a parent linked to their child: Vue d'ensemble
// / Dossier & finances / Actualités / Paiements. Recreated in the handoff's
// navy #0F172A + blue #2563EB system. Central theme: the parent sees a
// read-only view and the STUDENT controls what is shared (case-level
// visibility, mapped to the design's doc/message gates).
//
// Payments respect the app-wide "no in-app checkout" rule: the Paiements tab
// routes to the KPB advisor on WhatsApp instead of charging a card in-app.

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/utils/whatsapp_utils.dart';

class _P {
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
  static const infoBg = Color(0xFFEFF6FF);
  static const infoBorder = Color(0xFFBFDBFE);
  static const infoText = Color(0xFF1E40AF);
}

/// A shared-case document row (status → chip).
class _Doc {
  const _Doc(this.name, this.status);
  final String name;
  final String status; // ok | review | required
}

/// Normalized data the surface renders — real values overlaid on the design's
/// sample where the parent endpoints don't (yet) provide a field.
class _ParentData {
  _ParentData({
    required this.isSample,
    required this.parentName,
    required this.childName,
    required this.childInitials,
    required this.completion,
    required this.caseTitle,
    required this.caseSubtitle,
    required this.stepsDone,
    required this.stepsTotal,
    required this.docsShared,
    required this.docs,
    required this.messagesShared,
  });

  final bool isSample;
  final String parentName;
  final String childName;
  final String childInitials;
  final int completion; // 0..100
  final String caseTitle;
  final String caseSubtitle;
  final int stepsDone;
  final int stepsTotal;
  final bool docsShared;
  final List<_Doc> docs;
  final bool messagesShared;

  static _ParentData sample() => _ParentData(
        isSample: true,
        parentName: 'M. Diallo',
        childName: 'Aïcha',
        childInitials: 'AD',
        completion: 60,
        caseTitle: 'Université Grenoble Alpes 🇫🇷',
        caseSubtitle: 'M1 Économie',
        stepsDone: 3,
        stepsTotal: 10,
        docsShared: true,
        docs: const [
          _Doc('Bulletins de Licence', 'ok'),
          _Doc('Passeport (copie)', 'ok'),
          _Doc('Lettre de motivation', 'review'),
          _Doc('CV académique', 'required'),
        ],
        messagesShared: false,
      );
}

class ParentSurfaceScreen extends StatefulWidget {
  const ParentSurfaceScreen({super.key});

  @override
  State<ParentSurfaceScreen> createState() => _ParentSurfaceScreenState();
}

class _ParentSurfaceScreenState extends State<ParentSurfaceScreen> {
  final _api = Get.find<AppController>().apiClient;
  final _codeController = TextEditingController();

  bool _loading = true;
  bool _linking = false;
  String? _error;
  List<dynamic> _children = const [];
  List<dynamic> _cases = const [];
  int _tab = 0;

  bool get _linked => _children.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.listParentChildren(),
        _api.listParentVisibleCases(),
      ]);
      if (!mounted) return;
      setState(() {
        _children = results[0];
        _cases = results[1];
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'parent_load_error'.tr;
        _loading = false;
      });
    }
  }

  Future<void> _link() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _toast('parent_enter_code'.tr);
      return;
    }
    setState(() => _linking = true);
    try {
      await _api.acceptParentInvite(code);
      _toast('parent_linked_ok'.tr);
      await _refresh();
    } catch (_) {
      _toast('parent_link_error'.tr);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: _P.navy,
        behavior: SnackBarBehavior.floating,
      ));
  }

  void _whatsapp(String prefill, String contextType) {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill: prefill,
      source: 'parent_surface',
      contextType: contextType,
    );
  }

  /// Build the render data from real child/case, falling back to the sample.
  _ParentData _data() {
    if (!_linked) return _ParentData.sample();
    final child = (_children.first as Map)['child'] as Map? ?? const {};
    final childName = (child['fullName'] as String?)?.trim();
    final firstCase =
        _cases.isNotEmpty ? _cases.first as Map<String, dynamic> : null;
    if (childName == null || childName.isEmpty) return _ParentData.sample();

    final sample = _ParentData.sample();
    final first = childName.split(RegExp(r'\s+')).first;
    return _ParentData(
      isSample: false,
      parentName: 'parent_greeting_generic'.tr,
      childName: first,
      childInitials: _initials(childName),
      completion: sample.completion,
      caseTitle: firstCase?['title'] as String? ?? sample.caseTitle,
      caseSubtitle:
          (firstCase?['contextLabel'] as String?) ?? sample.caseSubtitle,
      stepsDone: sample.stepsDone,
      stepsTotal: sample.stepsTotal,
      docsShared: firstCase != null,
      docs: sample.docs,
      messagesShared: false,
    );
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '👤';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: _P.page,
        appBar: AppBar(
            title: Text('parent_appbar'.tr),
            backgroundColor: Colors.transparent),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_linked && _error == null) {
      return Scaffold(
        backgroundColor: _P.page,
        appBar: AppBar(
            title: Text('parent_appbar'.tr),
            backgroundColor: Colors.transparent),
        body: _OnboardingLink(
          controller: _codeController,
          linking: _linking,
          onLink: _link,
        ),
      );
    }

    final d = _data();
    return Scaffold(
      backgroundColor: _P.page,
      appBar: AppBar(
          title: Text('parent_appbar'.tr), backgroundColor: Colors.transparent),
      body: Column(
        children: [
          if (d.isSample) const _SampleBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: SingleChildScrollView(
                key: PageStorageKey<int>(_tab),
                physics: const AlwaysScrollableScrollPhysics(),
                child: switch (_tab) {
                  1 => _CaseTab(d: d, onAskAccess: () => _whatsapp(
                      'parent_wa_ask_access'.tr, 'parent_ask_access'),
                      onUploadProof: () =>
                          _whatsapp('parent_wa_upload'.tr, 'parent_upload')),
                  2 => _UpdatesTab(
                      d: d,
                      onAskAccess: () => _whatsapp(
                          'parent_wa_ask_access'.tr, 'parent_ask_access')),
                  3 => _PaymentsTab(
                      childName: d.childName,
                      onPay: (label) => _whatsapp(
                          'parent_wa_pay'.trParams({'item': label}),
                          'parent_payment')),
                  _ => _OverviewTab(
                      d: d,
                      onAdvisor: () => _whatsapp(
                          'parent_wa_advisor'.tr, 'parent_advisor')),
                },
              ),
            ),
          ),
          _BottomNav(current: _tab, onTap: (i) => setState(() => _tab = i)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding — link the parent account with the child's invite code.
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingLink extends StatelessWidget {
  const _OnboardingLink({
    required this.controller,
    required this.linking,
    required this.onLink,
  });
  final TextEditingController controller;
  final bool linking;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    Text('parent_onboarding_title'.tr,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.6,
                            color: _P.ink)),
                    const SizedBox(height: 14),
                    Text('parent_onboarding_sub'.tr,
                        style: const TextStyle(
                            fontSize: 13.5, height: 1.6, color: _P.slate)),
                    const SizedBox(height: 20),
                    Text('parent_invite_code_label'.tr,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: _P.slate)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: controller,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: _P.ink),
                      decoration: InputDecoration(
                        hintText: 'KTOU-XX-0000',
                        prefixIcon: const Icon(Icons.key_rounded,
                            size: 18, color: _P.blue),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _P.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: _P.border),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _cardBox(children: [
                      _bullet(Icons.check_circle, _P.green,
                          'parent_onboarding_b1'.tr),
                      _bullet(Icons.shield_outlined, _P.blue,
                          'parent_onboarding_b2'.tr),
                      _bullet(Icons.chat, _P.whatsapp,
                          'parent_onboarding_b3'.tr),
                    ]),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTap: linking ? null : onLink,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                    color: _P.blue, borderRadius: BorderRadius.circular(16)),
                alignment: Alignment.center,
                child: linking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.link_rounded,
                              size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('parent_link_cta'.tr,
                              style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _bullet(IconData icon, Color color, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.5),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155))),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Vue d'ensemble
// ─────────────────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.d, required this.onAdvisor});
  final _ParentData d;
  final VoidCallback onAdvisor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Navy header + jauge
        Container(
          color: _P.navy,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(d.childInitials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'parent_hello'
                                .trParams({'name': d.parentName}),
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text(
                            'parent_linked_readonly'
                                .trParams({'child': d.childName}),
                            style: const TextStyle(
                                color: _P.slate400, fontSize: 11.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.1))),
                child: Row(
                  children: [
                    _JaugeRing(value: d.completion),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('parent_jauge_label'.tr,
                              style: const TextStyle(
                                  color: _P.cyan,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8)),
                          const SizedBox(height: 3),
                          Text('parent_jauge_state'.tr,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 3),
                          Text('parent_jauge_sub'.tr,
                              style: const TextStyle(
                                  color: _P.slate400,
                                  fontSize: 11,
                                  height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Weekly report
              _cardBox(children: [
                Row(
                  children: [
                    Text('parent_weekly_label'.tr,
                        style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: _P.amber)),
                    const Spacer(),
                    Text('parent_weekly_when'.tr,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _P.slate400)),
                  ],
                ),
                const SizedBox(height: 8),
                Text('parent_weekly_title'.tr,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        height: 1.4,
                        color: _P.ink)),
                const SizedBox(height: 6),
                Text('parent_weekly_body'.tr,
                    style: const TextStyle(
                        fontSize: 12, height: 1.6, color: _P.slate)),
              ]),
              const SizedBox(height: 13),
              Row(
                children: [
                  Expanded(
                    child: _MiniCard(
                      label: 'parent_dossier_label'.tr,
                      value: '${d.stepsDone}/${d.stepsTotal} '
                          '${'parent_steps'.tr}',
                      valueColor: _P.ink,
                      progress: d.stepsTotal == 0
                          ? 0
                          : d.stepsDone / d.stepsTotal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _MiniCard(
                      label: 'parent_deadline_label'.tr,
                      value: 'J-12',
                      valueColor: _P.amber,
                      caption: 'Bourse Eiffel 🇫🇷',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              _AdvisorCta(onTap: onAdvisor),
              const SizedBox(height: 13),
              const _PrivacyNote(textKey: 'parent_privacy_note'),
            ],
          ),
        ),
      ],
    );
  }
}

class _JaugeRing extends StatelessWidget {
  const _JaugeRing({required this.value});
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: (value / 100).clamp(0.0, 1.0),
              strokeWidth: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              valueColor: const AlwaysStoppedAnimation(_P.cyan),
            ),
          ),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.label,
    required this.value,
    required this.valueColor,
    this.progress,
    this.caption,
  });
  final String label;
  final String value;
  final Color valueColor;
  final double? progress;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    return _cardBox(children: [
      Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: _P.slate400)),
      const SizedBox(height: 4),
      Text(value,
          style:
              TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: valueColor)),
      if (progress != null) ...[
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: LinearProgressIndicator(
            value: progress!.clamp(0.0, 1.0),
            minHeight: 5,
            backgroundColor: _P.track,
            valueColor: const AlwaysStoppedAnimation(_P.blue),
          ),
        ),
      ],
      if (caption != null) ...[
        const SizedBox(height: 4),
        Text(caption!,
            style: const TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w700, color: _P.slate)),
      ],
    ]);
  }
}

class _AdvisorCta extends StatelessWidget {
  const _AdvisorCta({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _cardBox(
        padded: false,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: _P.greenSoft,
                      borderRadius: BorderRadius.circular(13)),
                  child: const Icon(Icons.chat, size: 20, color: _P.whatsapp),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('parent_advisor_title'.tr,
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: _P.ink)),
                      Text('parent_advisor_sub'.tr,
                          style:
                              const TextStyle(fontSize: 11, color: _P.slate)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: Color(0xFFCBD5E1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Dossier & finances
// ─────────────────────────────────────────────────────────────────────────────

class _CaseTab extends StatelessWidget {
  const _CaseTab({
    required this.d,
    required this.onAskAccess,
    required this.onUploadProof,
  });
  final _ParentData d;
  final VoidCallback onAskAccess;
  final VoidCallback onUploadProof;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('parent_case_title'.tr,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 2),
          Text('${d.caseTitle} · ${d.caseSubtitle}',
              style: const TextStyle(fontSize: 11.5, color: _P.slate)),
          const SizedBox(height: 14),
          if (d.docsShared) ...[
            _sectionLabel('parent_docs_label'.tr),
            const SizedBox(height: 8),
            for (final doc in d.docs) ...[
              _DocRow(doc: doc),
              const SizedBox(height: 8),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              decoration: BoxDecoration(
                  color: _P.amberSoft, borderRadius: BorderRadius.circular(12)),
              child: Text('parent_docs_readonly'.tr,
                  style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF92400E))),
            ),
          ] else
            _LockedCard(
              title: 'parent_docs_locked_title'.tr,
              body: 'parent_docs_locked_body'.tr,
              onAskAccess: onAskAccess,
            ),
          const SizedBox(height: 16),
          _sectionLabel('parent_financing_label'.tr),
          const SizedBox(height: 8),
          _cardBox(children: [
            _finRow(Icons.check_circle, _P.green, _P.greenSoft,
                'parent_fin_statement'.tr, 'parent_fin_sent'.tr, _P.green),
            const SizedBox(height: 12),
            _finRow(Icons.upload_file, _P.red, _P.redSoft,
                'parent_fin_employer'.tr, 'parent_fin_required'.tr, _P.red),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onUploadProof,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                    color: _P.blue, borderRadius: BorderRadius.circular(14)),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_rounded,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 7),
                    Text('parent_fin_upload'.tr,
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('parent_fin_note'.tr,
                style: const TextStyle(
                    fontSize: 10.5, height: 1.5, color: _P.slate400)),
          ]),
        ],
      ),
    );
  }

  static Widget _finRow(IconData icon, Color color, Color bg, String label,
      String chip, Color chipColor) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(100)),
          child: Text(chip,
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w800, color: chipColor)),
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.doc});
  final _Doc doc;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, chip) = switch (doc.status) {
      'ok' => (Icons.check_circle, _P.green, _P.greenSoft, 'parent_doc_ok'.tr),
      'review' => (
          Icons.hourglass_top,
          _P.sky,
          _P.skySoft,
          'parent_doc_review'.tr
        ),
      _ => (Icons.upload_file, _P.red, _P.redSoft, 'parent_doc_required'.tr),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _P.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(doc.name,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _P.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(100)),
            child: Text(chip,
                style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w800, color: color)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Actualités
// ─────────────────────────────────────────────────────────────────────────────

class _UpdatesTab extends StatelessWidget {
  const _UpdatesTab({required this.d, required this.onAskAccess});
  final _ParentData d;
  final VoidCallback onAskAccess;

  static const _updates = [
    (icon: Icons.rate_review, bg: _P.blueSoft, c: _P.blue, key: 'parent_upd_letter'),
    (icon: Icons.schedule, bg: _P.amberSoft, c: _P.amber, key: 'parent_upd_eiffel'),
    (icon: Icons.verified, bg: _P.greenSoft, c: _P.green, key: 'parent_upd_bulletins'),
    (icon: Icons.podcasts, bg: _P.redSoft, c: _P.red, key: 'parent_upd_live'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('parent_updates_title'.tr,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 2),
          Text('parent_updates_sub'.tr,
              style: const TextStyle(fontSize: 11.5, color: _P.slate)),
          const SizedBox(height: 14),
          for (final u in _updates) ...[
            _cardBox(
              padded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                            color: u.bg,
                            borderRadius: BorderRadius.circular(12)),
                        child: Icon(u.icon, size: 18, color: u.c),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${u.key}_t'.tr,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: _P.ink)),
                            const SizedBox(height: 2),
                            Text('${u.key}_s'.tr,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    height: 1.5,
                                    color: _P.slate)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 5),
          if (d.messagesShared)
            _cardBox(children: [
              Text('parent_msg_from'.tr,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800, color: _P.ink)),
              const SizedBox(height: 4),
              Text('parent_msg_body'.tr,
                  style: const TextStyle(
                      fontSize: 12, height: 1.55, color: Color(0xFF334155))),
            ])
          else
            _LockedCard(
              title: 'parent_msg_locked_title'.tr,
              body: 'parent_msg_locked_body'.tr,
              onAskAccess: onAskAccess,
              compact: true,
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — Paiements (WhatsApp-advisor, no in-app checkout)
// ─────────────────────────────────────────────────────────────────────────────

class _PaymentsTab extends StatelessWidget {
  const _PaymentsTab({required this.childName, required this.onPay});
  final String childName;
  final void Function(String item) onPay;

  static const _packs = [
    (nameKey: 'parent_pack_review', descKey: 'parent_pack_review_desc', price: '25 000 FCFA'),
    (nameKey: 'parent_pack_full', descKey: 'parent_pack_full_desc', price: '75 000 FCFA'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('parent_pay_title'.tr,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _P.ink)),
          const SizedBox(height: 2),
          Text('parent_pay_sub'.tr,
              style: const TextStyle(fontSize: 11.5, color: _P.slate)),
          const SizedBox(height: 14),
          // Premium (navy) → arrange via advisor
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: _P.navy, borderRadius: BorderRadius.circular(16)),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                          color: const Color(0x2E38BDF8),
                          borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.workspace_premium,
                          size: 19, color: _P.cyan),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'parent_premium_title'
                                  .trParams({'child': childName}),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800)),
                          Text('parent_premium_sub'.tr,
                              style: const TextStyle(
                                  color: _P.slate400, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => onPay('parent_premium_item'.tr),
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                        color: _P.blue, borderRadius: BorderRadius.circular(14)),
                    alignment: Alignment.center,
                    child: Text('parent_premium_cta'.tr,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionLabel('parent_packs_label'.tr),
          const SizedBox(height: 8),
          for (final p in _packs) ...[
            _cardBox(
              padded: false,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.nameKey.tr,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: _P.ink)),
                            const SizedBox(height: 2),
                            Text(p.descKey.tr,
                                style: const TextStyle(
                                    fontSize: 11, height: 1.45, color: _P.slate)),
                            const SizedBox(height: 3),
                            Text(p.price,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: _P.blue)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => onPay(p.nameKey.tr),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                              color: _P.blue,
                              borderRadius: BorderRadius.circular(100)),
                          child: Text('parent_pay_cta'.tr,
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 5),
          const _PrivacyNote(
              textKey: 'parent_pay_note', icon: Icons.verified_user),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared bits
// ─────────────────────────────────────────────────────────────────────────────

Widget _cardBox({required List<Widget> children, bool padded = true}) {
  return Container(
    width: double.infinity,
    padding: padded ? const EdgeInsets.all(16) : EdgeInsets.zero,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _P.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

Widget _sectionLabel(String text) => Text(text.toUpperCase(),
    style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: _P.slate400));

class _LockedCard extends StatelessWidget {
  const _LockedCard({
    required this.title,
    required this.body,
    required this.onAskAccess,
    this.compact = false,
  });
  final String title;
  final String body;
  final VoidCallback onAskAccess;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 16 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1.5,
            style: BorderStyle.solid),
      ),
      child: compact
          ? Row(
              children: [
                const Icon(Icons.lock, size: 20, color: _P.slate400),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(body,
                        style: const TextStyle(
                            fontSize: 11.5, height: 1.5, color: _P.slate))),
                _askBtn(onAskAccess),
              ],
            )
          : Column(
              children: [
                const Icon(Icons.lock, size: 26, color: _P.slate400),
                const SizedBox(height: 10),
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: _P.ink)),
                const SizedBox(height: 6),
                Text(body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 12, height: 1.55, color: _P.slate)),
                const SizedBox(height: 12),
                _askBtn(onAskAccess),
              ],
            ),
    );
  }

  Widget _askBtn(VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: _P.blue, width: 1.5)),
          child: Text('parent_ask_access'.tr,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w800, color: _P.blue)),
        ),
      );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.textKey, this.icon = Icons.shield_outlined});
  final String textKey;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _P.infoBg,
        border: Border.all(color: _P.infoBorder),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: _P.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(textKey.tr,
                style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: _P.infoText)),
          ),
        ],
      ),
    );
  }
}

class _SampleBanner extends StatelessWidget {
  const _SampleBanner();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7ED),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, size: 16, color: _P.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text('parent_sample_banner'.tr,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _P.amber)),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.current, required this.onTap});
  final int current;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.space_dashboard, key: 'parent_nav_overview'),
    (icon: Icons.folder_shared, key: 'parent_nav_case'),
    (icon: Icons.campaign, key: 'parent_nav_updates'),
    (icon: Icons.account_balance_wallet, key: 'parent_nav_pay'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _P.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          4, 6, 4, 10 + MediaQuery.of(context).padding.bottom * 0.5),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 28,
                      decoration: BoxDecoration(
                        color:
                            current == i ? _P.blueSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Icon(_items[i].icon,
                          size: 20,
                          color: current == i ? _P.blue : _P.slate400),
                    ),
                    const SizedBox(height: 3),
                    Text(_items[i].key.tr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: current == i
                                ? FontWeight.w800
                                : FontWeight.w600,
                            color: current == i ? _P.blue : _P.slate400)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
