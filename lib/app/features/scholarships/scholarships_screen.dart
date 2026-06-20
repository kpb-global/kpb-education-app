import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/ui/components/scholarship_status_badge.dart';
import '../../core/utils/country_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../academy/academy_course_screen.dart';
import 'scholarship_eligibility_screen.dart';
import 'widgets/roadmap_timeline_view.dart';
import '../../core/data/roadmap_engine.dart';

class ScholarshipsScreen extends StatelessWidget {
  const ScholarshipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return GetBuilder<AppController>(
      builder: (_) {
        final items = controller.recommendedScholarships;

        return Scaffold(
          backgroundColor: context.kpb.pageBg,
          body: SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: context.kpb.pageBg,
                  leading: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 20, color: context.kpb.textPrimary),
                    onPressed: () => Navigator.canPop(context)
                        ? Navigator.pop(context)
                        : null,
                  ),
                  title: Text('nav_scholarships'.tr,
                      style: KpbTextStyles.headline
                          .copyWith(color: context.kpb.textPrimary)),
                ),
                if (controller.syncError != null)
                  SliverToBoxAdapter(
                    child: KpbSyncErrorBanner(onRetry: controller.pullToRefresh),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad,
                        vertical: KpbSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('recommandations_title_sc'.tr,
                            style: KpbTextStyles.titleLg
                                .copyWith(color: context.kpb.textPrimary)),
                        const SizedBox(height: 4),
                        Text('recommandations_desc_sc'.tr,
                            style: KpbTextStyles.body
                                .copyWith(color: context.kpb.textSecondary)),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty && !controller.isSyncing)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: KpbEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'Pas de bourses correspondantes',
                        subtitle:
                            'Essaie de modifier tes critères ou ton orientation.',
                      ),
                    ),
                  )
                else if (items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final s = items[index];
                          final country =
                              controller.countryByIdOrNull(s.countryId);
                          return StaggeredSlide(
                            index: index,
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(bottom: KpbSpacing.md),
                              child: _ScholarshipCard(
                                scholarship: s,
                                country: country,
                                controller: controller,
                              ),
                            ),
                          );
                        },
                        childCount: items.length,
                      ),
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScholarshipCard extends StatelessWidget {
  const _ScholarshipCard({
    required this.scholarship,
    required this.country,
    required this.controller,
  });

  final ScholarshipModel scholarship;
  final CountryModel? country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final countryName = country != null
        ? controller.resolve(country!.name)
        : s.countryId.toUpperCase();
    final name = controller.resolve(s.name);
    final deadline = controller.resolve(s.deadlineLabel);
    final match = controller.scholarshipMatch(s);

    return KpbCard(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(16),
      onTap: () => _openDetail(context, s, country, controller),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'schol_${s.id}',
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.kpb.surfaceBg,
                    borderRadius: KpbRadius.mdBr,
                    border: Border.all(color: context.kpb.gray100),
                  ),
                  child: Center(
                    child: Text(
                      countryFlag(s.countryId),
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      countryName.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.blue,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(name,
                        style: KpbTextStyles.titleMd.copyWith(
                            color: context.kpb.textPrimary, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AdmissionMeter(score: match, size: 34, strokeWidth: 3.5),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => controller.toggleSaved(
                      SavedItemType.scholarship,
                      s.id,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color:
                            controller.isSaved(SavedItemType.scholarship, s.id)
                                ? KpbColors.blue.withValues(alpha: 0.1)
                                : Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        controller.isSaved(SavedItemType.scholarship, s.id)
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_outline_rounded,
                        color:
                            controller.isSaved(SavedItemType.scholarship, s.id)
                                ? KpbColors.blue
                                : context.kpb.gray400,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ScholarshipStatusBadge(scholarship: s, compact: true),
              _InfoRow(
                  icon: Icons.payments_outlined,
                  label: controller.resolve(s.typeOfFunding)),
              _InfoRow(icon: Icons.event_outlined, label: deadline),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.kpb.gray400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: KpbTextStyles.caption
                  .copyWith(color: context.kpb.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheet
// ─────────────────────────────────────────────────────────────────────────────
void _openDetail(
  BuildContext context,
  ScholarshipModel s,
  CountryModel? country,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: ctx.kpb.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: _DetailSheetContent(
          scholarship: s,
          country: country,
          controller: controller,
          scrollController: sc,
        ),
      ),
    ),
  );
}

class _DetailSheetContent extends StatefulWidget {
  const _DetailSheetContent({
    required this.scholarship,
    required this.country,
    required this.controller,
    required this.scrollController,
  });

  final ScholarshipModel scholarship;
  final CountryModel? country;
  final AppController controller;
  final ScrollController scrollController;

  @override
  State<_DetailSheetContent> createState() => _DetailSheetContentState();
}

class _DetailSheetContentState extends State<_DetailSheetContent> {
  int _tabIndex = 0; // 0: Info, 1: Roadmap

  @override
  Widget build(BuildContext context) {
    final s = widget.scholarship;
    final country = widget.country;
    final controller = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parse deadline for roadmap (Mock fallback for demo)
    final deadline = RoadmapEngine.calculateDate(
        DateTime.now().add(const Duration(days: 90)), 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
      child: ListView(
        controller: widget.scrollController,
        children: [
          const SizedBox(height: KpbSpacing.md),
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: context.kpb.gray200,
                borderRadius: KpbRadius.pillBr,
              ),
            ),
          ),
          const SizedBox(height: KpbSpacing.lg),

          // TAB SELECTOR
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              borderRadius: KpbRadius.lgBr,
              border: Border.all(color: context.kpb.gray100),
            ),
            child: Row(
              children: [
                _buildTab(0, 'Info \u0026 Critères', isDark),
                _buildTab(1, 'Mon Parcours Succès', isDark),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.xl),

          if (_tabIndex == 0) ...[
            _buildInfoContent(s, country, controller, isDark),
          ] else ...[
            RoadmapTimelineView(scholarship: s, deadline: deadline),
          ],

          const SizedBox(height: KpbSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, bool isDark) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? KpbColors.blue : Colors.transparent,
            borderRadius: KpbRadius.mdBr,
            boxShadow: active ? (isDark ? null : KpbShadow.soft) : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              color: active ? Colors.white : context.kpb.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoContent(ScholarshipModel s, CountryModel? country,
      AppController controller, bool isDark) {
    final countryName = country != null
        ? controller.resolve(country.name)
        : s.countryId.toUpperCase();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KpbBadge(
                    label: countryName.toUpperCase(),
                    color: KpbColors.blue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    controller.resolve(s.name),
                    style: KpbTextStyles.displaySm
                        .copyWith(height: 1.1, color: context.kpb.textPrimary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Hero(
              tag: 'schol_${s.id}',
              child: AdmissionMeter(
                  score: controller.scholarshipMatch(s),
                  size: 54,
                  strokeWidth: 5),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.lg),
        Align(
          alignment: Alignment.centerLeft,
          child: ScholarshipStatusBadge(scholarship: s),
        ),
        const SizedBox(height: KpbSpacing.md),
        _AdmissionHook(
          score: controller.scholarshipMatch(s),
          scholarshipName: controller.resolve(s.name),
          isDark: isDark,
        ),
        const SizedBox(height: KpbSpacing.md),
        // KPB Academy is a V1.1+ module (hidden under MVP lock).
        if (!AppConfig.mvpOnly && s.academyCourseId != null) ...[
          _AcademyCtaCard(courseId: s.academyCourseId!, isDark: isDark),
          const SizedBox(height: KpbSpacing.md),
        ],
        _buildDetailRow(Icons.school_outlined, 'Niveau : ',
            controller.resolve(s.levelEligible)),
        _buildDetailRow(Icons.payments_outlined, 'Financement : ',
            controller.resolve(s.typeOfFunding)),
        _buildDetailRow(Icons.event_outlined, 'Date limite : ',
            controller.resolve(s.deadlineLabel)),
        const SizedBox(height: KpbSpacing.xl),
        Text('Critères clés :',
            style:
                KpbTextStyles.titleMd.copyWith(color: context.kpb.textPrimary)),
        const SizedBox(height: 16),
        ...s.keyRequirements.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 12),
                  child: Icon(Icons.check_circle_rounded,
                      size: 20, color: KpbColors.blue),
                ),
                Expanded(
                  child: Text(controller.resolve(e),
                      style: KpbTextStyles.body
                          .copyWith(color: context.kpb.textSecondary)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KpbSpacing.xl),
        OutlinedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            Get.to(() => ScholarshipEligibilityScreen(scholarship: s));
          },
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Suis-je éligible ?'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            foregroundColor:
                KpbColors.blue,
            side: BorderSide(
                color: KpbColors.blue),
          ),
        ),
        const SizedBox(height: KpbSpacing.sm),
        KpbButton(
          text: 'Candidater avec KPB',
          onPressed: () {
            Navigator.pop(context);
            _showApplicationOptions(context, s, country, controller);
          },
          bgColor: KpbColors.blue,
          icon: Icons.rocket_launch_rounded,
        ),
      ],
    );
  }

  void _showApplicationOptions(BuildContext context, ScholarshipModel s,
      CountryModel? country, AppController controller) {
    final countryLabel = country != null
        ? controller.resolve(country.name)
        : s.countryId.toUpperCase();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CaseComposerSheet(
        caseType: CaseType.scholarshipSupport,
        title: controller.resolve(s.name),
        contextLabel: countryLabel,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: context.kpb.gray400),
          ),
          const SizedBox(width: 12),
          Text(label,
              style: KpbTextStyles.body.copyWith(color: context.kpb.textMuted)),
          const SizedBox(width: 4),
          Expanded(
              child: Text(value,
                  style: KpbTextStyles.body.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.kpb.textPrimary))),
        ],
      ),
    );
  }
}

