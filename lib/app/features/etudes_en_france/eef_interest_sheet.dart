import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/ui/kpb_components.dart';
import 'eef_interest_controller.dart';

/// Les niveaux proposés. Les VALEURS sont des identifiants stables, jamais des
/// libellés traduits : elles partent en base et dans l'export commercial, et un
/// export dont la colonne « niveau » change de langue selon le téléphone de
/// l'étudiant n'est pas exploitable.
const _levelSlugs = <String>[
  'terminale',
  'bac',
  'licence',
  'master',
  'doctorat',
  'autre',
];

String _levelLabel(String slug) => 'eef_level_$slug'.tr;

/// Ouvre la feuille de déclaration d'intérêt.
///
/// Rend `true` si le serveur a confirmé l'enregistrement.
Future<bool> showEefInterestSheet(
  BuildContext context, {
  required EefInterestController controller,
}) async {
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _EefInterestSheet(controller: controller),
  );
  return confirmed ?? false;
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
  const _EefInterestSheet({required this.controller});

  final EefInterestController controller;

  @override
  State<_EefInterestSheet> createState() => _EefInterestSheetState();
}

class _EefInterestSheetState extends State<_EefInterestSheet> {
  String? _currentLevel;
  String? _targetLevel;
  bool _wantsPremium = false;

  @override
  void initState() {
    super.initState();
    // Une redéclaration part des réponses précédentes : c'est le cas d'usage
    // principal du bouton « modifier » (cocher l'intérêt Premium après avoir lu
    // le découpage).
    final existing = widget.controller.interest;
    _currentLevel = _knownLevel(existing.currentLevel);
    _targetLevel = _knownLevel(existing.targetLevel);
    _wantsPremium = existing.wantsPremium;
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
    final ok = await widget.controller.submit(
      currentLevel: _currentLevel,
      targetLevel: _targetLevel,
      wantsPremium: _wantsPremium,
    );
    if (!mounted) return;
    // On ne referme QUE sur confirmation du serveur. Sur échec, la feuille reste
    // et affiche la raison.
    if (ok) Navigator.of(context).pop(true);
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
                Text('eef_sheet_title'.tr, style: KpbTextStyles.title),
                const SizedBox(height: KpbSpacing.xs),
                Text(
                  'eef_sheet_body'.tr,
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
                  onTap: busy ? null : () => Navigator.of(context).pop(false),
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
