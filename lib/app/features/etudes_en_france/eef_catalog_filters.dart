/// Les filtres du catalogue « Études en France » : une barre de quatre boutons
/// (« Niveau », « Domaine », « Ville », « Procédure »), la rangée des filtres
/// actifs, et la feuille où l'on choisit.
///
/// ## Pourquoi une feuille, et pourquoi UNE requête
///
/// L'ancienne rangée de puces posait un filtre à chaque tap — donc une requête
/// par tap, sur les réseaux du public visé. Et une seule famille de villes y
/// aurait compté des dizaines de puces. Ici l'étudiant coche dans une feuille,
/// et rien ne part avant « Voir N formations » : une seule requête, quel que
/// soit le nombre de cases. Fermer la feuille sans valider ne change rien.
///
/// ## Ce que ces widgets ne font jamais
///
/// · Une couleur en dur : tout vient de [KpbColors] et de `context.kpb`, donc du
///   thème clair comme du thème sombre.
/// · Une couleur d'état qui dépende d'un `ChipTheme`. L'ancienne rangée écrivait
///   le libellé en `KpbTextStyles.caption` (gris) : le style explicite écrasait la
///   couleur d'état du thème, et un libellé sélectionné s'affichait gris sur
///   bleu — 1,09:1. Ici le fond ET le texte de chaque état sont posés ensemble,
///   au même endroit ([_FilterButton]), et un test les mesure sur les pixels.
/// · Une cible tactile sous 48 dp.
library;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/models/app_models.dart';
import '../../core/models/eef_search.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_catalog_controller.dart';
import 'eef_filter_options.dart';
import 'eef_help_line.dart';

/// Rend le nom d'un domaine (`d07`) dans la langue active, ou `null` quand le
/// référentiel de l'app ne le connaît pas.
typedef EefFieldNameResolver = String? Function(String fieldId);

/// Le nom d'un domaine dans la langue active, ou `null`.
///
/// Si la langue active n'a pas de nom mais l'autre oui, on rend l'autre : un nom
/// dans la mauvaise langue se lit, un domaine absent de la liste ne se choisit
/// pas. `null` seulement quand AUCUNE langue n'a de nom — le domaine est alors
/// ignoré ([eefFieldOptions]), jamais montré sous son code.
String? eefLocalizedName(LocalizedText? text, String locale) {
  if (text == null) return null;
  final preferred = (locale.startsWith('fr') ? text.fr : text.en).trim();
  if (preferred.isNotEmpty) return preferred;
  final other = (locale.startsWith('fr') ? text.en : text.fr).trim();
  return other.isEmpty ? null : other;
}

/// Les valeurs proposées pour [family], dans leur ordre d'affichage — celles que
/// le serveur a servies, plus celles que l'étudiant a déjà choisies.
List<EefFilterOption> eefFamilyOptions(
  EefFilterFamily family,
  EefCatalogController controller,
  EefFieldNameResolver fieldName,
) {
  final facet = controller.facets[family.facetKey] ?? const <EefFacetValue>[];
  final selected = controller.selectedValues(family.facetKey);
  // Une valeur choisie qui manque à la liste servie n'a plus de formation sous
  // les AUTRES filtres (liste complète : 0) — sauf si la liste est tronquée,
  // auquel cas on ne sait pas (`null`, jamais un 0 inventé).
  final missingCount =
      controller.facetsTruncated.contains(family.facetKey) ? null : 0;
  switch (family) {
    case EefFilterFamily.cycle:
      return eefCycleOptions(facet,
          selected: selected, missingCount: missingCount);
    case EefFilterFamily.field:
      return eefFieldOptions(facet,
          nameOf: fieldName, selected: selected, missingCount: missingCount);
    case EefFilterFamily.city:
      return eefCityOptions(facet,
          selected: selected, missingCount: missingCount);
    case EefFilterFamily.procedure:
      return eefProcedureOptions(facet,
          selected: selected, missingCount: missingCount);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// L'en-tête : la barre des boutons, puis la rangée des filtres actifs
// ─────────────────────────────────────────────────────────────────────────────

/// La barre de filtres ET la rangée des filtres actifs, dans une zone dont la
/// hauteur est BORNÉE par [maxHeight].
///
/// Elle est épinglée au-dessus de la liste. Sans borne, une rangée de puces
/// longue (dix villes choisies) ou un clavier ouvert sur un petit écran
/// feraient déborder la colonne de l'écran ; avec elle, l'en-tête défile à
/// l'intérieur de sa propre zone et la liste garde toujours de la place.
///
/// La borne vient de l'ÉCRAN, qui connaît la hauteur réellement libre : un
/// `MediaQuery` ne la donne pas, parce que le `Scaffold` consomme l'espace du
/// clavier avant de passer le corps à ses enfants — première version de cette
/// borne, qui comptait la hauteur de l'écran entier sous un clavier ouvert et
/// laissait déborder la colonne de 87 px.
class EefFilterHeader extends StatelessWidget {
  const EefFilterHeader({
    super.key,
    required this.controller,
    required this.fieldName,
    required this.maxHeight,
  });

  final EefCatalogController controller;
  final EefFieldNameResolver fieldName;

  /// La hauteur maximale de la zone, en dp.
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EefFilterBar(controller: controller, fieldName: fieldName),
            EefActiveFilters(controller: controller, fieldName: fieldName),
          ],
        ),
      ),
    );
  }
}

