import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/skeleton.dart';
import '../cases/case_composer_sheet.dart';
import '../cases/case_detail_screen.dart';
import '../community/community_screen.dart';
import '../orientation/orientation_screen.dart';
import '../saved/saved_screen.dart';
import '../search/search_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Flag helpers
// ─────────────────────────────────────────────────────────────────────────────
const _flags = <String, String>{
  'usa': '🇺🇸', 'canada': '🇨🇦', 'france': '🇫🇷', 'uk': '🇬🇧',
  'morocco': '🇲🇦', 'turkey': '🇹🇷', 'germany': '🇩🇪', 'spain': '🇪🇸',
  'china': '🇨🇳', 'belgium': '🇧🇪', 'italy': '🇮🇹', 'portugal': '🇵🇹',
};
String _flag(String id) => _flags[id] ?? '🌍';

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
            onRetry: controller.refresh,
          );
        }

        final profile = controller.profile;
        final firstName = profile?.fullName.split(' ').first ?? '';

        // Data — limited, curated
        final institutions = 
            controller.institutions.take(4).toList();
        final scholarships =
            controller.recommendedScholarships.take(3).toList();
        final articles =
            controller.publishedArticles.take(2).toList();
        final activeCases = controller.cases
            .where((c) =>
                c.status != CaseStatus.completed &&
                c.status != CaseStatus.cancelled &&
                c.status != CaseStatus.rejected)
            .take(2)
            .toList();
        final urgentScholarship = _findUrgentDeadline(scholarships);

        return Container(
          color: KpbColors.bgDarkMidnight,
          child: KpbRefresh(
            onRefresh: controller.refresh,
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
                      onTap: () => controller.goToTab(4),
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
                    onAction: () => controller.goToTab(2),
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

              // ── 5. Deadline urgente ───────────────────────────────
              if (urgentScholarship != null && controller.isStudent)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        KpbSpacing.pagePad, 0,
                        KpbSpacing.pagePad, KpbSpacing.xl),
                    child: _UrgentDeadlineCard(
                      scholarship: urgentScholarship,
                      controller: controller,
                    ),
                  ),
                ),

              // ── 5.5 Universités recommandées ───────────────────────────────
              if (institutions.isNotEmpty && (controller.isStudent || controller.isParent)) ...[
                SliverToBoxAdapter(
                  child: HScrollSection(
                    title: 'Universités recommandées',
                    actionLabel: 'Voir tout',
                    onAction: () => controller.goToTab(1), // Go to Explore
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
                        onTap: () => controller.goToTab(1),
                        width: 200,
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: KpbSpacing.xl)),
              ],

              // ── 6. Bourses pour toi ───────────────────────────────
              if (scholarships.isNotEmpty && (controller.isStudent || controller.isParent)) ...[
                SliverToBoxAdapter(
                  child: HScrollSection(
                    title: 'scholarships_for_you'.tr,
                    actionLabel: 'Voir tout',
                    onAction: () =>
                        Get.toNamed(AppRoutes.scholarships),
                    textColor: Colors.white,
                    itemCount: scholarships.length,
                    height: 160,
                    itemWidth: 200,
                    itemBuilder: (ctx, i) {
                      final s = scholarships[i];
                      return ScholarshipMiniCard(
                        name: controller.resolve(s.name),
                        countryFlag: _flag(s.countryId),
                        amount: controller.resolve(s.typeOfFunding),
                        matchScore: controller.scholarshipMatch(s),
                        onTap: () =>
                            Get.toNamed(AppRoutes.scholarships),
                        width: 200,
                      );
                    },
                  ),
                ),
                const SliverToBoxAdapter(
                    child: SizedBox(height: KpbSpacing.xl)),
              ],

              // ── 7. Articles récents ───────────────────────────────
              if (articles.isNotEmpty) ...[
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

  /// Find nearest scholarship with deadline within 30 days.
  ScholarshipModel? _findUrgentDeadline(
      List<ScholarshipModel> scholarships) {
    final now = DateTime.now();
    ScholarshipModel? nearest;
    int nearestDays = 31;

    for (final s in scholarships) {
      final label = s.deadlineLabel.fr;
      final parsed = _parseDeadline(label);
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
    // Expects format like "15 janvier 2025" or "31 mars 2024"
    const months = {
      'janvier': 1, 'février': 2, 'mars': 3, 'avril': 4,
      'mai': 5, 'juin': 6, 'juillet': 7, 'août': 8,
      'septembre': 9, 'octobre': 10, 'novembre': 11, 'décembre': 12,
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
              onTap: () => controller.goToTab(4),
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

    // Priority 2 — Profile < 50%
    final pct = ((profile?.completionScore ?? 0) * 100).round();
    if (pct < 50) {
      return _StepData(
        label: '📋 TON PROFIL',
        labelColor: KpbColors.blue,
        title: 'Complète ton profil',
        subtitle:
            'À $pct% — des champs manquants limitent tes recommandations',
        icon: Icons.tune_rounded,
        iconColor: KpbColors.blue,
        iconBg: KpbColors.skyLight,
        bgColor: const Color(0xFFEFF6FF),
        borderColor: const Color(0xFFBFDBFE),
        onTap: () => controller.goToTab(4),
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
          'Parcours les filières, pays et bourses qui matchent ton profil',
      icon: Icons.explore_outlined,
      iconColor: KpbColors.sky,
      iconBg: KpbColors.skyLight,
      bgColor: KpbColors.bgCard,
      borderColor: KpbColors.gray100,
      onTap: () => controller.goToTab(1),
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
        () => controller.goToTab(1),
      ),
      (
        Icons.workspace_premium_outlined,
        'Bourses',
        KpbColors.gold,
        () => Get.toNamed(AppRoutes.scholarships),
      ),
      (
        Icons.folder_copy_outlined,
        'Dossiers',
        KpbColors.success,
        () => controller.goToTab(2),
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
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              a.$2,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
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
    final deadline = scholarship.deadlineLabel.fr;
    final daysLeft = _daysLeft(deadline);

    return Container(
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
          // Countdown
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
              const Text(
                'jours',
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
                const Text(
                  '⏰ DEADLINE PROCHE',
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
                  'Clôture : $deadline',
                  style: const TextStyle(
                      fontSize: 12, color: KpbColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () =>
                Get.toNamed(AppRoutes.scholarships),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: KpbColors.gold,
                borderRadius: KpbRadius.mdBr,
              ),
              child: const Text(
                'Voir →',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  int _daysLeft(String label) {
    const months = {
      'janvier': 1, 'février': 2, 'mars': 3, 'avril': 4,
      'mai': 5, 'juin': 6, 'juillet': 7, 'août': 8,
      'septembre': 9, 'octobre': 10, 'novembre': 11, 'décembre': 12,
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
