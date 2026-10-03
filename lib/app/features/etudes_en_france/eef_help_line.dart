import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import 'eef_help_card.dart';

/// Les déclencheurs d'aide de la build 55 : de petits gestes qui ouvrent WhatsApp
/// vers le conseiller KPB, là où l'étudiant regarde quelque chose de précis — une
/// formation, un jeu de filtres, un outil du dossier.
///
/// ## Pourquoi un enum à part de [EefHelpStep]
///
/// Les étapes de la build 54 sont celles de la CARTE d'aide : un emplacement
/// (hub, bas de liste, catalogue vide…), un texte, un message. Ici le message
/// dépend de ce que l'étudiant regarde, et la règle d'un compte suspendu n'est
/// pas la même (les lignes de la build 54 disparaissent pour un pays suspendu ;
/// ces déclencheurs-ci RESTENT, au libellé neutre — décision du propriétaire du
/// 03/10/2026 : un étudiant dont le pays est suspendu peut faire sa procédure
/// par un autre pays, on ne bloque personne). Les mélanger aurait obligé chaque
/// test et chaque `switch` de la build 54 à connaître une exception qui ne le
/// concerne pas.
///
/// La clé sert de valeur analytique (`help_step`) et de racine des textes
/// (`eef_help_<clé>_question`…) : un enum se faute à la compilation, une chaîne
/// libre en silence.
enum EefHelpTrigger {
  /// Sous chaque formation du catalogue. Un bouton, sans question, et sans
  /// « vue » : une mesure par carte affichée serait du bruit.
  catalogProgram(
    key: 'catalog_program',
    surface: 'catalog',
    hasQuestion: false,
    countsShown: false,
  ),

  /// Sous les filtres actifs du catalogue : « tu hésites entre ces formations ? ».
  catalogFilters(key: 'catalog_filters', surface: 'catalog'),

  /// Les trois outils du dossier, quand ils sont ouverts depuis le hub.
  toolCv(key: 'tool_cv', surface: 'tools'),
  toolLetters(key: 'tool_letters', surface: 'tools'),
  toolInterview(key: 'tool_interview', surface: 'tools');

  const EefHelpTrigger({
    required this.key,
    required this.surface,
    this.hasQuestion = true,
    this.countsShown = true,
  });

  /// Identifiant stable : traductions, analytique (`help_step`), source du suivi
  /// WhatsApp (`eef_help_<clé>`).
  final String key;

  /// L'écran porteur — la propriété `surface` de l'analytique : `catalog` ou
  /// `tools` (les écrans d'outils ouverts depuis le hub).
  final String surface;

  /// Une question accompagne le lien (`eef_help_<clé>_question`).
  final bool hasQuestion;

  /// `eef_help_card_shown` part pour ce déclencheur (une fois par visite).
  final bool countsShown;

  /// Un écran d'outil : il n'a ni carte d'aide ni fond du thème — voir
  /// [EefHelpLine].
  bool get isTool => surface == 'tools';
}

/// Les messages que ces déclencheurs écrivent à WhatsApp.
///
/// ## Ce qu'ils contiennent, et ce qu'ils ne contiennent pas
///
/// Ils NOMMENT ce que l'étudiant regardait (la formation, l'université, la
/// ville ; les filtres posés ; l'outil), pour que le conseiller n'ait pas à le
/// redemander. Ils ne contiennent AUCUNE donnée personnelle : ni nom, ni e-mail,
/// ni téléphone, ni pays — le profil n'est pas lu. Pour un pays suspendu, ils
/// disent que la procédure est suspendue « dans mon pays » SANS le nommer, ne
/// citent aucun pays de remplacement (ce contenu n'est pas validé
/// juridiquement) et ne parlent jamais d'ouvrir un dossier.
///
/// ## Pourquoi tout est borné
///
/// Un intitulé de formation peut être long, une ville aussi, et le message part
/// dans un lien `wa.me/…?text=…` où chaque lettre accentuée coûte six
/// caractères. Un lien trop long est TRONQUÉ par WhatsApp : le message arriverait
/// coupé au milieu d'un mot, ou sans sa fin. Chaque morceau cité est donc
/// borné et coupé proprement ([clip]), de sorte que le gabarit — qui porte la
/// demande — arrive toujours entier.
abstract final class EefHelpMessages {
  /// Les bornes, en points de code, de chaque morceau cité.
  static const int maxProgramChars = 80;
  static const int maxInstitutionChars = 60;
  static const int maxCityChars = 30;
  static const int maxFilterLabelChars = 32;
  static const int maxFiltersChars = 300;

