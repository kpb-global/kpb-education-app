import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/services/coach_service.dart';
import '../../core/utils/whatsapp_utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Karatou Premium — App-engagement handoff (navy/blue).
//
// HONEST-PRODUCT NOTE: there is NO Premium product, price, subscription or
// payment anywhere in the app or backend, and Karatou does no in-app checkout
// (users are helped by a KPB advisor over WhatsApp — see the Parent surface
// `parent_premium_cta` and the AI-coach "Premium coming soon" copy). So this
// screen deliberately does NOT render the design's price ("4 900 FCFA/month"),
// the "Pay on karatou.app/premium" checkout, the "YOUR KARATOU ID — IT
// IDENTIFIES YOUR PAYMENT" block, or any billing state. It is an honest
// "coming soon / activate via a KPB advisor" screen. The single free-vs-premium
// row is the ONE real, verifiable limit: the AI Coach weekly quota (read live
// from CoachService, default 5). The lone CTA hands off to the WhatsApp advisor.
// ─────────────────────────────────────────────────────────────────────────────

class _Palette {
  static const navy = Color(0xFF0F172A);
  static const navyGradientEnd = Color(0xFF1E3A8A);
  static const blue = Color(0xFF2563EB);
  static const amber = Color(0xFFF59E0B);
  static const amberSoft = Color(0xFFFDE68A);
  static const slate400 = Color(0xFF94A3B8);
  static const body = Color(0xFF334155);
  static const border = Color(0xFFE2E8F0);
  static const subtle = Color(0xFFF1F5F9);
  static const page = Color(0xFFF8FAFC);
  static const chipBg = Color(0xFFEFF6FF);
  static const chipBorder = Color(0xFFBFDBFE);
  static const blueText = Color(0xFF1E40AF);
  static const cardTextOnNavy = Color(0xFFE2E8F0);
  static const whatsapp = Color(0xFF25D366);
}

const _heroGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_Palette.navy, _Palette.navyGradientEnd],
);

const _amberGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [_Palette.amber, _Palette.amberSoft],
);

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  // Real free-tier weekly AI-coach quota. Defaults to the documented free
  // limit (5) and is refreshed from the live quota when available.
  int _freeWeeklyLimit = 5;

  @override
  void initState() {
    super.initState();
    _loadQuota();
  }

  Future<void> _loadQuota() async {
    final userId = Get.find<AppController>().profile?.id;
    if (userId == null || userId.isEmpty) return;
    try {
      final quota = await CoachService().fetchQuota(userId);
      if (!mounted) return;
      setState(() => _freeWeeklyLimit = quota.limit);
    } catch (_) {
      // Keep the documented default; this screen is informational.
    }
  }

  void _contactAdvisor() {
    openWhatsAppOrToast(
      phone: AppConfig.whatsappNumber,
      prefill: 'premium_wa_prefill'.tr,
      source: 'student_premium',
      contextType: 'premium',
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = '$_freeWeeklyLimit';

    return Scaffold(
      backgroundColor: _Palette.page,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  _CircleBackButton(onTap: () => Navigator.of(context).pop()),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'premium_screen_title'.tr,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        color: _Palette.navy,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _heroCard(count),
                  const SizedBox(height: 14),
                  _comparisonCard(count),
                  const SizedBox(height: 14),
                  _howToCard(),
                ],
              ),
            ),

            // ── Advisor CTA (no checkout, no price) ─────────────────────────
            _ctaBar(),
          ],
        ),
      ),
    );
  }

  // ── Hero: value proposition framed against the REAL free limit ────────────
  Widget _heroCard(String count) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: _heroGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: _amberGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: _Palette.navy, size: 24),
              ),
              const SizedBox(width: 12),
              _SoonPill(label: 'premium_badge_soon'.tr),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'premium_hero_title'.tr,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'premium_hero_sub'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: _Palette.slate400,
            ),
          ),
          const SizedBox(height: 14),
          _ValueRow(text: 'premium_value_ai_coach'.trParams({'count': count})),
          const SizedBox(height: 8),
          _ValueRow(text: 'premium_value_advisors'.tr),
          const SizedBox(height: 8),
          _ValueRow(text: 'premium_value_more_soon'.tr),
        ],
      ),
    );
  }

  // ── Free vs Premium: ONLY the one real, verifiable row (AI coach quota) ────
  Widget _comparisonCard(String count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Column headers.
          Row(
            children: [
              _cell('premium_compare_feature'.tr,
                  flex: 14, header: true, align: TextAlign.left),
              _cell('premium_compare_free'.tr,
                  flex: 9, header: true, leftBorder: true),
              _cell('premium_compare_premium'.tr,
                  flex: 9, header: true, leftBorder: true, highlight: true),
            ],
          ),
          Container(height: 1, color: _Palette.subtle),
          // The single honest row.
          Row(
            children: [
              _cell('premium_row_ai_coach'.tr,
                  flex: 14, align: TextAlign.left, strong: true),
              _cell('premium_free_ai_coach'.trParams({'count': count}),
                  flex: 9, leftBorder: true),
              _cell('premium_unlimited_soon'.tr,
                  flex: 9, leftBorder: true, highlight: true, strong: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(
    String text, {
    required int flex,
    bool header = false,
    bool leftBorder = false,
    bool highlight = false,
    bool strong = false,
    TextAlign align = TextAlign.center,
  }) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: highlight ? _Palette.chipBg : Colors.transparent,
          border: leftBorder
              ? const Border(left: BorderSide(color: _Palette.subtle))
              : null,
        ),
        child: Text(
          text,
          textAlign: align,
          style: TextStyle(
            fontSize: header ? 10 : 12,
            height: 1.3,
            letterSpacing: header ? 0.4 : 0,
            fontWeight: header
                ? FontWeight.w800
                : (strong ? FontWeight.w800 : FontWeight.w600),
            color: header
                ? (highlight ? _Palette.blue : _Palette.slate400)
                : (highlight ? _Palette.blue : _Palette.body),
          ),
        ),
      ),
    );
  }

  // ── How to activate (honest: no in-app payment) ───────────────────────────
  Widget _howToCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'premium_how_title'.tr,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: _Palette.navy,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'premium_how_body'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: _Palette.body,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _Palette.chipBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _Palette.chipBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.shield_outlined,
                    size: 16, color: _Palette.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'premium_no_payment_note'.tr,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      fontWeight: FontWeight.w700,
                      color: _Palette.blueText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _Palette.border)),
      ),
      child: SizedBox(
        height: 52,
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _contactAdvisor,
          style: FilledButton.styleFrom(
            backgroundColor: _Palette.whatsapp,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.chat_rounded, size: 20),
          label: Text(
            'parent_premium_cta'.tr,
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }
}

class _CircleBackButton extends StatelessWidget {
  const _CircleBackButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(19),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _Palette.border),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            size: 19, color: _Palette.navy),
      ),
    );
  }
}

class _SoonPill extends StatelessWidget {
  const _SoonPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0x2E38BDF8),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: Color(0xFF38BDF8),
        ),
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 1),
          child: Icon(Icons.check_circle_rounded,
              size: 16, color: Color(0xFF4ADE80)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: _Palette.cardTextOnNavy,
            ),
          ),
        ),
      ],
    );
  }
}
