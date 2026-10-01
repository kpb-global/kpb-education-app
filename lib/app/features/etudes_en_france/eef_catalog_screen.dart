import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/models/eef_search.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_catalog_controller.dart';
import 'eef_data_notice.dart';
import 'eef_official_links.dart';

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
class EefCatalogScreen extends StatelessWidget {
  const EefCatalogScreen({super.key, this.source = 'hub'});

  /// Par quelle porte l'étudiant est arrivé — pour savoir laquelle amène du
  /// monde (voir `logEefCatalogViewed`).
  final String source;

  @override
  Widget build(BuildContext context) {
    // La route est joignable par lien profond même drapeaux éteints, comme
    // `EefEntry` : sans cette porte, un lien reçu avant l'ouverture montrerait un
    // catalogue que la vitrine dit « en préparation ». Elle se reconstruit à
    // l'arrivée des drapeaux serveur, pour ne pas rester sur « bientôt ».
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        if (!RemoteFeatureFlags.instance.eefSpaceEnabled) {
          return ComingSoonScreen(title: 'eef_catalog_title'.tr);
        }
        return _EefCatalogView(source: source);
      },
    );
  }
}

class _EefCatalogView extends StatefulWidget {
  const _EefCatalogView({required this.source});

  final String source;

  @override
  State<_EefCatalogView> createState() => _EefCatalogViewState();
}

class _EefCatalogViewState extends State<_EefCatalogView> {
  late final EefCatalogController _controller;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _queryField = TextEditingController();

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
    unawaited(AnalyticsService.instance.logEefCatalogViewed(widget.source));
    _controller.refresh();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    // Le champ suit le contrôleur. « Tout effacer » vide `query` côté
    // contrôleur ; sans cette synchronisation le champ gardait le texte, et
    // l'étudiant voyait « droit » dans la barre au-dessus de résultats qui ne
    // portaient plus aucun filtre. Pendant la frappe les deux sont égaux, donc
    // le curseur n'est jamais déplacé.
    if (_queryField.text != _controller.query) {
      _queryField.value = TextEditingValue(
        text: _controller.query,
        selection: TextSelection.collapsed(offset: _controller.query.length),
      );
    }
    setState(() {});
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
    _queryField.dispose();
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
          _SearchField(controller: _controller, field: _queryField),
          _FacetBar(controller: _controller),
          const _SuspensionBanner(),
          Expanded(child: _Results(controller: _controller, scroll: _scroll)),
          const SafeArea(top: false, child: EefSourcesRow()),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.field});

  final EefCatalogController controller;
  final TextEditingController field;

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
        controller: field,
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

    // Pas de hauteur fixe : à l'échelle de texte 1,3 d'un téléphone dont la
    // police est agrandie, une barre de 48 px coupait les puces. Elle prend la
    // hauteur de son contenu, et défile à l'horizontale si elle est trop large.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.pagePad),
      child: Row(children: chips),
    );
  }
}

/// La mise en garde de suspension, en tête du catalogue.
///
/// Le catalogue reste consultable — il informe aussi un étudiant qui se
/// renseigne pour plus tard, ou pour un proche. Mais un étudiant dont le pays est
/// suspendu doit le savoir AVANT de choisir une formation : l'officiel dit que
/// son dossier ne sera pas traité, et la liste ci-dessous, elle, a l'air d'une
/// offre ouverte. Même texte, même source que la vitrine (`EefCalendar`).
class _SuspensionBanner extends StatelessWidget {
  const _SuspensionBanner();

  @override
  Widget build(BuildContext context) {
    final country = Get.isRegistered<AppController>()
        ? Get.find<AppController>().profile?.countryOfResidence
        : null;
    if (!EefCalendar.isSuspendedFor(country)) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.xs,
        KpbSpacing.pagePad,
        KpbSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.all(KpbSpacing.md),
        decoration: BoxDecoration(
          color: context.kpb.warningLight,
          borderRadius: KpbRadius.mdBr,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.report_problem_outlined,
              size: 18,
              color: KpbColors.warning,
            ),
            const SizedBox(width: KpbSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'eef_suspended_notice'.tr,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: context.kpb.textPrimary),
                  ),
                  EefOfficialLink(
                    url: EefCalendar.suspensionSourceFor(country),
                    labelKey: 'eef_official_suspension_link',
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

class _Results extends StatelessWidget {
  const _Results({required this.controller, required this.scroll});

  final EefCatalogController controller;
  final ScrollController scroll;

  /// Un état plein écran (vide, pas publié) reste dans une liste : la mention
  /// des données et la non-affiliation doivent rester atteignables partout.
  Widget _stateWithNotice(Widget state) {
    return ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        KpbSpacing.xl,
      ),
      children: [state, const EefDataNotice()],
    );
  }

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

