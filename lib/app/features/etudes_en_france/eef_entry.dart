import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/controllers/app_controller.dart';
import '../../core/models/app_models.dart';
import '../../core/services/remote_feature_flags.dart';
import '../../core/ui/components/coming_soon_screen.dart';
import 'eef_home_screen.dart';
import 'eef_students_only_screen.dart';
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
/// L'espace réel PRIME sur la vitrine. Il s'ouvre par `eefSpace`, la clé que le
/// serveur pose pour la seule build 54 : elle ne retire pas la vitrine des
/// builds plus anciennes, donc le serveur PEUT servir `eefSpace` et `eefTeaser`
/// ensemble, et c'est ici que l'ordre se décide. L'ancien commutateur `eef`
/// ouvre l'espace aussi. Il vaut mieux montrer l'espace ouvert qu'un « bientôt »
/// devant un espace vivant.
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
    if (!flags.eefSpaceEnabled && !flags.eefTeaserEnabled) return false;

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
    return !isNonStudentAccount;
  }

  /// Le compte courant est-il un compte RÉSOLU qui n'est pas étudiant (parent,
  /// partenaire) ? L'invité n'a pas de profil et n'en fait pas partie : la
  /// vitrine l'accueille exprès, avec un bouton « créer mon compte ».
  ///
  /// Public pour que la bulle d'aide ([EefHelpBubble]) lise la MÊME règle : la
  /// recopier ailleurs, c'est la voir diverger.
  static bool get isNonStudentAccount {
    final profile = Get.isRegistered<AppController>()
        ? Get.find<AppController>().profile
        : null;
    return profile != null && profile.accountType != AccountType.student;
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
        final open = flags.eefSpaceEnabled || flags.eefTeaserEnabled;

        // Un parent arrivé par un lien partagé : `isVisible` ne masque que les
        // ENTRÉES, la route, elle, répond à tout le monde. Sans ce cas, il verrait
        // le hub, taperait, et recevrait un 403 traduit en « reconnecte-toi ».
        if (open && isNonStudentAccount) return const EefStudentsOnlyScreen();

        if (flags.eefSpaceEnabled) return EefHomeScreen(source: source);
        if (flags.eefTeaserEnabled) return EefTeaserScreen(source: source);
        return const ComingSoonScreen();
      },
    );
  }
}