class _AdmissionHook extends StatelessWidget {
  const _AdmissionHook(
      {required this.score,
      required this.scholarshipName,
      required this.isDark});
  final int score;
  final String scholarshipName;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (score >= 85) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: KpbColors.warning.withValues(alpha: 0.1),
        borderRadius: KpbRadius.xlBr,
        border: Border.all(color: KpbColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: KpbColors.warning.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: KpbColors.warning, size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Chances d\'admission : Faibles',
                style: TextStyle(
                  color: KpbColors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Ton dossier actuel est à $score%. Pour une bourse comme "$scholarshipName", le seuil de sécurité est de 85%.',
            style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : context.kpb.textSecondary,
                height: 1.4),
          ),
          const SizedBox(height: 16),
          KpbButton(
            text: 'Booster mon dossier à 85%',
            onPressed: () {
              Navigator.pop(context); // Close detail
              Get.toNamed(AppRoutes.caseCreate, arguments: {
                'type': CaseType.scholarshipSupport,
                'title': 'Analyse Boost : $scholarshipName',
              });
            },
            bgColor: KpbColors.warning,
            textColor: Colors.white,
            icon: Icons.trending_up_rounded,
          ),
        ],
      ),
    );
  }
}

class _AcademyCtaCard extends StatelessWidget {
  const _AcademyCtaCard({required this.courseId, required this.isDark});
  final String courseId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final course = controller.getAcademyCourse(courseId);
    if (course == null) return const SizedBox.shrink();

    final isPurchased = controller.hasPurchased(courseId);
    final themeColor = KpbColors.blue;

    return Container(
      padding: const EdgeInsets.all(KpbSpacing.lg),
      decoration: BoxDecoration(
        color: themeColor.withValues(alpha: 0.08),
        borderRadius: KpbRadius.xlBr,
        border: Border.all(color: themeColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: themeColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school_rounded, color: themeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                'KPB Academy',
                style: TextStyle(
                  color: themeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPurchased
                ? 'Continue ta formation'
                : 'Prépare ta candidature avec des experts',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: context.kpb.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Accède au pack de tutoriels vidéos exclusifs pour réussir ton dossier.',
            style: TextStyle(
                color: context.kpb.textSecondary, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 16),
          KpbButton(
            text: isPurchased ? 'Ouvrir mon pack' : 'Voir le Pack Réussite',
            onPressed: () => Get.to(() => AcademyCourseScreen(course: course)),
            bgColor: isPurchased ? KpbColors.success : themeColor,
            icon: isPurchased
                ? Icons.play_circle_fill_rounded
                : Icons.star_rounded,
          ),
        ],
      ),
    );
  }
}
