import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/models/eef_search.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_catalog_controller.dart';

/// Le catalogue « Études en France », cherché SUR LE SERVEUR.
///
/// ## Pourquoi cet écran ne charge pas le catalogue
///
/// `AppController` tient la totalité du catalogue en mémoire et filtre côté
/// app. C'était tenable à 133 formations ; à 10 247 c'est une app qui rame sur
/// les appareils les moins chers — ceux du public visé. Cet écran ne garde donc
/// jamais plus que les pages qu'on lui a demandé d'afficher, et tout le tri,
/// les filtres et les compteurs viennent de `GET /etudes-en-france/search`.
///
/// ## Ce que l'écran s'interdit
///
/// Confondre « rien ne correspond » et « je n'ai pas pu demander ». Le premier
/// est un fait qui appelle à élargir sa recherche, le second une panne qui
/// appelle à réessayer. Deux états, deux écrans, deux gestes.
class EefCatalogScreen extends StatefulWidget {
  const EefCatalogScreen({super.key});

  @override
  State<EefCatalogScreen> createState() => _EefCatalogScreenState();
}

class _EefCatalogScreenState extends State<EefCatalogScreen> {
  late final EefCatalogController _controller;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    // `AppApiClient` n'est pas enregistré dans GetX : il vit sur
    // `AppController`, qui l'a construit. Même motif que la vitrine.
    _controller = EefCatalogController(
      apiClient: Get.find<AppController>().apiClient,
    );
    _controller.addListener(_onControllerChanged);
    _scroll.addListener(_onScroll);
    _controller.refresh();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    // Un écran d'avance : la page suivante part avant que l'étudiant ne voie le
    // bas de la liste, donc sans temps mort visible.
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 600) _controller.loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('eef_catalog_title'.tr)),
      body: Column(
        children: [
          _SearchField(controller: _controller),
          _FacetBar(controller: _controller),
          Expanded(child: _Results(controller: _controller, scroll: _scroll)),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final EefCatalogController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.md,
        KpbSpacing.pagePad,
        KpbSpacing.sm,
      ),
      child: TextField(
        onChanged: controller.onQueryChanged,
        onSubmitted: controller.search,
        textInputAction: TextInputAction.search,
        decoration: KpbInputDecoration.build(
          context,
          label: 'eef_catalog_search_hint'.tr,
          prefixIcon: Icons.search_rounded,
        ),
      ),
    );
  }
}

/// Les sélecteurs. Chaque puce porte son compte, et ce compte est calculé
/// SANS le filtre de sa propre famille : il répond donc à « combien en
/// aurais-je si je choisissais celle-ci ? », ce qui est la seule question
/// qu'on se pose devant un filtre.
class _FacetBar extends StatelessWidget {
  const _FacetBar({required this.controller});

  final EefCatalogController controller;

  static const _facets = <({String key, String labelKey})>[
    (key: kEefFacetCycle, labelKey: 'eef_catalog_facet_cycle'),
    (key: kEefFacetProcedure, labelKey: 'eef_catalog_facet_procedure'),
  ];

  String _valueLabel(String facet, String value) {
    final key = 'eef_catalog_value_${facet}_$value';
    final translated = key.tr;
    // `.tr` rend la CLÉ quand elle manque. Servir « eef_catalog_value_cycle_x »
    // à un étudiant serait pire que servir la valeur brute du serveur.
    return translated == key ? value : translated;
  }

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    for (final facet in _facets) {
      final values = controller.facets[facet.key] ?? const <EefFacetValue>[];
      for (final entry in values) {
        chips.add(
          Padding(
            padding: const EdgeInsets.only(right: KpbSpacing.xs),
            child: FilterChip(
              selected: controller.isSelected(facet.key, entry.value),
              onSelected: (_) => controller.toggleFacet(facet.key, entry.value),
              label: Text(
                '${_valueLabel(facet.key, entry.value)} · ${entry.count}',
                style: KpbTextStyles.caption,
              ),
            ),
          ),
        );
      }
    }
    if (chips.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
        children: chips,
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.controller, required this.scroll});

  final EefCatalogController controller;
  final ScrollController scroll;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == EefCatalogPhase.failed) {
      return KpbErrorState(
        title: controller.failure == EefCatalogFailure.network
            ? 'eef_catalog_error_network_title'.tr
            : 'eef_catalog_error_server_title'.tr,
        subtitle: 'eef_catalog_error_body'.tr,
        onRetry: controller.refresh,
      );
    }

    if (controller.phase == EefCatalogPhase.loading &&
        controller.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (controller.isEmptyResult) {
      // Un résultat vide venu d'un serveur qui A répondu est un FAIT. On le dit
      // comme tel, et on propose le seul geste utile : élargir.
      return KpbEmptyState(
        icon: Icons.search_off_rounded,
        title: 'eef_catalog_empty_title'.tr,
        subtitle: 'eef_catalog_empty_body'.tr,
        actionLabel: 'eef_catalog_empty_action'.tr,
        onAction: controller.clearFilters,
      );
    }

    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.sm,
        KpbSpacing.pagePad,
        KpbSpacing.xl,
      ),
      itemCount: controller.items.length + 2,
      separatorBuilder: (_, __) => const SizedBox(height: KpbSpacing.sm),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
            child: Text(
              'eef_catalog_result_count'
                  .trParams({'count': '${controller.total}'}),
              style:
                  KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
            ),
          );
        }
        if (index <= controller.items.length) {
          return _ProgramCard(program: controller.items[index - 1]);
        }
        if (controller.phase == EefCatalogPhase.loadingMore) {
          return const Padding(
            padding: EdgeInsets.all(KpbSpacing.md),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program});

  final ProgramModel program;

  @override
  Widget build(BuildContext context) {
    // `LocalizedText.resolve` porte déjà la règle de repli. La réécrire ici
    // en ferait une seconde source de vérité, qui finirait par diverger.
    final locale = Get.locale?.languageCode ?? 'fr';

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(program.name.resolve(locale), style: KpbTextStyles.titleSm),
          const SizedBox(height: KpbSpacing.xs),
          Text(
            program.level.resolve(locale),
            style: KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
          ),
          const SizedBox(height: KpbSpacing.xs),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                size: 14,
                color: context.kpb.textMuted,
              ),
              const SizedBox(width: KpbSpacing.xs),
              Text(
                program.duration.resolve(locale),
                style: KpbTextStyles.caption
                    .copyWith(color: context.kpb.textMuted),
              ),
            ],
          ),
          // `KpbSourceLink` se masque lui-même quand l'URL est absente ou non
          // ouvrable : pas de condition ici, sinon la règle vivrait à deux
          // endroits et l'un des deux finirait par diverger.
          const SizedBox(height: KpbSpacing.sm),
          KpbSourceLink(url: program.sourceUrl),
        ],
      ),
    );
  }
}