  /// Au plus ce nombre de valeurs citées par famille de filtre, puis « … ».
  static const int maxFilterValuesPerFamily = 3;

  /// La borne du message entier (gabarit compris), en points de code.
  static const int maxMessageChars = 520;

  /// La borne du message ENCODÉ dans le lien. Une marge prudente : un lien de
  /// 2 000 caractères est ce que les clients tolèrent d'ordinaire. La limite
  /// exacte de WhatsApp n'a pas été mesurée sur appareil.
  static const int maxEncodedChars = 1800;

  /// Coupe [text] à [maxChars] points de code au plus.
  ///
  /// - les retours à la ligne, tabulations et caractères de contrôle deviennent
  ///   des espaces, puis les espaces se réduisent : une donnée du catalogue ne
  ///   peut pas casser la mise en forme du message ;
  /// - la coupe tombe sur une limite de mot quand il y en a une raisonnablement
  ///   proche (on ne perd pas plus de la moitié du texte pour y arriver), sinon
  ///   au caractère ;
  /// - elle compte en POINTS DE CODE (`runes`), jamais en unités UTF-16 : couper
  ///   au milieu d'une paire de substitution (un emoji) laisserait une moitié
  ///   de caractère, que l'encodage du lien refuse ;
  /// - la ponctuation orpheline qui précéderait « … » est retirée.
  static String clip(String text, int maxChars) {
    if (maxChars <= 0) return '';
    final cleaned = text
        .replaceAll(RegExp(r'[\u0000-\u001F\u007F]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final runes = cleaned.runes.toList(growable: false);
    if (runes.length <= maxChars) return cleaned;
    if (maxChars == 1) return '…';

    // Une place est gardée pour « … ».
    var end = maxChars - 1;
    if (runes[end] != 0x20) {
      final lastSpace = runes.sublist(0, end).lastIndexOf(0x20);
      if (lastSpace >= end * 0.5) end = lastSpace;
    }
    final kept = String.fromCharCodes(runes.sublist(0, end))
        .replaceFirst(RegExp(r"[\s,;:.\-–—(«“‘’'\x22]+$"), '');
    return '$kept…';
  }

  /// Un morceau cité : borné, et sans `@` — `trParams` remplace `@clé`, et un
  /// nom de formation qui en contiendrait un rejouerait un autre paramètre.
  static String _quoted(String? raw, int maxChars) =>
      clip((raw ?? '').replaceAll('@', ''), maxChars);

  /// Le message d'une formation : intitulé, université, ville.
  static String forProgram({
    required String program,
    String? institution,
    String? city,
    required bool suspended,
  }) {
    final place = [
      _quoted(institution, maxInstitutionChars),
      _quoted(city, maxCityChars),
    ].where((part) => part.isNotEmpty).join(', ');
    final key = suspended
        ? 'eef_help_prefill_program_suspended'
        : 'eef_help_prefill_program';
    return key.trParams({
      'program': _quoted(program, maxProgramChars),
      'place': place.isEmpty ? '' : ' ($place)',
    });
  }

  /// Le message d'un jeu de filtres. [summary] est celui de
  /// `eefFiltersHelpSummary` : niveau, domaine, ville (et procédure, sauf pour un
  /// compte suspendu) choisis.
  ///
  /// Un résumé qui reste VIDE une fois nettoyé — un identifiant que l'app ne sait
  /// pas nommer, ou, pour un compte suspendu, une procédure seule — ne produit pas
  /// de parenthèses vides : le message n'a alors simplement rien à citer.
  static String forFilters({required String summary, required bool suspended}) {
    final quoted = _quoted(summary, maxFiltersChars);
    if (quoted.isEmpty) {
      return (suspended
              ? 'eef_help_prefill_filters_none_suspended'
              : 'eef_help_prefill_filters_none')
          .tr;
    }
    final key = suspended
        ? 'eef_help_prefill_filters_suspended'
        : 'eef_help_prefill_filters';
    return key.trParams({'filters': quoted});
  }

  /// Le message d'un outil du dossier (CV, lettre de motivation, entretien).
  static String forTool(EefHelpTrigger tool, {required bool suspended}) {
    assert(tool.isTool, '${tool.key} n\'est pas un outil du dossier');
    final key =
        suspended ? 'eef_help_prefill_tool_suspended' : 'eef_help_prefill_tool';
    return key.trParams({'tool': 'eef_help_${tool.key}_label'.tr});
  }
}

/// Quelle ligne d'aide le catalogue montre sous le compteur.
enum EefCatalogHelpLine {
  /// Aucune.
  none,

  /// La ligne de procédure de la build 54 (`EefHelpStep.catalogProcedure`).
  procedure,

  /// La ligne « tu hésites entre ces formations ? » de la build 55.
  filters,
}

/// UNE ligne d'aide à la fois sous les filtres — jamais deux empilées.
///
/// ## La règle
///
/// 1. la ligne de procédure garde la priorité : c'est la plus précise (elle
///    parle d'une procédure qu'on confond), et elle existait avant ;
/// 2. sinon la ligne des filtres, dès qu'un filtre est posé ;
/// 3. sinon rien.
///
/// ## Pourquoi [suspended] y figure
///
/// La ligne de procédure disparaît pour un compte dont le pays est suspendu
/// (règle de la build 54 : la mise en garde de suspension est déjà à l'écran).
/// Lui laisser la priorité ne montrerait alors AUCUNE ligne à un étudiant qui
/// filtre — alors que ces comptes voient les déclencheurs de la build 55. La
/// priorité ne vaut donc que pour une ligne qu'on VOIT.
EefCatalogHelpLine eefCatalogHelpLineFor({
  required bool confusingProcedure,
  required bool filtersActive,
  required bool suspended,
}) {
  if (confusingProcedure && !suspended) return EefCatalogHelpLine.procedure;
  if (filtersActive) return EefCatalogHelpLine.filters;
  return EefCatalogHelpLine.none;
}

/// Un déclencheur d'aide : une ligne (« question + lien »), ou un bouton seul
/// pour [EefHelpTrigger.catalogProgram].
///
/// ## Compte suspendu
///
/// Il VOIT le déclencheur. Le lien devient « Parler à un conseiller » et le
/// message ne parle que d'options — les textes de la question ne parlent jamais
/// d'ouvrir un dossier, ils sont communs aux deux variantes. La suspension est
/// lue ICI, au point unique [EefHelp.isSuspended], et la ligne se reconstruit à
/// l'arrivée des drapeaux serveur (la liste des pays suspendus vit dans
/// `/config/app`).
///
/// ## Mesure
///
/// `eef_help_cta_tapped` part au tap (étape = [EefHelpTrigger.key], écran, forme
/// `compact`), puis `whatsapp_handoff` (`source` = `eef_help_<clé>`).
/// `eef_help_card_shown` part UNE fois par visite de l'écran, pour les
/// déclencheurs qui le comptent ([EefHelpTrigger.countsShown]). Ni l'un ni
/// l'autre ne porte l'intitulé d'une formation, une ville, un libellé de filtre :
/// la seule porte vers l'analytique ([EefHelpAnalytics]) n'accepte que trois
/// identifiants fermés.
///
/// ## Mention « un accompagnement n'est pas une garantie »
///
/// Le catalogue la porte déjà UNE fois — dans la carte pleine de bas de liste, ou,
/// tant que la liste est paginée et que cette carte n'existe pas, dans l'en-tête de
/// la liste — et la répéter sous chaque formation ou chaque ligne serait du bruit :
/// les lignes de la build 54 n'en portent pas non plus. Un ÉCRAN D'OUTIL, lui, n'a
/// aucune carte : la ligne est son seul déclencheur, et la mention l'accompagne.
///
/// ## Fond
///
/// Dans le catalogue, la ligne vit sur le fond du thème (clair ou sombre) : ses
/// couleurs viennent de `context.kpb` et du thème des boutons de texte. Les
/// écrans d'outils posent leur propre fond clair en dur (`KpbColors.canvas`) :
/// une ligne qui lirait les couleurs du thème y serait illisible en sombre. Elle
/// s'y dessine donc sur SA surface (la même que l'`AiDisclosureBanner` au-dessus
/// d'elle), avec des couleurs de jeton fixes dont le contraste ne dépend pas du
/// thème.
class EefHelpLine extends StatefulWidget {
  const EefHelpLine({
    super.key,
    required this.trigger,
    this.prefill,
    this.subject,
  });

  final EefHelpTrigger trigger;

  /// Le message de WhatsApp, selon que le compte est suspendu. Absent : le
  /// message de l'outil ([EefHelpMessages.forTool]). Appelé AU TAP, pas à la
  /// construction : il lit l'état du moment (les filtres posés).
  final String Function(bool suspended)? prefill;

  /// Ce dont parle le bouton, pour les lecteurs d'écran (l'intitulé d'une
  /// formation) : vingt boutons « Demander de l'aide » à la suite ne disent pas
  /// de laquelle ils parlent.
  final String? subject;

  @override
  State<EefHelpLine> createState() => _EefHelpLineState();
}

class _EefHelpLineState extends State<EefHelpLine> {
  bool _shownLogged = false;

  void _logShownOnce() {
    if (_shownLogged) return;
    _shownLogged = true;
    if (eefHelpAlreadyCountedThisVisit(context, widget.trigger.key)) return;
    // Après le cadre : une mesure n'a pas à tourner pendant `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EefHelp.analytics.shown(
        step: widget.trigger.key,
        surface: widget.trigger.surface,
        variant: 'compact',
      );
    });
  }

  void _onTap({required bool suspended}) {
    final trigger = widget.trigger;
    EefHelp.analytics.tapped(
      step: trigger.key,
      surface: trigger.surface,
      variant: 'compact',
    );
    final message = widget.prefill?.call(suspended) ??
        EefHelpMessages.forTool(trigger, suspended: suspended);
    unawaited(openWhatsAppOrToast(
      // Le point d'entrée commun : on n'ouvre pas un second chemin vers le
      // conseiller.
      prefill: kpbWhatsAppPrefill(custom: message),
      source: 'eef_help_${trigger.key}',
      contextType: 'eef_help',
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruite à l'arrivée des drapeaux serveur : voir la doc de la classe.
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        final trigger = widget.trigger;
        final suspended = EefHelp.isSuspended();
        if (trigger.countsShown) _logShownOnce();

        final subject = widget.subject;
        final link = _HelpLink(
          label: (suspended ? 'eef_help_line_neutral_cta' : 'eef_help_line_cta')
              .tr,
          semanticsLabel: subject == null
              ? null
              : (suspended
                      ? 'eef_help_line_neutral_subject'
                      : 'eef_help_line_subject')
                  .trParams({'subject': subject.replaceAll('@', '')}),
          onOwnSurface: trigger.isTool,
          onTap: () => _onTap(suspended: suspended),
        );

        if (!trigger.hasQuestion) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: link,
          );
        }

        final question = 'eef_help_${trigger.key}_question'.tr;
        if (trigger.isTool) {
          return _ToolBanner(question: question, link: link);
        }
        // `Wrap` et non `Row` : à l'échelle de texte 1,3 d'un petit téléphone, la
        // question et le lien ne tiennent pas sur une ligne, et une `Row`
        // coupait ou débordait. Le lien passe sous la question.
        return Padding(
          padding: const EdgeInsets.only(top: KpbSpacing.xs),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KpbSpacing.sm,
            children: [
              Text(
                question,
                style: KpbTextStyles.bodySm
                    .copyWith(color: context.kpb.textSecondary),
              ),
              link,
            ],
          ),
        );
      },
    );
  }
}