/// Les quatre boutons. Chacun porte le NOMBRE de valeurs choisies (« Ville · 2 »)
/// et ouvre la feuille de sa famille.
///
/// Un `Wrap` et non une rangée qui défile : à l'échelle de texte 1,3 d'un
/// téléphone de 360 dp, le dernier bouton d'une rangée horizontale serait coupé
/// par le bord de l'écran — un libellé coupé que rien n'invite à faire défiler.
/// Passé à la ligne, chaque bouton reste entier et atteignable.
class EefFilterBar extends StatelessWidget {
  const EefFilterBar({
    super.key,
    required this.controller,
    required this.fieldName,
  });

  final EefCatalogController controller;
  final EefFieldNameResolver fieldName;

  /// Une famille se montre quand il y a quelque chose à y choisir (ou déjà
  /// choisi). La ville fait exception : sa feuille interroge le serveur ellemême,
  /// elle a donc toujours quelque chose à proposer.
  bool _shows(EefFilterFamily family) {
    if (family == EefFilterFamily.city) return true;
    return controller.selectedValues(family.facetKey).isNotEmpty ||
        eefFamilyOptions(family, controller, fieldName).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    // Pas de barre quand le serveur n'a rien servi à filtrer (recherche sans
    // résultat, panne, catalogue non publié) : des boutons qui ouvrent des
    // feuilles vides sont pires que pas de boutons. « Tout effacer » de l'état
    // vide reste le geste pour en sortir.
    //
    // « Rien servi » veut dire des listes vides, pas une table vide : le serveur
    // rend TOUJOURS les six clés de facette, vides quand rien n'est publié.
    if (controller.facets.values.every((values) => values.isEmpty) &&
        controller.activeFilterCount == 0) {
      return const SizedBox.shrink();
    }

    final buttons = <Widget>[
      for (final family in EefFilterFamily.values)
        if (_shows(family))
          _FilterButton(
            family: family,
            count: controller.selectedValues(family.facetKey).length,
            onTap: () => showEefFilterSheet(
              context,
              family: family,
              controller: controller,
              fieldName: fieldName,
            ),
          ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        KpbSpacing.sm,
      ),
      child: Wrap(
        spacing: KpbSpacing.sm,
        runSpacing: KpbSpacing.sm,
        children: buttons,
      ),
    );
  }
}

