import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/shell_tabs.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/kpb_theme_ext.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// Flag helpers
// ─────────────────────────────────────────────────────────────────────────────
String _flag(String id) => countryFlag(id);

// ─────────────────────────────────────────────────────────────────────────────
// HomeScreen
//
// One job per screen: "Où en es-tu ? Quelle est ta prochaine étape ?"
//
// Structure (contextual, not catalog):
//   1. AppBar  — greeting + search + profile
//   2. Hero    — rôle + CTAs principaux
//   3. ⚡ Prochaine étape — card intelligente basée sur l'état du profil
//   4. 🗂 Quick actions — 4 tuiles
//   5. 📁 Dossiers actifs — si dossiers en cours (max 2)
//   6. ⏰ Deadline urgente — si bourse < 30 jours (1 card)
//   7. 🏆 Bourses pour toi — 3 cards horizontal scroll
//   8. 📰 Articles récents — 2 articles
// ─────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

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
        final institutions = 
            controller.institutions.take(4).toList();
        final articles =
            controller.publishedArticles.take(2).toList();
        final activeCases = controller.cases
            .where((c) =>
                c.status != CaseStatus.completed &&
                c.status != CaseStatus.cancelled &&
                c.status != CaseStatus.rejected)
            .take(2)
            .toList();

        return Container(
          color: KpbColors.bgDarkMidnight,
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
                            ? 'Bonjour, $firstName 👋'
                            : 'Bonjour 👋',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        controller.isStudent
                            ? 'Votre tableau de bord'
                            : controller.isParent
                                ? 'Espace parent'
                                : 'Espace partenaire',
                        style: KpbTextStyles.caption.copyWith(color: KpbColors.textDarkSecondary),
                      ),
                    ],
                  ),
                ),
                actions: [
                  // Search
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KpbColors.glassBg,
                        border: Border.all(color: KpbColors.glassBorder),
                        borderRadius: KpbRadius.pillBr,
                      ),
                      child: const Icon(Icons.search_rounded,
                          size: 20, color: Colors.white),
                    ),
                    onPressed: () => Get.to(() => const SearchScreen()),
                  ),
                  // Saved items
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: KpbColors.glassBg,
                        border: Border.all(color: KpbColors.glassBorder),
                        borderRadius: KpbRadius.pillBr,
                      ),
                      child: const Icon(Icons.bookmark_border_rounded,
                          size: 20, color: Colors.white),
                    ),
                    onPressed: () => Get.to(() => const SavedScreen()),
                  ),
                  // Profile
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => controller.goToTab(StudentShellTab.profile),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: KpbColors.glassBg,
                          border: Border.all(color: KpbColors.glassBorder),
                          borderRadius: KpbRadius.pillBr,
                        ),
                        child: const Icon(Icons.person_outline_rounded,
                            size: 20, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      KpbSpacing.pagePad, KpbSpacing.sm,
                      KpbSpacing.pagePad, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── 1. Hero Card ──────────────────────────────
                      StaggeredSlide(
                        index: 0,
                        child: _HeroCard(controller: controller),
                      ),
                      const SizedBox(height: KpbSpacing.lg),

                      // ── 2. Prochaine étape (contextual) ──────────
                      if (controller.isStudent) ...[
                        StaggeredSlide(
                          index: 1,
                          child: _NextStepCard(
                            controller: controller,
                            activeCases: activeCases,
                          ),
                        ),
                        const SizedBox(height: KpbSpacing.lg),
                      ],

                      // ── 3. Quick Actions ──────────────────────────
                      StaggeredSlide(
                        index: 2,
                        child: _QuickActions(controller: controller),
                      ),
                      const SizedBox(height: KpbSpacing.lg),

                      // ── 3.5 Assistant d'Orientation IA ───────────
                      const StaggeredSlide(
                        index: 3,
                        child: _AiAdvisorBanner(),
                      ),
                      const SizedBox(height: KpbSpacing.lg),

                      // ── 3.6 Inscriptions à l'Étranger ───────────────────
                      StaggeredSlide(
                        index: 4,
                        child: _AbroadEnrollmentCard(controller: controller),
                      ),
                      const SizedBox(height: KpbSpacing.lg),

                      // ── 3.7 Outils étudiants ─────────────────────────────
                      if (controller.isStudent)
                        StaggeredSlide(
                          index: 5,
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
                    title: 'Dossiers actifs',
                    actionLabel: 'Voir tout',
                    onAction: () => controller.goToTab(StudentShellTab.cases),
                    textColor: Colors.white,
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: KpbSpacing.pagePad),
                  sliver: SliverList.separated(
                    itemCount: activeCases.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: KpbSpacing.sm),
                    itemBuilder: (ctx, i) =>
                        _ActiveCaseCard(
                          item: activeCases[i],
                          controller: controller,
                        ),
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: KpbSpacing.xl)),
              ],

              // ── 5.5 Universités recommandées ───────────────────────────────
              if (institutions.isNotEmpty && (controller.isStudent || controller.isParent)) ...[
                SliverToBoxAdapter(
                  child: HScrollSection(
                    title: 'Universités recommandées',
                    actionLabel: 'Voir tout',
                    onAction: () => controller.goToTab(StudentShellTab.universities),
                    textColor: Colors.white,
                    itemCount: institutions.length,
                    height: 160,
                    itemWidth: 200,
                    itemBuilder: (ctx, i) {
                      final institution = institutions[i];
                      return InstitutionMiniCard(
                        name: controller.resolve(institution.name),
                        countryFlag: _flag(institution.countryId),
                        location: controller.resolve(institution.location),
                        tuitionLabel: controller.resolve(institution.tuitionLabel),
                        isPartner: institution.isPartner,
                        score: controller.institutionMatch(institution),
                        onTap: () => controller.goToTab(StudentShellTab.universities),
                        width: 200,
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
                    actionLabel: 'Voir tout',
                    onAction: () =>
                        Get.to(() => const CommunityScreen()),
                    textColor: Colors.white,
                  ),
                ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Card — simplified, role-focused
// ─────────────────────────────────────────────────────────────────────────────
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final profile = controller.profile;
    final progress = profile?.completionScore ?? 0.0;
    final pct = (progress * 100).round();

    return Container(
      decoration: BoxDecoration(
        gradient: KpbColors.stitchHeroGradient,
        borderRadius: KpbRadius.xlBr,
        boxShadow: [
          BoxShadow(
            color: KpbColors.stitchCyberCyan.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
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
                      ? 'Développons\nvotre réseau'
                      : controller.isParent
                          ? 'Accompagnez\nvotre enfant'
                          : 'Votre parcours\nvers l\'étranger',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Démarrez votre orientation personnalisée\ndès aujourd\'hui.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _HeroCta(
                      label: controller.isStudent
                          ? 'Orientation'
                          : controller.isParent
                              ? 'Consultation'
                              : 'Devenir partenaire',
                      primary: true,
                      onTap: () {
                        if (controller.isStudent) {
                          Get.to(() => const OrientationScreen());
                        } else {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => const CaseComposerSheet(
                              caseType: CaseType.consultation,
                              title: 'Prendre rendez-vous',
                              contextLabel: 'KPB Education',
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (controller.isStudent && pct < 100) ...[
            const SizedBox(width: KpbSpacing.md),
            GestureDetector(
              onTap: () => controller.goToTab(StudentShellTab.profile),
              child: Column(
                children: [
                  SizedBox(
                    height: 72,
                    width: 72,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                        Center(
                          child: Text(
                            '$pct%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Avancement Global',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
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

class _HeroCta extends StatelessWidget {
  const _HeroCta({
    required this.label,
    required this.primary,
    required this.onTap,
  });
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.25),
          border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
          borderRadius: KpbRadius.pillBr,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'Démarrer ➔',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: KpbColors.stitchCyberCyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Next Step Card
// ─────────────────────────────────────────────────────────────────────────────
class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.controller,
    required this.activeCases,
  });
  final AppController controller;
  final List<StudentCase> activeCases;

  @override
  Widget build(BuildContext context) {
    final step = _resolveStep(context);

    // Dark mode variant formatting
    final isAlert = step.iconColor == KpbColors.error;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Next Step',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: KpbColors.bgDarkCard,
            borderRadius: KpbRadius.lgBr,
            border: Border.all(
              color: isAlert ? KpbColors.stitchNeonRed.withValues(alpha: 0.5) : KpbColors.glassBorder, 
              width: 1.5
            ),
            boxShadow: [
              if (isAlert)
                BoxShadow(
                  color: KpbColors.stitchNeonRed.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 2,
                )
            ],
          ),
          padding: const EdgeInsets.all(KpbSpacing.md),
          child: Row(
            children: [
              // Icon
              Icon(step.icon, color: isAlert ? KpbColors.stitchNeonRed : step.iconColor, size: 28),
              const SizedBox(width: 16),

              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isAlert ? KpbColors.stitchNeonRed : step.iconColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      step.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: KpbColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // CTA button
              GestureDetector(
                onTap: step.onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: KpbRadius.pillBr,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Text(
                    'Gérer',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
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
      orElse: () => activeCases.isEmpty
          ? _placeholder
          : activeCases.first,
    );

    if (activeCases.isNotEmpty &&
        (urgentCase.status == CaseStatus.documentsNeeded ||
            urgentCase.status == CaseStatus.awaitingStudent ||
            urgentCase.status == CaseStatus.awaitingPayment)) {
      final isPayment =
          urgentCase.status == CaseStatus.awaitingPayment;
      final isDocs =
          urgentCase.status == CaseStatus.documentsNeeded;
      return _StepData(
        label: '⚡ ACTION REQUISE',
        labelColor: KpbColors.error,
        title: isPayment
            ? 'Paiement en attente'
            : isDocs
                ? 'Documents à envoyer'
                : 'Réponse attendue de toi',
        subtitle: controller.resolve(urgentCase.nextStepTitle),
        icon: isPayment
            ? Icons.credit_card_rounded
            : isDocs
                ? Icons.upload_file_rounded
                : Icons.reply_rounded,
        iconColor: KpbColors.error,
        iconBg: KpbColors.errorLight,
        bgColor: const Color(0xFFFEF2F2),
        borderColor: const Color(0xFFFCA5A5),
        onTap: () =>
            Get.to(() => CaseDetailScreen(caseId: urgentCase.id)),
      );
    }

    // Priority 2 — Profile incomplete / skipped onboarding
    if (controller.needsProfileCompletionBanner) {
      final pct = ((profile?.completionScore ?? 0) * 100).round();
      return _StepData(
        label: '📋 TON PROFIL',
        labelColor: KpbColors.blue,
        title: 'Complète ton profil',
        subtitle: controller.onboardingSkipped
            ? 'Quelques infos manquent pour personnaliser tes recommandations'
            : 'À $pct% — des champs manquants limitent tes recommandations',
        icon: Icons.tune_rounded,
        iconColor: KpbColors.blue,
        iconBg: KpbColors.skyLight,
        bgColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFFBFDBFE),
        onTap: () => Get.to(() => const OnboardingScreen()),
      );
    }

    // Priority 3 — No orientation done
    if (!hasOrientation) {
      return _StepData(
        label: '🧭 DÉCOUVERTE',
        labelColor: KpbColors.blue,
        title: 'Fais ton test d\'orientation',
        subtitle:
            '5 questions pour trouver les filières qui te correspondent',
        icon: Icons.psychology_rounded,
        iconColor: KpbColors.blue,
        iconBg: KpbColors.skyLight,
        bgColor: KpbColors.bgCard,
        borderColor: KpbColors.gray100,
        onTap: () => Get.to(() => const OrientationScreen()),
      );
    }

    // Priority 4 — Orientation done, no active cases
    if (activeCases.isEmpty) {
      return _StepData(
        label: '🚀 PROCHAINE ÉTAPE',
        labelColor: KpbColors.success,
        title: 'Démarre ton dossier',
        subtitle:
            'Tu as un profil et des résultats d\'orientation — c\'est le bon moment',
        icon: Icons.folder_copy_outlined,
        iconColor: KpbColors.success,
        iconBg: KpbColors.successLight,
        bgColor: const Color(0xFFF0FDF4),
        borderColor: const Color(0xFFBBF7D0),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => const CaseComposerSheet(
            caseType: CaseType.applicationSupport,
            title: 'Nouveau dossier',
            contextLabel: 'KPB Education',
          ),
        ),
      );
    }

    // Default — everything in progress
    return _StepData(
      label: '🌍 EXPLORER',
      labelColor: KpbColors.sky,
      title: 'Découvre de nouvelles opportunités',
      subtitle:
          'Parcours les filières, pays et grandes écoles qui matchent ton profil',
      icon: Icons.explore_outlined,
      iconColor: KpbColors.sky,
      iconBg: KpbColors.skyLight,
      bgColor: KpbColors.bgCard,
      borderColor: KpbColors.gray100,
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
  advisorPhone: null,
  advisorWhatsapp: null,
);

class _StepData {
  const _StepData({
    required this.label,
    required this.labelColor,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.bgColor,
    required this.borderColor,
    required this.onTap,
  });
  final String label;
  final Color labelColor;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color bgColor;
  final Color borderColor;
  final VoidCallback onTap;
}

// ─────────────────────────────────────────────────────────────────────────────
// Quick Actions — 4 tiles
// ─────────────────────────────────────────────────────────────────────────────
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final actions = [
      (
        Icons.psychology_outlined,
        'Orientation',
        KpbColors.stitchDeepPurple,
        () => Get.to(() => const OrientationScreen()),
      ),
      (
        Icons.explore_outlined,
        'Explorer',
        KpbColors.stitchCyberCyan,
        () => controller.goToTab(StudentShellTab.destinations),
      ),
      (
        Icons.apartment_outlined,
        'Écoles',
        KpbColors.gold,
        () => controller.goToTab(StudentShellTab.universities),
      ),
      (
        Icons.folder_copy_outlined,
        'Dossiers',
        KpbColors.success,
        () => controller.goToTab(StudentShellTab.cases),
      ),
    ];

    return Row(
      children: actions
          .map((a) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                      right: a == actions.last ? 0 : 8),
                  child: GestureDetector(
                    onTap: a.$4,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: KpbColors.bgDarkCard,
                        border: Border.all(color: a.$3.withValues(alpha: 0.5)),
                        borderRadius: KpbRadius.xsBr,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(a.$1, color: a.$3, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            a.$2,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ))
          .toList(),
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
          color: KpbColors.stitchCyberCyan.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: KpbColors.stitchCyberCyan.withValues(alpha: 0.1),
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
              gradient: KpbColors.stitchHeroGradient,
              borderRadius: KpbRadius.mdBr,
              boxShadow: [
                BoxShadow(
                  color: KpbColors.stitchCyberCyan.withValues(alpha: 0.4),
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
                    const Text(
                      "Conseiller d'Orientation IA",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: KpbColors.stitchCyberCyan.withValues(alpha: 0.2),
                        borderRadius: KpbRadius.xsBr,
                        border: Border.all(
                          color: KpbColors.stitchCyberCyan.withValues(alpha: 0.5),
                          width: 0.5,
                        ),
                      ),
                      child: const Text(
                        "Nouveau",
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: KpbColors.stitchCyberCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  "Trouvez votre école privée en France selon votre budget et vos objectifs. Discutez instantanément !",
                  style: TextStyle(
                    fontSize: 12,
                    color: KpbColors.textDarkSecondary,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => Get.to(() => const AiChatScreen()),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Discuter avec l'IA",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: KpbColors.stitchCyberCyan,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 14,
                        color: KpbColors.stitchCyberCyan,
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
  const _ActiveCaseCard(
      {required this.item, required this.controller});
  final StudentCase item;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final si = _statusInfo(item.status);

    return KpbCard(
      onTap: () => Get.to(() => CaseDetailScreen(caseId: item.id)),
      padding: const EdgeInsets.all(KpbSpacing.md),
      child: Row(
        children: [
          // Status indicator dot
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
          KpbBadge(
            label: si.label,
            color: si.color,
            small: true,
          ),
        ],
      ),
    );
  }

  ({Color color, String label}) _statusInfo(CaseStatus s) {
    switch (s) {
      case CaseStatus.documentsNeeded:
        return (color: KpbColors.warning, label: 'Docs requis');
      case CaseStatus.awaitingPayment:
        return (color: KpbColors.error, label: 'Paiement');
      case CaseStatus.awaitingStudent:
        return (color: KpbColors.error, label: 'Ta réponse');
      case CaseStatus.scheduled:
        return (color: KpbColors.success, label: 'RDV planifié');
      case CaseStatus.inProgress:
        return (color: KpbColors.blue, label: 'En cours');
      case CaseStatus.underReview:
        return (color: KpbColors.gold, label: 'En révision');
      case CaseStatus.counselorAssigned:
        return (color: KpbColors.sky, label: 'Conseiller assigné');
      case CaseStatus.submitted:
        return (color: KpbColors.sky, label: 'Soumis');
      case CaseStatus.applicationSubmitted:
        return (color: KpbColors.blueMid, label: 'Candidature envoyée');
      case CaseStatus.waitingDecision:
        return (color: KpbColors.gold, label: 'En attente');
      default:
        return (color: KpbColors.gray400, label: 'En cours');
    }
  }
}

// ── Urgent Deadline Card removed ─────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Article Card — compact, 2-line summary
// ─────────────────────────────────────────────────────────────────────────────
class _ArticleCard extends StatelessWidget {
  const _ArticleCard(
      {required this.article, required this.controller});
  final ArticleModel article;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      onTap: () => Get.to(() => const CommunityScreen()),
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
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: KpbColors.gray300),
        ],
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
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.public_rounded,
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
                          const Text(
                            "Inscriptions à l'Étranger",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: KpbColors.gold.withValues(alpha: 0.15),
                              borderRadius: KpbRadius.xsBr,
                              border: Border.all(
                                color: KpbColors.gold.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: const Text(
                              "Accompagnement",
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
                      const Text(
                        "Postulez dans les meilleures universités du monde (Canada, USA, UK, Allemagne, Maroc).",
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Découvrir",
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
              children: const [
                Text(
                  "S'inscrire à l'Étranger",
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
            const Text(
              "Découvrez les destinations d'études où KPB Education vous accompagne de A à Z : orientation, admission et visa.",
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
                              Get.to(() => CountryDetailScreen(countryId: country.id));
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
                                      color: Colors.white.withValues(alpha: 0.06),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.05),
                                                borderRadius: KpbRadius.xsBr,
                                              ),
                                              child: Text(
                                                "Admission : ${controller.resolve(country.admissionDifficulty)}",
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                  color: KpbColors.textDarkSecondary,
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
                                              "Scolarité : ",
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.white.withValues(alpha: 0.6),
                                              ),
                                            ),
                                            Text(
                                              controller.resolve(country.tuitionRange),
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
        margin: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
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
                    'Outils etudiants',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: context.kpb.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'CV, lettres de motivation, et plus',
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
