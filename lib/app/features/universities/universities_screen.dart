import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/program_filter_service.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/country_utils.dart';
import '../../core/ui/skeleton_loader.dart';
import '../../core/utils/study_level.dart';
import '../explore/program_detail_screen.dart';
import 'widgets/program_catalog_card.dart';

/// M6 — Recherche universités avec filtres et onglets Partenaires / Toutes.
class UniversitiesScreen extends StatefulWidget {
  const UniversitiesScreen({super.key, this.initialFieldId});

  /// Pre-filter from orientation or deep link.
  final String? initialFieldId;

  @override
  State<UniversitiesScreen> createState() => _UniversitiesScreenState();
}

class _UniversitiesScreenState extends State<UniversitiesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ProgramFilterState _filters;
  bool _filtersExpanded = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  static const _pageSize = 25;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _filters = ProgramFilterState(
      partnerOnly: true,
      fieldId: widget.initialFieldId,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _filters = _filters.copyWith(
          partnerOnly: _tabController.index == 0,
        );
        _visibleCount = _pageSize; // reset on tab switch
      });
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      // Load next page when within 400 px of the bottom.
      setState(() => _visibleCount += _pageSize);
    }
  }

  void _resetFilters() {
    setState(() {
      _visibleCount = _pageSize;
      _searchController.clear();
      _filters = ProgramFilterState(partnerOnly: _tabController.index == 0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GetBuilder<AppController>(
      builder: (controller) {
        final programs = ProgramFilterService.apply(
          controller.programs,
          _filters,
          controller,
        );

        return Scaffold(
          appBar: AppBar(
            title: Text('nav_universities'.tr),
            bottom: TabBar(
              controller: _tabController,
              onTap: (index) {
                setState(() {
                  _filters = _filters.copyWith(partnerOnly: index == 0);
                });
              },
              tabs: [
                Tab(text: 'm6_tab_partners'.tr),
                Tab(text: 'm6_tab_all'.tr),
              ],
            ),
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterHeader(
                filters: _filters,
                expanded: _filtersExpanded,
                searchController: _searchController,
                controller: controller,
                onToggleExpanded: () =>
                    setState(() => _filtersExpanded = !_filtersExpanded),
                onQueryChanged: (value) =>
                    setState(() => _filters = _filters.copyWith(query: value)),
                onFiltersChanged: (next) => setState(() => _filters = next),
                onReset: _resetFilters,
                resultCount: programs.length,
              ),
              Expanded(
                child: controller.programs.isEmpty && controller.isSyncing
                    ? _ProgramSkeletonList()
                    : controller.programs.isEmpty
                        ? const KpbEmptyState(
                            icon: Icons.menu_book_outlined,
                            title: 'Aucune formation disponible',
                            subtitle:
                                'Synchronisez l\'app avec le serveur pour charger le catalogue.',
                          )
                        : programs.isEmpty
                            ? KpbEmptyState(
                                icon: Icons.search_off_rounded,
                                title: 'catalog_no_match_title'.tr,
                                subtitle: 'catalog_no_match_body'.tr,
                                actionLabel: 'm6_reset_filters'.tr,
                                onAction: _resetFilters,
                              )
                            : _PaginatedProgramList(
                                programs: programs,
                                visibleCount: _visibleCount,
                                scrollController: _scrollController,
                                controller: controller,
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
// Paginated program list — renders the first [visibleCount] items, loads more
// when the user scrolls within 400 px of the bottom (auto-triggered via the
// parent's _scrollController listener).
// ─────────────────────────────────────────────────────────────────────────────

/// Skeleton list shown while the catalog is syncing (first launch).
class _ProgramSkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.sm,
        KpbSpacing.pagePad,
        KpbSpacing.pagePad,
      ),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonLoader.card(height: 90),
        ],
      ),
    );
  }
}

class _PaginatedProgramList extends StatelessWidget {
  const _PaginatedProgramList({
    required this.programs,
    required this.visibleCount,
    required this.scrollController,
    required this.controller,
  });

  final List<ProgramModel> programs;
  final int visibleCount;
  final ScrollController scrollController;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final shown = programs.take(visibleCount).toList();
    final hasMore = programs.length > visibleCount;

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        KpbSpacing.pagePad,
      ),
      itemCount: shown.length + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == shown.length) {
          // Footer load-indicator while next page is being rendered.
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final program = shown[index];
        final institution =
            controller.institutionByIdOrNull(program.institutionId);
        final isPartner = institution?.isPartner ?? false;

        return ProgramCatalogCard(
          name: controller.resolve(program.name),
          institution:
              institution != null ? controller.resolve(institution.name) : null,
          level: programLevelLabel(controller.resolve(program.level)),
          tuition: controller.resolve(program.tuition),
          language: controller.resolve(program.language),
          duration: controller.resolve(program.duration),
          flag: countryFlag(program.countryId),
          saved: controller.isSaved(SavedItemType.program, program.id),
          isPartner: isPartner,
          onSave: () =>
              controller.toggleSaved(SavedItemType.program, program.id),
          onTap: () => Get.to(() => ProgramDetailScreen(programId: program.id)),
        );
      },
    );
  }
}

