import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/kpb_components.dart';
import '../../core/utils/whatsapp_utils.dart';
import 'eef_help_bubble.dart';
import 'eef_help_card.dart';

/// Par quelle porte la feuille d'information des écoles privées a été ouverte.
/// La valeur de [key] est la propriété `entry` de `eef_private_info_opened` : un
/// identifiant fermé, écrit ici et nulle part ailleurs (jamais une chaîne libre).
enum EefPrivateInfoEntry {
  /// L'option « écoles privées » du menu de la bulle.
  bubble('bubble'),

  /// La ligne de l'état « aucun résultat » du catalogue.
  catalogEmpty('catalog_empty');

  const EefPrivateInfoEntry(this.key);

  final String key;
}

/// Le repli juridique de la phrase sur les frais (« varient beaucoup d'une école
/// à l'autre ») remplace la phrase par défaut (« en général plus élevés que dans
/// le public ») quand ce booléen est vrai.
///
/// Fermé : c'est une décision du propriétaire et du juridique, pas un réglage de
/// l'app. Les deux textes existent en français et en anglais, un test verrouille
/// leur présence ET le fait que le repli n'est affiché nulle part tant que ce
/// booléen reste faux. Basculer ce booléen est le SEUL geste qui change le texte.
const bool _useFeesFallback = false;

/// Les écoles privées sont-elles proposables ICI, MAINTENANT ?
///
/// Deux conditions, lues au même endroit pour que la ligne du catalogue, l'option
/// de la bulle et la feuille ne puissent pas diverger :
///
/// - le serveur a ouvert `features.eefPrivateSchools` (fermé par défaut : clé
///   absente, ancien backend ou repli de compilation = fermé) ;
/// - le compte n'a pas un pays dont la procédure est suspendue
///   ([EefHelp.isSuspended], le point unique) : un compte suspendu ne lit JAMAIS
///   « école privée » — ni ligne, ni option, ni feuille.
bool eefPrivateSchoolsAvailable() =>
    RemoteFeatureFlags.instance.eefPrivateSchoolsEnabled &&
    !EefHelp.isSuspended();

/// La pastille « Service KPB » : ce qui suit est une offre de KPB, pas un conseil
/// neutre ni une donnée officielle.
class EefKpbServiceChip extends StatelessWidget {
  const EefKpbServiceChip({super.key});

  @override
  Widget build(BuildContext context) =>
      KpbBadgeLight(label: 'eef_help_private_chip'.tr);
}

/// Ouvre la feuille d'information « Les écoles privées : ce qu'il faut savoir ».
///
/// ## Ce que la fonction garantit
///
/// - **Jamais ouverte seule** : seuls un tap sur le lien du catalogue ou sur
///   l'option de la bulle l'appellent.
/// - **Rien si ce n'est pas proposable** ([eefPrivateSchoolsAvailable]) : un
///   appel tardif (la suspension ou la fermeture du serveur arrive pendant que
///   l'étudiant lit) ne montre ni n'envoie rien.
/// - **WhatsApp SEUL** : « En parler à un conseiller » ferme la feuille PUIS passe
///   par [kpbWhatsAppPrefill] et [openWhatsAppOrToast], le point d'entrée commun.
///   Aucun lien vers un autre écran : la feuille informe, elle n'ouvre pas de
///   dossier et n'envoie aucune coordonnée.
/// - **« Pas maintenant » ne mesure et n'ouvre rien.**
///
/// ## Mesure
///
/// `eef_private_info_opened` (`entry`) à l'ouverture — ce n'est pas un envoi ;
/// `eef_help_cta_tapped` (`help_step` = `private_sheet`, `variant` = `sheet`)
/// UNIQUEMENT pour ce qui part vers WhatsApp, avec les trois propriétés de la
/// carte d'aide, AVANT l'ouverture ; `whatsapp_handoff` (`source` =
/// `eef_help_private_sheet`) dit ensuite si elle a réussi.
Future<void> showEefPrivateSchoolsSheet(
  BuildContext context, {
  required EefBubbleSurface surface,
  required EefPrivateInfoEntry entry,
}) async {
  if (!eefPrivateSchoolsAvailable()) return;
  EefHelp.analytics.privateInfoOpened(entry: entry.key);

  TransitionRoute<Object?>? route;
  final wantsAdvisor = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // Un iPad ne tire pas une feuille de 768 dp de large.
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (sheetContext) {
      route ??= ModalRoute.of(sheetContext);
      return _PrivateSchoolsSheet(surface: surface);
    },
  );
  if (wantsAdvisor != true) return;

  // `showModalBottomSheet` rend la main dès le DÉBUT de la fermeture : on attend
  // qu'elle soit finie. Le toast d'un WhatsApp absent ne doit pas naître sous une
  // feuille encore à l'écran, ni WhatsApp s'ouvrir devant elle.
  await route?.completed;

  // Relu APRÈS la fermeture : la suspension ou la fermeture du serveur a pu
  // arriver pendant la lecture. Un compte devenu suspendu n'envoie pas ce message.
  if (!eefPrivateSchoolsAvailable()) return;

  // Part AVANT l'ouverture de WhatsApp : `whatsapp_handoff` dit ensuite si elle a
  // réussi.
  EefHelp.analytics.tapped(
    step: 'private_sheet',
    surface: surface.key,
    variant: 'sheet',
  );
  unawaited(openWhatsAppOrToast(
    // Le point d'entrée commun : on n'ouvre pas un second chemin vers le
    // conseiller.
    prefill: kpbWhatsAppPrefill(custom: _messageFor(surface)),
    source: 'eef_help_private_sheet',
    contextType: 'eef_help',
  ));
}

