import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/components/scholarship_status_badge.dart';
import '../../core/utils/whatsapp_utils.dart';

/// Three-state answer for one eligibility criterion.
enum CriterionAnswer { yes, maybe, no }

/// Overall readiness verdict for a scholarship self-check.
enum ScholarshipEligibilityVerdict { eligible, conditional, unlikely }

/// Pure, deterministic verdict. Mirrors the M11 simulator philosophy:
/// fully client-side, offline, trivially unit-testable.
/// - any "no"  → unlikely (a stated criterion is not met)
/// - all "yes" → eligible
/// - otherwise (some "maybe", no "no") → conditional
ScholarshipEligibilityVerdict computeScholarshipEligibility(
  Iterable<CriterionAnswer> answers,
) {
  final list = answers.toList();
  if (list.isEmpty) return ScholarshipEligibilityVerdict.conditional;
  if (list.any((a) => a == CriterionAnswer.no)) {
    return ScholarshipEligibilityVerdict.unlikely;
  }
  if (list.every((a) => a == CriterionAnswer.yes)) {
    return ScholarshipEligibilityVerdict.eligible;
  }
  return ScholarshipEligibilityVerdict.conditional;
}

/// Interactive "Suis-je éligible ?" self-check for a single scholarship.
/// The student answers each stated eligibility criterion (Oui / Peut-être /
/// Non); the verdict points them to a KPB advisor on WhatsApp.
class ScholarshipEligibilityScreen extends StatefulWidget {
  const ScholarshipEligibilityScreen({super.key, required this.scholarship});

  final ScholarshipModel scholarship;

  @override
  State<ScholarshipEligibilityScreen> createState() =>
      _ScholarshipEligibilityScreenState();
}

