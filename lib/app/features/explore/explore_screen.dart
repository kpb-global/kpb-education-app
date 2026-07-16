import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/utils/study_level.dart';
import '../../core/utils/tuition_utils.dart';
import '../cases/case_composer_sheet.dart';
import '../compare/institution_compare_screen.dart';
import 'country_detail_screen.dart';
import 'program_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Country flag lookup (shared with home)
// ─────────────────────────────────────────────────────────────────────────────
String _flag(String id) => countryFlag(id);

// ─────────────────────────────────────────────────────────────────────────────
// Palette (App-engagement handoff · Student App.dc.html · "Onglet pays"). Local
// to this file — same pattern as Home/Onboarding; no shared design-system file.
// Only the Countries grid below is restyled to the handoff (PR2).
// ─────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const sky = Color(0xFF38BDF8);
  static const slate = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const body = Color(0xFF475569);
}

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AppController>();

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('explore_title'.tr),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'explore_tab_fields'.tr),
              Tab(text: 'program_country'.tr),
              Tab(text: 'explore_tab_programs'.tr),
              Tab(text: 'explore_tab_universities'.tr),
              Tab(text: 'explore_tab_support'.tr),
            ],
          ),
        ),
        body: GetBuilder<AppController>(
          builder: (_) => TabBarView(
            children: [
              _FieldsGrid(controller: controller),
              CountriesCatalogGrid(controller: controller),
              ProgramsCatalogList(controller: controller),
              InstitutionsCatalogTab(controller: controller),
              _SupportList(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldsGrid extends StatelessWidget {
  const _FieldsGrid({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final fields = controller.fields;

    if (fields.isEmpty) {
      return KpbEmptyState(
        icon: Icons.school_outlined,
        title: 'explore_no_fields_title'.tr,
        subtitle: 'explore_no_fields_body'.tr,
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: fields.length,
      itemBuilder: (context, index) {
        final field = fields[index];
        final saved = controller.isSaved(SavedItemType.field, field.id);
        return _FieldGridCard(
          name: controller.resolve(field.name),
          description: controller.resolve(field.description),
          careers: field.careers.take(2).map(controller.resolve).toList(),
          accentColor: field.accentColor,
          saved: saved,
          onSave: () => controller.toggleSaved(SavedItemType.field, field.id),
          onTap: () => _openFieldDetail(context, field, controller),
        );
      },
    );
  }
}

class _FieldGridCard extends StatelessWidget {
  const _FieldGridCard({
    required this.name,
    required this.description,
    required this.careers,
    required this.accentColor,
    required this.saved,
    required this.onSave,
    required this.onTap,
  });

  final String name;
  final String description;
  final List<String> careers;
  final Color accentColor;
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.kpb.cardBg,
          borderRadius: KpbRadius.lgBr,
          boxShadow: KpbShadow.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color header
            Container(
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withValues(alpha: 0.75)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(KpbRadius.lg),
                ),
              ),
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'a11y_save'.tr,
                    child: GestureDetector(
                      onTap: onSave,
                      child: Icon(
                        saved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      description,
                      style: KpbTextStyles.caption,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: careers
                          .map(
                            (c) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.1),
                                borderRadius: KpbRadius.pillBr,
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
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
// Tab: Pays — grille avec drapeaux
// ─────────────────────────────────────────────────────────────────────────────
class CountriesCatalogGrid extends StatelessWidget {
  const CountriesCatalogGrid({super.key, required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final countries = controller.countries;

    if (countries.isEmpty) {
      return KpbEmptyState(
        icon: Icons.public_outlined,
        title: 'explore_no_countries_title'.tr,
        subtitle: 'explore_no_countries_body'.tr,
      );
    }

    // "Onglet pays" (handoff): a subtitle, a vertical list of dark navy country
    // guide cards, and a closing "more coming" tip card.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      itemCount: countries.length + 2,
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 11 : 10),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Text(
            'dest_list_subtitle'.tr,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _Palette.slate,
            ),
          );
        }
        if (index == countries.length + 1) {
          return const _MoreDestinationsTip();
        }

        final country = countries[index - 1];
        final intake = controller.resolve(country.nextIntakeLabel);
        final tuition = controller.resolve(country.tuitionRange);
        final popularFields = country.popularFieldIds.take(2).map((id) {
          try {
            return controller.resolve(controller.fieldById(id).name);
          } catch (_) {
            return id;
          }
        }).toList();
        // Bind the most useful real field available as the card subtitle.
        final subtitle = intake.isNotEmpty
            ? intake
            : tuition.isNotEmpty
                ? tuition
                : popularFields.join(' · ');

        return _CountryGuideCard(
          flag:
              displayCountryFlag(id: country.id, flagEmoji: country.flagEmoji),
          name: controller.resolve(country.name),
          subtitle: subtitle,
          onTap: () => Get.to(() => CountryDetailScreen(countryId: country.id)),
        );
      },
    );
  }
}

/// Dark navy "country guide" row (App-engagement handoff). Flag + name +
/// real-data subtitle + a GUIDE → affordance; opens the full country guide.
class _CountryGuideCard extends StatelessWidget {
  const _CountryGuideCard({
    required this.flag,
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  final String flag;
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _Palette.navy,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Text(flag, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _Palette.slate400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'guide_short'.tr,
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: _Palette.sky,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_rounded,
                    size: 13, color: _Palette.sky),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Closing tip card: honest "more destinations coming" note (no fabricated
/// countries), matching the handoff's "Onglet pays" footer.
class _MoreDestinationsTip extends StatelessWidget {
  const _MoreDestinationsTip();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _Palette.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_rounded,
              size: 18, color: _Palette.blue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'dest_more_coming_tip'.tr,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.55,
                fontWeight: FontWeight.w600,
                color: _Palette.body,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Formations — liste enrichie
// ─────────────────────────────────────────────────────────────────────────────
class ProgramsCatalogList extends StatefulWidget {
  const ProgramsCatalogList({super.key, required this.controller});
  final AppController controller;

  @override
  State<ProgramsCatalogList> createState() => _ProgramsCatalogListState();
}

class _ProgramsCatalogListState extends State<ProgramsCatalogList> {
  String _query = '';
  String? _fieldFilter;

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final query = _query.trim().toLowerCase();
    final filtered = controller.programs.where((program) {
      if (_fieldFilter != null && program.fieldId != _fieldFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        controller.resolve(program.name),
        controller.resolve(program.level),
        program.fieldId,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();

    final programs = [...filtered]..sort((a, b) {
        bool isPartner(ProgramModel p) {
          final inst = controller.institutionByIdOrNull(p.institutionId);
          return inst?.isPartner ?? false;
        }

        final partnerCmp =
            (isPartner(a) ? 0 : 1).compareTo(isPartner(b) ? 0 : 1);
        if (partnerCmp != 0) return partnerCmp;
        return controller
            .resolve(a.name)
            .toLowerCase()
            .compareTo(controller.resolve(b.name).toLowerCase());
      });

    if (controller.programs.isEmpty) {
      return KpbEmptyState(
        icon: Icons.menu_book_outlined,
        title: 'explore_no_programs_title'.tr,
        subtitle: 'explore_no_programs_body'.tr,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            KpbSpacing.pagePad,
            KpbSpacing.pagePad,
            KpbSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: KpbInputDecoration.build(
                  context,
                  label: 'explore_search_program'.tr,
                  prefixIcon: Icons.search_rounded,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: KpbSpacing.sm),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: Text('catalog_filter_all'.tr),
                      selected: _fieldFilter == null,
                      onSelected: (_) => setState(() => _fieldFilter = null),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('catalog_filter_business'.tr),
                      selected: _fieldFilter == 'business',
                      onSelected: (_) =>
                          setState(() => _fieldFilter = 'business'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('catalog_filter_cs'.tr),
                      selected: _fieldFilter == 'computer_science',
                      onSelected: (_) =>
                          setState(() => _fieldFilter = 'computer_science'),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: Text('catalog_filter_engineering'.tr),
                      selected: _fieldFilter == 'engineering',
                      onSelected: (_) =>
                          setState(() => _fieldFilter = 'engineering'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'catalog_program_count'
                    .trParams({'count': '${programs.length}'}),
                style: KpbTextStyles.caption.copyWith(
                  color: context.kpb.textMuted,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: programs.isEmpty
              ? KpbEmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'catalog_no_match_title'.tr,
                  subtitle: 'catalog_no_match_body'.tr,
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    KpbSpacing.pagePad,
                    0,
                    KpbSpacing.pagePad,
                    KpbSpacing.pagePad,
                  ),
                  itemCount: programs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final program = programs[index];
                    InstitutionModel? institution;
                    try {
                      institution =
                          controller.institutionById(program.institutionId);
                    } catch (_) {}

                    final saved =
                        controller.isSaved(SavedItemType.program, program.id);
                    final isPartner = institution?.isPartner ?? false;

                    return _ProgramCard(
                      name: controller.resolve(program.name),
                      institution: institution != null
                          ? controller.resolve(institution.name)
                          : null,
                      level:
                          programLevelLabel(controller.resolve(program.level)),
                      tuition: controller.resolve(program.tuition),
                      currencyCode: controller.profile?.preferredCurrency,
                      language: controller.resolve(program.language),
                      duration: controller.resolve(program.duration),
                      campusCount: program.campusOfferings.length,
                      flag: _flag(program.countryId),
                      saved: saved,
                      isPartner: isPartner,
                      onSave: () => controller.toggleSaved(
                        SavedItemType.program,
                        program.id,
                      ),
                      onTap: () => Get.to(
                        () => ProgramDetailScreen(programId: program.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({
    required this.name,
    required this.institution,
    required this.level,
    required this.tuition,
    required this.currencyCode,
    required this.language,
    required this.duration,
    required this.flag,
    required this.saved,
    this.campusCount = 0,
    this.isPartner = false,
    required this.onSave,
    required this.onTap,
  });

  final String name;
  final String? institution;
  final String level;
  final String tuition;
  final String? currencyCode;
  final String language;
  final String duration;
  final String flag;
  final bool saved;

  /// Number of campuses the formation is offered on (multi-campus schools like
  /// OMNES). 0/1 = no badge.
  final int campusCount;
  final bool isPartner;
  final VoidCallback onSave;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayedTuition = TuitionUtils.displayFromTuition(
      tuition,
      currencyCode,
    );
    return KpbCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flag
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: context.kpb.surfaceBg,
              borderRadius: KpbRadius.mdBr,
            ),
            child: Center(
              child: Text(flag, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: KpbTextStyles.titleMd, maxLines: 2),
                if (institution != null) ...[
                  const SizedBox(height: 3),
                  Text(institution!, style: KpbTextStyles.caption),
                ],
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (isPartner)
                      KpbBadgeLight(
                        label: 'catalog_partner_badge'.tr,
                        bgColor: KpbColors.skyLight,
                        textColor: KpbColors.blue,
                      ),
                    if (campusCount > 1)
                      KpbBadgeLight(
                        label: 'explore_campus_count'
                            .trParams({'count': '$campusCount'}),
                        bgColor: KpbColors.skyLight,
                        textColor: KpbColors.blue,
                      ),
                    KpbBadgeLight(label: level),
                    KpbBadgeLight(label: duration),
                    KpbBadgeLight(label: language),
                    KpbBadgeLight(
                      label: displayedTuition.isNotEmpty
                          ? displayedTuition
                          : tuition,
                      bgColor: KpbColors.goldLight,
                      textColor: KpbColors.gold,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'a11y_save'.tr,
            child: GestureDetector(
              onTap: onSave,
              child: Icon(
                saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: saved ? KpbColors.blue : context.kpb.gray300,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Universités — liste avec mode comparaison
// ─────────────────────────────────────────────────────────────────────────────
class InstitutionsCatalogTab extends StatefulWidget {
  const InstitutionsCatalogTab({super.key, required this.controller});
  final AppController controller;

  @override
  State<InstitutionsCatalogTab> createState() => _InstitutionsCatalogTabState();
}

class _InstitutionsCatalogTabState extends State<InstitutionsCatalogTab> {
  final Set<String> _compareSet = {};

  void _toggleCompare(String id) {
    setState(() {
      if (_compareSet.contains(id)) {
        _compareSet.remove(id);
      } else if (_compareSet.length < 2) {
        _compareSet.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final institutions = ctrl.institutions;

    return Stack(
      children: [
        ListView.separated(
          padding: EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            KpbSpacing.pagePad,
            KpbSpacing.pagePad,
            _compareSet.isNotEmpty ? 100 : KpbSpacing.pagePad,
          ),
          itemCount: institutions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final inst = institutions[index];
            final saved = ctrl.isSaved(SavedItemType.institution, inst.id);
            final inCompare = _compareSet.contains(inst.id);
            final score = ctrl.institutionMatch(inst);

            return _InstitutionCard(
              institution: inst,
              controller: ctrl,
              saved: saved,
              inCompare: inCompare,
              compareDisabled: !inCompare && _compareSet.length >= 2,
              score: score,
              onSave: () =>
                  ctrl.toggleSaved(SavedItemType.institution, inst.id),
              onCompare: () => _toggleCompare(inst.id),
              onShare: () => _shareInstitution(ctrl, inst),
              onApply: () => _openInstitutionDetail(context, inst, ctrl),
            );
          },
        ),

        // ── Compare bar ───────────────────────────────────────────────
        if (_compareSet.isNotEmpty)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(KpbSpacing.pagePad,
                  KpbSpacing.sm, KpbSpacing.pagePad, KpbSpacing.lg),
              decoration: BoxDecoration(
                color: context.kpb.cardBg,
                boxShadow: KpbShadow.float,
                border: Border(top: BorderSide(color: context.kpb.gray100)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'compare_selected'
                              .trParams({'n': '${_compareSet.length}'}),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.kpb.textPrimary,
                          ),
                        ),
                        if (_compareSet.length < 2)
                          Text(
                            'choose_second_uni'.tr,
                            style: TextStyle(
                                fontSize: 12, color: context.kpb.textMuted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_compareSet.length == 2)
                    FilledButton.icon(
                      onPressed: () {
                        final ids = _compareSet.toList();
                        Get.to(() => InstitutionCompareScreen(
                              institutionId1: ids[0],
                              institutionId2: ids[1],
                            ));
                      },
                      icon: const Icon(Icons.compare_arrows_rounded, size: 16),
                      label: Text('compare'.tr),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => setState(() => _compareSet.clear()),
                      child: Text('cancel'.tr),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  void _shareInstitution(AppController ctrl, InstitutionModel inst) {
    final name = ctrl.resolve(inst.name);
    final location = ctrl.resolve(inst.location);
    final tuition = ctrl.resolve(inst.tuitionLabel);
    SharePlus.instance.share(ShareParams(
      text: '🏛 $name\n📍 $location\n💰 $tuition\n\n'
              'explore_share_university'
          .tr,
    ));
  }
}

void _openInstitutionDetail(
  BuildContext context,
  InstitutionModel institution,
  AppController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _InstitutionDetailSheet(
      institution: institution,
      controller: controller,
    ),
  );
}

class _InstitutionCard extends StatelessWidget {
  const _InstitutionCard({
    required this.institution,
    required this.controller,
    required this.saved,
    required this.inCompare,
    required this.compareDisabled,
    required this.score,
    required this.onSave,
    required this.onCompare,
    required this.onShare,
    required this.onApply,
  });

  final InstitutionModel institution;
  final AppController controller;
  final bool saved;
  final bool inCompare;
  final bool compareDisabled;
  final int score;
  final VoidCallback onSave;
  final VoidCallback onCompare;
  final VoidCallback onShare;
  final VoidCallback onApply;

  Color _scoreColor(BuildContext context) {
    if (score >= 85) return KpbColors.success;
    if (score >= 70) return KpbColors.blue;
    if (score >= 50) return KpbColors.gold;
    return context.kpb.gray400;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: context.kpb.cardBg,
        borderRadius: KpbRadius.lgBr,
        boxShadow: KpbShadow.card,
        border: inCompare ? Border.all(color: KpbColors.blue, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KpbSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Flag
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: context.kpb.surfaceBg,
                    borderRadius: KpbRadius.mdBr,
                  ),
                  child: Center(
                    child: Text(
                      _flag(institution.countryId),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
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
                              maxLines: 2,
                            ),
                          ),
                          if (institution.isPartner)
                            KpbBadge(
                              label: 'badge_partner'.tr,
                              color: KpbColors.gold,
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        controller.resolve(institution.location),
                        style: KpbTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            // Info row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                KpbBadgeLight(
                  label: controller.resolve(institution.tuitionLabel),
                  bgColor: KpbColors.goldLight,
                  textColor: KpbColors.gold,
                ),
                ...institution.studyLevels.take(2).map(
                      (l) => KpbBadgeLight(label: l),
                    ),
                KpbBadgeLight(
                  label: 'explore_programs_count'
                      .trParams({'count': '${institution.programIds.length}'}),
                  bgColor: KpbColors.skyLight,
                  textColor: KpbColors.blue,
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            // Action bar
            Row(
              children: [
                // Match score
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _scoreColor(context).withValues(alpha: 0.1),
                    borderRadius: KpbRadius.pillBr,
                  ),
                  child: Text(
                    '$score%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _scoreColor(context),
                    ),
                  ),
                ),
                const Spacer(),
                // Share
                _ActionIcon(
                  icon: Icons.share_outlined,
                  color: context.kpb.gray400,
                  onTap: onShare,
                  semanticLabel: 'a11y_share'.tr,
                ),
                const SizedBox(width: 6),
                // Compare toggle
                GestureDetector(
                  onTap: compareDisabled ? null : onCompare,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: inCompare
                          ? KpbColors.blue
                          : compareDisabled
                              ? context.kpb.gray100
                              : KpbColors.bgMuted,
                      borderRadius: KpbRadius.pillBr,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.compare_arrows_rounded,
                          size: 13,
                          color: inCompare
                              ? Colors.white
                              : compareDisabled
                                  ? context.kpb.gray300
                                  : context.kpb.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          inCompare
                              ? 'compare_selected_label'.tr
                              : 'compare'.tr,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: inCompare
                                ? Colors.white
                                : compareDisabled
                                    ? context.kpb.gray300
                                    : context.kpb.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Save
                _ActionIcon(
                  icon: saved
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: saved ? KpbColors.blue : context.kpb.gray400,
                  onTap: onSave,
                  semanticLabel: 'a11y_save'.tr,
                ),
              ],
            ),
            const SizedBox(height: KpbSpacing.sm),
            // ── Primary CTA ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onApply,
                icon: const Icon(Icons.school_rounded, size: 16),
                label: Text('apply_with_kpb'.tr),
                style: FilledButton.styleFrom(
                  backgroundColor: KpbColors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: const RoundedRectangleBorder(
                      borderRadius: KpbRadius.mdBr),
                  textStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.color,
    required this.onTap,
    required this.semanticLabel,
  });
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: context.kpb.surfaceBg,
            borderRadius: KpbRadius.smBr,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Accompagnement
// ─────────────────────────────────────────────────────────────────────────────
class _SupportList extends StatelessWidget {
  const _SupportList({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final destinations = controller.visibleSupportDestinations;
    final offers = controller.publishedServiceOffers;

    return ListView(
      padding: const EdgeInsets.all(KpbSpacing.pagePad),
      children: [
        if (destinations.isNotEmpty) ...[
          Text('support_destinations'.tr, style: KpbTextStyles.title),
          const SizedBox(height: KpbSpacing.sm),
          ...destinations.map((dest) {
            CountryModel? country;
            try {
              country = controller.countryById(dest.countryId);
            } catch (_) {}
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: KpbCard(
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: context.kpb.surfaceBg,
                        borderRadius: KpbRadius.mdBr,
                      ),
                      child: Center(
                        child: Text(
                          _flag(dest.countryId),
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            country != null
                                ? controller.resolve(country.name)
                                : dest.countryId,
                            style: KpbTextStyles.titleMd,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dest.counselorNames.join(', '),
                            style: KpbTextStyles.caption,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 4,
                            children: dest.availableServiceTypes
                                .take(3)
                                .map((s) => KpbBadgeLight(label: s))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'a11y_save'.tr,
                      child: GestureDetector(
                        onTap: () => controller.toggleSaved(
                            SavedItemType.country, dest.countryId),
                        child: Icon(
                          controller.isSaved(
                                  SavedItemType.country, dest.countryId)
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: context.kpb.gray300,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: KpbSpacing.md),
        ],
        if (offers.isNotEmpty) ...[
          Text('kpb_offers'.tr, style: KpbTextStyles.title),
          const SizedBox(height: KpbSpacing.sm),
          ...offers.map((offer) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: KpbCard(
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => CaseComposerSheet(
                      caseType: CaseType.consultation,
                      title: controller.resolve(offer.name),
                      contextLabel: offer.offerType,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: context.kpb.skyLight,
                          borderRadius: KpbRadius.mdBr,
                        ),
                        child: const Icon(
                          Icons.star_outline_rounded,
                          color: KpbColors.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              controller.resolve(offer.name),
                              style: KpbTextStyles.titleMd,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              controller.resolve(offer.priceLabel),
                              style: KpbTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: context.kpb.gray400,
                      ),
                    ],
                  ),
                ),
              )),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail bottom sheets
// ─────────────────────────────────────────────────────────────────────────────
void _openFieldDetail(
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
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    controller.resolve(field.description),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            _DetailSection(
              title: 'field_careers'.tr,
              icon: Icons.work_outline_rounded,
              items: field.careers.map(controller.resolve).toList(),
            ),
            _DetailSection(
              title: 'field_key_subjects'.tr,
              icon: Icons.menu_book_outlined,
              items: field.subjects.map(controller.resolve).toList(),
            ),
            _DetailSection(
              title: 'field_skills_developed'.tr,
              icon: Icons.bolt_outlined,
              items: field.skills.map(controller.resolve).toList(),
            ),
            const SizedBox(height: KpbSpacing.sm),
            FilledButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => CaseComposerSheet(
                    caseType: CaseType.consultation,
                    title: controller.resolve(field.name),
                    contextLabel: controller.resolve(field.name),
                  ),
                );
              },
              child: Text('request_support'.tr),
            ),
            const SizedBox(height: KpbSpacing.xl),
          ],
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers for detail sheets
// ─────────────────────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: KpbColors.blue),
        const SizedBox(width: 8),
        Text(title, style: KpbTextStyles.titleMd),
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  final String title;
  final IconData icon;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: KpbSpacing.md),
      child: KpbCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: title, icon: icon),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ',
                        style: TextStyle(
                            color: KpbColors.blue,
                            fontWeight: FontWeight.w700)),
                    Expanded(child: Text(item, style: KpbTextStyles.body)),
                  ],
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
// Institution Detail Sheet — Conversion Funnel
// ─────────────────────────────────────────────────────────────────────────────
class _InstitutionDetailSheet extends StatelessWidget {
  const _InstitutionDetailSheet({
    required this.institution,
    required this.controller,
  });

  final InstitutionModel institution;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const score = 85; // Mock score for now

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.kpb.pageBg,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(KpbRadius.xl)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.kpb.gray200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.lg),
                children: [
                  // Hero Card
                  GradientHeroCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(_flag(institution.countryId),
                                style: const TextStyle(fontSize: 32)),
                            const Spacer(),
                            if (institution.isPartner)
                              KpbBadge(
                                label: 'badge_official_partner'.tr,
                                color: Colors.white.withValues(alpha: 0.2),
                                icon: Icons.verified_rounded,
                                small: true,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          controller.resolve(institution.name),
                          style: KpbTextStyles.displaySm
                              .copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          controller.resolve(institution.location),
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.lg),

                  // Admission Meter
                  const AdmissionMeter(
                    score: score,
                    size: 80,
                    strokeWidth: 8,
                  ),
                  const SizedBox(height: KpbSpacing.lg),

                  // Overview
                  KpbCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                            title: 'institution_overview'.tr,
                            icon: Icons.info_outline_rounded),
                        const SizedBox(height: 8),
                        Text(
                          controller.resolve(institution.overview),
                          style: KpbTextStyles.body,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KpbSpacing.md),

                  // Details
                  Row(
                    children: [
                      Expanded(
                        child: KpbCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('fees_per_year'.tr,
                                  style: KpbTextStyles.label),
                              const SizedBox(height: 4),
                              Text(controller.resolve(institution.tuitionLabel),
                                  style: KpbTextStyles.titleMd),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KpbCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('levels'.tr, style: KpbTextStyles.label),
                              const SizedBox(height: 4),
                              Text(institution.studyLevels.join(', '),
                                  style: KpbTextStyles.titleMd),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: KpbSpacing.md),

                  // Programs
                  _SectionTitle(
                      title: 'institution_popular_programs'.tr,
                      icon: Icons.list_alt_rounded),
                  const SizedBox(height: 12),
                  ...institution.programIds.take(3).map((id) {
                    try {
                      final prog = controller.programById(id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: KpbCard(
                          padding: const EdgeInsets.all(12),
                          onTap: () => Get.to(
                            () => ProgramDetailScreen(programId: prog.id),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(controller.resolve(prog.name),
                                        style: KpbTextStyles.titleMd),
                                    Text(controller.resolve(prog.level),
                                        style: KpbTextStyles.caption),
                                  ],
                                ),
                              ),
                              const Icon(Icons.arrow_forward_ios_rounded,
                                  size: 14, color: KpbColors.blue),
                            ],
                          ),
                        ),
                      );
                    } catch (_) {
                      return const SizedBox.shrink();
                    }
                  }),

                  if (institution.isPartner) ...[
                    const SizedBox(height: KpbSpacing.lg),
                    const _IncentiveSection(),
                  ],

                  const SizedBox(height: KpbSpacing.xxl),
                ],
              ),
            ),
            // Bottom Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  KpbSpacing.lg,
                  KpbSpacing.md,
                  KpbSpacing.lg,
                  KpbSpacing.xl + MediaQuery.of(context).padding.bottom),
              decoration: BoxDecoration(
                color: context.kpb.cardBg,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CaseComposerSheet(
                          caseType: CaseType.consultation,
                          title: 'institution_kpb_expert'.tr,
                          contextLabel: controller.resolve(institution.name),
                        ),
                      ),
                      child: Text('talk_to_expert'.tr),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: KpbButton(
                      label: institution.isPartner
                          ? 'institution_enroll_via_kpb'.tr
                          : 'learn_more'.tr,
                      onTap: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => CaseComposerSheet(
                          caseType: CaseType.applicationSupport,
                          title: controller.resolve(institution.name),
                          contextLabel: institution.isPartner
                              ? 'institution_premium_support_guaranteed'.tr
                              : 'institution_premium_support'.tr,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncentiveSection extends StatelessWidget {
  const _IncentiveSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(KpbSpacing.md),
          decoration: BoxDecoration(
            color: KpbColors.blue.withValues(alpha: 0.05),
            borderRadius: KpbRadius.lgBr,
            border: Border.all(color: KpbColors.blue.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome_rounded,
                      color: KpbColors.blue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'institution_kpb_benefits'.tr,
                    style:
                        KpbTextStyles.titleMd.copyWith(color: KpbColors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildIncentiveRow(
                icon: Icons.verified_user_rounded,
                title: 'institution_priority_admission'.tr,
                subtitle: 'institution_priority_admission_desc'.tr,
              ),
              const SizedBox(height: 12),
              _buildIncentiveRow(
                icon: Icons.support_agent_rounded,
                title: 'institution_dedicated_coach'.tr,
                subtitle: 'institution_dedicated_coach_desc'.tr,
              ),
              const SizedBox(height: 12),
              _buildIncentiveRow(
                icon: Icons.account_balance_rounded,
                title: 'institution_exclusive_scholarships'.tr,
                subtitle: 'institution_exclusive_scholarships_desc'.tr,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIncentiveRow({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: KpbRadius.smBr,
          ),
          child: Icon(icon, color: KpbColors.blue, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: KpbTextStyles.titleMd),
              Text(subtitle, style: KpbTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