/// Le message exact : il nomme l'ÉCRAN et rien d'autre (ni nom, ni pays, ni
/// budget, ni champ à compléter).
String _messageFor(EefBubbleSurface surface) => EefBubbleMessages.messageFor(
      EefBubbleOption.private,
      surface,
      suspended: false,
    );

class _PrivateSchoolsSheet extends StatefulWidget {
  const _PrivateSchoolsSheet({required this.surface});

  final EefBubbleSurface surface;

  @override
  State<_PrivateSchoolsSheet> createState() => _PrivateSchoolsSheetState();
}

class _PrivateSchoolsSheetState extends State<_PrivateSchoolsSheet> {
  /// Un seul choix par feuille : un second tap, avant que la fermeture ne soit
  /// finie, dépilerait l'écran qui est dessous.
  bool _picked = false;

  void _close({required bool wantsAdvisor}) {
    if (_picked) return;
    _picked = true;
    Navigator.of(context).pop(wantsAdvisor);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;

    // Point 2 : la phrase sur les frais, ou son repli juridique.
    final fees = _useFeesFallback
        ? 'eef_help_private_point_fees_fallback'.tr
        : 'eef_help_private_point_fees'.tr;
    // Point 4 : ce que KPB est — une seule phrase, aucune autre mention.
    final status = 'eef_help_private_point_status'.tr;
    final points = <String>[
      'eef_help_private_point_terms'.tr,
      fees,
      'eef_help_private_point_steps'.tr,
      status,
    ];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        key: const ValueKey('eef-private-sheet'),
        padding: const EdgeInsets.fromLTRB(
          KpbSpacing.pagePad,
          0,
          KpbSpacing.pagePad,
          KpbSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Align(
              alignment: AlignmentDirectional.centerStart,
              child: EefKpbServiceChip(),
            ),
            const SizedBox(height: KpbSpacing.sm),
            Semantics(
              header: true,
              child: Text(
                'eef_help_private_title'.tr,
                style: KpbTextStyles.title.copyWith(color: c.textPrimary),
              ),
            ),
            const SizedBox(height: KpbSpacing.md),
            for (final point in points) ...[
              _Point(text: point),
              const SizedBox(height: KpbSpacing.sm),
            ],
            const SizedBox(height: KpbSpacing.xs),
            Text(
              'eef_help_fineprint'.tr,
              style: KpbTextStyles.caption.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: KpbSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('eef-private-sheet-cta'),
                onPressed: () => _close(wantsAdvisor: true),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: KpbSpacing.md,
                    vertical: KpbSpacing.sm,
                  ),
                ),
                // Le libellé PASSE À LA LIGNE (jamais coupé par un « … ») à
                // l'échelle de texte 1,3 d'un petit téléphone.
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.chat_rounded, size: 18),
                    const SizedBox(width: KpbSpacing.sm),
                    Flexible(
                      child: Text(
                        'eef_help_private_cta'.tr,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: KpbSpacing.sm),
            // Le message exact qui partira : lu AVANT le tap, par les yeux comme
            // par un lecteur d'écran.
            Text(
              'eef_help_private_message_label'.tr,
              style: KpbTextStyles.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: KpbSpacing.xs),
            Text(
              _messageFor(widget.surface),
              style: KpbTextStyles.bodySm.copyWith(color: c.textSecondary),
            ),
            const SizedBox(height: KpbSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                key: const ValueKey('eef-private-sheet-dismiss'),
                onPressed: () => _close(wantsAdvisor: false),
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  'eef_help_private_dismiss'.tr,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Un point de la feuille : une puce et une phrase qui passe à la ligne.
class _Point extends StatelessWidget {
  const _Point({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Icon(Icons.circle, size: 6, color: c.textSecondary),
        ),
        const SizedBox(width: KpbSpacing.sm + 2),
        Expanded(
          child: Text(
            text,
            style: KpbTextStyles.bodySm.copyWith(color: c.textPrimary),
          ),
        ),
      ],
    );
  }
}

/// La ligne secondaire de l'état « aucun résultat » du catalogue : une pastille
/// « Service KPB », une phrase et un lien qui ouvre la feuille d'information.
///
/// ## Ce qu'elle est, et n'est pas
///
/// Une LIGNE, pas une seconde carte : l'état « aucun résultat » porte déjà la
/// carte d'aide (`EefHelpCard`, un bouton plein vers WhatsApp). Elle n'a aucun
/// bouton WhatsApp — l'étudiant lit d'abord, choisit ensuite — et ne s'affiche que
/// là : jamais dans « rien n'est publié », une liste non vide, le hub, ni près de
/// la mention des données.
///
/// ## Quand elle existe
///
/// [eefPrivateSchoolsAvailable] : l'interrupteur serveur ouvert ET un compte non
/// suspendu. Elle se reconstruit à l'arrivée des drapeaux (la liste des pays
/// suspendus vit dans `/config/app`) ; absente, elle ne laisse aucune marge.
///
/// ## Mesure
///
/// `eef_help_card_shown` (`help_step` = `private_note`, `surface` = `catalog`,
/// `variant` = `note`) UNE fois par visite de l'écran — la même mémoire que les
/// autres emplacements — pour savoir combien d'étudiants la voient ;
/// `eef_private_info_opened` (`entry` = `catalog_empty`) au tap sur le lien.
class EefPrivateSchoolsNote extends StatefulWidget {
  const EefPrivateSchoolsNote({super.key});

