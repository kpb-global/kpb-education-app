import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_controller.dart';
import '../../navigation/app_boot_screen.dart';
import '../app_tokens.dart';

/// Le mur invité, en UN seul endroit.
///
/// ## Pourquoi ce composant existe
///
/// Il y avait deux murs invité dans le dépôt, écrits séparément
/// (`case_create_screen.dart` et `cases_screen.dart`), et zéro sur les autres
/// surfaces qui en avaient besoin. Deux copies, c'est déjà une de trop : celle
/// qu'on améliore et celle qu'on oublie. Surtout, ni l'une ni l'autre ne faisait
/// la seule chose qui compte commercialement — **convertir** : le bouton
/// renvoyait vers l'écran de démarrage sans dire au contrôleur que l'invité
/// venait d'accepter de créer un compte, donc sans quitter le mode invité et
/// sans rien mesurer.
///
/// Ce composant appelle `leaveGuestForSignup(source: …)`, ce qui fait trois
/// choses d'un coup : sortir du mode invité, remettre l'onboarding à faire, et
/// journaliser l'événement `guest_to_signup` avec l'écran d'origine. Le `source`
/// est obligatoire précisément pour qu'on sache LAQUELLE des surfaces convertit.
class KpbGuestGate extends StatelessWidget {
  const KpbGuestGate({
    super.key,
    required this.source,
    this.titleKey = 'guest_case_gate_title',
    this.bodyKey = 'guest_case_gate_body',
    this.ctaKey = 'guest_case_gate_cta',
    this.icon = Icons.lock_person_outlined,
    this.onConverted,
  });

  /// D'où part la conversion — arrive tel quel dans l'entonnoir analytique.
  /// Valeurs en usage : `scholarships_gate`, `case_tunnel_gate`.
  final String source;

  final String titleKey;
  final String bodyKey;
  final String ctaKey;
  final IconData icon;

  /// Appelé APRÈS `leaveGuestForSignup` et AVANT la navigation, pour que l'hôte
  /// referme ce qui doit l'être — une feuille modale, par exemple.
  final VoidCallback? onConverted;

  void _convert() {
    // L'ordre compte, et c'est la partie qu'on oublie : sans
    // `leaveGuestForSignup`, le routeur de démarrage voit `isGuestMode == true`
    // et renvoie l'utilisateur DIRECTEMENT dans la coquille invité — la boucle
    // exacte que ce mur est censé rompre. La méthode remet aussi l'onboarding à
    // faire et journalise la conversion avec l'écran d'origine.
    Get.find<AppController>().leaveGuestForSignup(source: source);
    onConverted?.call();
    Get.offAll<void>(() => const AppBootScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KpbSpacing.pagePad,
        vertical: KpbSpacing.lg,
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 64, color: KpbColors.actionPrimary),
              const SizedBox(height: KpbSpacing.lg),
              Text(
                titleKey.tr,
                style: KpbTextStyles.headline,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KpbSpacing.sm),
              Text(
                bodyKey.tr,
                style: KpbTextStyles.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: KpbSpacing.xl),
              FilledButton.icon(
                icon: const Icon(Icons.login_rounded),
                label: Text(ctaKey.tr),
                onPressed: _convert,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
