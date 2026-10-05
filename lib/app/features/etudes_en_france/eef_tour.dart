import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/config/app_config.dart';
import '../../core/services/analytics_service.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_help_bubble.dart';
import 'eef_help_card.dart';
import 'eef_tour_store.dart';

/// Ce qui a ouvert la visite (propriété `tour_trigger` de `eef_tour_shown`).
enum EefTourTrigger {
  /// La première ouverture du hub réel.
  firstOpen('first_open'),

  /// Le bouton « ? » de la barre du hub.
  replay('replay');

  const EefTourTrigger(this.key);

  final String key;
}

/// Comment la visite s'est fermée (propriété `tour_exit` de
/// `eef_tour_completed`).
enum EefTourExit {
  /// « Compris », à la dernière carte.
  finished('finished'),

  /// Toute autre fermeture : « Passer », le retour Android, le voile, un
  /// glissement vers le bas.
  skipped('skipped');

  const EefTourExit(this.key);

  final String key;
}

/// Ce que la visite mesure. Une interface plutôt que `AnalyticsService` en
/// direct, pour la même raison que [EefHelpAnalytics] : le service n'a pas de
/// constructeur public, donc un test ne pouvait rien affirmer sur ce qui est
/// mesuré.
abstract interface class EefTourAnalytics {
  /// La visite s'est affichée (`eef_tour_shown`). [trigger] : `first_open` ou
  /// `replay`.
  void shown({required String trigger});

  /// La visite s'est fermée (`eef_tour_completed`). [exit] : `finished` ou
  /// `skipped` ; [cardsSeen] : le nombre de cartes atteintes.
  void completed({required String exit, required int cardsSeen});
}

class _ServiceEefTourAnalytics implements EefTourAnalytics {
  const _ServiceEefTourAnalytics();

  @override
  void shown({required String trigger}) =>
      unawaited(AnalyticsService.instance.logEefTourShown(trigger: trigger));

  @override
  void completed({required String exit, required int cardsSeen}) =>
      unawaited(AnalyticsService.instance.logEefTourCompleted(
        exit: exit,
        cardsSeen: cardsSeen,
      ));
}

/// Les étapes possibles de la visite, dans l'ordre. Une étape est identifiée par
/// son numéro DANS LE TEXTE (`eef_tour_<n>_…`), pas par sa position : omettre
/// « Prépare tes documents » ne renumérote pas les clés des autres.
enum EefTourStep {
  /// Où l'on est, et où se dépose la candidature.
  welcome(1, Icons.school_rounded),

  /// Le catalogue et ses filtres.
  find(2, Icons.travel_explore_rounded),

  /// Les outils (CV, lettres, entretien). Omise quand les outils IA sont masqués.
  documents(3, Icons.description_rounded),

  /// La bulle verte WhatsApp. Omise quand elle n'est pas affichée.
  bubble(4, Icons.chat_rounded);

  const EefTourStep(this.number, this.icon);

  /// Le numéro des clés de traduction.
  final int number;

  /// Le pictogramme du disque.
  final IconData icon;

  String get titleKey => 'eef_tour_${number}_title';

  /// La clé du corps. Seule la première étape a une variante NEUTRE, pour un
  /// compte dont le pays est suspendu : ni « candidature » ni « dossier », aucun
  /// pays nommé.
  String bodyKey({required bool suspended}) => this == welcome && suspended
      ? 'eef_tour_1_neutral_body'
      : 'eef_tour_${number}_body';
}

