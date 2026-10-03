import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/ui/kpb_components.dart';
import 'eef_interest_controller.dart';
import 'eef_profile_prefill.dart';

/// Les niveaux proposés. Les VALEURS sont des identifiants stables, jamais des
/// libellés traduits : elles partent en base et dans l'export commercial, et un
/// export dont la colonne « niveau » change de langue selon le téléphone de
/// l'étudiant n'est pas exploitable.
const _levelSlugs = kEefLevelSlugs;

String _levelLabel(String slug) => 'eef_level_$slug'.tr;

/// Ce que la feuille fait à la validation.
enum EefSheetMode {
  /// Première déclaration : `POST`, avec le consentement au rappel.
  declare,

  /// Modification d'une déclaration existante : `PATCH`, niveaux et domaines
  /// seulement. Le consentement n'est NI redemandé NI réécrit.
  edit,
}

/// Comment la feuille s'est refermée.
enum _SheetResult {
  /// Le serveur a confirmé l'enregistrement.
  confirmed,

  /// « Annuler » : rien n'a été envoyé.
  cancelled,

  /// « Me retirer de la liste » : la feuille se referme, puis l'écran porteur
  /// lance son flux de retrait.
  withdraw,
}

/// Ouvre la feuille de déclaration d'intérêt.
///
/// Rend `true` si le serveur a confirmé l'enregistrement.
///
/// ## Le retrait, depuis la feuille
///
/// Le texte de consentement promet « tu peux te retirer à tout moment, depuis cet
/// écran ». Quand une déclaration EXISTE (modification, ou nouvelle réponse d'une
/// vitrine déjà déclarée), la feuille propose donc « Me retirer de la liste ».
/// Elle ne fait rien elle-même : [onWithdraw] est le flux de retrait de l'écran
/// porteur — la confirmation « Te retirer de la liste ? », la méthode du
/// contrôleur, les messages `eef_withdraw_*` —, qu'on ne réécrit pas ici. Il est
/// lancé APRÈS la fermeture de la feuille : ses messages (retiré, ou échec avec
/// l'adresse de recours) se lisent alors sur l'écran porteur, au lieu d'être cachés
/// derrière elle. Sans [onWithdraw], pas de lien : un lien qu'aucun écran ne tient
/// serait muet.
Future<bool> showEefInterestSheet(
  BuildContext context, {
  required EefInterestController controller,
  EefSheetMode mode = EefSheetMode.declare,
  Future<void> Function()? onWithdraw,
}) async {
  // Une feuille repart d'un état propre : l'échec d'un retrait (ou d'un envoi
  // abandonné) ne doit pas s'afficher comme l'échec d'un envoi qu'on n'a pas
  // tenté. Voir `EefInterestController.clearFailure`.
  controller.clearFailure();
  final result = await showModalBottomSheet<_SheetResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _EefInterestSheet(
      controller: controller,
      mode: mode,
      canWithdraw: onWithdraw != null,
    ),
  );
  if (result == _SheetResult.withdraw) {
    // L'écran porteur a pu disparaître pendant la fermeture : on ne lui parle
    // plus.
    if (context.mounted) await onWithdraw?.call();
    return false;
  }
  return result == _SheetResult.confirmed;
}

/// Le formulaire de déclaration.
///
/// ## Pourquoi tous les champs sont optionnels sauf l'action
///
/// Parce que la vitrine mesure UN signal : « est-ce que ça t'intéresse ». Rendre
/// le niveau et la filière obligatoires aurait transformé ce signal en
/// formulaire à remplir, et on aurait mesuré la patience plutôt que l'intérêt.
/// Les champs sont là parce qu'ils qualifient le rappel commercial, pas parce
/// qu'ils conditionnent la réponse.
///
/// ## Pourquoi la feuille ne se referme pas sur un échec
///
/// C'est le cœur du sujet. Un `Navigator.pop()` optimiste suivi d'un toast
/// d'erreur laisse l'étudiant devant un écran inchangé, avec un message qui
/// disparaît en trois secondes — et la conviction d'avoir répondu. C'est
/// exactement le défaut que le masquage `documentUploadEnabled` documente :
/// « fourni ✓ » coché avant l'appel réseau, échec avalé, document jamais reçu.
/// Ici la feuille RESTE ouverte, l'erreur s'affiche À L'INTÉRIEUR et ne
/// s'efface pas, et le bouton redevient actionnable pour réessayer.
class _EefInterestSheet extends StatefulWidget {
  const _EefInterestSheet({
    required this.controller,
    required this.mode,
    required this.canWithdraw,
  });