class _ScholarshipEligibilityScreenState
    extends State<ScholarshipEligibilityScreen> {
  final AppController _controller = Get.find<AppController>();
  final Map<int, CriterionAnswer> _answers = {};
  bool _showResult = false;

  /// Prefer the dedicated eligibility criteria; fall back to key requirements
  /// for scholarships that have not been enriched yet.
  List<LocalizedText> get _criteria => widget.scholarship.eligibility.isNotEmpty
      ? widget.scholarship.eligibility
      : widget.scholarship.keyRequirements;

  bool get _allAnswered =>
      _criteria.isNotEmpty && _answers.length == _criteria.length;

  String get _name => _controller.resolve(widget.scholarship.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: const Text('Suis-je éligible ?'),
        backgroundColor: context.kpb.pageBg,
        foregroundColor: context.kpb.textPrimary,
        elevation: 0,
      ),
      body: _criteria.isEmpty ? _noCriteria() : _checklist(),
    );
  }

  Widget _checklist() {
    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        Text(_name, style: KpbTextStyles.titleLg),
        const SizedBox(height: KpbSpacing.sm),
        Align(
          alignment: Alignment.centerLeft,
          child: ScholarshipStatusBadge(scholarship: widget.scholarship),
        ),
        const SizedBox(height: KpbSpacing.sm),
        Text(
          'Réponds honnêtement à chaque critère pour estimer ton éligibilité. '
          'Ce n’est qu’une indication — un conseiller confirmera ton cas.',
          style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textSecondary),
        ),
        const SizedBox(height: KpbSpacing.lg),
        for (var i = 0; i < _criteria.length; i++) _criterionTile(i),
        const SizedBox(height: KpbSpacing.md),
        KpbButton(
          text: 'Voir mon résultat',
          icon: Icons.fact_check_rounded,
          bgColor: _allAnswered ? KpbColors.blue : context.kpb.gray300,
          onPressed: _allAnswered
              ? () => setState(() => _showResult = true)
              : () {},
        ),
        if (!_allAnswered)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Réponds à tous les critères pour voir ton résultat.',
              style:
                  KpbTextStyles.caption.copyWith(color: context.kpb.textSecondary),
              textAlign: TextAlign.center,
            ),
          ),
        if (_showResult && _allAnswered) ...[
          const SizedBox(height: KpbSpacing.lg),
          _verdictCard(),
        ],
        const SizedBox(height: KpbSpacing.xl),
      ],
    );
  }

  Widget _criterionTile(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: KpbSpacing.sm),
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.mdBr,
        boxShadow: KpbShadow.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_controller.resolve(_criteria[i]), style: KpbTextStyles.body),
          const SizedBox(height: KpbSpacing.sm),
          Row(
            children: [
              _answerChip(i, CriterionAnswer.yes, 'Oui', KpbColors.success),
              const SizedBox(width: 8),
              _answerChip(i, CriterionAnswer.maybe, 'Peut-être',
                  KpbColors.warning),
              const SizedBox(width: 8),
              _answerChip(i, CriterionAnswer.no, 'Non', KpbColors.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _answerChip(int i, CriterionAnswer value, String label, Color color) {
    final selected = _answers[i] == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() {
          _answers[i] = value;
          _showResult = false; // answers changed — require re-check
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? color : context.kpb.surfaceBg,
            borderRadius: KpbRadius.mdBr,
            border: Border.all(
                color: selected ? color : context.kpb.gray200, width: 1),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.kpb.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _verdictCard() {
    final verdict = computeScholarshipEligibility(_answers.values);
    final unmet = <String>[
      for (var i = 0; i < _criteria.length; i++)
        if (_answers[i] != CriterionAnswer.yes) _controller.resolve(_criteria[i]),
    ];

    final (Color color, IconData icon, String title, String body) = switch (
        verdict) {
      ScholarshipEligibilityVerdict.eligible => (
          KpbColors.success,
          Icons.verified_rounded,
          '🟢 Tu sembles éligible',
          'Tu remplis les critères annoncés. Prépare ton dossier — un conseiller '
              'KPB peut t’accompagner pour maximiser tes chances.',
        ),
      ScholarshipEligibilityVerdict.conditional => (
          KpbColors.warning,
          Icons.help_outline_rounded,
          '🟡 Éligibilité à confirmer',
          'Tu remplis une partie des critères mais certains restent à vérifier. '
              'Un conseiller peut t’aider à confirmer ton éligibilité.',
        ),
      ScholarshipEligibilityVerdict.unlikely => (
          KpbColors.error,
          Icons.info_outline_rounded,
          '🔴 Probablement non éligible',
          'Au moins un critère clé ne semble pas rempli. Des exceptions existent '
              'parfois — parles-en à un conseiller, ou explore d’autres bourses.',
        ),
    };

    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: KpbTextStyles.titleMd.copyWith(color: color)),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(body, style: KpbTextStyles.bodySm),
          if (unmet.isNotEmpty &&
              verdict != ScholarshipEligibilityVerdict.eligible) ...[
            const SizedBox(height: KpbSpacing.md),
            Text('À vérifier :', style: KpbTextStyles.label),
            const SizedBox(height: 4),
            ...unmet.map(
              (c) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                        child: Text(c, style: KpbTextStyles.bodySm)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: KpbSpacing.lg),
          KpbButton(
            text: 'Discuter avec un conseiller',
            icon: Icons.chat_rounded,
            bgColor: KpbColors.success,
            onPressed: _contactAdvisor,
          ),
        ],
      ),
    );
  }

  Widget _noCriteria() {
    return Padding(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Les critères d’éligibilité de cette bourse ne sont pas encore '
            'détaillés. Un conseiller KPB peut vérifier ton cas directement.',
            textAlign: TextAlign.center,
            style: KpbTextStyles.body.copyWith(color: context.kpb.textSecondary),
          ),
          const SizedBox(height: KpbSpacing.lg),
          KpbButton(
            text: 'Discuter avec un conseiller',
            icon: Icons.chat_rounded,
            bgColor: KpbColors.success,
            onPressed: _contactAdvisor,
          ),
        ],
      ),
    );
  }

  void _contactAdvisor() {
    openWhatsAppOrToast(
      prefill:
          'Bonjour KPB Education, je m’intéresse à la bourse « $_name » et '
          'j’aimerais vérifier mon éligibilité / être accompagné(e).',
    );
  }
}