/// La visite guidée du hub « Études en France » : trois ou quatre cartes dans
/// une feuille, montrées UNE fois à la première ouverture du hub réel, et
/// rejouables par le bouton « ? » de la barre.
///
/// ## Ce qu'elle est, et ce qu'elle n'est pas
///
/// Une feuille modale, pas un mur : le hub reste visible derrière, le voile se
/// touche, « Passer » est sur chaque carte. Pas de spot lumineux sur les tuiles
/// (une liste paresseuse au contenu variable ne s'y prête pas), pas de
/// dépendance. Elle ne réutilise NI le diaporama de départ (`Get.offAll` vide la
/// pile, et son texte parle du Canada) NI la ligne de profil « Revoir le
/// tutoriel de démarrage » (elle rejoue le questionnaire).
///
/// ## Quand elle s'ouvre
///
/// À la première ouverture du hub réel — jamais la vitrine, jamais l'écran des
/// parents — si le drapeau « vue » n'est pas posé ([store]), que le hub est
/// encore monté et courant, et qu'AUCUN dialogue ni aucune feuille n'est
/// ouvert par-dessus. Le drapeau est posé à l'AFFICHAGE, pas à la fin : un
/// plantage, « Passer » ou le retour Android ne la font pas revenir.
///
/// ## Une panne vaut « déjà vue »
///
/// Si le stockage ne répond pas — en lecture comme en écriture — la visite ne
/// s'ouvre pas, sans exception : une visite qui reviendrait à chaque ouverture
/// faute de pouvoir noter qu'elle a eu lieu est pire qu'une visite perdue.
///
/// ## Ce qu'elle ne dit jamais
///
/// Rien sur les écoles privées, aucun prix, aucune promesse. Pour un compte dont
/// le pays est suspendu, seule la première carte change (voir
/// [EefTourStep.bodyKey]) ; les autres cartes sont identiques.
abstract final class EefTour {
  /// Le magasin du drapeau « vue » — REMPLAÇABLE par un test.
  @visibleForTesting
  static EefTourStore store = const SharedPreferencesEefTourStore();

  /// Ce qui est mesuré — REMPLAÇABLE par un test.
  @visibleForTesting
  static EefTourAnalytics analytics = const _ServiceEefTourAnalytics();

  @visibleForTesting
  static void resetForTest() {
    store = const SharedPreferencesEefTourStore();
    analytics = const _ServiceEefTourAnalytics();
  }

  /// Les étapes à montrer : toutes, moins celles qui nommeraient un élément
  /// absent. Une étape ne décrit jamais ce que l'étudiant ne voit pas.
  static List<EefTourStep> stepsFor({
    required bool aiTools,
    required bool bubble,
  }) =>
      [
        for (final step in EefTourStep.values)
          if (step != EefTourStep.documents || aiTools)
            if (step != EefTourStep.bubble || bubble) step,
      ];

  /// Peut-on ouvrir une feuille ICI, MAINTENANT ? L'écran est monté ET sa route
  /// est celle du dessus : un dialogue, une autre feuille ou un écran poussé
  /// par-dessus la rendent non courante.
  ///
  /// À appeler APRÈS un `context.mounted` (le contexte a pu mourir pendant une
  /// attente).
  static bool _isTopRoute(BuildContext context) =>
      ModalRoute.of(context)?.isCurrent == true;

  /// Montre la visite si c'est la première ouverture. Rend `true` si elle a été
  /// montrée (la future se termine alors à la FIN de la visite), `false` sinon.
  ///
  /// L'ordre est voulu : lire le drapeau, vérifier qu'on peut ouvrir, ÉCRIRE le
  /// drapeau, vérifier de nouveau, puis ouvrir. Écrire avant d'ouvrir, c'est ce
  /// qui garantit qu'une écriture en panne ne produit pas une visite en boucle.
  static Future<bool> showIfFirstOpen(BuildContext context) async {
    try {
      if (await store.hasBeenShown()) return false;
    } catch (_) {
      return false;
    }
    if (!context.mounted || !_isTopRoute(context)) return false;
    try {
      await store.markShown();
    } catch (_) {
      return false;
    }
    if (!context.mounted || !_isTopRoute(context)) return false;
    await show(context, trigger: EefTourTrigger.firstOpen);
    return true;
  }