  final EefInterestController controller;
  final EefSheetMode mode;

  /// L'écran porteur tient un flux de retrait : le lien peut exister.
  final bool canWithdraw;

  @override
  State<_EefInterestSheet> createState() => _EefInterestSheetState();
}

class _EefInterestSheetState extends State<_EefInterestSheet> {
  String? _currentLevel;
  String? _targetLevel;
  final Set<String> _fieldIds = <String>{};
  bool _wantsPremium = false;

  bool get _isEdit => widget.mode == EefSheetMode.edit;

  /// Une déclaration EXISTAIT-elle à l'ouverture de la feuille ? Figé dans
  /// [initState] : `controller.declared` devient vrai dès que le serveur confirme
  /// une PREMIÈRE déclaration — pendant que la feuille se referme (~200 ms) —, et
  /// un lien lu sur ce drapeau vivant apparaissait dans la feuille qui se ferme, en
  /// la faisant grandir. En première déclaration il n'y a rien à retirer : c'est
  /// l'écran porteur qui tient la promesse, une fois la feuille fermée.
  late final bool _hadDeclaration;

  @override
  void initState() {
    super.initState();
    _hadDeclaration = widget.controller.declared;
    // Une redéclaration part des réponses précédentes : c'est le cas d'usage
    // principal du bouton « modifier » (cocher l'intérêt Premium après avoir lu
    // le découpage).
    final existing = widget.controller.interest;
    _currentLevel = _knownLevel(existing.currentLevel);
    _targetLevel = _knownLevel(existing.targetLevel);
    _wantsPremium = existing.wantsPremium;
    _fieldIds.addAll(eefFieldIdsFromProfile(existing.fieldIds));

    // Première déclaration : on part de ce que le PROFIL sait déjà, plutôt que
    // de reposer à l'étudiant des questions qu'il a traitées à l'onboarding.
    // Jamais par-dessus une réponse existante, et jamais pour une valeur que la
    // table fermée ne reconnaît pas.
    if (!existing.declared && Get.isRegistered<AppController>()) {
      final profile = Get.find<AppController>().profile;
      _currentLevel ??= eefLevelSlugForProfileLevel(profile?.currentLevel);
      _targetLevel ??= eefLevelSlugForProfileLevel(profile?.targetLevel);
      if (_fieldIds.isEmpty) {
        _fieldIds.addAll(eefFieldIdsFromProfile(profile?.fieldIds));
      }
    }
  }

  /// Ne repropose une valeur que si elle fait partie des choix offerts.
  ///
  /// Une valeur venue du serveur qui ne serait plus dans [_levelSlugs] — après
  /// un renommage — ferait lever `DropdownButton` (« There should be exactly one
  /// item with [DropdownButton]'s value »). Le champ repart alors vide plutôt
  /// que de casser l'écran.
  static String? _knownLevel(String? raw) =>
      raw != null && _levelSlugs.contains(raw) ? raw : null;

