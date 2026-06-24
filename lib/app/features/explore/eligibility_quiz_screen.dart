import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/program_recommendation_utils.dart';
import '../cases/case_composer_sheet.dart';
import 'country_detail_screen.dart';

class EligibilityQuizScreen extends StatefulWidget {
  const EligibilityQuizScreen({super.key, required this.countryId});

  final String countryId;

  @override
  State<EligibilityQuizScreen> createState() => _EligibilityQuizScreenState();
}

class _EligibilityQuizScreenState extends State<EligibilityQuizScreen> {
  late final AppController _controller;
  CountryModel? _country;
  var _loading = true;
  var _submitting = false;
  String? _error;
  var _questionIndex = 0;
  final Map<String, String> _answers = <String, String>{};
  CountryQuizResultModel? _result;

  @override
  void initState() {
    super.initState();
    _controller = Get.find<AppController>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final country = await _controller.loadCountryDetail(widget.countryId);
      if (!mounted) return;
      if (country.eligibilityQuiz == null ||
          country.eligibilityQuiz!.questions.isEmpty) {
        setState(() {
          _error = 'Quiz indisponible pour ce pays.';
          _loading = false;
        });
        return;
      }
      setState(() {
        _country = country;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger le quiz.';
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final result = await _controller.submitCountryQuiz(
        widget.countryId,
        _answers,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      Get.snackbar(
        'Erreur',
        'Impossible de calculer ton éligibilité. Réessaie.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  void _selectOption(String questionId, String value) {
    setState(() => _answers[questionId] = value);
  }

  void _next() {
    final quiz = _country?.eligibilityQuiz;
    if (quiz == null) return;
    if (_questionIndex < quiz.questions.length - 1) {
      setState(() => _questionIndex++);
      return;
    }
    _submit();
  }

  void _back() {
    if (_questionIndex == 0) {
      Get.back<void>();
      return;
    }
    setState(() => _questionIndex--);
  }

  @override
  Widget build(BuildContext context) {
    final country = _country;
    return Scaffold(
      backgroundColor: context.kpb.pageBg,
      appBar: AppBar(
        title: Text(country != null
            ? 'Quiz · ${_controller.resolve(country.name)}'
            : 'Quiz d\'éligibilité'),
        backgroundColor: context.kpb.cardBg,
        foregroundColor: context.kpb.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return KpbEmptyState(
        icon: Icons.quiz_outlined,
        title: 'Quiz indisponible',
        subtitle: _error!,
        action: FilledButton(
          onPressed: _load,
          child: Text('retry'.tr),
        ),
      );
    }

    if (_result != null) {
      return _ResultView(
        country: _country!,
        result: _result!,
        controller: _controller,
      );
    }

    final quiz = _country!.eligibilityQuiz!;
    final question = quiz.questions[_questionIndex];
    final selected = _answers[question.id];
    final progress = (_questionIndex + 1) / quiz.questions.length;

    return Column(
      children: [
        LinearProgressIndicator(
          value: progress,
          minHeight: 4,
          backgroundColor: context.kpb.gray100,
          color: KpbColors.blue,
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(KpbSpacing.pagePad),
            children: [
              Text(
                'Question ${_questionIndex + 1}/${quiz.questions.length}',
                style: KpbTextStyles.caption,
              ),
              const SizedBox(height: 8),
              Text(
                question.textFor(_controller.localeCode),
                style: KpbTextStyles.titleLg,
              ),
              const SizedBox(height: 20),
              ...question.options.map(
                (option) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _OptionTile(
                    label: option.labelFor(_controller.localeCode),
                    selected: selected == option.value,
                    onTap: () => _selectOption(question.id, option.value),
                  ),
                ),
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              KpbSpacing.pagePad,
              8,
              KpbSpacing.pagePad,
              12,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _back,
                    child: Text(_questionIndex == 0 ? 'Annuler' : 'Retour'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: selected == null || _submitting ? null : _next,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _questionIndex == quiz.questions.length - 1
                                ? 'Voir mon verdict'
                                : 'Suivant',
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? KpbColors.skyLight : context.kpb.cardBg,
      borderRadius: KpbRadius.mdBr,
      child: InkWell(
        onTap: onTap,
        borderRadius: KpbRadius.mdBr,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: KpbRadius.mdBr,
            border: Border.all(
              color: selected ? KpbColors.blue : context.kpb.gray200,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: selected ? KpbColors.blue : context.kpb.gray400,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: context.kpb.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.country,
    required this.result,
    required this.controller,
  });

  final CountryModel country;
  final CountryQuizResultModel result;
  final AppController controller;

  Color _accent() {
    switch (result.verdict) {
      case EligibilityVerdict.eligible:
        return KpbColors.success;
      case EligibilityVerdict.eligibleWithConditions:
        return KpbColors.warning;
      case EligibilityVerdict.notEligible:
        return KpbColors.error;
    }
  }

  IconData _icon() {
    switch (result.verdict) {
      case EligibilityVerdict.eligible:
        return Icons.check_circle_rounded;
      case EligibilityVerdict.eligibleWithConditions:
        return Icons.info_rounded;
      case EligibilityVerdict.notEligible:
        return Icons.cancel_rounded;
    }
  }

  void _primaryCta(BuildContext context) {
    if (result.verdict == EligibilityVerdict.notEligible &&
        result.alternativeCountryIds.isNotEmpty) {
      final altId = result.alternativeCountryIds.first;
      Get.off(() => CountryDetailScreen(countryId: altId));
      return;
    }

    final normalizedCountryId = normalizeCountryId(country.id);
    final recommended = result.verdict != EligibilityVerdict.notEligible
        ? ProgramRecommendationUtils.recommendedProgramForCountry(
            controller,
            normalizedCountryId,
            schoolHint: 'ece',
            campusHint: 'lyon',
          )
        : null;
    final institution = recommended != null
        ? controller.institutionByIdOrNull(recommended.institutionId)
        : null;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CaseComposerSheet(
        caseType: result.verdict == EligibilityVerdict.eligible
            ? CaseType.applicationSupport
            : CaseType.consultation,
        title: recommended != null
            ? 'Inscription — ${controller.resolve(recommended.name)}'
            : 'Étudier en ${controller.resolve(country.name)}',
        contextLabel: result.verdictTitle,
        countryId: normalizedCountryId,
        institutionId: recommended?.institutionId ?? institution?.id,
        programId: recommended?.id,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        Container(
          padding: const EdgeInsets.all(KpbSpacing.lg),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.1),
            borderRadius: KpbRadius.lgBr,
            border: Border.all(color: accent.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_icon(), color: accent, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      result.verdictTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(result.verdictMessage, style: KpbTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (result.alternativeCountryIds.isNotEmpty &&
            result.verdict == EligibilityVerdict.notEligible) ...[
          Text('alternative_destinations'.tr, style: KpbTextStyles.titleMd),
          const SizedBox(height: 10),
          ...result.alternativeCountryIds.map((id) {
            final alt = controller.countryByIdOrNull(id);
            if (alt == null) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: KpbCard(
                child: ListTile(
                  leading: Text(
                    displayCountryFlag(id: alt.id, flagEmoji: alt.flagEmoji),
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(controller.resolve(alt.name)),
                  subtitle: alt.nextIntakeLabel.fr.isNotEmpty
                      ? Text(controller.resolve(alt.nextIntakeLabel))
                      : null,
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () =>
                      Get.to(() => CountryDetailScreen(countryId: alt.id)),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
        ],
        FilledButton(
          onPressed: () => _primaryCta(context),
          child: Text(result.ctaLabel),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => Get.back<void>(),
          child: Text('back_to_country'.tr),
        ),
      ],
    );
  }
}
