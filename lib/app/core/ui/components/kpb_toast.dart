import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_tokens.dart';

// ─────────────────────────────────────────────────────────────────────────────
// KpbToast — retour d'action unifié (succès / info / erreur)
// ─────────────────────────────────────────────────────────────────────────────
// Un seul point d'entrée pour confirmer une action utilisateur, à la place des
// Get.snackbar ad hoc : icône + couleurs token + haptique. Le SnackBar hérite
// du snackBarTheme (navy, flottant, arrondi) ; seules les teintes sémantiques
// succès/erreur sont posées ici.
enum KpbToastKind { success, info, error }

class KpbToast {
  KpbToast._();

  static void success(BuildContext context, String message) =>
      show(context, message, kind: KpbToastKind.success);

  static void info(BuildContext context, String message) =>
      show(context, message, kind: KpbToastKind.info);

  static void error(BuildContext context, String message) =>
      show(context, message, kind: KpbToastKind.error);

  static void show(
    BuildContext context,
    String message, {
    KpbToastKind kind = KpbToastKind.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    // Haptique calée sur la matrice produit : succès = léger, erreur = fort
    // (une seule fois, jamais par champ).
    switch (kind) {
      case KpbToastKind.success:
        HapticFeedback.lightImpact();
      case KpbToastKind.error:
        HapticFeedback.heavyImpact();
      case KpbToastKind.info:
        break;
    }

    final (icon, iconColor, background) = switch (kind) {
      KpbToastKind.success => (
          Icons.check_circle_outline,
          KpbColors.successOnDark,
          KpbColors.brandNavy,
        ),
      KpbToastKind.info => (
          Icons.info_outline,
          KpbColors.actionOnDark,
          KpbColors.brandNavy,
        ),
      KpbToastKind.error => (
          Icons.error_outline,
          Colors.white,
          KpbColors.error,
        ),
    };

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          backgroundColor: background,
          content: Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: KpbSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: KpbTextStyles.bodyFamily,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