/// Un bouton de filtre.
///
/// Deux états, tous deux lisibles :
///  · au repos — fond de carte, texte principal, bordure appuyée ;
///  · actif — fond d'action PLEIN, texte blanc (5,17:1), le nombre choisi dans
///    le libellé. L'état ne tient donc pas à la seule couleur : « Ville · 2 »
///    se lit sans la voir.
///
/// Le fond et le texte sont décidés ICI, ensemble, parce que le défaut qu'on ne
/// reproduit pas est précisément un fond posé d'un côté (le thème) et un style
/// de texte explicite de l'autre qui l'écrasait.
class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.family,
    required this.count,
    required this.onTap,
  });

  final EefFilterFamily family;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final active = count > 0;
    final fill = active ? KpbColors.actionPrimary : c.cardBg;
    final foreground = active ? KpbColors.textOnDark : c.textPrimary;
    final border = active ? KpbColors.actionPrimary : c.gray300;

    final name = family.labelKey.tr;
    final visibleLabel = active ? '$name · $count' : name;
    final value = active
        ? 'eef_catalog_filter_semantics_count'.trParams({'count': '$count'})
        : 'eef_catalog_filter_semantics_none'.tr;

    return Semantics(
      key: ValueKey('eef-filter-button-${family.facetKey}'),
      container: true,
      button: true,
      // « Sélectionné » = ce filtre porte au moins un choix.
      selected: active,
      label: name,
      value: value,
      hint: 'eef_catalog_filter_semantics_hint'.tr,
      onTap: onTap,
      // L'arbre visuel dit la même chose, autrement : on ne l'expose pas deux
      // fois à un lecteur d'écran.
      excludeSemantics: true,
      child: Material(
        color: fill,
        shape: StadiumBorder(side: BorderSide(color: border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.only(
                left: KpbSpacing.md,
                right: KpbSpacing.sm,
                top: KpbSpacing.sm,
                bottom: KpbSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Le libellé passe à la ligne plutôt que d'être coupé.
                  Flexible(
                    child: Text(
                      visibleLabel,
                      style: KpbTextStyles.titleSm.copyWith(color: foreground),
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.xs),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: foreground,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// La rangée des filtres actifs : chacun en puce qu'on retire d'un tap, plus
/// « Tout effacer » dès qu'il y en a au moins un.
///
/// « Tout effacer » vide aussi le texte du champ de recherche — c'est le même
/// geste que celui de l'état « aucune formation » : un seul sens pour ces deux
/// mots sur tout l'écran.
class EefActiveFilters extends StatelessWidget {
  const EefActiveFilters({
    super.key,
    required this.controller,
    required this.fieldName,
  });

  final EefCatalogController controller;
  final EefFieldNameResolver fieldName;

  @override
  Widget build(BuildContext context) {
    if (controller.activeFilterCount == 0) return const SizedBox.shrink();

    final chips = <Widget>[
      for (final family in EefFilterFamily.values)
        for (final option in eefFamilyOptions(family, controller, fieldName))
          if (controller.isSelected(family.facetKey, option.value))
            _ActiveChip(
              key: ValueKey(
                  'eef-active-chip-${family.facetKey}-${option.value}'),
              label: option.label,
              onRemove: () =>
                  controller.toggleFacet(family.facetKey, option.value),
            ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        KpbSpacing.xs,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              container: true,
              label: 'eef_catalog_active_filters'.tr,
              child: Wrap(
                spacing: KpbSpacing.sm,
                children: chips,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('eef-active-clear-all'),
            onPressed: controller.clearFilters,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text('eef_catalog_active_clear_all'.tr),
          ),
        ],
      ),
    );
  }
}

/// Les filtres posés, en clair, pour le message d'aide : « Niveau : Master ;
/// Ville : Lyon, Paris ».
///
/// Les mêmes libellés que les puces ([eefFamilyOptions]), dans l'ordre des
/// familles — niveau, domaine, ville, procédure — et, dans une famille, dans
/// l'ordre de la feuille. Au plus [EefHelpMessages.maxFilterValuesPerFamily]
/// valeurs par famille, puis « … » ; chaque libellé est borné. La borne du
/// résumé entier est posée par `EefHelpMessages.forFilters`.
///
/// La procédure s'y ajoute aux trois familles de la demande (niveau, domaine,
/// ville) : c'est ce qui dit au conseiller de quelle voie on parle — SAUF pour un
/// compte dont le pays est suspendu ([suspended]). Le nom d'une procédure y est
/// parfois « DAP dossier jaune » : le message d'un compte suspendu ne contient
/// jamais le mot « dossier », et il n'a pas à dire de quelle voie on parle quand
/// il dit que la procédure est suspendue. Sans autre filtre, le résumé est alors
/// vide, et [EefHelpMessages.forFilters] sait écrire un message sans rien citer.
String eefFiltersHelpSummary(
  EefCatalogController controller,
  EefFieldNameResolver fieldName, {
  bool suspended = false,
}) {
  const maxValues = EefHelpMessages.maxFilterValuesPerFamily;
  final parts = <String>[];
  for (final family in EefFilterFamily.values) {
    if (suspended && family == EefFilterFamily.procedure) continue;
    final labels = [
      for (final option in eefFamilyOptions(family, controller, fieldName))
        if (controller.isSelected(family.facetKey, option.value)) option.label,
    ];
    if (labels.isEmpty) continue;
    final shown = [
      for (final label in labels.take(maxValues))
        EefHelpMessages.clip(label, EefHelpMessages.maxFilterLabelChars),
    ].join(', ');
    parts.add('eef_help_filters_family'.trParams({
      'family': family.labelKey.tr,
      'values': labels.length > maxValues ? '$shown, …' : shown,
    }));
  }
  return parts.join(' ; ');
}

/// La ligne « Tu hésites entre ces formations ? », sous les filtres actifs.
///
/// ## Où elle est montée
///
/// Par l'ÉCRAN, en tête de la liste des résultats — sous les puces et « Tout
/// effacer » (l'en-tête épinglé), puis sous le compteur « N formations », au-dessus
/// de la première formation —, et non dans [EefActiveFilters] lui-même : l'en-tête
/// des filtres est ÉPINGLÉ au-dessus de la liste, et une ligne de plus y mangerait
/// de la hauteur en permanence sur les petits téléphones. Dans la liste, elle
/// défile avec elle. Et la règle « une seule ligne d'aide à la fois, la ligne
/// de procédure d'abord » ([eefCatalogHelpLineFor]) se décide au MÊME endroit que
/// la ligne de procédure, qui est dans cette liste.
///
/// Elle ne s'affiche pas quand l'écran montre une carte pleine à la place de la
/// liste (aucun résultat, catalogue non publié) : au plus une carte pleine par
/// écran, et deux invitations côte à côte seraient une de trop.
class EefFiltersHelpLine extends StatelessWidget {
  const EefFiltersHelpLine({
    super.key,
    required this.controller,
    required this.fieldName,
  });

  final EefCatalogController controller;
  final EefFieldNameResolver fieldName;

  @override
  Widget build(BuildContext context) {
    return EefHelpLine(
      trigger: EefHelpTrigger.catalogFilters,
      // Lu AU TAP : les filtres posés à ce moment-là, pas à la construction.
      prefill: (suspended) => EefHelpMessages.forFilters(
        summary: eefFiltersHelpSummary(
          controller,
          fieldName,
          suspended: suspended,
        ),
        suspended: suspended,
      ),
    );
  }
}

/// Une puce de filtre actif. La zone tactile fait 48 dp de haut ; la puce
/// visible, plus fine, est centrée dedans.
class _ActiveChip extends StatelessWidget {
  const _ActiveChip({super.key, required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Semantics(
      container: true,
      button: true,
      label: 'eef_catalog_active_remove'.trParams({'label': label}),
      onTap: onRemove,
      excludeSemantics: true,
      child: InkWell(
        onTap: onRemove,
        borderRadius: KpbRadius.pillBr,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: Center(
            widthFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.skyLight,
                borderRadius: KpbRadius.pillBr,
                border: Border.all(color: KpbColors.actionPrimary),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  KpbSpacing.md - 4,
                  KpbSpacing.xs + 2,
                  KpbSpacing.sm,
                  KpbSpacing.xs + 2,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        style: KpbTextStyles.titleSm
                            .copyWith(color: c.textPrimary),
                      ),
                    ),
                    const SizedBox(width: KpbSpacing.xs),
                    Icon(Icons.close_rounded, size: 18, color: c.textPrimary),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// La feuille de choix
// ─────────────────────────────────────────────────────────────────────────────

/// Ouvre la feuille de [family] et applique le choix — en UNE requête — si
/// l'étudiant valide. Fermer la feuille (balayage, retour, fond) ne change rien.
Future<void> showEefFilterSheet(
  BuildContext context, {
  required EefFilterFamily family,
  required EefCatalogController controller,
  required EefFieldNameResolver fieldName,
}) async {
  // Le champ de recherche peut avoir le focus (l'étudiant vient de taper « droit »
  // puis touche « Ville »). Sans ceci, Flutter le lui REND à la fermeture de la
  // feuille : le clavier remonte par-dessus la liste qu'on vient de filtrer.
  FocusManager.instance.primaryFocus?.unfocus();
  final chosen = await showModalBottomSheet<Set<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _EefFilterSheet(
      family: family,
      controller: controller,
      fieldName: fieldName,
    ),
  );
  // `null` = fermée sans valider. Et si l'écran a disparu pendant ce temps, son
  // contrôleur est détruit : on n'y touche plus.
  if (chosen == null || !context.mounted) return;
  await controller.setFacetSelection(family.facetKey, chosen);
}

class _EefFilterSheet extends StatefulWidget {
  const _EefFilterSheet({
    required this.family,
    required this.controller,
    required this.fieldName,
  });

  final EefFilterFamily family;
  final EefCatalogController controller;
  final EefFieldNameResolver fieldName;

  @override
  State<_EefFilterSheet> createState() => _EefFilterSheetState();
}

class _EefFilterSheetState extends State<_EefFilterSheet> {
  /// Ce que l'étudiant avait déjà choisi à l'ouverture — la base de comparaison.
  late final Set<String> _initial =
      widget.controller.selectedValues(widget.family.facetKey);

  /// Le BROUILLON : tout ce que l'étudiant coche reste ici, jusqu'à « Voir N
  /// formations ». Le contrôleur n'en sait rien.
  late final Set<String> _draft = <String>{..._initial};

  /// Le nombre de formations avec les filtres posés à l'ouverture. Instantané :
  /// la feuille est modale, la liste derrière elle ne bouge pas.
  late final int _totalAtOpen = widget.controller.total;

  final TextEditingController _search = TextEditingController();
  String _query = '';

  // La liste des villes. Seule la ville interroge le serveur à l'ouverture.
  bool get _isCity => widget.family == EefFilterFamily.city;
  late bool _loadingCities = _isCity;
  EefCitiesOutcome? _outcome;

  /// Numéro de la requête de villes en vol : une réponse arrivée après un
  /// « Réessayer » plus récent (ou après la fermeture) est jetée, comme la règle
  /// n° 1 le fait pour la recherche.
  int _citiesToken = 0;

  /// Les options des familles servies par la recherche — figées à l'ouverture.
  late final List<EefFilterOption> _facetOptions = _isCity
      ? const <EefFilterOption>[]
      : eefFamilyOptions(
          widget.family,
          widget.controller,
          widget.fieldName,
        );

  @override
  void initState() {
    super.initState();
    if (_isCity) _loadCities();
  }

  @override
  void dispose() {
    _citiesToken += 1;
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final token = ++_citiesToken;
    final outcome = await widget.controller.loadCities();
    if (!mounted || token != _citiesToken) return;
    setState(() {
      _outcome = outcome;
      _loadingCities = false;
    });
  }

  void _retryCities() {
    setState(() {
      _loadingCities = true;
      _outcome = null;
    });
    _loadCities();
  }

  /// Les villes triées de la réponse [_cityOptionsOutcome] : calculées UNE fois
  /// par réponse. `_options` est lu à chaque `build` — donc à chaque frappe dans
  /// la recherche et à chaque case cochée —, et trier plusieurs centaines de
  /// villes en les pliant (accents, ponctuation) coûte plusieurs dizaines de
  /// millisecondes sur un téléphone d'entrée de gamme : sans cette mémoire, la
  /// frappe saccadait.
  EefCitiesOutcome? _cityOptionsOutcome;
  List<EefFilterOption> _cityOptionsCache = const <EefFilterOption>[];

  /// Les options de la feuille, dans l'ordre d'affichage.
  List<EefFilterOption> get _options {
    if (!_isCity) return _facetOptions;
    final outcome = _outcome;
    if (outcome == null || outcome.status == EefCitiesStatus.failed) {
      return const <EefFilterOption>[];
    }
    if (!identical(outcome, _cityOptionsOutcome)) {
      _cityOptionsOutcome = outcome;
      _cityOptionsCache = eefCityOptions(
        outcome.cities,
        selected: _initial,
        // Liste complète : une ville absente n'a plus de formation sous les
        // autres filtres. Repli : la liste est tronquée, on ne sait pas.
        missingCount: outcome.status == EefCitiesStatus.loaded ? 0 : null,
      );
    }
    return _cityOptionsCache;
  }

  /// Le nombre EXACT de formations que donnerait le brouillon, ou `null`.
  ///
  /// Chaque formation a UNE valeur par famille : la somme des comptes des
  /// valeurs cochées est donc exacte (les comptes ignorent le filtre de leur
  /// propre famille et tiennent compte des autres). Brouillon vide : le total
  /// SANS cette famille — celui du serveur pour les villes, ou celui de la liste
  /// affichée si la famille n'était pas filtrée. Tout autre cas est inconnu, et
  /// le bouton le dit plutôt que d'afficher un nombre inventé.
  int? _applyCount() {
    if (_draft.isEmpty) {
      if (_isCity && _outcome?.status == EefCitiesStatus.loaded) {
        final total = _outcome!.total;
        if (total != null) return total;
      }
      return _initial.isEmpty ? _totalAtOpen : null;
    }
    final counts = <String, int?>{
      for (final option in _options) option.value: option.count,
    };
    var sum = 0;
    for (final value in _draft) {
      final count = counts[value];
      if (count == null) return null;
      sum += count;
    }
    return sum;
  }

  String _applyLabel() {
    final count = _applyCount();
    if (count == null) return 'eef_catalog_sheet_apply_generic'.tr;
    if (count == 0) return 'eef_catalog_sheet_apply_zero'.tr;
    if (count == 1) return 'eef_catalog_sheet_apply_one'.tr;
    return 'eef_catalog_sheet_apply_many'.trParams({'count': '$count'});
  }

  void _toggle(String value) {
    setState(() {
      if (!_draft.remove(value)) _draft.add(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      // Le clavier de la recherche de ville : la feuille monte avec lui, et le
      // bouton « Voir N formations » reste visible au-dessus.
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        key: const ValueKey('eef-filter-sheet'),
        constraints: BoxConstraints(maxHeight: media.size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context),
            if (_isCity) ..._buildCityTop(context),
            if (_isCity)
              Expanded(child: _buildCityBody(context))
            else
              Flexible(child: _buildOptionList(_options)),
            _buildApplyBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final c = context.kpb;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        KpbSpacing.pagePad,
        0,
        KpbSpacing.pagePad,
        KpbSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                widget.family.labelKey.tr,
                style: KpbTextStyles.title.copyWith(color: c.textPrimary),
              ),
            ),
          ),
          if (_draft.isNotEmpty)
            TextButton(
              key: const ValueKey('eef-filter-sheet-clear'),
              onPressed: () => setState(_draft.clear),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              child: Text('eef_catalog_filter_clear'.tr),
            ),
        ],
      ),
    );
  }

  /// Au-dessus de la liste des villes : la mention du repli, puis la recherche
  /// locale (seulement quand il y a une liste à chercher).
  List<Widget> _buildCityTop(BuildContext context) {
    final c = context.kpb;
    final outcome = _outcome;
    final hasList = outcome != null && outcome.status != EefCitiesStatus.failed;
    return [
      if (outcome?.status == EefCitiesStatus.fallback)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            0,
            KpbSpacing.pagePad,
            KpbSpacing.sm,
          ),
          child: Text(
            'eef_catalog_city_fallback'.tr,
            key: const ValueKey('eef-filter-sheet-fallback'),
            style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
          ),
        ),
      if (hasList)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            0,
            KpbSpacing.pagePad,
            KpbSpacing.sm,
          ),
          child: TextField(
            key: const ValueKey('eef-filter-sheet-search'),
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.search,
            decoration: KpbInputDecoration.build(
              context,
              label: 'eef_catalog_city_search_hint'.tr,
              prefixIcon: Icons.search_rounded,
            ),
          ),
        ),
    ];
  }

  Widget _buildCityBody(BuildContext context) {
    final c = context.kpb;
    final outcome = _outcome;

    if (_loadingCities || outcome == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: KpbSpacing.md),
              Text(
                'eef_catalog_city_loading'.tr,
                textAlign: TextAlign.center,
                style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    if (outcome.status == EefCitiesStatus.failed) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(KpbSpacing.pagePad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'eef_catalog_city_error_title'.tr,
              textAlign: TextAlign.center,
              style: KpbTextStyles.titleMd.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              // Deux phrases, deux gestes — comme l'écran des résultats : une
              // coupure appelle à vérifier sa connexion, une panne serveur à
              // patienter.
              outcome.failure == EefCatalogFailure.network
                  ? 'eef_catalog_city_error_network'.tr
                  : 'eef_catalog_city_error_server'.tr,
              key: const ValueKey('eef-filter-sheet-error-body'),
              textAlign: TextAlign.center,
              style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: KpbSpacing.md),
            FilledButton(
              key: const ValueKey('eef-filter-sheet-retry'),
              onPressed: _retryCities,
              child: Text('eef_catalog_city_retry'.tr),
            ),
          ],
        ),
      );
    }

    final matches = eefFilterCityOptions(_options, _query);
    if (matches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(KpbSpacing.lg),
          child: Text(
            'eef_catalog_city_empty'.tr,
            key: const ValueKey('eef-filter-sheet-empty'),
            textAlign: TextAlign.center,
            style: KpbTextStyles.body.copyWith(color: c.textSecondary),
          ),
        ),
      );
    }
    return _buildOptionList(matches, lazy: true);
  }

  /// La liste des cases. Les villes peuvent être des centaines : `lazy` ne monte
  /// que ce qui est à l'écran. Les autres familles ont une douzaine de valeurs,
  /// et la feuille épouse alors leur hauteur.
  Widget _buildOptionList(List<EefFilterOption> options, {bool lazy = false}) {
    Widget row(EefFilterOption option) => _OptionRow(
          option: option,
          selected: _draft.contains(option.value),
          onToggle: () => _toggle(option.value),
        );
    if (lazy) {
      return ListView.builder(
        itemCount: options.length,
        itemBuilder: (_, index) => row(options[index]),
      );
    }
    return ListView(
      shrinkWrap: true,
      children: [for (final option in options) row(option)],
    );
  }

  Widget _buildApplyBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          KpbSpacing.sm,
          KpbSpacing.pagePad,
          KpbSpacing.md,
        ),
        child: FilledButton(
          key: const ValueKey('eef-filter-sheet-apply'),
          onPressed: () => Navigator.of(context).pop(Set<String>.of(_draft)),
          child: Text(_applyLabel(), textAlign: TextAlign.center),
        ),
      ),
    );
  }
}

