import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/data/eef_calendar.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';

/// Les endroits de l'espace « Études en France » où un étudiant peut être perdu,
/// et où l'on pose la question : « c'est flou ? tu veux de l'aide ? ».
///
/// ## Pourquoi un enum fermé et pas une chaîne libre
///
/// La clé d'étape [key] sert de clé de traduction (`eef_help_<key>_question`…),
/// de libellé dans le message WhatsApp prérempli, et de valeur analytique. Une
/// chaîne libre se faute en silence — `.tr` rendrait alors la CLÉ à l'écran —
/// alors qu'un enum se faute à la compilation, et un test balaie ses valeurs
/// pour prouver que chacune a ses textes en français ET en anglais.
///
/// [compact] dit la forme : une ligne et un lien, ou une carte. Elle est
/// attachée à l'étape et non choisie par l'appelant, parce que chaque forme a
/// ses propres textes (une carte porte un corps et un bouton, une ligne non) :
/// laisser l'appelant la choisir permettrait de demander une carte pour une
/// étape qui n'a pas de corps.
enum EefHelpStep {
  /// Le hub, carte principale : « pour passer à l'étape supérieure… ».
  hub(key: 'hub', surface: 'hub', compact: false),

  /// Le hub, sous le héros : procédure, dates et dépôt. La candidature se dépose
  /// auprès des services officiels, pas dans KPB : l'étudiant ne sait pas
  /// toujours où ni quand.
  procedure(key: 'procedure', surface: 'hub', compact: true),

  /// Le hub, sous les outils : les pièces du dossier.
  documents(key: 'documents', surface: 'hub', compact: true),

  /// Le catalogue, sous les résultats.
  catalogResults(key: 'catalog_results', surface: 'catalog', compact: false),

  /// Le catalogue, au-dessus des résultats, quand la procédure filtrée est
  /// de celles qu'on confond (voir [eefProcedureIsConfusing]).
  catalogProcedure(key: 'catalog_procedure', surface: 'catalog', compact: true),

  /// Le catalogue, quand la recherche ne trouve rien.
  catalogEmpty(key: 'catalog_empty', surface: 'catalog', compact: false),

  /// Le catalogue, quand rien n'est encore publié : l'écran disait « demande à
  /// un conseiller » sans lui donner le moyen de le faire.
  catalogUnpublished(
    key: 'catalog_unpublished',
    surface: 'catalog',
    compact: false,
  );

  const EefHelpStep({
    required this.key,
    required this.surface,
    required this.compact,
  });

  /// Identifiant stable : traductions, message prérempli, analytique.
  final String key;

  /// L'écran porteur (`hub` ou `catalog`) — la propriété « surface » de
  /// l'analytique.
  final String surface;

  /// Une ligne et un lien (`true`), ou une carte avec bouton (`false`).
  final bool compact;
}

/// Les procédures d'admission pour lesquelles on propose de l'aide : le dossier
/// jaune, Parcoursup, et ce qui est « hors procédure ».
///
/// La liste est celle du propriétaire du produit, pas une déduction : elle dit
/// où l'on veut proposer de l'aide, pas ce que chaque procédure exige — le
/// catalogue n'explique aucune procédure, et cette carte non plus.
const _kConfusingProcedures = {'hors_eef', 'dap_jaune', 'parcoursup'};

/// Les valeurs de `procedureType` que l'app sait nommer (voir les clés
/// `eef_catalog_value_procedureType_*`).
const _kKnownProcedures = {
  'dap_blanche',
  'dap_jaune',
  'eef',
  'parcoursup',
  'hors_eef',
};

/// `true` quand [procedureType] est une de celles qu'on confond. Une valeur
/// absente ou inconnue n'en fait PAS partie : voir [eefProcedureIsKnown].
bool eefProcedureIsConfusing(String? procedureType) =>
    _kConfusingProcedures.contains(procedureType?.trim());

/// `false` quand la procédure est absente ou n'est pas une valeur que l'app
/// connaît — la carte de formation n'affiche alors aucun badge, et l'étudiant
/// ne sait pas par où candidater.
bool eefProcedureIsKnown(String? procedureType) =>
    _kKnownProcedures.contains(procedureType?.trim());

/// Ce que la carte d'aide mesure. Une interface plutôt que `AnalyticsService`
/// en direct, pour la même raison que `EefCatalogAnalytics` : le service n'a pas
/// de constructeur public, donc un test ne pouvait rien affirmer sur ce qui est
/// mesuré — et ce qui n'est pas testé ici est ce qui finit par envoyer une
/// donnée personnelle dans un événement.
abstract interface class EefHelpAnalytics {
  void shown({
    required String step,
    required String surface,
    required String variant,
  });

