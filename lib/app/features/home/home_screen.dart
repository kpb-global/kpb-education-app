import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/skeleton.dart';
import '../../core/utils/country_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../cases/case_detail_screen.dart';
import '../community/community_screen.dart';
import '../orientation/orientation_screen.dart';
import '../saved/saved_screen.dart';
import '../search/search_screen.dart';
import '../ai_advisor/ai_chat_screen.dart';
import '../explore/country_detail_screen.dart';
import '../onboarding/onboarding_screen.dart';
import '../tools/student_tools_screen.dart';
import 'counsellor_testimonials_carousel.dart';
import 'home_impact_proof.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flag helpers
// ─────────────────────────────────────────────────────────────────────────────
String _flag(String id) => countryFlag(id);

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen — light premium, momentum-first
//
// One job per screen: "Où en es-tu ? Quelle est ta prochaine étape ?"
//   1. AppBar  — greeting + search / saved / profile
//   2. Hero    — brand banner + animated progress ring (momentum)
//   3. ⚡ Prochaine étape — smart next-best-action card
//   4. 🗂 Quick actions — 4 light tiles
//   5. 🤖 Assistant d'Orientation IA · 🌍 Inscriptions à l'Étranger · 🛠 Outils
//   6. 📁 Dossiers actifs · ⏰ Deadline · 🏛 Universités · 🏆 Bourses · 📰 Articles
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final c = context.kpb;

    return GetBuilder<AppController>(
      builder: (_) {
        if (controller.isSyncing && controller.profile == null) {
          return const HomeScreenSkeleton();
        }

        if (controller.syncError != null && controller.profile == null) {
          return KpbErrorState(
            onRetry: controller.pullToRefresh,
          );
        }

        final profile = controller.profile;
        final firstName = profile?.fullName.split(' ').first ?? '';

        // Data — limited, curated
        final institutions = controller.institutions.take(4).toList();
        final scholarships =
            controller.recommendedScholarships.take(3).toList();
        final articles = controller.publishedArticles.take(2).toList();
        final activeCases = controller.cases
            .where((c) =>
                c.status != CaseStatus.completed &&
                c.status != CaseStatus.cancelled &&
                c.status != CaseStatus.rejected)
            .take(2)
            .toList();
        final urgentScholarship = _findUrgentDeadline(scholarships);

        return Container(
          color: c.pageBg,
          child: KpbRefresh(
            onRefresh: controller.pullToRefresh,
            child: CustomScrollView(
              slivers: [
                // ── App Bar ───────────────────────────────────────────
                SliverAppBar(
                  floating: true,
                  snap: true,
                  pinned: false,
                  toolbarHeight: 64,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  title: Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName.isNotEmpty
                              ? 'home_greeting_named'
                                  .trParams({'name': firstName})
                              : 'home_greeting'.tr,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          controller.isStudent
                              ? 'home_subtitle_student'.tr
                              : controller.isParent
                                  ? 'home_subtitle_parent'.tr
                                  : 'home_subtitle_partner'.tr,
                          style: KpbTextStyles.caption
                              .copyWith(color: c.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    _AppBarChip(
                      icon: Icons.search_rounded,
                      onTap: () => Get.to(() => const SearchScreen()),
                    ),
                    _AppBarChip(
                      icon: Icons.bookmark_border_rounded,
                      onTap: () => Get.to(() => const SavedScreen()),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _AppBarChip(
                        icon: Icons.person_outline_rounded,
                        onTap: () =>
                            controller.goToTab(StudentShellTab.profile),
                      ),
                    ),
                  ],
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                        KpbSpacing.sm, KpbSpacing.pagePad, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 1. Hero ─────────────────────────────────
                        StaggeredSlide(
                          index: 0,
                          child: _HeroCard(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 1.5 Preuve sociale vérifiable & datée ────
                        // Self-hides until real impact data is available.
                        const HomeImpactProof(),

                        // ── 1.6 Avis publiés (preuve sociale) ────────
                        // Self-hides until real published reviews exist.
                        const StaggeredSlide(
                          index: 1,
                          child: CounsellorTestimonialsCarousel(),
                        ),

                        // ── 2. Prochaine étape ──────────────────────
                        if (controller.isStudent) ...[
                          StaggeredSlide(
                            index: 2,
                            child: _NextStepCard(
                              controller: controller,
                              activeCases: activeCases,
                            ),
                          ),
                          const SizedBox(height: KpbSpacing.lg),
                        ],

                        // ── 3. Quick Actions ────────────────────────
                        StaggeredSlide(
                          index: 3,
                          child: _QuickActions(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 3.5 Assistant d'Orientation IA ──────────
                        const StaggeredSlide(
                          index: 4,
                          child: _AiAdvisorBanner(),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 3.6 Inscriptions à l'Étranger ───────────
                        StaggeredSlide(
                          index: 5,
                          child: _AbroadEnrollmentCard(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 3.7 Outils étudiants ────────────────────
                        if (controller.isStudent)
                          StaggeredSlide(
                            index: 6,
                            child: _StudentToolsBanner(),
                          ),
                        const SizedBox(height: KpbSpacing.xl),
                      ],
                    ),
                  ),
                ),

                // ── 4. Dossiers actifs ────────────────────────────────
                if (activeCases.isNotEmpty && controller.isStudent) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'home_active_cases_title'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => controller.goToTab(StudentShellTab.cases),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.sm)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad),
                    sliver: SliverList.separated(
                      itemCount: activeCases.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KpbSpacing.sm),
                      itemBuilder: (ctx, i) => _ActiveCaseCard(
                        item: activeCases[i],
                        controller: controller,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 5. Deadline urgente ───────────────────────────────
                if (urgentScholarship != null && controller.isStudent)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad, 0,
                          KpbSpacing.pagePad, KpbSpacing.xl),
                      child: _UrgentDeadlineCard(
                        scholarship: urgentScholarship,
                        controller: controller,
                      ),
                    ),
                  ),

                // ── 5.5 Universités recommandées ───────────────────────
                if (institutions.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'home_recommended_universities_title'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () =>
                          controller.goToTab(StudentShellTab.universities),
                      itemCount: institutions.length,
                      height: 168,
                      itemWidth: 210,
                      itemBuilder: (ctx, i) {
                        final institution = institutions[i];
                        return _InstitutionCard(
                          name: controller.resolve(institution.name),
                          flag: _flag(institution.countryId),
                          location: controller.resolve(institution.location),
                          tuition: controller.resolve(institution.tuitionLabel),
                          isPartner: institution.isPartner,
                          score: controller.institutionMatch(institution),
                          onTap: () =>
                              controller.goToTab(StudentShellTab.universities),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 6. Bourses pour toi ───────────────────────────────
                if (scholarships.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'scholarships_for_you'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => Get.toNamed(AppRoutes.scholarships),
                      itemCount: scholarships.length,
                      height: 168,
                      itemWidth: 210,
                      itemBuilder: (ctx, i) {
                        final s = scholarships[i];
                        return _ScholarshipCard(
                          name: controller.resolve(s.name),
                          flag: _flag(s.countryId),
                          funding: controller.resolve(s.typeOfFunding),
                          score: controller.scholarshipMatch(s),
                          onTap: () => Get.toNamed(AppRoutes.scholarships),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 7. Articles récents ───────────────────────────────
                // Community/articles is a V1.1+ module (hidden under MVP lock).
                if (!AppConfig.mvpOnly && articles.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'latest_articles'.tr,
                      actionLabel: 'see_all'.tr,
                      onAction: () => Get.to(() => const CommunityScreen()),
                    ),
                  ),
                  const SliverToBoxAdapter(
                      child: SizedBox(height: KpbSpacing.sm)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad),
                    sliver: SliverList.separated(
                      itemCount: articles.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: KpbSpacing.sm),
                      itemBuilder: (ctx, i) => _ArticleCard(
                        article: articles[i],
                        controller: controller,
                      ),
                    ),
                  ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Find nearest scholarship with deadline within 30 days.
  ScholarshipModel? _findUrgentDeadline(List<ScholarshipModel> scholarships) {
    final now = DateTime.now();
    ScholarshipModel? nearest;
    int nearestDays = 31;

    for (final s in scholarships) {
      final parsed = _parseDeadline(s.deadlineLabel.fr);
      if (parsed != null) {
        final days = parsed.difference(now).inDays;
        if (days >= 0 && days <= 30 && days < nearestDays) {
          nearestDays = days;
          nearest = s;
        }
      }
    }
    return nearest;
  }

  DateTime? _parseDeadline(String label) {
    const months = {
      'janvier': 1,
      'février': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'août': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'décembre': 12,
    };
    final parts = label.toLowerCase().split(' ');
    if (parts.length < 3) return null;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App bar chip — light, soft-elevated icon button
// ─────────────────────────────────────────────────────────────────────────────
class _AppBarChip extends StatelessWidget {
  const _AppBarChip({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: KpbPressable(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: c.cardBg,
            shape: BoxShape.circle,
            boxShadow: c.softShadow,
            border: Border.all(color: c.border),
          ),
          child: Icon(icon, size: 20, color: c.textSecondary),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card — brand banner + animated progress ring
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final progress = (profile?.completionScore ?? 0.0).clamp(0.0, 1.0);
    final pct = (progress * 100).round();
    final showRing = controller.isStudent && pct < 100;

    return Container(
      decoration: BoxDecoration(
        gradient: KpbColors.heroGradient,
        borderRadius: KpbRadius.xlBr,
        boxShadow: KpbShadow.blue,
      ),
      padding: const EdgeInsets.all(KpbSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.isPartner
                      ? 'home_hero_title_partner'.tr
                      : controller.isParent
                          ? 'home_hero_title_parent'.tr
                          : 'home_hero_title_student'.tr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  controller.isStudent
                      ? 'home_hero_subtitle_student'.tr
                      : 'home_hero_subtitle_other'.tr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _HeroCta(
                  label: controller.isStudent
                      ? 'nav_orientation'.tr
                      : controller.isParent
                          ? 'home_hero_cta_consultation'.tr
                          : 'home_hero_cta_become_partner'.tr,
                  onTap: () {
                    if (controller.isStudent) {
                      Get.to(() => const OrientationScreen());
                    } else {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CaseComposerSheet(
                          caseType: CaseType.consultation,
                          title: 'home_case_title_book_appointment'.tr,
                          contextLabel: 'KPB Education',
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          if (showRing) ...[
            const SizedBox(width: KpbSpacing.md),
            KpbPressable(
              onTap: () => controller.goToTab(StudentShellTab.profile),
              child: Column(
                children: [
                  _AnimatedRing(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    'home_hero_profile_ring_label'.tr,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Animated white progress ring used in the hero.
class _AnimatedRing extends StatelessWidget {
  const _AnimatedRing({required this.value});
  final double value;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        height: 72,
        width: 72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            Center(
              child: Text(
                '${(v * 100).round()}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: KpbColors.blue,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded,
                size: 16, color: KpbColors.blue),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next Step Card — light, accent-driven next-best-action
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({required this.controller, required this.activeCases});
  final AppController controller;
  final List<StudentCase> activeCases;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final step = _resolveStep(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('next_step'.tr, style: KpbTextStyles.title),
        const SizedBox(height: 12),
        KpbPressable(
          onTap: step.onTap,
          child: Container(
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: step.iconColor.withValues(alpha: 0.25)),
              boxShadow: c.cardShadow,
            ),
            padding: const EdgeInsets.all(KpbSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: step.iconColor.withValues(alpha: 0.12),
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: Icon(step.icon, color: step.iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.label.toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: step.iconColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.subtitle,
                        style: KpbTextStyles.caption.copyWith(
                          color: c.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: step.iconColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  _StepData _resolveStep(BuildContext context) {
    final profile = controller.profile;
    final hasOrientation = controller.latestOrientationSession != null;

    // Priority 1 — Case requires immediate action
    final urgentCase = activeCases.firstWhere(
      (c) =>
          c.status == CaseStatus.documentsNeeded ||
          c.status == CaseStatus.awaitingStudent ||
          c.status == CaseStatus.awaitingPayment,
      orElse: () => activeCases.isEmpty ? _placeholder : activeCases.first,
    );

    if (activeCases.isNotEmpty &&
        (urgentCase.status == CaseStatus.documentsNeeded ||
            urgentCase.status == CaseStatus.awaitingStudent ||
            urgentCase.status == CaseStatus.awaitingPayment)) {
      final isPayment = urgentCase.status == CaseStatus.awaitingPayment;
      final isDocs = urgentCase.status == CaseStatus.documentsNeeded;
      return _StepData(
        label: 'home_next_step_label_action_required'.tr,
        title: isPayment
            ? 'home_next_step_title_talk_advisor'.tr
            : isDocs
                ? 'home_next_step_title_documents_to_send'.tr
                : 'home_next_step_title_response_expected'.tr,
        subtitle: controller.resolve(urgentCase.nextStepTitle),
        icon: isPayment
            ? Icons.chat_rounded
            : isDocs
                ? Icons.upload_file_rounded
                : Icons.reply_rounded,
        iconColor: KpbColors.error,
        onTap: () => Get.to(() => CaseDetailScreen(caseId: urgentCase.id)),
      );
    }

    // Priority 2 — Profile incomplete / skipped onboarding
    if (controller.needsProfileCompletionBanner) {
      final pct = ((profile?.completionScore ?? 0) * 100).round();
      return _StepData(
        label: 'home_next_step_label_your_profile'.tr,
        title: 'home_next_step_title_complete_profile'.tr,
        subtitle: controller.onboardingSkipped
            ? 'home_next_step_subtitle_missing_info'.tr
            : 'home_profile_pct_notice'.trParams({'pct': '$pct'}),
        icon: Icons.tune_rounded,
        iconColor: KpbColors.blue,
        onTap: () => Get.to(() => const OnboardingScreen()),
      );
    }

    // Priority 3 — No orientation done
    if (!hasOrientation) {
      return _StepData(
        label: 'home_next_step_label_discovery'.tr,
        title: 'home_next_step_title_take_orientation'.tr,
        subtitle: 'home_next_step_subtitle_orientation'.tr,
        icon: Icons.psychology_rounded,
        iconColor: KpbColors.blue,
        onTap: () => Get.to(() => const OrientationScreen()),
      );
    }

    // Priority 4 — Orientation done, no active cases
    if (activeCases.isEmpty) {
      return _StepData(
        label: 'home_next_step_label_next_step'.tr,
        title: 'home_next_step_title_start_case'.tr,
        subtitle: 'home_next_step_subtitle_start_case'.tr,
        icon: Icons.rocket_launch_rounded,
        iconColor: KpbColors.success,
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => CaseComposerSheet(
            caseType: CaseType.applicationSupport,
            title: 'home_case_title_new_case'.tr,
            contextLabel: 'KPB Education',
          ),
        ),
      );
    }

    // Default — everything in progress
    return _StepData(
      label: 'home_next_step_label_explore'.tr,
      title: 'home_next_step_title_discover_opportunities'.tr,
      subtitle: 'home_next_step_subtitle_explore'.tr,
      icon: Icons.explore_rounded,
      iconColor: KpbColors.sky,
      onTap: () => controller.goToTab(StudentShellTab.destinations),
    );
  }
}

// Placeholder for firstWhere default (never rendered)
final _placeholder = StudentCase(
  id: '',
  referenceCode: '',
  title: const LocalizedText(fr: '', en: ''),
  description: const LocalizedText(fr: '', en: ''),
  contextLabel: const LocalizedText(fr: '', en: ''),
  status: CaseStatus.draft,
  type: CaseType.consultation,
  preferredContactMethod: ContactMethod.inApp,
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  nextStepTitle: const LocalizedText(fr: '', en: ''),
  nextStepDescription: const LocalizedText(fr: '', en: ''),
  timeline: const [],
  messages: const [],
  documentRequests: const [],
);

class _StepData {
  const _StepData({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  final String label;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions — 4 light tiles
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final actions = <(IconData, String, Color, VoidCallback)>[
      (
        Icons.psychology_rounded,
        'nav_orientation'.tr,
        KpbColors.blue,
        () => Get.to(() => const OrientationScreen()),
      ),
      (
        Icons.explore_rounded,
        'home_next_step_label_explore'.tr,
        KpbColors.sky,
        () => controller.goToTab(StudentShellTab.destinations),
      ),
      (
        Icons.workspace_premium_rounded,
        'home_quick_action_scholarships'.tr,
        KpbColors.gold,
        () => Get.toNamed(AppRoutes.scholarships),
      ),
      (
        Icons.folder_copy_rounded,
        'home_quick_action_cases'.tr,
        KpbColors.success,
        () => controller.goToTab(StudentShellTab.cases),
      ),
    ];

    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: a == actions.last ? 0 : 8),
              child: QuickActionTile(
                icon: a.$1,
                label: a.$2,
                color: a.$3,
                onTap: a.$4,
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assistant d'Orientation IA Banner
// ─────────────────────────────────────────────────────────────────────────────
class _AiAdvisorBanner extends StatelessWidget {
  const _AiAdvisorBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KpbColors.bgDarkCard,
        borderRadius: KpbRadius.lgBr,
        border: Border.all(
          color: KpbColors.blue.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: KpbColors.blue.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(KpbSpacing.md),
      child: Row(
        children: [
          // Glowing AI icon
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: KpbColors.heroGradient,
              borderRadius: KpbRadius.mdBr,
              boxShadow: [
                BoxShadow(
                  color: KpbColors.blue.withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'home_ai_advisor_title'.tr,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KpbColors.blue.withValues(alpha: 0.2),
                        borderRadius: KpbRadius.xsBr,
                        border: Border.all(
                          color: KpbColors.blue.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        'home_badge_new'.tr,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: KpbColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'home_find_school_desc'.tr,
                  style: TextStyle(
                    fontSize: 12,
                    color: KpbColors.textDarkSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Get.to(() => const AiChatScreen()),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'home_ai_advisor_cta'.tr,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: KpbColors.blue,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: KpbColors.blue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Active Case Card — compact, status-driven
// ─────────────────────────────────────────────────────────────────────────────
class _ActiveCaseCard extends StatelessWidget {
  const _ActiveCaseCard({required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final si = _statusInfo(item.status);

    return KpbPressable(
      onTap: () => Get.to(() => CaseDetailScreen(caseId: item.id)),
      child: KpbCard(
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: si.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.resolve(item.title),
                    style: KpbTextStyles.titleMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    controller.resolve(item.nextStepTitle),
                    style: KpbTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            KpbBadge(label: si.label, color: si.color, small: true),
          ],
        ),
      ),
    );
  }

  ({Color color, String label}) _statusInfo(CaseStatus s) {
    switch (s) {
      case CaseStatus.documentsNeeded:
        return (
          color: KpbColors.warning,
          label: 'case_status_documents_needed'.tr
        );
      case CaseStatus.awaitingPayment:
        return (
          color: KpbColors.error,
          label: 'case_status_awaiting_payment'.tr
        );
      case CaseStatus.awaitingStudent:
        return (
          color: KpbColors.error,
          label: 'case_status_awaiting_student'.tr
        );
      case CaseStatus.scheduled:
        return (color: KpbColors.success, label: 'case_status_scheduled'.tr);
      case CaseStatus.inProgress:
        return (color: KpbColors.blue, label: 'case_status_in_progress'.tr);
      case CaseStatus.underReview:
        return (color: KpbColors.gold, label: 'case_status_under_review'.tr);
      case CaseStatus.counselorAssigned:
        return (
          color: KpbColors.sky,
          label: 'case_status_counselor_assigned'.tr
        );
      case CaseStatus.submitted:
        return (color: KpbColors.sky, label: 'case_status_submitted'.tr);
      case CaseStatus.applicationSubmitted:
        return (
          color: KpbColors.blueMid,
          label: 'case_status_application_submitted'.tr
        );
      case CaseStatus.waitingDecision:
        return (
          color: KpbColors.gold,
          label: 'case_status_waiting_decision'.tr
        );
      default:
        return (color: KpbColors.gray400, label: 'case_status_in_progress'.tr);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Institution Card (home)
// ─────────────────────────────────────────────────────────────────────────────
class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.name,
    required this.flag,
    required this.location,
    required this.tuition,
    required this.isPartner,
    required this.score,
    required this.onTap,
  });

  final String name;
  final String flag;
  final String location;
  final String tuition;
  final bool isPartner;
  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return KpbPressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                AdmissionMeter(
                    score: score, size: 30, strokeWidth: 3, showLabel: false),
                if (isPartner) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: KpbBadge(
                        label: 'badge_partner'.tr,
                        color: KpbColors.gold,
                        small: true,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              location,
              style: KpbTextStyles.caption.copyWith(color: c.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              tuition,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: KpbColors.blue,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Light Scholarship Card (home)
// ─────────────────────────────────────────────────────────────────────────────
class _ScholarshipCard extends StatelessWidget {
  const _ScholarshipCard({
    required this.name,
    required this.flag,
    required this.funding,
    required this.score,
    required this.onTap,
  });

  final String name;
  final String flag;
  final String funding;
  final int score;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return KpbPressable(
      onTap: onTap,
      child: Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.cardBg,
          borderRadius: KpbRadius.lgBr,
          boxShadow: c.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 24)),
                const Spacer(),
                MatchBadge(score: score),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: c.textPrimary,
                height: 1.25,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(Icons.payments_rounded,
                    size: 14, color: KpbColors.success),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    funding,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: KpbColors.success,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Urgent Deadline Card
// ─────────────────────────────────────────────────────────────────────────────
class _UrgentDeadlineCard extends StatelessWidget {
  const _UrgentDeadlineCard(
      {required this.scholarship, required this.controller});
  final ScholarshipModel scholarship;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final deadline = controller.resolve(scholarship.deadlineLabel);
    // Deadline countdown is parsed from the canonical French label
    // (the month map below is French-only), independent of display locale.
    final daysLeft = _daysLeft(scholarship.deadlineLabel.fr);

    return KpbPressable(
      onTap: () => Get.toNamed(AppRoutes.scholarships),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF7ED), Color(0xFFFEF3C7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
              color: KpbColors.gold.withValues(alpha: 0.4), width: 1.5),
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  daysLeft >= 0 ? '$daysLeft' : '!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: KpbColors.gold,
                    height: 1,
                  ),
                ),
                Text(
                  'home_days_left_label'.tr,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: KpbColors.gold,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            const VerticalDivider(
                width: 1, thickness: 1, color: Color(0xFFFDE68A)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_deadline_near_label'.tr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: KpbColors.gold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    controller.resolve(scholarship.name),
                    style: KpbTextStyles.titleMd,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${'closing_label'.tr} : $deadline',
                    style: const TextStyle(
                        fontSize: 12, color: KpbColors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: KpbColors.gold,
                borderRadius: KpbRadius.mdBr,
              ),
              child: Text(
                'home_deadline_see_button'.tr,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _daysLeft(String label) {
    const months = {
      'janvier': 1,
      'février': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'août': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'décembre': 12,
    };
    final parts = label.toLowerCase().split(' ');
    if (parts.length < 3) return -1;
    final day = int.tryParse(parts[0]);
    final month = months[parts[1]];
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return -1;
    final dt = DateTime(year, month, day);
    return dt.difference(DateTime.now()).inDays;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Article Card — compact, 2-line summary
// ─────────────────────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article, required this.controller});
  final ArticleModel article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbPressable(
      onTap: () => Get.to(() => const CommunityScreen()),
      child: KpbCard(
        child: Row(
          children: [
            Container(
              width: 4,
              height: 56,
              decoration: const BoxDecoration(
                color: KpbColors.blue,
                borderRadius: KpbRadius.pillBr,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.resolve(article.title),
                    style: KpbTextStyles.titleMd,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    controller.resolve(article.summary),
                    style: KpbTextStyles.caption,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                size: 18, color: context.kpb.gray300),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inscriptions à l'Étranger — Widget & Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AbroadEnrollmentCard extends StatelessWidget {
  const _AbroadEnrollmentCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showAbroadCountriesSheet(context, controller),
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: KpbColors.bgDarkCard,
          borderRadius: KpbRadius.lgBr,
          border: Border.all(
            color: KpbColors.gold.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: KpbColors.gold.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Premium World Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: KpbColors.goldGradient,
                    borderRadius: KpbRadius.mdBr,
                    boxShadow: [
                      BoxShadow(
                        color: KpbColors.gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.public_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'register_abroad_title'.tr,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KpbColors.gold.withValues(alpha: 0.15),
                              borderRadius: KpbRadius.xsBr,
                              border: Border.all(
                                color: KpbColors.gold.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              'home_badge_guidance'.tr,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: KpbColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'home_apply_world_desc'.tr,
                        style: TextStyle(
                          fontSize: 12,
                          color: KpbColors.textDarkSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            Container(
              height: 0.5,
              color: Colors.white.withValues(alpha: 0.1),
            ),
            const SizedBox(height: 12),
            // Footer with dynamic flag list & CTA
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Horizontal Row of Flags
                Row(
                  children: const ['canada', 'usa', 'uk', 'germany', 'morocco']
                      .map((id) => Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: KpbRadius.xsBr,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              _flag(id),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ))
                      .toList(),
                ),
                // CTA text & arrow
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'discover'.tr,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: KpbColors.gold,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 14,
                      color: KpbColors.gold,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

void _showAbroadCountriesSheet(BuildContext context, AppController controller) {
  final targetCountryIds = ['canada', 'usa', 'uk', 'germany', 'morocco'];
  final countries = targetCountryIds
      .map((id) => controller.countries.firstWhereOrNull((c) => c.id == id))
      .whereType<CountryModel>()
      .toList();

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: KpbColors.bgDarkMidnight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
        padding: EdgeInsets.only(
          left: KpbSpacing.lg,
          right: KpbSpacing.lg,
          top: KpbSpacing.md,
          bottom: KpbSpacing.xl + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grab handle
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: KpbRadius.pillBr,
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Header Title
            Row(
              children: [
                Text(
                  'register_abroad_cta'.tr,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  "🌍",
                  style: TextStyle(fontSize: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'home_destinations_desc'.tr,
              style: TextStyle(
                fontSize: 13,
                color: KpbColors.textDarkSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            // List of countries
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: countries.map((country) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: KpbColors.bgDarkCard,
                        borderRadius: KpbRadius.mdBr,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.05),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: KpbRadius.mdBr,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              Get.back();
                              Get.to(() =>
                                  CountryDetailScreen(countryId: country.id));
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(KpbSpacing.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Flag circular badge
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.06),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      _flag(country.id),
                                      style: const TextStyle(fontSize: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  // Text contents
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              controller.resolve(country.name),
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                                color: Colors.white,
                                              ),
                                            ),
                                            // Difficulty Badge
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withValues(alpha: 0.05),
                                                borderRadius: KpbRadius.xsBr,
                                              ),
                                              child: Text(
                                                'home_admission_prefix'
                                                    .trParams({
                                                  'value': controller.resolve(
                                                      country
                                                          .admissionDifficulty)
                                                }),
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: KpbColors
                                                      .textDarkSecondary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          controller.resolve(country.whyStudy),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: KpbColors.textDarkSecondary,
                                            height: 1.35,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        // Budget Row
                                        Row(
                                          children: [
                                            const Icon(
                                              Icons.payments_outlined,
                                              size: 14,
                                              color: KpbColors.gold,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'tuition_prefix'.tr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white
                                                    .withValues(alpha: 0.6),
                                              ),
                                            ),
                                            Text(
                                              controller.resolve(
                                                  country.tuitionRange),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: KpbColors.gold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Right Chevron
                                  const Padding(
                                    padding: EdgeInsets.only(top: 12),
                                    child: Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white30,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Student Tools Banner — CV generator + Letters shortcut
// ─────────────────────────────────────────────────────────────────────────────

class _StudentToolsBanner extends StatelessWidget {
  const _StudentToolsBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Get.to(() => const StudentToolsScreen()),
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              KpbColors.blue.withValues(alpha: 0.15),
              KpbColors.success.withValues(alpha: 0.10),
            ],
          ),
          borderRadius: KpbRadius.xlBr,
          border: Border.all(
            color: KpbColors.blue.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KpbColors.blue.withValues(alpha: 0.15),
                borderRadius: KpbRadius.mdBr,
              ),
              child: const Icon(
                Icons.build_circle_rounded,
                color: KpbColors.blue,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'home_student_tools_title'.tr,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.kpb.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'home_student_tools_subtitle'.tr,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.kpb.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: context.kpb.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
