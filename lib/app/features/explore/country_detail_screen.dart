import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/app_tokens.dart';
import '../../core/ui/kpb_theme_ext.dart';
import '../../core/ui/kpb_components.dart';
import '../cases/case_composer_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Country flag lookup
// ─────────────────────────────────────────────────────────────────────────────
const _flags = <String, String>{
  'usa': '🇺🇸', 'canada': '🇨🇦', 'france': '🇫🇷', 'uk': '🇬🇧',
  'morocco': '🇲🇦', 'turkey': '🇹🇷', 'germany': '🇩🇪', 'spain': '🇪🇸',
  'china': '🇨🇳', 'belgium': '🇧🇪', 'italy': '🇮🇹', 'portugal': '🇵🇹',
};
String _flag(String id) => _flags[id] ?? '🌍';

// ─────────────────────────────────────────────────────────────────────────────
// Country Detail Screen — Phase B
// ─────────────────────────────────────────────────────────────────────────────
class CountryDetailScreen extends StatelessWidget {
  const CountryDetailScreen({super.key, required this.countryId});
  final String countryId;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();
    CountryModel country;
    try {
      country = controller.countryById(countryId);
    } catch (_) {
      return const Scaffold(body: Center(child: Text('Pays introuvable')));
    }

    final institutions = controller.institutions
        .where((i) => i.countryId == countryId)
        .toList();
    final programs = controller.programs
        .where((p) => p.countryId == countryId)
        .toList();
    final scholarships = controller.scholarships
        .where((s) => s.countryId == countryId)
        .toList();

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: context.kpb.pageBg,
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            // ── Sliver App Bar avec hero ──────────────────────────────
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: KpbColors.navy,
              foregroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              flexibleSpace: FlexibleSpaceBar(
                background: _CountryHero(
                  country: country,
                  controller: controller,
                ),
                collapseMode: CollapseMode.parallax,
              ),
              actions: [
                IconButton(
                  icon: Icon(
                    controller.isSaved(SavedItemType.country, countryId)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: Colors.white,
                  ),
                  onPressed: () =>
                      controller.toggleSaved(SavedItemType.country, countryId),
                ),
              ],
            ),
            // ── TabBar sticky ─────────────────────────────────────────
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyTabBarDelegate(
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  indicatorColor: KpbColors.blue,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.label,
                  labelColor: KpbColors.blue,
                  unselectedLabelColor: context.kpb.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  tabs: const [
                    Tab(text: 'Aperçu'),
                    Tab(text: 'Universités'),
                    Tab(text: 'Bourses'),
                    Tab(text: 'Visa'),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _OverviewTab(country: country, controller: controller),
              _UniversitiesTab(
                institutions: institutions,
                programs: programs,
                controller: controller,
              ),
              _ScholarshipsTab(
                scholarships: scholarships,
                country: country,
                controller: controller,
              ),
              _VisaTab(country: country, controller: controller),
            ],
          ),
        ),
        // ── CTA bottom bar ────────────────────────────────────────────
        bottomNavigationBar: _BottomCta(
          country: country,
          controller: controller,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero
// ─────────────────────────────────────────────────────────────────────────────
class _CountryHero extends StatelessWidget {
  const _CountryHero({required this.country, required this.controller});
  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: KpbColors.heroGradient),
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(_flag(country.id), style: const TextStyle(fontSize: 52)),
          const SizedBox(height: 8),
          Text(
            controller.resolve(country.name),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _HeroChip(
                icon: Icons.school_outlined,
                label: controller.resolve(country.tuitionRange),
              ),
              _HeroChip(
                icon: Icons.home_outlined,
                label: controller.resolve(country.livingCostRange),
              ),
              _HeroChip(
                icon: Icons.trending_up_rounded,
                label: controller.resolve(country.admissionDifficulty),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: KpbRadius.pillBr,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 1 — Aperçu
// ─────────────────────────────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.country, required this.controller});
  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final popularFields = country.popularFieldIds.map((id) {
      try {
        return controller.fieldById(id);
      } catch (_) {
        return null;
      }
    }).whereType<FieldModel>().toList();

    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        // Pourquoi étudier ici
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: KpbColors.gold, size: 20),
                  SizedBox(width: 8),
                  Text('Pourquoi étudier ici ?', style: KpbTextStyles.titleMd),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                controller.resolve(country.whyStudy),
                style: KpbTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Coûts
        KpbCard(
          child: Column(
            children: [
              KpbInfoRow(
                icon: Icons.school_outlined,
                label: 'Frais de scolarité',
                value: controller.resolve(country.tuitionRange),
                iconColor: KpbColors.blue,
              ),
              const KpbDivider(indent: 48),
              KpbInfoRow(
                icon: Icons.home_outlined,
                label: 'Coût de la vie / mois',
                value: controller.resolve(country.livingCostRange),
                iconColor: KpbColors.success,
              ),
              const KpbDivider(indent: 48),
              KpbInfoRow(
                icon: Icons.bar_chart_rounded,
                label: 'Niveau d\'admission',
                value: controller.resolve(country.admissionDifficulty),
                iconColor: KpbColors.warning,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Filières populaires
        if (popularFields.isNotEmpty) ...[
          KpbCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.trending_up_rounded,
                        color: KpbColors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Filières populaires', style: KpbTextStyles.titleMd),
                  ],
                ),
                const SizedBox(height: 12),
                ...popularFields.map(
                  (f) => InkWell(
                    onTap: () => _openFieldDetailSheet(context, f, controller),
                    borderRadius: KpbRadius.smBr,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: f.accentColor.withValues(alpha: 0.12),
                              borderRadius: KpbRadius.smBr,
                            ),
                            child: Icon(Icons.school_outlined,
                                color: f.accentColor, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              controller.resolve(f.name),
                              style: KpbTextStyles.titleMd,
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: context.kpb.gray400, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 60),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 2 — Universités
// ─────────────────────────────────────────────────────────────────────────────
class _UniversitiesTab extends StatelessWidget {
  const _UniversitiesTab({
    required this.institutions,
    required this.programs,
    required this.controller,
  });
  final List<InstitutionModel> institutions;
  final List<ProgramModel> programs;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (institutions.isEmpty) {
      return KpbEmptyState(
        icon: Icons.account_balance_outlined,
        title: 'Universités à venir',
        subtitle:
            'Nous ajoutons continuellement de nouveaux établissements partenaires.',
        action: FilledButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CaseComposerSheet(
              caseType: CaseType.consultation,
              title: 'Demande d\'information université',
              contextLabel: 'KPB Education',
            ),
          ),
          child: const Text('Nous contacter'),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        ...institutions.map((inst) {
          final instPrograms =
              programs.where((p) => p.institutionId == inst.id).toList();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _InstitutionCard(
              institution: inst,
              programs: instPrograms,
              controller: controller,
            ),
          );
        }),
        const SizedBox(height: 60),
      ],
    );
  }
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.institution,
    required this.programs,
    required this.controller,
  });
  final InstitutionModel institution;
  final List<ProgramModel> programs;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.kpb.skyLight,
                  borderRadius: KpbRadius.mdBr,
                ),
                child: const Icon(Icons.account_balance_outlined,
                    color: KpbColors.blue, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            controller.resolve(institution.name),
                            style: KpbTextStyles.titleMd,
                          ),
                        ),
                        if (institution.isPartner)
                          const KpbBadge(
                            label: 'Partenaire',
                            color: KpbColors.success,
                            small: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.resolve(institution.location),
                      style: KpbTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            controller.resolve(institution.overview),
            style: KpbTextStyles.bodySm,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (institution.studyLevels.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ...institution.studyLevels
                    .map((l) => KpbBadgeLight(label: l)),
                KpbBadgeLight(
                  label: controller.resolve(institution.tuitionLabel),
                  bgColor: KpbColors.goldLight,
                  textColor: KpbColors.gold,
                ),
              ],
            ),
          ],
          if (programs.isNotEmpty) ...[
            const SizedBox(height: 12),
            const KpbDivider(),
            const SizedBox(height: 10),
            const Text('Formations', style: KpbTextStyles.label),
            const SizedBox(height: 8),
            ...programs.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(Icons.menu_book_outlined,
                        size: 16, color: KpbColors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        controller.resolve(p.name),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: context.kpb.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      controller.resolve(p.duration),
                      style: KpbTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CaseComposerSheet(
                  caseType: CaseType.applicationSupport,
                  title: controller.resolve(institution.name),
                  contextLabel: controller.resolve(institution.location),
                ),
              ),
              child: const Text('Demander un accompagnement'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 3 — Bourses
// ─────────────────────────────────────────────────────────────────────────────
class _ScholarshipsTab extends StatelessWidget {
  const _ScholarshipsTab({
    required this.scholarships,
    required this.country,
    required this.controller,
  });
  final List<ScholarshipModel> scholarships;
  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    if (scholarships.isEmpty) {
      return const KpbEmptyState(
        icon: Icons.workspace_premium_outlined,
        title: 'Bourses à venir',
        subtitle: 'Nous référençons continuellement de nouvelles bourses.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      itemCount: scholarships.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final s = scholarships[index];
        final match = controller.scholarshipMatch(s);
        final saved = controller.isSaved(SavedItemType.scholarship, s.id);

        return KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.resolve(s.name),
                      style: KpbTextStyles.titleMd,
                    ),
                  ),
                  MatchBadge(score: match),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => controller.toggleSaved(
                      SavedItemType.scholarship,
                      s.id,
                    ),
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
              const SizedBox(height: 8),
              Text(controller.resolve(s.typeOfFunding), style: KpbTextStyles.bodySm),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (s.deadlineLabel.fr.isNotEmpty)
                    KpbBadgeLight(
                      label: '⏳ ${controller.resolve(s.deadlineLabel)}',
                      bgColor: KpbColors.warningLight,
                      textColor: KpbColors.warning,
                    ),
                  ...s.keyRequirements
                      .take(2)
                      .map((e) => KpbBadgeLight(label: controller.resolve(e))),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CaseComposerSheet(
                      caseType: CaseType.scholarshipSupport,
                      title: controller.resolve(s.name),
                      contextLabel: controller.resolve(country.name),
                    ),
                  ),
                  child: const Text('Candidater avec KPB'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab 4 — Visa
// ─────────────────────────────────────────────────────────────────────────────
class _VisaTab extends StatelessWidget {
  const _VisaTab({required this.country, required this.controller});
  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.article_outlined,
                      color: KpbColors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Procédure visa', style: KpbTextStyles.titleMd),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                controller.resolve(country.visaOverview),
                style: KpbTextStyles.body,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const KpbCard(
          child: Column(
            children: [
              _VisaStep(
                step: 1,
                title: 'Obtenir une lettre d\'admission',
                subtitle: 'Indispensable pour toute demande de visa étudiant.',
              ),
              KpbDivider(indent: 52),
              _VisaStep(
                step: 2,
                title: 'Préparer les documents financiers',
                subtitle:
                    'Relevés bancaires, garant ou preuve de bourse selon le pays.',
              ),
              KpbDivider(indent: 52),
              _VisaStep(
                step: 3,
                title: 'Déposer la demande',
                subtitle:
                    'Consulat, Campus France ou portail en ligne selon la destination.',
              ),
              KpbDivider(indent: 52),
              _VisaStep(
                step: 4,
                title: 'Suivi et biométrie',
                subtitle:
                    'Rendez-vous biométrique et délai de traitement à anticiper.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        KpbCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.support_agent_outlined,
                      color: KpbColors.success, size: 20),
                  SizedBox(width: 8),
                  Text('Accompagnement KPB', style: KpbTextStyles.titleMd),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Nos conseillers vous accompagnent dans la préparation de votre dossier visa : documents, délais et démarches.',
                style: KpbTextStyles.body,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CaseComposerSheet(
                      caseType: CaseType.consultation,
                      title: 'Aide visa ${controller.resolve(country.name)}',
                      contextLabel: controller.resolve(country.name),
                    ),
                  ),
                  child: const Text('Parler à un conseiller'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }
}

class _VisaStep extends StatelessWidget {
  const _VisaStep({
    required this.step,
    required this.title,
    required this.subtitle,
  });
  final int step;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: KpbColors.blue,
              borderRadius: KpbRadius.smBr,
            ),
            child: Center(
              child: Text(
                '$step',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: KpbTextStyles.titleMd),
                const SizedBox(height: 3),
                Text(subtitle, style: KpbTextStyles.bodySm),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom CTA bar
// ─────────────────────────────────────────────────────────────────────────────
class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.country, required this.controller});
  final CountryModel country;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        12,
        KpbSpacing.pagePad,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        border: Border(top: BorderSide(color: context.kpb.gray100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                controller.toggleSaved(SavedItemType.country, country.id);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    controller.isSaved(SavedItemType.country, country.id)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    controller.isSaved(SavedItemType.country, country.id)
                        ? 'Sauvegardé'
                        : 'Sauvegarder',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => CaseComposerSheet(
                  caseType: CaseType.applicationSupport,
                  title: 'Étudier en ${controller.resolve(country.name)}',
                  contextLabel: controller.resolve(country.name),
                ),
              ),
              child: const Text('Démarrer mon dossier'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky TabBar delegate
// ─────────────────────────────────────────────────────────────────────────────
class _StickyTabBarDelegate extends SliverPersistentHeaderDelegate {
  const _StickyTabBarDelegate(this.tabBar);
  final TabBar tabBar;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: context.kpb.cardBg,
      child: tabBar,
    );
  }

  @override
  double get maxExtent => tabBar.preferredSize.height;
  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  bool shouldRebuild(covariant _StickyTabBarDelegate oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Field detail sheet (shared utility for country detail)
// ─────────────────────────────────────────────────────────────────────────────
void _openFieldDetailSheet(
  BuildContext context,
  FieldModel field,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
        child: ListView(
          controller: scrollController,
          children: [
            const SizedBox(height: KpbSpacing.sm),
            Container(
              padding: const EdgeInsets.all(KpbSpacing.md),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    field.accentColor,
                    field.accentColor.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: KpbRadius.lgBr,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    controller.resolve(field.name),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.resolve(field.description),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            if (field.careers.isNotEmpty) ...[
              const Text('Débouchés', style: KpbTextStyles.titleMd),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: field.careers
                    .map((c) => KpbBadgeLight(
                          label: controller.resolve(c),
                          bgColor: field.accentColor.withValues(alpha: 0.1),
                          textColor: field.accentColor,
                        ))
                    .toList(),
              ),
              const SizedBox(height: KpbSpacing.md),
            ],
            if (field.subjects.isNotEmpty) ...[
              const Text('Matières clés', style: KpbTextStyles.titleMd),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: field.subjects
                    .map((s) => KpbBadgeLight(
                          label: controller.resolve(s),
                          bgColor: context.kpb.gray100,
                          textColor: context.kpb.textSecondary,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    ),
  );
}