  void tapped({
    required String step,
    required String surface,
    required String variant,
  });

  /// Le menu de la bulle d'aide a été ouvert (`eef_bubble_opened`). Une seule
  /// propriété : l'écran porteur (`hub` ou `catalog`).
  void bubbleOpened({required String surface});
}

class _ServiceEefHelpAnalytics implements EefHelpAnalytics {
  const _ServiceEefHelpAnalytics();

  @override
  void shown({
    required String step,
    required String surface,
    required String variant,
  }) =>
      unawaited(AnalyticsService.instance.logEefHelpCardShown(
        step: step,
        surface: surface,
        variant: variant,
      ));

  @override
  void tapped({
    required String step,
    required String surface,
    required String variant,
  }) =>
      unawaited(AnalyticsService.instance.logEefHelpCtaTapped(
        step: step,
        surface: surface,
        variant: variant,
      ));

  @override
  void bubbleOpened({required String surface}) =>
      unawaited(AnalyticsService.instance.logEefBubbleOpened(surface: surface));
}

/// Cette étape a-t-elle déjà été comptée pendant la visite de l'écran ? La
/// première fois, rend `false` ET la note ; ensuite, `true`.
///
/// Pas d'`AutomaticKeepAliveClientMixin` : tenir la carte vivante dans sa
/// liste est la réponse habituelle, mais la carte vit aussi dans des listes
/// que l'écran remplace d'un état à l'autre (résultats, vide, non publié), et
/// le mixin y levait « Incorrect use of ParentDataWidget » (mesuré par le
/// test « tout effacer »). Le `PageStorage` n'a pas ce défaut.
///
/// Partagée avec les lignes d'aide de la build 55 (`EefHelpLine`) : une seule
/// mémoire, une seule définition de « une fois par visite ».
bool eefHelpAlreadyCountedThisVisit(BuildContext context, String stepKey) {
  final bucket = PageStorage.maybeOf(context);
  if (bucket == null) return false;
  final identifier = 'eef_help_shown_$stepKey';
  if (bucket.readState(context, identifier: identifier) == true) return true;
  bucket.writeState(context, true, identifier: identifier);
  return false;
}

/// Les règles de la carte d'aide qui ne tiennent pas dans un widget : à qui
/// elle parle, et ce qu'elle écrit à WhatsApp.
abstract final class EefHelp {
  /// La porte vers la mesure, celle de la carte — remplaçable par un test via
  /// [EefHelpCard.analytics]. Les lignes d'aide de la build 55 (`EefHelpLine`)
  /// passent par ici : une seule porte, donc un seul endroit où un test regarde ce
  /// qui est mesuré.
  static EefHelpAnalytics get analytics => EefHelpCard.analytics;

  /// L'étudiant est-il dans un pays où la procédure est suspendue ?
  ///
  /// ## Pourquoi la carte le lit elle-même
  ///
  /// Parce que la règle « une incitation ne suggère JAMAIS de démarrer un
  /// dossier pour un pays suspendu » ne doit pas dépendre de la mémoire de
  /// l'appelant. Le dépôt a déjà payé ce prix (PARC-05, puis la carte d'accueil
  /// qui annonçait « ouverture dans 41 jours » à un étudiant nigérien) : une
  /// garde posée sur certaines portes seulement protège les portes qui l'ont.
  /// Ici l'appelant ne passe qu'une étape ; la suspension est lue au point
  /// unique, [EefCalendar.isSuspendedFor].
  static bool isSuspended() {
    final country = Get.isRegistered<AppController>()
        ? Get.find<AppController>().profile?.countryOfResidence
        : null;
    return EefCalendar.isSuspendedFor(country);
  }

  /// Le nom de l'étape, tel que l'écrit le message prérempli.
  static String stepLabel(EefHelpStep step) => 'eef_help_step_${step.key}'.tr;