/// La ligne d'un écran d'outil, sur sa propre surface — voir « Fond » dans la
/// doc de [EefHelpLine]. Mêmes jetons que `AiDisclosureBanner`, avec un texte
/// `textSecondary` : `textMuted` n'y fait que 4,4:1.
class _ToolBanner extends StatelessWidget {
  const _ToolBanner({required this.question, required this.link});

  final String question;
  final Widget link;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: KpbSpacing.md - 4,
        vertical: KpbSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: KpbColors.actionPrimarySoft,
        borderRadius: KpbRadius.smBr,
        border: Border.all(color: KpbColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: KpbSpacing.sm,
            children: [
              Text(
                question,
                style: KpbTextStyles.bodySm
                    .copyWith(color: KpbColors.textSecondary),
              ),
              link,
            ],
          ),
          // L'écran d'outil n'a pas de carte pleine : la mention accompagne
          // l'unique déclencheur.
          Padding(
            padding: const EdgeInsets.only(bottom: KpbSpacing.xs),
            child: Text(
              'eef_help_fineprint'.tr,
              style: KpbTextStyles.caption
                  .copyWith(color: KpbColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le lien : une icône de conversation et le libellé, dans un bouton de texte du
/// thème, sur 48 dp de haut au moins.
///
/// Un `TextButton` plutôt qu'un `InkWell` posé à la main : il hérite du thème sa
/// couleur d'action (lisible en clair ET en sombre), ses états pressé et focus, et
/// son libellé PASSE À LA LIGNE à l'échelle de texte 1,3 au lieu d'être coupé. Il
/// porte aussi son propre `Material` : l'encre du toucher se peint AU-DESSUS du
/// fond bleu d'un écran d'outil, pas dessous.
class _HelpLink extends StatelessWidget {
  const _HelpLink({
    required this.label,
    required this.onTap,
    required this.onOwnSurface,
    this.semanticsLabel,
  });

  final String label;
  final String? semanticsLabel;
  final VoidCallback onTap;

  /// Sur la surface propre d'un écran d'outil : couleur d'action fixe.
  final bool onOwnSurface;

  @override
  Widget build(BuildContext context) {
    // Sur un fond CLAIR (le thème clair, ou la surface propre d'un écran d'outil,
    // claire dans les deux thèmes) la surcouche pressée assombrit le fond sous un
    // texte `actionPrimary` : mesuré, 3,66 à 3,94:1 — le doigt est SUR le lien au
    // moment où l'on le lit. Pressé, le texte passe donc à `actionPrimaryPressed`
    // (4,9 à 5,1:1 sur ces fonds). En thème sombre le texte est clair et la
    // surcouche l'éclaircit : la couleur du thème suffit.
    final lightSurface =
        onOwnSurface || Theme.of(context).brightness == Brightness.light;

    return Semantics(
      // Un nœud à lui : sans `container`, une carte qui fusionne ses
      // descendants noierait le libellé (« à propos de cette formation ») dans
      // celui de la carte.
      container: true,
      button: true,
      enabled: true,
      label: semanticsLabel ?? label,
      onTap: onTap,
      // L'arbre visuel dit la même chose : on ne l'expose pas deux fois.
      excludeSemantics: true,
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          tapTargetSize: MaterialTapTargetSize.padded,
          padding: const EdgeInsets.symmetric(horizontal: KpbSpacing.sm),
          foregroundColor: onOwnSurface ? KpbColors.actionPrimary : null,
        ).copyWith(
          // `copyWith` et non `styleFrom(foregroundColor:)` : la surcouche reste
          // celle que `styleFrom` dérive de la couleur de repos.
          foregroundColor: lightSurface
              ? WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.pressed)
                      ? KpbColors.actionPrimaryPressed
                      : KpbColors.actionPrimary,
                )
              : null,
        ),
        icon: const Icon(Icons.chat_rounded, size: 16),
        label: Text(label),
      ),
    );
  }
}
