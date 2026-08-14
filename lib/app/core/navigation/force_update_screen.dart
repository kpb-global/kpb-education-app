import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/whatsapp_utils.dart';

/// Hard gate shown when the installed build is older than the backend's
/// minimum supported version. Non-dismissable by design: back navigation is
/// blocked and the only way forward is the store update.
///
/// ## Pourquoi cet écran a DEUX boutons, et pas un
///
/// C'est un `PopScope(canPop: false)`. Rien ne le referme : ni le geste retour,
/// ni un bouton d'annulation. Or son unique action était grisée quand
/// `storeUrl` est vide — et l'URL de store vient du serveur, donc elle peut être
/// vide par oubli de configuration, par erreur de déploiement, ou simplement
/// parce que la plateforme n'est pas encore renseignée.
///
/// Dans cet état, l'app était **définitivement inutilisable** : un écran qu'on ne
/// peut pas quitter, avec zéro action possible. Et ce n'est pas un cas
/// théorique : cet écran est le SEUL levier à distance pendant une fenêtre
/// TestFlight, il ne peut voyager que dans une build, et s'en servir avant de
/// l'avoir réparé transformait la build en brique chez chaque testeur.
///
/// La règle qui en sort, valable au-delà de cet écran : **on ne laisse jamais un
/// écran non refermable avec une seule action, et jamais avec une action qui
/// peut être désactivée.** Le second chemin — joindre un conseiller sur WhatsApp
/// — est toujours actif, parce qu'il ne dépend d'aucune configuration.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.storeUrl});

  /// Platform store page for the app; empty when not configured.
  final String storeUrl;

  bool get _hasStoreUrl => storeUrl.trim().isNotEmpty;

  /// La sortie de secours. Passe par le point d'étranglement WhatsApp du dépôt,
  /// donc l'échec éventuel est journalisé dans l'entonnoir et l'utilisateur voit
  /// un message — pas un bouton qui ne fait rien.
  void _contactAdvisor() {
    openWhatsAppOrToast(
      prefill: kpbWhatsAppPrefill(custom: 'force_update_prefill'.tr),
      source: 'force_update',
      contextType: 'blocked_build',
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.system_update, size: 72, color: primary),
                  const SizedBox(height: 24),
                  Text(
                    'force_update_title'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'force_update_body'.tr,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 32),
                  // Le chemin principal quand il est configuré. Masqué — et non
                  // grisé — quand il ne l'est pas : un bouton désactivé sur un
                  // écran sans sortie est une impasse déguisée en interface.
                  if (_hasStoreUrl)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => launchUrl(
                          Uri.parse(storeUrl.trim()),
                          mode: LaunchMode.externalApplication,
                        ),
                        icon: const Icon(Icons.open_in_new),
                        label: Text('force_update_cta'.tr),
                      ),
                    ),
                  if (_hasStoreUrl) const SizedBox(height: 12),
                  // TOUJOURS actif, et c'est tout l'objet du correctif. Ne dépend
                  // d'aucune configuration serveur : le numéro du conseiller est
                  // un `--dart-define` embarqué dans la build.
                  SizedBox(
                    width: double.infinity,
                    child: _hasStoreUrl
                        ? OutlinedButton.icon(
                            onPressed: _contactAdvisor,
                            icon: const Icon(Icons.chat_outlined),
                            label: Text('force_update_contact_cta'.tr),
                          )
                        : FilledButton.icon(
                            onPressed: _contactAdvisor,
                            icon: const Icon(Icons.chat_outlined),
                            label: Text('force_update_contact_cta'.tr),
                          ),
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
