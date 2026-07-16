import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/components/verified_advisor_sheet.dart';
import '../explore/explore_screen.dart' show openInstitutionDetail;

// ─────────────────────────────────────────────────────────────────────────────
// Post-decision / "plan B" screen (App-engagement handoff · net-new).
// Keyed off a REAL rejected case. HONEST by construction:
//   • The case model has NO rejection-reason and NO success-rate stat, so the
//     design's "insufficient proof of funding" reason and the "1 in 3
//     applications succeeds" line are DROPPED — replaced by a generic, non-
//     numeric encouragement.
//   • "Plan B" is the top real alternative institutions ranked by the shared
//     controller.institutionMatch score (the refused one excluded best-effort
//     by name), not a hand-picked fiction.
//   • The counselor CTA routes through the existing verified-advisor → WhatsApp
//     hand-off. No in-app payment, no fake notification entry.
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const sky = Color(0xFF38BDF8);
  static const slate = Color(0xFF64748B);
  static const body = Color(0xFF475569);
  static const border = Color(0xFFE2E8F0);
  static const line = Color(0xFFF1F5F9);
  static const lineSoft = Color(0xFFF8FAFC);
  static const page = Color(0xFFF8FAFC);
  static const card = Color(0xFFFFFFFF);
  static const chipBg = Color(0xFFEFF6FF);
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFDCFCE7);
  static const red = Color(0xFFDC2626);
  static const redBg = Color(0xFFFEE2E2);
  static const whatsapp = Color(0xFF25D366);
  static const cardShadow = Color(0x0A0F172A);
}

const _cardShadow = <BoxShadow>[
  BoxShadow(color: _Palette.cardShadow, blurRadius: 2, offset: Offset(0, 1)),
];

/// One computed alternative institution for the plan B list.
class _Alt {
  const _Alt({
    required this.flag,
    required this.name,
    required this.why,
    required this.pct,
    required this.institution,
  });
  final String? flag;
  final String name;
  final String why;
  final int pct;

  /// Backing catalog institution — tapping the row opens its real detail
  /// sheet (handoff: plan B rows deep-link to the university).
  final InstitutionModel institution;
}

class PostDecisionScreen extends StatelessWidget {
  const PostDecisionScreen({super.key, required this.caseId});
  final String caseId;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AppController>();
    final c = ctrl.cases.firstWhereOrNull((e) => e.id == caseId);

