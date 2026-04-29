import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_routes.dart';
import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';
import '../academy/academy_course_screen.dart';
import 'widgets/roadmap_timeline_view.dart';
import '../../core/data/roadmap_engine.dart';

const _countryFlags = <String, String>{
  'usa': '🇺🇸', 'canada': '🇨🇦', 'france': '🇫🇷', 'uk': '🇬🇧',
  'morocco': '🇲🇦', 'turkey': '🇹🇷', 'germany': '🇩🇪', 'spain': '🇪🇸',
  'china': '🇨🇳', 'belgium': '🇧🇪', 'italy': '🇮🇹', 'portugal': '🇵🇹', 'germany_de': '🇩🇪',
};

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
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                    onPressed: () => Navigator.canPop(context)
                        ? Navigator.pop(context)
                        : null,
                  ),
                  title: Text('nav_scholarships'.tr, style: KpbTextStyles.headline),
                ),
                if (controller.syncError != null)
                  SliverToBoxAdapter(
                    child: KpbSyncErrorBanner(onRetry: controller.refresh),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: KpbSpacing.pagePad, vertical: KpbSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('recommandations_title_sc'.tr,
                            style: KpbTextStyles.titleLg),
                        const SizedBox(height: 4),
                        Text('recommandations_desc_sc'.tr,
                            style: KpbTextStyles.body),
                      ],
                    ),
                  ),
                ),
                if (items.isEmpty && !controller.isSyncing)
                  const SliverFillRemaining(
                    child: KpbEmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'Pas de bourses correspondantes',
                      subtitle:
                          'Essaie de modifier tes critères ou ton orientation.',
                    ),
                  )
                else if (items.isNotEmpty)
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final s = items[index];
                          final country = controller.countries
                              .firstWhere((c) => c.id == s.countryId);
                          return StaggeredSlide(
                            index: index,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: KpbSpacing.md),
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
  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final name = controller.resolve(s.name);
    final deadline = controller.resolve(s.deadlineLabel);
    final match = controller.scholarshipMatch(s);

    return KpbCard(
      margin: const EdgeInsets.only(bottom: 16),
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: context.kpb.surfaceBg,
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: Center(
                    child: Text(
                      _countryFlags[country.id] ?? '🌍',
                      style: const TextStyle(fontSize: 24),
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
                      controller.resolve(country.name).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: KpbColors.blue,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(name,
                        style: KpbTextStyles.titleMd,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AdmissionMeter(score: match, size: 32, strokeWidth: 3),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () => controller.toggleSaved(
                      SavedItemType.scholarship,
                      s.id,
                    ),
                    child: Icon(
                      controller.isSaved(SavedItemType.scholarship, s.id)
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_outline_rounded,
                      color: controller.isSaved(SavedItemType.scholarship, s.id)
                          ? KpbColors.blue
                          : context.kpb.gray400,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _InfoRow(
                  icon: Icons.payments_outlined,
                  label: controller.resolve(s.typeOfFunding)),
              const SizedBox(width: 16),
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
          Icon(icon, size: 14, color: context.kpb.gray400),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: KpbTextStyles.caption,
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
  CountryModel country,
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
          color: context.kpb.cardBg,
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
  final CountryModel country;
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
    
    // Parse deadline for roadmap (Mock fallback for demo)
    final deadline = RoadmapEngine.calculateDate(DateTime.now().add(const Duration(days: 90)), 0); 
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
      child: ListView(
        controller: widget.scrollController,
        children: [
          const SizedBox(height: KpbSpacing.md),
          Center(
            child: Container(
              width: 38,
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
            ),
            child: Row(
              children: [
                _buildTab(0, 'Info \u0026 Critères'),
                _buildTab(1, 'Mon Parcours Succès'),
              ],
            ),
          ),
          const SizedBox(height: KpbSpacing.xl),

          if (_tabIndex == 0) ...[
            _buildInfoContent(s, country, controller),
          ] else ...[
            RoadmapTimelineView(scholarship: s, deadline: deadline),
          ],
          
          const SizedBox(height: KpbSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final active = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? KpbColors.blue : Colors.transparent,
            borderRadius: KpbRadius.mdBr,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : context.kpb.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoContent(ScholarshipModel s, CountryModel country, AppController controller) {
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
                    label: controller.resolve(country.name).toUpperCase(),
                    color: KpbColors.blue,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    controller.resolve(s.name),
                    style: KpbTextStyles.displaySm.copyWith(height: 1.1),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Hero(
              tag: 'schol_${s.id}',
              child: AdmissionMeter(score: controller.scholarshipMatch(s), size: 48, strokeWidth: 5),
            ),
          ],
        ),
        const SizedBox(height: KpbSpacing.md),
        
        _AdmissionHook(
          score: controller.scholarshipMatch(s),
          scholarshipName: controller.resolve(s.name),
        ),
        const SizedBox(height: KpbSpacing.md),
        
        if (s.academyCourseId != null) ...[
           _AcademyCtaCard(courseId: s.academyCourseId!),
           const SizedBox(height: KpbSpacing.md),
        ],

        _buildDetailRow(Icons.school_outlined, 'Niveau : ', controller.resolve(s.levelEligible)),
        _buildDetailRow(Icons.payments_outlined, 'Financement : ', controller.resolve(s.typeOfFunding)),
        _buildDetailRow(Icons.event_outlined, 'Date limite : ', controller.resolve(s.deadlineLabel)),
        const SizedBox(height: KpbSpacing.lg),
        const Text('Critères clés :', style: KpbTextStyles.titleMd),
        const SizedBox(height: 12),
        ...s.keyRequirements.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                    padding: EdgeInsets.only(top: 6, right: 12),
                    child: Icon(Icons.check_circle_outline,
                        size: 16, color: KpbColors.blue)),
                Expanded(
                  child: Text(controller.resolve(e),
                      style: KpbTextStyles.body),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: KpbSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _showApplicationOptions(context, s, country, controller);
            },
            child: const Text('Candidater avec KPB'),
          ),
        ),
      ],
    );
  }

  void _showApplicationOptions(BuildContext context, ScholarshipModel s, CountryModel country, AppController controller) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => CaseComposerSheet(
          caseType: CaseType.scholarshipSupport,
          title: controller.resolve(s.name),
          contextLabel: controller.resolve(country.name),
        ),
      );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.kpb.gray400),
          const SizedBox(width: 8),
          Text(label, style: KpbTextStyles.body.copyWith(color: context.kpb.gray400)),
          const SizedBox(width: 4),
          Expanded(child: Text(value, style: KpbTextStyles.body.copyWith(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _AdmissionHook extends StatelessWidget {
  const _AdmissionHook({required this.score, required this.scholarshipName});
  final int score;
  final String scholarshipName;

  @override
  Widget build(BuildContext context) {
    if (score >= 85) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KpbColors.warning.withValues(alpha: 0.1),
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: KpbColors.warning.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: KpbColors.warning, size: 20),
              SizedBox(width: 8),
              Text(
                'Chances d\'admission : Faibles',
                style: TextStyle(
                  color: KpbColors.warning,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ton dossier actuel est à $score%. Pour une bourse comme "$scholarshipName", le seuil de sécurité est de 85%.',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close detail
                Get.toNamed(AppRoutes.caseCreate, arguments: {
                  'type': CaseType.scholarshipSupport,
                  'title': 'Analyse Boost : $scholarshipName',
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: KpbColors.blue,
                foregroundColor: Colors.white,
                shape: const RoundedRectangleBorder(borderRadius: KpbRadius.mdBr),
              ),
              child: const Text('Booster mon dossier à 85%'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcademyCtaCard extends StatelessWidget {
  const _AcademyCtaCard({required this.courseId});
  final String courseId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    final course = controller.getAcademyCourse(courseId);
    if (course == null) return const SizedBox.shrink();

    final isPurchased = controller.hasPurchased(courseId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: KpbColors.blue.withValues(alpha: 0.08),
        borderRadius: KpbRadius.lgBr,
        border: Border.all(color: KpbColors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.school_rounded, color: KpbColors.blue, size: 20),
              SizedBox(width: 8),
              Text(
                'KPB Academy',
                style: TextStyle(
                  color: KpbColors.blue,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPurchased ? 'Continue ta formation' : 'Prépare ta candidature avec des experts',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Accède au pack de tutoriels vidéos exclusifs pour réussir ton dossier.',
            style: TextStyle(color: context.kpb.gray400, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Get.to(() => AcademyCourseScreen(course: course)),
              icon: Icon(isPurchased ? Icons.play_circle_fill_rounded : Icons.star_rounded, size: 18),
              label: Text(isPurchased ? 'Ouvrir mon pack' : 'Voir le Pack Réussite'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isPurchased ? KpbColors.success : KpbColors.blue,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