  /// Ouvre la visite, sans toucher au drapeau. Rend la main quand la feuille est
  /// entièrement refermée.
  static Future<void> show(
    BuildContext context, {
    required EefTourTrigger trigger,
  }) async {
    final steps = stepsFor(
      aiTools: AppConfig.aiToolsEnabled,
      bubble: EefHelpBubble.shouldShow(context),
    );
    // Lue UNE fois, à l'affichage : le texte d'une carte ne change pas sous les
    // yeux de l'étudiant quand les drapeaux serveur arrivent.
    final suspended = EefHelp.isSuspended();
    final progress = _TourProgress();

    analytics.shown(trigger: trigger.key);

    TransitionRoute<Object?>? route;
    final exit = await showModalBottomSheet<EefTourExit>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Un iPad ne tire pas une feuille de 768 dp de large.
      constraints: const BoxConstraints(maxWidth: 480),
      routeSettings: const RouteSettings(name: 'eef_tour'),
      builder: (sheetContext) {
        route ??= ModalRoute.of(sheetContext);
        return _TourSheet(
          steps: steps,
          suspended: suspended,
          progress: progress,
        );
      },
    );

    analytics.completed(
      // Tout ce qui n'est pas « Compris » est un « Passer » : le bouton, le
      // retour Android, le voile, un glissement vers le bas.
      exit: (exit ?? EefTourExit.skipped).key,
      cardsSeen: progress.cardsSeen,
    );

    // `showModalBottomSheet` rend la main dès le DÉBUT de la fermeture : on
    // attend qu'elle soit finie, pour que ce qui suit (l'entrée de la bulle) se
    // joue à l'écran et non sous la feuille qui s'efface.
    await route?.completed;
  }
}

/// Le plus haut indice de carte atteint, partagé entre la feuille et
/// l'appelant (qui mesure à la fermeture).
class _TourProgress {
  int _highest = 0;

  void reach(int index) {
    if (index > _highest) _highest = index;
  }

  /// Le nombre de cartes ATTEINTES (la plus haute vue, pas le nombre de pages
  /// tournées : revenir en arrière ne le diminue pas).
  int get cardsSeen => _highest + 1;
}

/// La feuille : un compteur, les cartes dans un `PageView`, des points, et deux
/// boutons épinglés (« Passer », « Suivant »/« Compris »).
class _TourSheet extends StatefulWidget {
  const _TourSheet({
    required this.steps,
    required this.suspended,
    required this.progress,
  });

  final List<EefTourStep> steps;
  final bool suspended;
  final _TourProgress progress;

  @override
  State<_TourSheet> createState() => _TourSheetState();
}

class _TourSheetState extends State<_TourSheet> {
  final PageController _pages = PageController();
  int _index = 0;

  /// Vrai dès qu'une sortie est partie : un second tap ne dépile pas l'écran qui
  /// est dessous.
  bool _closing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _close(EefTourExit exit) {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop(exit);
  }

  void _goTo(int target) {
    if (target < 0 || target >= widget.steps.length) return;
    setState(() => _index = target);
    widget.progress.reach(target);
    // « Réduire les animations » de l'OS : la carte change sans glisser.
    if (MediaQuery.disableAnimationsOf(context)) {
      _pages.jumpToPage(target);
    } else {
      unawaited(_pages.animateToPage(
        target,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      ));
    }
  }