  @override
  State<EefPrivateSchoolsNote> createState() => _EefPrivateSchoolsNoteState();
}

class _EefPrivateSchoolsNoteState extends State<EefPrivateSchoolsNote> {
  bool _shownLogged = false;

  /// Vrai de l'ouverture de la feuille jusqu'à sa fermeture (et au départ vers
  /// WhatsApp) : un second tap est ignoré. Posé de façon SYNCHRONE — deux
  /// activations sans cadre entre elles tombent toutes deux sur le lien encore là.
  bool _sheetOpen = false;

  void _logShownOnce() {
    if (_shownLogged) return;
    _shownLogged = true;
    if (eefHelpAlreadyCountedThisVisit(context, 'private_note')) return;
    // Après le cadre : une mesure n'a pas à tourner pendant `build`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      EefHelp.analytics.shown(
        step: 'private_note',
        surface: EefBubbleSurface.catalog.key,
        variant: 'note',
      );
    });
  }

  Future<void> _open() async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    try {
      await showEefPrivateSchoolsSheet(
        context,
        surface: EefBubbleSurface.catalog,
        entry: EefPrivateInfoEntry.catalogEmpty,
      );
    } finally {
      _sheetOpen = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        if (!eefPrivateSchoolsAvailable()) return const SizedBox.shrink();
        _logShownOnce();
        final c = context.kpb;
        final link = 'eef_help_private_note_link'.tr;
        return Padding(
          key: const ValueKey('eef-private-note'),
          padding: const EdgeInsets.only(bottom: KpbSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // `Wrap` et non `Row` : à l'échelle de texte 1,3 d'un petit
              // téléphone, la pastille et la phrase ne tiennent pas sur une
              // ligne.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: KpbSpacing.sm,
                runSpacing: KpbSpacing.xs,
                children: [
                  const EefKpbServiceChip(),
                  Text(
                    'eef_help_private_note_text'.tr,
                    style: KpbTextStyles.bodySm.copyWith(
                      color: c.textSecondary,
                    ),
                  ),
                ],
              ),
              Semantics(
                key: const ValueKey('eef-private-note-link'),
                // Un nœud à lui : sans `container`, le lien se fondrait dans le
                // nœud voisin (pastille et phrase) et ne serait plus un bouton.
                container: true,
                button: true,
                label: link,
                onTap: _open,
                excludeSemantics: true,
                child: InkWell(
                  onTap: _open,
                  child: ConstrainedBox(
                    // 48 dp : la même cible tactile que les commandes de la feuille.
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        link,
                        style: KpbTextStyles.labelSm.copyWith(
                          color: KpbColors.blue,
                          decoration: TextDecoration.underline,
                          decorationColor: KpbColors.blue,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
