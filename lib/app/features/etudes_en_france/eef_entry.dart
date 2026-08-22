import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/components/coming_soon_screen.dart';
import 'eef_home_screen.dart';
import 'eef_teaser_screen.dart';

/// LE point d'entrée unique de l'espace « Études en France ».
///
/// ## Pourquoi il existe
///
/// Parce que l'arbitrage « vitrine ou espace réel ou rien » doit être écrit UNE
/// fois. Il y a quatre portes vers ce module (accueil, tiroir, boîte à outils,
/// lien profond), et recopier la condition à chaque porte, c'est garantir
/// qu'une porte gardera l'ancienne règle le jour de la bascule. Le dépôt a déjà
/// nommé ce défaut : `student_tools_screen.dart` explique que garder la garde
/// sur le seul tiroir rejouait à l'identique le défaut PARC-05 — dix-huit points
/// d'entrée, un seul gardé.
///
/// ## L'ordre des cas
///
/// L'espace réel PRIME sur la vitrine. Le serveur garantit déjà qu'ils ne sont
/// jamais servis tous les deux (`eef` retire `eefTeaser`), mais l'ordre est
/// écrit ici aussi : un repli de compilation ou un backend plus ancien pourrait
/// rendre les deux vrais, et il vaut mieux montrer l'espace ouvert qu'un
/// « bientôt » devant un espace vivant.
///
/// ## Le troisième cas
///
/// Les deux drapeaux à faux ne mènent PAS à un écran vide : un lien profond
/// `kpb://etudes-en-france` reçu par un téléphone dont le serveur n'a pas encore
/// ouvert le module tombe sur [ComingSoonScreen], qui existe précisément pour
/// que ce cas n'échoue pas silencieusement.
class EefEntry extends StatelessWidget {
  const EefEntry({super.key, this.source = 'direct'});

  /// Par quelle porte on est arrivé — arrive tel quel dans l'entonnoir.
  final String source;

  /// Vrai quand une entrée de navigation vers ce module doit être VISIBLE.
  ///
  /// Les points d'entrée appellent ceci ; la route, elle, reste toujours
  /// joignable et retombe sur [ComingSoonScreen]. C'est la différence entre
  /// « ne pas proposer » et « ne pas répondre » : masquer une entrée est un
  /// choix éditorial, casser un lien profond est un cul-de-sac.
  static bool get isVisible {
    final flags = RemoteFeatureFlags.instance;
    if (!flags.eefEnabled && !flags.eefTeaserEnabled) return false;

    // ── Comptes étudiants SEULEMENT ──────────────────────────────────────
    //
    // `StudentAuthGuard` authentifie aussi les comptes parent et partenaire —
    // son propre commentaire le dit — et la déclaration d'intérêt écrit les
    // coordonnées du profil appelant. Un parent qui tape « ça m'intéresse »
    // ferait donc entrer SES nom, e-mail et téléphone dans la liste d'appel
    // des étudiants, et le conseiller rappellerait la mauvaise personne.
    //
    // Le refus vit AUSSI côté serveur (`etudes-en-france.controller.ts`), et
    // c'est lui qui protège la donnée. Ceci est l'autre moitié : sans elle, un
    // parent verrait le bouton, taperait, et recevrait un 403 traduit en
    // « reconnecte-toi » — un message faux qui l'enverrait se déconnecter.
    //
    // Le compte non résolu (`profile == null`) passe : c'est l'invité, que la
    // vitrine accueille exprès avec un bouton « créer mon compte ».
    final profile = Get.isRegistered<AppController>()
        ? Get.find<AppController>().profile
        : null;
    if (profile != null && profile.accountType != AccountType.student) {
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    // Reconstruit quand les drapeaux serveur arrivent : au démarrage, `refresh`
    // est lancé sans attente, donc le premier cadre peut se peindre sur les
    // replis de compilation. Sans cette écoute, un utilisateur qui ouvre l'app
    // et navigue tout de suite resterait sur « bientôt » jusqu'au prochain
    // démarrage à froid.
    return ValueListenableBuilder<int>(
      valueListenable: RemoteFeatureFlags.instance.flagsVersion,
      builder: (context, _, __) {
        final flags = RemoteFeatureFlags.instance;
        if (flags.eefEnabled) return const EefHomeScreen();
        if (flags.eefTeaserEnabled) return EefTeaserScreen(source: source);
        return const ComingSoonScreen();
      },
    );
  }
}