  /// Le message que WhatsApp ouvre déjà rédigé.
  ///
  /// Il nomme l'ÉTAPE, pour que le conseiller sache d'où vient l'étudiant sans
  /// le lui redemander. Il ne contient AUCUNE donnée personnelle : ni nom, ni
  /// e-mail, ni téléphone, ni pays, ni identifiant — le profil n'est pas lu.
  /// Pour un pays suspendu, il dit que la procédure est suspendue « dans mon
  /// pays » sans le nommer, et demande les autres options : il ne parle jamais
  /// d'ouvrir un dossier.
  ///
  /// Passe par [kpbWhatsAppPrefill] (`custom:`), le point d'entrée commun : on
  /// n'ouvre pas un second chemin vers le conseiller.
  static String prefillFor(EefHelpStep step, {required bool suspended}) {
    final key = suspended ? 'eef_help_prefill_suspended' : 'eef_help_prefill';
    return kpbWhatsAppPrefill(
      custom: key.trParams({'step': stepLabel(step)}),
    );
  }
}

/// La carte d'aide de l'espace « Études en France » : une question courte, une
/// phrase d'incitation, un bouton qui ouvre WhatsApp vers le conseiller KPB avec
/// un message qui dit à quelle étape en est l'étudiant.
///
/// Deux formes, selon [EefHelpStep.compact] : une carte (question, phrase,
/// bouton, mention) pour les moments où l'étudiant s'arrête, une ligne et un
/// lien pour les étapes intermédiaires.
///
/// ## Ce que la carte s'interdit
///
/// - **Suggérer de démarrer un dossier à un étudiant dont le pays est suspendu.**
///   Elle change de texte (« parler des autres options »), de bouton et de
///   message prérempli ; les formes compactes, elles, disparaissent — la
///   mise en garde de suspension est déjà à l'écran, et trois invitations de
///   plus la noieraient.
/// - **Promettre un résultat.** La mention sous la carte dit qu'un
///   accompagnement n'est pas une garantie d'admission ni de visa. Aucun prix
///   n'est cité : il n'y en a pas dans l'app pour cette étape.
/// - **Se confondre avec le service officiel.** KPB est un organisme privé ;
///   la carte dit « conseiller KPB » et jamais le nom de l'opérateur de l'État
///   (voir `eef_naming_test.dart`).
/// - **Ouvrir un second chemin vers WhatsApp.** Le tap passe par
///   [openWhatsAppOrToast], qui journalise `whatsapp_handoff` et affiche le
///   repli quand WhatsApp ne s'ouvre pas.
///
/// ## Mesure
///
/// `eef_help_card_shown` part UNE fois par étape et par visite de l'écran : la
/// mémoire vit dans le `PageStorage` de la route, pas dans la carte. Une liste
/// paresseuse démonte une carte sortie du champ puis la remonte quand on
/// revient — sans cette mémoire, faire défiler la liste de haut en bas compterait
/// dix « vues » d'une même carte, et le taux de clic s'effondrerait pour une
/// raison de défilement. Ouvrir l'écran de nouveau est une nouvelle visite. Une
/// liste paresseuse monte aussi la carte un peu AVANT qu'elle ne soit visible :
/// c'est une borne haute de la portée, pas un compte d'yeux.
/// `eef_help_cta_tapped` part au tap, avant l'ouverture de WhatsApp. Ni l'un ni
/// l'autre ne porte de donnée personnelle.
class EefHelpCard extends StatefulWidget {
  const EefHelpCard({super.key, required this.step});

  final EefHelpStep step;

  /// Ce qui est mesuré, REMPLAÇABLE par un test.
  @visibleForTesting
  static EefHelpAnalytics analytics = const _ServiceEefHelpAnalytics();

  @visibleForTesting
  static void resetForTest() {
    analytics = const _ServiceEefHelpAnalytics();
  }

  @override
  State<EefHelpCard> createState() => _EefHelpCardState();
}

class _EefHelpCardState extends State<EefHelpCard> {
  bool _shownLogged = false;

  String get _variant => widget.step.compact ? 'compact' : 'card';

  bool _alreadyCountedThisVisit() =>
      eefHelpAlreadyCountedThisVisit(context, widget.step.key);