class _FilterHeader extends StatelessWidget {
  const _FilterHeader({
    required this.filters,
    required this.expanded,
    required this.searchController,
    required this.controller,
    required this.onToggleExpanded,
    required this.onQueryChanged,
    required this.onFiltersChanged,
    required this.onReset,
    required this.resultCount,
  });

  final ProgramFilterState filters;
  final bool expanded;
  final TextEditingController searchController;
  final AppController controller;
  final VoidCallback onToggleExpanded;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ProgramFilterState> onFiltersChanged;
  final VoidCallback onReset;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
            controller: searchController,
            decoration: KpbInputDecoration.build(
              context,
              label: 'm6_search_program'.tr,
              prefixIcon: Icons.search_rounded,
            ),
            onChanged: onQueryChanged,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onToggleExpanded,
                  icon: Icon(
                    expanded ? Icons.expand_less : Icons.tune_rounded,
                    size: 18,
                  ),
                  label: Text(
                    filters.hasActiveFilters
                        ? 'm6_filters_active'.tr
                        : 'm6_filters_title'.tr,
                  ),
                ),
              ),
              if (filters.hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(onPressed: onReset, child: Text('m6_reset'.tr)),
              ],
            ],
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            _CountryFilter(
              countries: controller.countries,
              selectedId: filters.countryId,
              onChanged: (id) => onFiltersChanged(
                filters.copyWith(
                  countryId: id,
                  clearCountryId: id == null,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'm6_filter_budget'.trParams({
                'max': '${filters.budgetMaxEur.round()}',
              }),
              style: KpbTextStyles.caption,
            ),
            Slider(
              value: filters.budgetMaxEur,
              min: 1000,
              max: 30000,
              divisions: 29,
              label: '${filters.budgetMaxEur.round()} €',
              onChanged: (value) =>
                  onFiltersChanged(filters.copyWith(budgetMaxEur: value)),
            ),
            _ChipRow(
              label: 'm6_filter_level'.tr,
              options:
                  programLevelFilters.map((e) => (e.key, e.labelFr)).toList(),
              selectedKey: filters.levelKey,
              onSelected: (key) => onFiltersChanged(
                filters.copyWith(
                  levelKey: key,
                  clearLevelKey: key == null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ChipRow(
              label: 'm6_filter_field'.tr,
              options: [
                (null, 'catalog_filter_all'.tr),
                ...controller.fields.map(
                  (f) => (f.id, controller.resolve(f.name)),
                ),
              ],
              selectedKey: filters.fieldId,
              onSelected: (key) => onFiltersChanged(
                filters.copyWith(
                  fieldId: key,
                  clearFieldId: key == null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _ChipRow(
              label: 'm6_filter_language'.tr,
              options: programLanguageFilters
                  .map((e) => (e.key, e.labelFr))
                  .toList(),
              selectedKey: filters.languageKey,
              onSelected: (key) => onFiltersChanged(
                filters.copyWith(
                  languageKey: key,
                  clearLanguageKey: key == null,
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            'catalog_program_count'.trParams({'count': '$resultCount'}),
            style: KpbTextStyles.caption.copyWith(
              color: context.kpb.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountryFilter extends StatelessWidget {
  const _CountryFilter({
    required this.countries,
    required this.selectedId,
    required this.onChanged,
  });

  final List<CountryModel> countries;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: selectedId,
      decoration: KpbInputDecoration.build(
        context,
        label: 'm6_filter_country'.tr,
      ),
      items: [
        DropdownMenuItem<String?>(
          value: null,
          child: Text('catalog_filter_all'.tr),
        ),
        ...countries.map(
          (country) => DropdownMenuItem<String?>(
            value: country.id,
            child: Text(
              '${countryFlag(country.id, fallbackEmoji: country.flagEmoji)} ${country.name.fr}',
            ),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({
    required this.label,
    required this.options,
    required this.selectedKey,
    required this.onSelected,
  });

  final String label;
  final List<(String?, String)> options;
  final String? selectedKey;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KpbTextStyles.caption),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: options.map((option) {
              final (key, text) = option;
              final selected = selectedKey == key;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                // Custom chip (NOT Material FilterChip): M3 FilterChip overrides
                // even an explicit label colour with its own onSurfaceVariant,
                // which rendered unselected chips grey-on-grey. A plain
                // Container + Text guarantees the colour sticks.
                child: GestureDetector(
                  onTap: () => onSelected(selected ? null : key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                    decoration: BoxDecoration(
                      color: selected ? KpbColors.blue : KpbColors.gray100,
                      borderRadius: KpbRadius.pillBr,
                      border: Border.all(
                        color: selected ? KpbColors.blue : KpbColors.gray300,
                      ),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : KpbColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