    return Scaffold(
      backgroundColor: _Palette.page,
      body: SafeArea(
        bottom: false,
        child: c == null
            ? _emptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  _header(),
                  const SizedBox(height: 13),
                  _decisionCard(ctrl, c),
                  const SizedBox(height: 13),
                  ..._planB(ctrl, c),
                  _counselorCta(ctrl, c),
                ],
              ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'case_not_found_subtitle'.tr,
              style: const TextStyle(color: _Palette.slate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Get.back(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _Palette.card,
              shape: BoxShape.circle,
              border: Border.all(color: _Palette.border),
            ),
            child: const Icon(Icons.arrow_back_rounded,
                size: 19, color: _Palette.navy),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'post_decision_title'.tr,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            color: _Palette.navy,
          ),
        ),
      ],
    );
  }

  Widget _decisionCard(AppController ctrl, StudentCase c) {
    final title = ctrl.resolve(c.title);
    final flag = _caseFlag(ctrl, c);
    return Container(
      decoration: BoxDecoration(
        color: _Palette.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
        boxShadow: _cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (flag != null)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text(flag, style: const TextStyle(fontSize: 26)),
                )
              else
                Container(
                  margin: const EdgeInsets.only(right: 10),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _Palette.chipBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.folder_copy_rounded,
                      size: 18, color: _Palette.blue),
                ),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _Palette.navy,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: _Palette.redBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'status_rejected'.tr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _Palette.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Generic, honest encouragement — no fabricated reason, no invented
          // success-rate statistic (the case model carries neither).
          Text(
            'post_decision_encouragement'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.65,
              color: _Palette.body,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _planB(AppController ctrl, StudentCase c) {
    final alts = _alternatives(ctrl, c);
    if (alts.isEmpty) return const [];
    return [
      Container(
        decoration: BoxDecoration(
          color: _Palette.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _Palette.border),
          boxShadow: _cardShadow,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'post_decision_plan_b_title'.tr,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: _Palette.navy,
              ),
            ),
            const SizedBox(height: 11),
            for (var i = 0; i < alts.length; i++) ...[
              if (i > 0) const SizedBox(height: 9),
              _altRow(ctrl, alts[i]),
            ],
          ],
        ),
      ),
      const SizedBox(height: 13),
    ];
  }

  Widget _altRow(AppController ctrl, _Alt alt) {
    return Builder(
      builder: (context) => Semantics(
        button: true,
        label: alt.name,
        child: GestureDetector(
          onTap: () => openInstitutionDetail(context, alt.institution, ctrl),
          child: _altRowBody(alt),
        ),
      ),
    );
  }

  Widget _altRowBody(_Alt alt) {
    return Container(
      decoration: BoxDecoration(
        color: _Palette.lineSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _Palette.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      child: Row(
        children: [
          if (alt.flag != null)
            Padding(
              padding: const EdgeInsets.only(right: 11),
              child: Text(alt.flag!, style: const TextStyle(fontSize: 20)),
            )
          else
            Container(
              margin: const EdgeInsets.only(right: 11),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: _Palette.chipBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.school_rounded,
                  size: 15, color: _Palette.blue),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alt.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _Palette.navy,
                  ),
                ),
                if (alt.why.isNotEmpty) ...[
                  const SizedBox(height: 1),
                  Text(
                    alt.why,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 10.5, color: _Palette.slate),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: _Palette.greenBg,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              '${alt.pct}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: _Palette.green,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded,
              size: 16, color: _Palette.slate),
        ],
      ),
    );
  }

  Widget _counselorCta(AppController ctrl, StudentCase c) {
    return Semantics(
      button: true,
      label: 'post_decision_counselor_title'.tr,
      child: GestureDetector(
        onTap: () => showVerifiedAdvisorThenWhatsApp(
          advisorName: c.assignedAdvisorName,
          prefill: 'post_decision_whatsapp_prefill'
              .trParams({'title': ctrl.resolve(c.title)}),
          source: 'post_decision',
          contextType: 'case',
        ),
        child: Container(
          decoration: BoxDecoration(
            color: _Palette.navy,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _Palette.whatsapp,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.redeem_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'post_decision_counselor_title'.tr,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'post_decision_counselor_subtitle'.tr,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.45,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded,
                  color: _Palette.sky, size: 17),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Top real alternatives by the shared match score, excluding (best-effort,
  /// by name) the institution the refused case is about.
  List<_Alt> _alternatives(AppController ctrl, StudentCase c) {
    final refusedHay =
        '${ctrl.resolve(c.title)} ${ctrl.resolve(c.contextLabel)}'
            .toLowerCase();
    return ctrl.recommendedInstitutions
        .where((inst) {
          final name = ctrl.resolve(inst.name).toLowerCase();
          return name.isNotEmpty && !refusedHay.contains(name);
        })
        .take(3)
        .map((inst) {
          final country = ctrl.countryByIdOrNull(inst.countryId);
          final location = ctrl.resolve(inst.location);
          return _Alt(
            flag: (country != null && country.flagEmoji.isNotEmpty)
                ? country.flagEmoji
                : null,
            name: ctrl.resolve(inst.name),
            why: location.isNotEmpty
                ? location
                : (country != null ? ctrl.resolve(country.name) : ''),
            pct: ctrl.institutionMatch(inst),
            institution: inst,
          );
        })
        .toList();
  }

  /// Best-effort flag for the refused case: the case model has no country, so
  /// we only show one when a known catalog country name actually appears in the
  /// case title/context — never a fabricated one.
  String? _caseFlag(AppController ctrl, StudentCase c) {
    final hay = '${ctrl.resolve(c.title)} ${ctrl.resolve(c.contextLabel)}'
        .toLowerCase();
    for (final country in ctrl.countries) {
      final name = ctrl.resolve(country.name).toLowerCase();
      if (name.isNotEmpty &&
          country.flagEmoji.isNotEmpty &&
          hay.contains(name)) {
        return country.flagEmoji;
      }
    }
    return null;
  }
}