  Future<void> _submit() async {
    // Les domaines partent dans l'ordre de la taxonomie, pas dans l'ordre des
    // taps : deux étudiants qui cochent les mêmes cases donnent le même
    // enregistrement.
    final fieldIds = [
      for (final id in kEefFieldIds)
        if (_fieldIds.contains(id)) id,
    ];
    final ok = _isEdit
        // Chaîne vide = « effacé » côté serveur : un niveau remis sur « je
        // préfère ne pas dire » doit réellement être retiré, pas laissé tel quel.
        ? await widget.controller.updateProfile(
            currentLevel: _currentLevel ?? '',
            targetLevel: _targetLevel ?? '',
            fieldIds: fieldIds,
          )
        : await widget.controller.submit(
            currentLevel: _currentLevel,
            targetLevel: _targetLevel,
            fieldIds: fieldIds,
            wantsPremium: _wantsPremium,
          );
    if (!mounted) return;
    // On ne referme QUE sur confirmation du serveur. Sur échec, la feuille reste
    // et affiche la raison.
    if (ok) Navigator.of(context).pop(_SheetResult.confirmed);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final busy = widget.controller.phase == EefInterestPhase.submitting;
        final failure = widget.controller.failure;

        return Padding(
          padding: EdgeInsets.only(
            left: KpbSpacing.pagePad,
            right: KpbSpacing.pagePad,
            top: KpbSpacing.lg,
            // Le clavier : sans cette marge, le bouton de confirmation passe
            // sous le clavier logiciel dès que le champ se déploie.
            bottom: KpbSpacing.lg + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'eef_profile_edit_title'.tr : 'eef_sheet_title'.tr,
                  style: KpbTextStyles.title,
                ),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  _isEdit ? 'eef_profile_edit_body'.tr : 'eef_sheet_body'.tr,
                  style: KpbTextStyles.bodySm
                      .copyWith(color: context.kpb.textMuted),
                ),
                const SizedBox(height: KpbSpacing.lg),

                _LevelField(
                  label: 'eef_field_current_level'.tr,
                  value: _currentLevel,
                  enabled: !busy,
                  onChanged: (value) => setState(() => _currentLevel = value),
                ),
                const SizedBox(height: KpbSpacing.md),
                _LevelField(
                  label: 'eef_field_target_level'.tr,
                  value: _targetLevel,
                  enabled: !busy,
                  onChanged: (value) => setState(() => _targetLevel = value),
                ),
                const SizedBox(height: KpbSpacing.md),

                // Les domaines : ce que la recherche du catalogue filtre. Plusieurs
                // choix, aucun obligatoire.
                Text(
                  'eef_field_domains'.tr,
                  style: KpbTextStyles.labelSm
                      .copyWith(color: context.kpb.textMuted),
                ),
                const SizedBox(height: KpbSpacing.xs),
                Wrap(
                  spacing: KpbSpacing.xs,
                  runSpacing: KpbSpacing.xs,
                  children: [
                    for (final id in kEefFieldIds)
                      FilterChip(
                        // Taille seule : une couleur dans `style:` écraserait
                        // le libellé par état du chipTheme (blanc sur la puce
                        // cochée) — `caption` y mettait textMuted, 1,09:1 sur
                        // actionPrimary.
                        label: Text(
                          eefFieldLabel(id),
                          style: const TextStyle(fontSize: 12),
                        ),
                        selected: _fieldIds.contains(id),
                        onSelected: busy
                            ? null
                            : (selected) => setState(() {
                                  if (selected) {
                                    _fieldIds.add(id);
                                  } else {
                                    _fieldIds.remove(id);
                                  }
                                }),
                      ),
                  ],
                ),
                const SizedBox(height: KpbSpacing.md),

                // Réservé à la première déclaration : l'intérêt Premium et le
                // consentement ne se modifient PAS par un `PATCH` — c'est tout
                // son contrat. Les afficher en modification laisserait croire
                // qu'on peut les changer ici.
                if (!_isEdit) ...[
                  // LA question du lot : y a-t-il une demande pour le payant.
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _wantsPremium,
                    onChanged: busy
                        ? null
                        : (value) => setState(() => _wantsPremium = value),
                    title: Text(
                      'eef_field_wants_premium'.tr,
                      style: KpbTextStyles.bodySm,
                    ),
                  ),

                  const SizedBox(height: KpbSpacing.sm),

                  // Le consentement, DIT avant le bouton qui le donne. Le
                  // serveur horodate la réception de cette action : c'est la
                  // preuve, et elle serait sans valeur si l'écran n'avait pas
                  // annoncé ce à quoi l'étudiant consent.
                  Text(
                    'eef_consent_notice'.tr,
                    style: KpbTextStyles.caption
                        .copyWith(color: context.kpb.textMuted),
                  ),
                ],

