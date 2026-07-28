import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../app_tokens.dart';
import '../kpb_theme_ext.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbTextField — champ de formulaire labellisé (architecture §9.4)
// ─────────────────────────────────────────────────────────────────────────────
// Enveloppe TextFormField avec : libellé externe lisible, marqueur « optionnel »,
// validation inline du thème, chaînage clavier (textInputAction/focusNode) et
// sémantique. Fond/bordures/focus/erreurs viennent de l'inputDecorationTheme —
// aucune couleur locale.
class KpbTextField extends StatelessWidget {
  const KpbTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.prefixIcon,
    this.keyboardType,
    this.textInputAction,
    this.focusNode,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.obscureText = false,
    this.enabled = true,
    this.optional = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.suffix,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final IconData? prefixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool obscureText;
  final bool enabled;

  /// Affiche le champ comme facultatif : pas d'astérisque implicite, un
  /// marqueur discret « (optionnel) » géré par le caller via `label` sinon.
  final bool optional;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final c = context.kpb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                label,
                style: KpbTextStyles.titleSm.copyWith(color: c.textPrimary),
              ),
            ),
            if (optional) ...[
              const SizedBox(width: KpbSpacing.xs),
              Text(
                '·',
                style: KpbTextStyles.caption.copyWith(color: c.textMuted),
              ),
              const SizedBox(width: KpbSpacing.xs),
              Text(
                'field_optional'.tr,
                style: KpbTextStyles.caption.copyWith(color: c.textMuted),
              ),
            ],
          ],
        ),
        const SizedBox(height: KpbSpacing.xs + 2),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          obscureText: obscureText,
          enabled: enabled,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          textCapitalization: textCapitalization,
          autofillHints: autofillHints,
          style: KpbTextStyles.body.copyWith(color: c.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20) : null,
            suffixIcon: suffix,
            counterText: maxLength != null ? '' : null,
          ),
        ),
      ],
    );
  }
}