  void _onPageChanged(int index) {
    widget.progress.reach(index);
    if (index != _index) setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    final steps = widget.steps;
    final isLast = _index == steps.length - 1;

    return Semantics(
      key: const ValueKey('eef-tour-sheet'),
      // La route porte un nom (« Visite de l'espace ») : un lecteur d'écran
      // l'annonce à l'ouverture, et le focus reste dans la feuille.
      namesRoute: true,
      label: 'eef_tour_title'.tr,
      explicitChildNodes: true,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KpbSpacing.pagePad,
            KpbSpacing.lg,
            KpbSpacing.pagePad,
            KpbSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // « Étape 2 sur 4 » : annoncé quand il change.
              Semantics(
                liveRegion: true,
                child: Text(
                  'eef_tour_counter'.trParams({
                    'n': '${_index + 1}',
                    'total': '${steps.length}',
                  }),
                  textAlign: TextAlign.center,
                  style: KpbTextStyles.caption.copyWith(
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: KpbSpacing.sm),
              // Le contenu défile si l'écran est trop petit (texte ×1,3 sur
              // 320×568) ; les boutons, eux, restent épinglés dessous.
              Flexible(
                child: SingleChildScrollView(
                  child: Stack(
                    children: [
                      // Les cartes, invisibles : la plus haute donne sa hauteur à
                      // la zone, pour que la feuille ne saute pas d'une carte à
                      // l'autre. Exclues de la sémantique (Visibility).
                      for (final step in steps)
                        Visibility(
                          visible: false,
                          maintainState: true,
                          maintainAnimation: true,
                          maintainSize: true,
                          child: _StepPage(
                            step: step,
                            suspended: widget.suspended,
                          ),
                        ),
                      Positioned.fill(
                        child: PageView(
                          controller: _pages,
                          onPageChanged: _onPageChanged,
                          children: [
                            for (final step in steps)
                              _StepPage(
                                step: step,
                                suspended: widget.suspended,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: KpbSpacing.md),
              ExcludeSemantics(
                key: const ValueKey('eef-tour-dots'),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < steps.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                          width: 8,
                          height: 8,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _index
                                  ? KpbColors.actionPrimary
                                  : c.border,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: KpbSpacing.md),
              // Des `TextButton`/`FilledButton` du thème et non `KpbButton`, qui
              // coupe son libellé avec une ellipse : ici les libellés passent à
              // la ligne (voir `_HelpButton`, eef_help_card.dart).
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: TextButton(
                      key: const ValueKey('eef-tour-skip'),
                      onPressed: () => _close(EefTourExit.skipped),
                      style: TextButton.styleFrom(
                        foregroundColor: KpbColors.actionPrimary,
                        minimumSize: const Size(48, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(
                          horizontal: KpbSpacing.md,
                          vertical: KpbSpacing.sm,
                        ),
                      ),
                      child: Text(
                        'eef_tour_skip'.tr,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: KpbSpacing.sm),
                  Flexible(
                    child: FilledButton(
                      key: const ValueKey('eef-tour-next'),
                      onPressed: isLast
                          ? () => _close(EefTourExit.finished)
                          : () => _goTo(_index + 1),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(96, 48),
                        tapTargetSize: MaterialTapTargetSize.padded,
                        padding: const EdgeInsets.symmetric(
                          horizontal: KpbSpacing.lg,
                          vertical: KpbSpacing.sm,
                        ),
                      ),
                      child: Text(
                        (isLast ? 'eef_tour_done' : 'eef_tour_next').tr,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Une carte : un pictogramme dans un disque, un titre, un texte.
class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.suspended});

  final EefTourStep step;
  final bool suspended;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    // La miniature de la bulle est celle de la vraie : le vert WhatsApp et une
    // icône marine générique, jamais le logo de WhatsApp.
    final isBubble = step == EefTourStep.bubble;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          // Décoratif : le titre dit déjà la même chose.
          child: ExcludeSemantics(
            child: SizedBox(
              width: 64,
              height: 64,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isBubble
                      ? KpbColors.whatsapp
                      : KpbColors.actionPrimary.withValues(alpha: 0.12),
                ),
                child: Center(
                  child: Icon(
                    step.icon,
                    size: 30,
                    color: isBubble
                        ? KpbColors.brandNavy
                        : KpbColors.actionPrimary,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: KpbSpacing.md),
        Semantics(
          // Un nœud à lui : sans `container`, le titre et le texte fusionnent en
          // un seul nœud, et c'est ce paragraphe entier qui serait annoncé comme
          // un en-tête.
          container: true,
          header: true,
          child: Text(
            step.titleKey.tr,
            key: const ValueKey('eef-tour-title'),
            textAlign: TextAlign.center,
            style: KpbTextStyles.titleMd.copyWith(color: c.textPrimary),
          ),
        ),
        const SizedBox(height: KpbSpacing.sm),
        Text(
          step.bodyKey(suspended: suspended).tr,
          key: const ValueKey('eef-tour-body'),
          textAlign: TextAlign.center,
          style: KpbTextStyles.body.copyWith(color: c.textSecondary),
        ),
      ],
    );
  }
}
