import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';
import '../explore/country_detail_screen.dart';

class OrientationScreen extends StatefulWidget {
  const OrientationScreen({super.key});

  @override
  State<OrientationScreen> createState() => _OrientationScreenState();
}

class _OrientationScreenState extends State<OrientationScreen> {
  final Map<String, List<String>> _answers = {};
  int _questionIndex = 0;
  bool _showResults = false;
  bool _isSubmitting = false;

  AppController get _ctrl => Get.find<AppController>();

  @override
  void initState() {
    super.initState();
    final pending = _ctrl.pendingOrientationAnswers;
    if (pending.isNotEmpty) {
      _answers.addAll(pending);
      _questionIndex = _ctrl.pendingOrientationQuestionIndex;
    } else if (_ctrl.latestOrientationSession != null) {
      _showResults = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (_) {
        if (!_ctrl.isStudent) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            body: _ConsultativeView(controller: _ctrl),
          );
        }

        final questions = _ctrl.orientationQuestions;
        final latestResult = _ctrl.latestOrientationSession;
        final hasResult = latestResult != null;

        // Show results if test already done or user just finished
        if (_showResults && hasResult) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            body: _ResultsView(
              result: latestResult,
              controller: _ctrl,
              onRetake: () {
                _ctrl.clearOrientationProgress();
                setState(() {
                  _answers.clear();
                  _questionIndex = 0;
                  _showResults = false;
                });
              },
            ),
          );
        }

        if (_isSubmitting || _ctrl.isSubmittingOrientation) {
          return Scaffold(
            backgroundColor: context.kpb.pageBg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    'Analyse de vos réponses…',
                    style: KpbTextStyles.body,
                  ),
                ],
              ),
            ),
          );
        }

        if (questions.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final question = questions[_questionIndex];
        final selectedIds = _answers[question.id] ?? [];
        final progress = (_questionIndex + 1) / questions.length;

        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          body: SafeArea(
            child: Column(
              children: [
                // ── Progress header ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.md, KpbSpacing.pagePad, 0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              if (_questionIndex > 0) {
                                setState(() => _questionIndex--);
                              } else {
                                Get.back();
                              }
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: context.kpb.cardBg,
                                borderRadius: KpbRadius.mdBr,
                                boxShadow: KpbShadow.card,
                              ),
                              child: Icon(
                                _questionIndex > 0
                                    ? Icons.arrow_back_rounded
                                    : Icons.close_rounded,
                                size: 18,
                                color: context.kpb.textSecondary,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                'nav_orientation'.tr,
                                style: KpbTextStyles.titleMd,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: KpbColors.blue.withValues(alpha: 0.1),
                              borderRadius: KpbRadius.pillBr,
                            ),
                            child: Text(
                              '${_questionIndex + 1}/${questions.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: KpbColors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: KpbSpacing.sm),
                      ClipRRect(
                        borderRadius: KpbRadius.pillBr,
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: context.kpb.gray100,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              KpbColors.blue),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Question card ───────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(KpbSpacing.pagePad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: KpbSpacing.md),
                        // Question number badge
                        KpbBadge(
                          label: 'Question ${_questionIndex + 1}',
                          color: KpbColors.blue,
                        ),
                        const SizedBox(height: KpbSpacing.sm),
                        // Question text
                        Text(
                          _ctrl.resolve(question.prompt),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.kpb.textPrimary,
                            height: 1.3,
                          ),
                        ),
                        if (question.multiSelect) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Plusieurs réponses possibles',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.kpb.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: KpbSpacing.lg),
                        // Options
                        ...question.options.map((option) {
                          final selected = selectedIds.contains(option.id);
                          return Padding(
                            padding:
                                const EdgeInsets.only(bottom: KpbSpacing.sm),
                            child: _OptionCard(
                              label: _ctrl.resolve(option.label),
                              selected: selected,
                              onTap: () {
                                setState(() {
                                  final current = [...selectedIds];
                                  if (question.multiSelect) {
                                    if (selected) {
                                      current.remove(option.id);
                                    } else {
                                      current.add(option.id);
                                    }
                                  } else {
                                    current
                                      ..clear()
                                      ..add(option.id);
                                  }
                                  _answers[question.id] = current;
                                  _ctrl.saveOrientationProgress(
                                      _answers, _questionIndex);
                                });
                              },
                            ),
                          );
                        }),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),

                // ── Bottom CTA ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                      KpbSpacing.sm, KpbSpacing.pagePad, KpbSpacing.md),
                  decoration: BoxDecoration(
                    color: context.kpb.pageBg,
                    boxShadow: KpbShadow.float,
                  ),
                  child: FilledButton(
                    onPressed: selectedIds.isEmpty
                        ? null
                        : () {
                            if (_questionIndex < questions.length - 1) {
                              setState(() => _questionIndex++);
                              _ctrl.saveOrientationProgress(
                                  _answers, _questionIndex);
                            } else {
                              setState(() => _isSubmitting = true);
                              _ctrl.submitOrientation(_answers).then((_) {
                                if (!mounted) return;
                                setState(() {
                                  _isSubmitting = false;
                                  _showResults = true;
                                });
                              }).catchError((_) {
                                if (!mounted) return;
                                setState(() => _isSubmitting = false);
                              });
                            }
                          },
                    child: Text(
                      _questionIndex < questions.length - 1
                          ? 'Continuer →'
                          : 'Voir mes résultats',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Option card (styled answer option)
// ─────────────────────────────────────────────────────────────────────────────
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? KpbColors.blue : context.kpb.cardBg,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
            color: selected ? KpbColors.blue : context.kpb.gray100,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected ? KpbShadow.soft : KpbShadow.card,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? Colors.white : KpbColors.bgMuted,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.white : context.kpb.gray200,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: KpbColors.blue)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.kpb.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Results view
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsView extends StatelessWidget {
  const _ResultsView({
    required this.result,
    required this.controller,
    required this.onRetake,
  });

  final dynamic result;
  final AppController controller;
  final VoidCallback onRetake;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Pinned Header ──────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          floating: false,
          backgroundColor: KpbColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
            ),
          ),
          title: const Text(
            'Orientation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // ── Hero banner content ────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
            ),
            padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                KpbSpacing.sm, KpbSpacing.pagePad, KpbSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KpbBadge(
                  label: '✅ Orientation complète',
                  color: KpbColors.success,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Vos résultats',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Basé sur vos réponses, voici les filières qui vous correspondent le mieux.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── Recommendations ────────────────────────────────────────────────
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              KpbSpacing.pagePad, KpbSpacing.lg, KpbSpacing.pagePad, 0),
          sliver: SliverList.separated(
            itemCount: (result.recommendations as List).length,
            separatorBuilder: (_, __) => const SizedBox(height: KpbSpacing.md),
            itemBuilder: (ctx, i) {
              final rec = (result.recommendations as List)[i];
              final field = controller.fieldByIdOrNull(rec.fieldId);
              if (field == null) {
                return const SizedBox.shrink();
              }
              final countries = (rec.relatedCountryIds as List<String>)
                  .map(controller.countryByIdOrNull)
                  .whereType<CountryModel>()
                  .take(3)
                  .toList();
              final scholarships = (rec.relatedScholarshipIds as List<String>)
                  .map(controller.scholarshipByIdOrNull)
                  .whereType<ScholarshipModel>()
                  .take(3)
                  .toList();
              final isBest = i == 0;

              return _RecommendationCard(
                rec: rec,
                field: field,
                countries: countries,
                scholarships: scholarships,
                controller: controller,
                isBest: isBest,
                context: ctx,
              );
            },
          ),
        ),

        // ── Action buttons ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                KpbSpacing.xl, KpbSpacing.pagePad, KpbSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Primary: explore results
                FilledButton.icon(
                  icon: const Icon(Icons.school_rounded, size: 18),
                  label: const Text('Voir les écoles'),
                  onPressed: () {
                    final topField = (result.recommendations as List).isNotEmpty
                        ? (result.recommendations as List).first.fieldId
                            as String
                        : null;
                    Get.back();
                    controller.goToUniversitiesForField(topField);
                  },
                ),
                const SizedBox(height: KpbSpacing.sm),
                OutlinedButton.icon(
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: const Text('Explorer mes résultats'),
                  onPressed: () {
                    Get.back();
                    controller.goToTab(StudentShellTab.universities);
                  },
                ),
                const SizedBox(height: KpbSpacing.sm),
                // Secondary: open a support case
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Démarrer un dossier'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: Get.context!,
                    isScrollControlled: true,
                    builder: (_) => const CaseComposerSheet(
                      caseType: CaseType.applicationSupport,
                      title: 'Dossier de candidature',
                      contextLabel: 'Suite orientation',
                    ),
                  ),
                ),
                const SizedBox(height: KpbSpacing.md),
                // Tertiary: retake
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Refaire le test'),
                  onPressed: onRetake,
                  style: TextButton.styleFrom(
                    foregroundColor: context.kpb.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Recommendation card
// ─────────────────────────────────────────────────────────────────────────────
class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.rec,
    required this.field,
    required this.countries,
    required this.scholarships,
    required this.controller,
    required this.isBest,
    required this.context,
  });

  final dynamic rec;
  final FieldModel field;
  final List<CountryModel> countries;
  final List<ScholarshipModel> scholarships;
  final AppController controller;
  final bool isBest;
  final BuildContext context;

  @override
  Widget build(BuildContext ctx) {
    final score = rec.score as int;
    final accentColor = field.accentColor;
    final saved = controller.isSaved(SavedItemType.field, field.id);

    return KpbCard(
      border: isBest
          ? Border.all(color: KpbColors.blue.withValues(alpha: 0.3), width: 2)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Field header ────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: KpbRadius.lgBr,
                ),
                child: Center(
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: accentColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isBest)
                      const KpbBadge(
                          label: '⭐ Meilleur match', color: KpbColors.blue),
                    if (isBest) const SizedBox(height: 4),
                    if (rec.iaResilience == 'high')
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: KpbBadge(
                          label: '🛡 Résilient à l\'IA',
                          color: KpbColors.success,
                        ),
                      ),
                    Text(controller.resolve(field.name),
                        style: KpbTextStyles.title),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () =>
                    controller.toggleSaved(SavedItemType.field, field.id),
                child: Icon(
                  saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: saved ? KpbColors.blue : context.kpb.gray300,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),

          // ── Match bar ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: KpbRadius.pillBr,
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 6,
              backgroundColor: context.kpb.gray100,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
            ),
          ),
          const SizedBox(height: KpbSpacing.md),

          // ── Why it fits ──────────────────────────────────────────────
          Text(
            'Pourquoi c\'est fait pour vous',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: context.kpb.textMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            controller.resolve(rec.explanation),
            style: KpbTextStyles.body,
          ),
          if ((rec.jobs as List<String>).isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.md),
            Text(
              'Métiers visés',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: (rec.jobs as List<String>).map((job) {
                return KpbBadge(label: job, color: accentColor);
              }).toList(),
            ),
          ],
          const SizedBox(height: KpbSpacing.md),

          // ── Countries ────────────────────────────────────────────────
          if (countries.isNotEmpty) ...[
            Text(
              'Pays recommandés',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: countries.map<Widget>((country) {
                return GestureDetector(
                  onTap: () =>
                      Get.to(() => CountryDetailScreen(countryId: country.id)),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.kpb.surfaceBg,
                      borderRadius: KpbRadius.pillBr,
                    ),
                    child: Text(
                      controller.resolve(country.name),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.kpb.textSecondary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],

          // ── Scholarships ─────────────────────────────────────────────
          if (scholarships.isNotEmpty) ...[
            Text(
              'Bourses disponibles',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: context.kpb.textMuted,
              ),
            ),
            const SizedBox(height: 8),
            ...scholarships.map<Widget>(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_outlined,
                        size: 14, color: KpbColors.gold),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        controller.resolve(s.name),
                        style: TextStyle(
                          fontSize: 13,
                          color: context.kpb.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
          ],

          const KpbDivider(),
          const SizedBox(height: KpbSpacing.sm),

          // ── CTAs ────────────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    controller.goToUniversitiesForField(field.id);
                    Get.back();
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Voir les écoles'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CaseComposerSheet(
                      caseType: CaseType.consultation,
                      title: controller.resolve(field.name),
                      contextLabel: controller.resolve(field.name),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Être accompagné'),
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
// Consultative view (non-student)
// ─────────────────────────────────────────────────────────────────────────────
class _ConsultativeView extends StatelessWidget {
  const _ConsultativeView({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // ── Pinned Header ──────────────────────────────────────────────────
        SliverAppBar(
          pinned: true,
          floating: false,
          backgroundColor: KpbColors.navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Get.back(),
          ),
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
            ),
          ),
          title: const Text(
            'Orientation',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // ── Content header ─────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              gradient: KpbColors.heroGradient,
            ),
            padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                KpbSpacing.sm, KpbSpacing.pagePad, KpbSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('nav_orientation'.tr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 8),
                Text(
                  controller.isParent
                      ? 'home_for_parent'.tr
                      : 'home_for_partner'.tr,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(KpbSpacing.pagePad),
            child: KpbCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: KpbColors.blue.withValues(alpha: 0.1),
                      borderRadius: KpbRadius.mdBr,
                    ),
                    child: const Icon(Icons.support_agent_rounded,
                        color: KpbColors.blue, size: 26),
                  ),
                  const SizedBox(height: KpbSpacing.md),
                  Text(
                    controller.isParent
                        ? 'parent_support'.tr
                        : 'partner_redirect'.tr,
                    style: KpbTextStyles.body,
                  ),
                  const SizedBox(height: KpbSpacing.md),
                  FilledButton.icon(
                    icon: const Icon(Icons.calendar_today_rounded, size: 18),
                    label: Text('book_consultation'.tr),
                    onPressed: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const CaseComposerSheet(
                        caseType: CaseType.consultation,
                        title: 'KPB advisory session',
                        contextLabel: 'Orientation support',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