/// Une valeur à cocher : case, libellé, compte. La ligne entière est la cible
/// tactile (48 dp au moins), pas seulement la case.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.option,
    required this.selected,
    required this.onToggle,
  });

  final EefFilterOption option;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final count = option.count;
    final semanticsLabel = count == null
        ? option.label
        : 'eef_catalog_option_semantics'.trParams({
            'label': option.label,
            'count': '$count',
          });

    return Semantics(
      container: true,
      checked: selected,
      label: semanticsLabel,
      onTap: onToggle,
      excludeSemantics: true,
      child: InkWell(
        key: ValueKey('eef-filter-option-${option.value}'),
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KpbSpacing.pagePad - KpbSpacing.sm,
            ),
            child: Row(
              children: [
                // Un seul arrêt de focus par ligne : la ligne (`InkWell`) porte déjà
                // le geste — Entrée ou Espace au clavier, un bouton de commutation —,
                // et la case comptait un second arrêt à elle, donc deux appuis sur
                // Tab par ville, sur une liste de plusieurs centaines. Le tap
                // direct sur la case, lui, reste actif.
                ExcludeFocus(
                  child: Checkbox(
                    value: selected,
                    onChanged: (_) => onToggle(),
                    // La case est le SEUL signe visuel de la sélection : le libellé
                    // ne change pas. Le thème la contourne en `borderStrong`
                    // (#CBD5E1), 1,48:1 sur blanc, 2,03:1 en sombre — bien sous les
                    // 3:1 que WCAG 1.4.11 demande à un composant. Le contour prend
                    // donc le texte secondaire (7,58:1 / 6,03:1), et le bleu
                    // d'action une fois cochée.
                    side: WidgetStateBorderSide.resolveWith(
                      (states) => BorderSide(
                        color: states.contains(WidgetState.selected)
                            ? KpbColors.actionPrimary
                            : c.textSecondary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: KpbSpacing.xs),
                // Le libellé passe à la ligne : « Énergie, Environnement &
                // Développement durable » ne tient pas sur 360 dp à 1,3.
                Expanded(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: KpbSpacing.xs),
                    child: Text(
                      option.label,
                      style: KpbTextStyles.body.copyWith(color: c.textPrimary),
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: KpbSpacing.sm),
                  Text(
                    '$count',
                    style:
                        KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
