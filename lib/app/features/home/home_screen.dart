import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/kpb_theme_ext.dart';
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
// HomeScreen — light premium, momentum-first
//
// One job per screen: "Où en es-tu ? Quelle est ta prochaine étape ?"
//   1. AppBar  — greeting + search / saved / profile
//   2. Hero    — brand banner + animated progress ring (momentum)
//   3. ⚡ Prochaine étape — smart next-best-action card
//   4. 🗂 Quick actions — 4 light tiles
//   5. 📁 Dossiers actifs · ⏰ Deadline · 🏛 Universités · 🏆 Bourses · 📰 Articles
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
          return KpbErrorState(onRetry: controller.refresh);
        }

        final profile = controller.profile;
        final firstName = profile?.fullName.split(' ').first ?? '';

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
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          controller.isStudent
                              ? 'Votre tableau de bord'
                              : controller.isParent
                                  ? 'Espace parent'
                                  : 'Espace partenaire',
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
                        onTap: () => controller.goToTab(4),
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
                        // ── 1. Hero ─────────────────────────────────
                        StaggeredSlide(
                          index: 0,
                          child: _HeroCard(controller: controller),
                        ),
                        const SizedBox(height: KpbSpacing.lg),

                        // ── 2. Prochaine étape ──────────────────────
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

                        // ── 3. Quick Actions ────────────────────────
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
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.sm)),
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
                  const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),
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

                // ── 5.5 Universités recommandées ───────────────────────
                if (institutions.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'Universités recommandées',
                      actionLabel: 'Voir tout',
                      onAction: () => controller.goToTab(1),
                      itemCount: institutions.length,
                      height: 168,
                      itemWidth: 210,
                      itemBuilder: (ctx, i) {
                        final institution = institutions[i];
                        return _InstitutionCard(
                          name: controller.resolve(institution.name),
                          flag: _flag(institution.countryId),
                          location: controller.resolve(institution.location),
                          tuition:
                              controller.resolve(institution.tuitionLabel),
                          isPartner: institution.isPartner,
                          score: controller.institutionMatch(institution),
                          onTap: () => controller.goToTab(1),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 6. Bourses pour toi ───────────────────────────────
                if (scholarships.isNotEmpty &&
                    (controller.isStudent || controller.isParent)) ...[
                  SliverToBoxAdapter(
                    child: HScrollSection(
                      title: 'scholarships_for_you'.tr,
                      actionLabel: 'Voir tout',
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
                  const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.xl)),
                ],

                // ── 7. Articles récents ───────────────────────────────
                if (articles.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: 'latest_articles'.tr,
                      actionLabel: 'Voir tout',
                      onAction: () => Get.to(() => const CommunityScreen()),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: KpbSpacing.sm)),
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
                      ? 'Développons\nvotre réseau'
                      : controller.isParent
                          ? 'Accompagnez\nvotre enfant'
                          : 'Votre parcours\nvers l\'étranger',
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
                      ? 'Une étape à la fois — on avance ensemble.'
                      : 'Démarrez dès aujourd\'hui.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                _HeroCta(
                  label: controller.isStudent
                      ? 'Orientation'
                      : controller.isParent
                          ? 'Consultation'
                          : 'Devenir partenaire',
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
          ),
          if (showRing) ...[
            const SizedBox(width: KpbSpacing.md),
            KpbPressable(
              onTap: () => controller.goToTab(4),
              child: Column(
                children: [
                  _AnimatedRing(value: progress),
                  const SizedBox(height: 8),
                  Text(
                    'Profil',
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
        Text('Prochaine étape', style: KpbTextStyles.title),
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

    final urgentCase = activeCases.firstWhere(
      (c) =>
          c.status == CaseStatus.documentsNeeded ||
          c.status == CaseStatus.awaitingStudent ||
          c.status == CaseStatus.awaitingPayment,
      orElse: () =>
          activeCases.isEmpty ? _placeholder : activeCases.first,
    );

    if (activeCases.isNotEmpty &&
        (urgentCase.status == CaseStatus.documentsNeeded ||
            urgentCase.status == CaseStatus.awaitingStudent ||
            urgentCase.status == CaseStatus.awaitingPayment)) {
      final isPayment = urgentCase.status == CaseStatus.awaitingPayment;
      final isDocs = urgentCase.status == CaseStatus.documentsNeeded;
      return _StepData(
        label: 'Action requise',
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
        onTap: () => Get.to(() => CaseDetailScreen(caseId: urgentCase.id)),
      );
    }

    final pct = ((profile?.completionScore ?? 0) * 100).round();
    if (pct < 50) {
      return _StepData(
        label: 'Ton profil',
        title: 'Complète ton profil',
        subtitle:
            'À $pct% — des champs manquants limitent tes recommandations',
        icon: Icons.tune_rounded,
        iconColor: KpbColors.blue,
        onTap: () => controller.goToTab(4),
      );
    }

    if (!hasOrientation) {
      return _StepData(
        label: 'Découverte',
        title: 'Fais ton test d\'orientation',
        subtitle:
            '5 questions pour trouver les filières qui te correspondent',
        icon: Icons.psychology_rounded,
        iconColor: KpbColors.blue,
        onTap: () => Get.to(() => const OrientationScreen()),
      );
    }

    if (activeCases.isEmpty) {
      return _StepData(
        label: 'Prochaine étape',
        title: 'Démarre ton dossier',
        subtitle:
            'Profil et orientation prêts — c\'est le bon moment pour te lancer',
        icon: Icons.rocket_launch_rounded,
        iconColor: KpbColors.success,
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

    return _StepData(
      label: 'Explorer',
      title: 'Découvre de nouvelles opportunités',
      subtitle:
          'Parcours les filières, pays et bourses qui matchent ton profil',
      icon: Icons.explore_rounded,
      iconColor: KpbColors.sky,
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
        'Orientation',
        KpbColors.blue,
        () => Get.to(() => const OrientationScreen()),
      ),
      (
        Icons.explore_rounded,
        'Explorer',
        KpbColors.sky,
        () => controller.goToTab(1),
      ),
      (
        Icons.workspace_premium_rounded,
        'Bourses',
        KpbColors.gold,
        () => Get.toNamed(AppRoutes.scholarships),
      ),
      (
        Icons.folder_copy_rounded,
        'Dossiers',
        KpbColors.success,
        () => controller.goToTab(2),
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
                AdmissionMeter(score: score, size: 30, strokeWidth: 3,
                    showLabel: false),
                if (isPartner) ...[
                  const SizedBox(width: 6),
                  const KpbBadge(
                    label: 'Partenaire',
                    color: KpbColors.gold,
                    small: true,
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
    final deadline = scholarship.deadlineLabel.fr;
    final daysLeft = _daysLeft(deadline);

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
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          ],
        ),
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
