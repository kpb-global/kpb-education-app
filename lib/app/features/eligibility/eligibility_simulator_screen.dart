import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/share_card_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/share_link.dart';
import '../../core/utils/study_level.dart';
import '../onboarding/onboarding_m2_constants.dart';
import 'eligibility_pdf.dart';
import 'eligibility_simulator_data.dart';

/// M11 — Simulateur d'éligibilité : 5 entrées → verdict 🟢/🟡/🔴 par pays + PDF.
class EligibilitySimulatorScreen extends StatefulWidget {
  const EligibilitySimulatorScreen({super.key});

  @override
  State<EligibilitySimulatorScreen> createState() =>
      _EligibilitySimulatorScreenState();
}

class _EligibilitySimulatorScreenState
    extends State<EligibilitySimulatorScreen> {
  static const _engine = EligibilityEngine();

  late EligibilityInput _input;
  final _budgetCtrl = TextEditingController();

  /// Boundary captured as the shareable verdict card (KPB-165).
  final _shareKey = GlobalKey();
  List<EligibilityResult>? _results;

  AppController get _controller => Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    final profile = _controller.profile;
    _input = profile != null
        ? EligibilityInput.fromProfile(profile)
        : const EligibilityInput();
    // Normalise any legacy/raw level ("L1", "M1"…) to a canonical label so the
    // dropdown (whose items are canonical) never receives an unknown value.
    final level = normalizeStudentLevel(_input.studyLevel);
    _input = _input.copyWith(
      studyLevel: level?.labelFr,
      clearStudyLevel: level == null,
    );
    if (_input.bacSeries != null &&
        !onboardingBacSeries.contains(_input.bacSeries)) {
      _input = _input.copyWith(clearBacSeries: true);
    }
    if (_input.monthlyBudgetEur != null) {
      _budgetCtrl.text = _input.monthlyBudgetEur.toString();
    }
  }

  @override
  void dispose() {
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _evaluate() {
    FocusScope.of(context).unfocus();
    final budget = int.tryParse(_budgetCtrl.text.trim());
    _input = _input.copyWith(
      monthlyBudgetEur: budget,
      clearBudget: budget == null,
    );
    setState(() => _results = _engine.evaluate(_input));
  }

  /// KPB-165: share the verdict as an image + invite link. The referral code is
  /// fetched best-effort — a failure means the link goes out without `ref`
  /// rather than blocking the share.
  Future<void> _shareVerdict() async {
    final results = _results;
    if (results == null) return;

    String? referralCode;
    try {
      final data = await _controller.apiClient.getMyReferral();
      final code = (data['code'] as String?)?.trim();
      if ((code ?? '').isNotEmpty) referralCode = code;
    } catch (_) {
      // Share without attribution rather than not at all.
    }

    final eligible =
        results.where((r) => r.verdict == EligibilityVerdict.eligible).length;
    final text = 'eligibility_share_prefill'.trParams({
      'count': '$eligible',
      'total': '${results.length}',
      'link': buildInviteLink(
        source: ShareSource.eligibility,
        referralCode: referralCode,
        deepPath: AppRoutes.eligibility,
      ),
    });

    final withImage = await ShareCardService.instance.shareBoundary(
      boundaryKey: _shareKey,
      text: text,
      source: ShareSource.eligibility,
    );
    if (!withImage && mounted) {
      Get.snackbar(
        AppConfig.brandName,
        'eligibility_share_image_failed'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(KpbSpacing.md),
      );
    }
  }

  Future<void> _exportPdf() async {
    final results = _results;
    if (results == null) return;
    try {
      await shareEligibilityPdf(
        input: _input,
        results: results,
        studentName: _controller.profile?.fullName,
      );
    } catch (_) {
      Get.snackbar(
        'eligibility_export_failed_title'.tr,
        'eligibility_export_failed_body'.tr,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(KpbSpacing.md),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text('eligibility_simulator_title'.tr),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        children: [
          const _IntroCard(),
          const SizedBox(height: KpbSpacing.lg),
          _buildForm(context),
          const SizedBox(height: KpbSpacing.lg),
          FilledButton.icon(
            onPressed: _evaluate,
            icon: const Icon(Icons.travel_explore_rounded),
            label: Text('evaluate_eligibility'.tr),
          ),
          if (results != null) ...[
            const SizedBox(height: KpbSpacing.xl),
            // KPB-165: the summary doubles as the shareable card. Wrapped in a
            // RepaintBoundary with its own title + brand line so the exported
            // PNG stands alone in a conversation.
            RepaintBoundary(
              key: _shareKey,
              child: ColoredBox(
                color: KpbColors.surface,
                child: Padding(
                  padding: const EdgeInsets.all(KpbSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'eligibility_share_card_title'.tr,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: KpbColors.brandNavy,
                        ),
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      _SummaryRow(results: results),
                      const SizedBox(height: KpbSpacing.sm),
                      Text(
                        '${AppConfig.brandName} · ${AppConfig.brandDomain}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: KpbColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            ...results.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: KpbSpacing.md),
                  child: _ResultCard(result: r),
                )),
            const SizedBox(height: KpbSpacing.sm),
            OutlinedButton.icon(
              onPressed: _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: Text('eligibility_export_pdf'.tr),
            ),
            const SizedBox(height: KpbSpacing.sm),
            // KPB-165: share the verdict as a card carrying an invite link.
            OutlinedButton.icon(
              onPressed: _shareVerdict,
              icon: const Icon(Icons.ios_share_rounded),
              label: Text('eligibility_share_verdict'.tr),
            ),
            const SizedBox(height: KpbSpacing.lg),
          ],
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('eligibility_your_info'.tr, style: KpbTextStyles.titleMd),
          const SizedBox(height: KpbSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _input.studyLevel,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'eligibility_current_study_level'.tr,
              prefixIcon: Icon(Icons.school_outlined, size: 20),
            ),
            items: onboardingStudyLevels
                .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                .toList(),
            onChanged: (v) => setState(() {
              _input = _input.copyWith(studyLevel: v);
              if (v == null || !studyLevelNeedsBacSeries(v)) {
                _input = _input.copyWith(bacSeries: null);
              }
            }),
          ),
          if (_input.studyLevel != null &&
              studyLevelNeedsBacSeries(_input.studyLevel!)) ...[
            const SizedBox(height: KpbSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _input.bacSeries,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'eligibility_bac_series'.tr,
                prefixIcon: Icon(Icons.workspace_premium_outlined, size: 20),
              ),
              items: onboardingBacSeries
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _input = _input.copyWith(bacSeries: v)),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),
          TextField(
            controller: _budgetCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'eligibility_monthly_budget_eur'.tr,
              hintText: 'eligibility_budget_hint'.tr,
              prefixIcon: Icon(Icons.euro_rounded, size: 20),
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),
          _LangSelector(
            label: 'eligibility_french_level'.tr,
            value: _input.frenchLevel,
            onChanged: (v) =>
                setState(() => _input = _input.copyWith(frenchLevel: v)),
          ),
          const SizedBox(height: KpbSpacing.md),
          _LangSelector(
            label: 'eligibility_english_level'.tr,
            value: _input.englishLevel,
            onChanged: (v) =>
                setState(() => _input = _input.copyWith(englishLevel: v)),
          ),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.lgBr,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'eligibility_hook'.tr,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6),
          Text(
            'eligibility_intro'.tr,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _LangSelector extends StatelessWidget {
  const _LangSelector({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final LangLevel value;
  final ValueChanged<LangLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KpbTextStyles.label),
        const SizedBox(height: 6),
        Wrap(
          spacing: KpbSpacing.sm,
          children: LangLevel.values.map((level) {
            return ChoiceChip(
              label: Text(level.labelFr),
              selected: value == level,
              onSelected: (_) => onChanged(level),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.results});

  final List<EligibilityResult> results;

  @override
  Widget build(BuildContext context) {
    final green =
        results.where((r) => r.verdict == EligibilityVerdict.eligible).length;
    final amber = results
        .where((r) => r.verdict == EligibilityVerdict.eligibleWithConditions)
        .length;
    final red = results
        .where((r) => r.verdict == EligibilityVerdict.notEligible)
        .length;
    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
              count: green,
              label: 'eligibility_summary_eligible'.tr,
              color: KpbColors.success),
        ),
        const SizedBox(width: KpbSpacing.sm),
        Expanded(
          child: _SummaryChip(
              count: amber,
              label: 'eligibility_summary_conditions'.tr,
              color: KpbColors.warning),
        ),
        const SizedBox(width: KpbSpacing.sm),
        Expanded(
          child: _SummaryChip(
              count: red,
              label: 'eligibility_summary_to_prepare'.tr,
              color: KpbColors.error),
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.count,
    required this.label,
    required this.color,
  });

  final int count;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Column(
        children: [
          Text('$count', style: KpbTextStyles.titleLg.copyWith(color: color)),
          Text(label,
              style: KpbTextStyles.caption.copyWith(color: color),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final EligibilityResult result;

  Color get _color {
    switch (result.verdict) {
      case EligibilityVerdict.eligible:
        return KpbColors.success;
      case EligibilityVerdict.eligibleWithConditions:
        return KpbColors.warning;
      case EligibilityVerdict.notEligible:
        return KpbColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      border: Border.all(color: _color.withValues(alpha: 0.35)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(result.rule.flag, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Text(result.rule.nameFr, style: KpbTextStyles.titleMd),
              ),
              KpbBadge(
                label: '${result.verdictEmoji} ${result.score}%',
                color: _color,
                small: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(result.verdictLabel,
              style: KpbTextStyles.label.copyWith(color: _color)),
          const SizedBox(height: KpbSpacing.sm),
          ClipRRect(
            borderRadius: KpbRadius.pillBr,
            child: LinearProgressIndicator(
              value: result.score / 100,
              minHeight: 6,
              backgroundColor: context.kpb.gray100,
              color: _color,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          ...result.reasons.map(
            (reason) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.circle, size: 6, color: context.kpb.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(reason, style: KpbTextStyles.bodySm),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.sm),
          Container(
            padding: const EdgeInsets.all(KpbSpacing.sm),
            decoration: BoxDecoration(
              color: context.kpb.gray50,
              borderRadius: KpbRadius.smBr,
            ),
            child: Text(result.advice, style: KpbTextStyles.caption),
          ),
        ],
      ),
    );
  }
}