                // Le retrait, LÀ où une déclaration existe — et seulement là. En
                // première déclaration il n'y a rien à retirer avant « Valider » :
                // la promesse du consentement y est tenue par l'écran porteur, qui
                // montre « Me retirer de la liste » dès que le serveur a confirmé.
                // Sous le consentement qui le promet, au-dessus du bouton qui
                // valide. En `tertiary`, comme sur le hub : se retirer d'une liste
                // d'intérêt n'est pas supprimer un compte.
                if (widget.canWithdraw && _hadDeclaration) ...[
                  const SizedBox(height: KpbSpacing.sm),
                  KpbButton(
                    key: const ValueKey('eef-sheet-withdraw'),
                    label: 'eef_withdraw_cta'.tr,
                    variant: KpbButtonVariant.tertiary,
                    fullWidth: true,
                    onTap: busy
                        ? null
                        : () =>
                            Navigator.of(context).pop(_SheetResult.withdraw),
                  ),
                ],

                if (failure != null) ...[
                  const SizedBox(height: KpbSpacing.md),
                  _FailureNotice(failure: failure),
                ],

                const SizedBox(height: KpbSpacing.lg),
                KpbButton(
                  label: failure == null
                      ? 'eef_sheet_confirm'.tr
                      : 'eef_sheet_retry'.tr,
                  fullWidth: true,
                  loading: busy,
                  onTap: busy ? null : _submit,
                ),
                const SizedBox(height: KpbSpacing.sm),
                KpbButton(
                  label: 'eef_sheet_cancel'.tr,
                  variant: KpbButtonVariant.tertiary,
                  fullWidth: true,
                  onTap: busy
                      ? null
                      : () => Navigator.of(context).pop(_SheetResult.cancelled),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LevelField extends StatelessWidget {
  const _LevelField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: KpbInputDecoration.build(context, label: label),
      onChanged: enabled ? onChanged : null,
      items: [
        // « Je préfère ne pas dire » est une option EXPLICITE, pas une absence.
        // Sans elle, un étudiant qui a choisi un niveau par erreur ne peut plus
        // revenir à « non renseigné » — et un champ qu'on ne peut pas vider est
        // un champ obligatoire déguisé.
        DropdownMenuItem<String>(
          value: null,
          child: Text('eef_level_unspecified'.tr),
        ),
        for (final slug in _levelSlugs)
          DropdownMenuItem<String>(
            value: slug,
            child: Text(_levelLabel(slug)),
          ),
      ],
    );
  }
}

/// L'échec, à l'écran et durable.
///
/// Trois messages seulement, parce que l'étudiant n'a que trois gestes
/// possibles : vérifier sa connexion, se reconnecter, réessayer plus tard. Un
/// catalogue d'erreurs plus fin aurait produit des phrases que personne ne sait
/// traduire en action.
class _FailureNotice extends StatelessWidget {
  const _FailureNotice({required this.failure});

  final EefInterestFailure failure;

  String get _messageKey => switch (failure) {
        EefInterestFailure.network => 'eef_error_network',
        EefInterestFailure.unauthorized => 'eef_error_unauthorized',
        EefInterestFailure.server => 'eef_error_server',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(KpbSpacing.md),
      decoration: BoxDecoration(
        color: KpbColors.errorLight,
        borderRadius: KpbRadius.mdBr,
        border: Border.all(color: KpbColors.error),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: KpbColors.error,
          ),
          const SizedBox(width: KpbSpacing.sm),
          Expanded(
            child: Text(
              _messageKey.tr,
              style: KpbTextStyles.bodySm.copyWith(color: KpbColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