    // Avant « vide » : un catalogue où RIEN n'est publié n'a pas de recherche
    // trop étroite. Lui proposer « tout effacer » enverrait l'étudiant retirer
    // des filtres sur une base vide.
    if (controller.isCatalogNotPublished) {
      return _stateWithNotice(
        KpbEmptyState(
          icon: Icons.hourglass_top_rounded,
          title: 'eef_catalog_unpublished_title'.tr,
          subtitle: 'eef_catalog_unpublished_body'.tr,
        ),
      );
    }

    if (controller.isEmptyResult) {
      // Un résultat vide venu d'un serveur qui A répondu est un FAIT. On le dit
      // comme tel, et on propose le seul geste utile : élargir.
      return _stateWithNotice(
        KpbEmptyState(
          icon: Icons.search_off_rounded,
          title: 'eef_catalog_empty_title'.tr,
          subtitle: 'eef_catalog_empty_body'.tr,
          actionLabel: 'eef_catalog_empty_action'.tr,
          onAction: controller.clearFilters,
        ),
      );
    }

    final items = controller.items;
    return ListView.separated(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        KpbSpacing.sm,
        KpbSpacing.pagePad,
        KpbSpacing.xl,
      ),
      // En-tête + cartes + pied (état de la page suivante) + mentions.
      itemCount: items.length + 3,
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
        if (index <= items.length) {
          return _ProgramCard(item: items[index - 1]);
        }
        if (index == items.length + 1) {
          return _ListFooter(controller: controller);
        }
        return const Padding(
          padding: EdgeInsets.only(top: KpbSpacing.md),
          child: EefDataNotice(),
        );
      },
    );
  }
}

/// Ce qui se passe sous la dernière carte : la page suivante qui charge, ou qui
/// a échoué.
///
/// Un échec de page suivante ne remplace PAS la liste (voir
/// [EefCatalogController.loadMoreFailed]) : il se dit ici, au bas de ce qui a été
/// lu, avec le geste qui relance.
class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final EefCatalogController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.phase == EefCatalogPhase.loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(KpbSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (controller.loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: KpbSpacing.sm),
        child: Column(
          children: [
            Text(
              'eef_catalog_more_failed'.tr,
              textAlign: TextAlign.center,
              style:
                  KpbTextStyles.bodySm.copyWith(color: context.kpb.textMuted),
            ),
            TextButton(
              onPressed: controller.retryLoadMore,
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text('eef_catalog_more_retry'.tr),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.item});

  final EefProgram item;

  /// Le libellé de la procédure, ou `null` si la valeur n'est pas connue de
  /// l'app. `.tr` rend la CLÉ quand elle manque : un badge « eef_catalog_value_… »
  /// serait pire que pas de badge.
  String? _procedureLabel() {
    final procedure = item.procedureType;
    if (procedure == null) return null;
    final key = 'eef_catalog_value_procedureType_$procedure';
    final translated = key.tr;
    return translated == key ? null : translated;
  }

  @override
  Widget build(BuildContext context) {
    // `LocalizedText.resolve` porte déjà la règle de repli. La réécrire ici
    // en ferait une seconde source de vérité, qui finirait par diverger.
    final locale = Get.locale?.languageCode ?? 'fr';
    final program = item.program;

    // L'université d'abord : « L1 - Droit » existe dans une quarantaine
    // d'établissements, et une carte qui n'en nomme aucun est inutilisable pour
    // choisir. Quand le serveur n'en a pas servi, la carte reste honnête — la
    // formation seule, sans nom inventé.
    final institution = item.institution;
    final institutionName = institution?.name.resolve(locale) ?? '';
    final acronym = institution?.acronym;
    final institutionLabel = institutionName.isEmpty
        ? ''
        : (acronym != null && !institutionName.contains(acronym)
            ? '$institutionName ($acronym)'
            : institutionName);
    final city = item.campusCity ?? institution?.location.resolve(locale) ?? '';
    final where =
        [institutionLabel, city].where((p) => p.isNotEmpty).join(' · ');

    final procedure = _procedureLabel();
    final level = program.level.resolve(locale);

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(program.name.resolve(locale), style: KpbTextStyles.titleSm),
          if (where.isNotEmpty) ...[
            const SizedBox(height: KpbSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.school_outlined,
                    size: 14,
                    color: context.kpb.textMuted,
                  ),
                ),
                const SizedBox(width: KpbSpacing.xs),
                Expanded(
                  child: Text(
                    where,
                    style: KpbTextStyles.bodySm
                        .copyWith(color: context.kpb.textSecondary),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: KpbSpacing.xs),
          Wrap(
            spacing: KpbSpacing.sm,
            runSpacing: KpbSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (procedure != null)
                KpbBadge(
                  label: procedure,
                  small: true,
                  color: item.procedureType == 'hors_eef'
                      ? KpbColors.warning
                      : KpbColors.blue,
                ),
              if (level.isNotEmpty)
                Text(
                  level,
                  style: KpbTextStyles.bodySm
                      .copyWith(color: context.kpb.textMuted),
                ),
            ],
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
              Expanded(
                child: Text(
                  program.duration.resolve(locale),
                  style: KpbTextStyles.caption
                      .copyWith(color: context.kpb.textMuted),
                ),
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