  void _logShownOnce() {
    if (_shownLogged) return;
    _shownLogged = true;
    if (_alreadyCountedThisVisit()) return;
    // Après le cadre : une mesure n'a pas à tourner pendant `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EefHelpCard.analytics.shown(
        step: widget.step.key,
        surface: widget.step.surface,
        variant: _variant,
      );
    });
  }

  void _onTap({required bool suspended}) {
    final step = widget.step;
    EefHelpCard.analytics.tapped(
      step: step.key,
      surface: step.surface,
      variant: _variant,
    );
    unawaited(openWhatsAppOrToast(
      prefill: EefHelp.prefillFor(step, suspended: suspended),
      source: 'eef_help_${step.key}',
      contextType: 'eef_help',
    ));
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruite à l'arrivée des drapeaux serveur : la liste des pays
    // suspendus VIT dans `/config/app`. Sans cette écoute, une carte montée sur
    // les valeurs de repli resterait sur le texte « démarrer un dossier » après
    // que le serveur a dit que le pays est suspendu — et `const EefHelpCard()`
    // n'est jamais reconstruite par son parent.
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        final suspended = EefHelp.isSuspended();
        final step = widget.step;
        if (step.compact && suspended) return const SizedBox.shrink();
        _logShownOnce();
        return step.compact
            ? _CompactHelp(
                step: step,
                onTap: () => _onTap(suspended: suspended),
              )
            : _FullHelp(
                step: step,
                suspended: suspended,
                onTap: () => _onTap(suspended: suspended),
              );
      },
    );
  }
}

/// La carte : question, phrase d'incitation, bouton, mention.
class _FullHelp extends StatelessWidget {
  const _FullHelp({
    required this.step,
    required this.suspended,
    required this.onTap,
  });

  final EefHelpStep step;
  final bool suspended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Pays suspendu : un seul jeu de textes neutres, quelle que soit l'étape.
    // Le contexte (recherche vide, catalogue à venir…) voyage dans le message
    // prérempli, pas dans une promesse que la suspension rendrait fausse.
    final prefix = suspended ? 'eef_help_neutral' : 'eef_help_${step.key}';

    return KpbCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: KpbColors.whatsapp.withValues(alpha: 0.14),
                  borderRadius: KpbRadius.smBr,
                ),
                child: const Icon(
                  Icons.chat_rounded,
                  size: 20,
                  color: KpbColors.whatsapp,
                ),
              ),
              const SizedBox(width: KpbSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${prefix}_question'.tr,
                    style: KpbTextStyles.titleSm,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            '${prefix}_body'.tr,
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
          const SizedBox(height: KpbSpacing.md),
          _HelpButton(label: '${prefix}_cta'.tr, onTap: onTap),
          const SizedBox(height: KpbSpacing.sm),
          Text(
            'eef_help_fineprint'.tr,
            style: KpbTextStyles.caption.copyWith(color: context.kpb.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Le bouton de la carte : un `FilledButton` du thème, dont le libellé PASSE À
/// LA LIGNE.
///
/// ## Pourquoi pas `KpbButton`
///
/// `KpbButton` rend son libellé en `Text(overflow: ellipsis)` sans `maxLines` :
/// mesuré, le libellé ne passe pas à la ligne, il est COUPÉ par un « … ». Or le
/// libellé de cette carte est une phrase (« Démarrer l'étude de mon dossier sur
/// WhatsApp », 44 caractères) qui ne tient pas sur une ligne dès 360 pt de large
/// à l'échelle de texte 1,3 — le public de cette app. Un bouton dont le verbe
/// est coupé est un bouton qu'on n'ose pas toucher. `KpbButton` est partagé par
/// tout le dépôt : ce correctif est local, et le défaut est signalé à part.
class _HelpButton extends StatelessWidget {
  const _HelpButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: KpbSpacing.md,
            vertical: KpbSpacing.sm,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_rounded, size: 18),
            const SizedBox(width: KpbSpacing.sm),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }
}

/// Une ligne et un lien — pour les étapes où une carte pleine serait de trop.
class _CompactHelp extends StatelessWidget {
  const _CompactHelp({required this.step, required this.onTap});

  final EefHelpStep step;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = 'eef_help_compact_cta'.tr;
    // `Wrap` et non `Row` : à l'échelle de texte 1,3 d'un petit téléphone, la
    // question et le lien ne tiennent pas sur une ligne, et une `Row` coupait
    // ou débordait. Le lien passe sous la question.
    return Padding(
      padding: const EdgeInsets.only(top: KpbSpacing.xs),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: KpbSpacing.sm,
        children: [
          Text(
            'eef_help_${step.key}_question'.tr,
            style: KpbTextStyles.bodySm.copyWith(
              color: context.kpb.textSecondary,
            ),
          ),
          Semantics(
            button: true,
            label: label,
            child: InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                // 44 pt : la cible tactile minimale d'un lien d'une ligne.
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.chat_rounded,
                      size: 14,
                      color: KpbColors.blue,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        label,
                        style: KpbTextStyles.labelSm.copyWith(
                          color: KpbColors.blue,
                          decoration: TextDecoration.underline,
                          decorationColor: KpbColors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
