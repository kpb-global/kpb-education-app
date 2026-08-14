// Méta-test du harnais : le paramètre `enableRemoteSync` de `pumpTestApp` est-il
// RÉELLEMENT honoré ?
//
// Ce fichier ne teste aucune fonctionnalité de l'app. Il teste l'outil de test,
// parce que quatre fois sur ce projet le mensonge venait de là. Le scénario qu'il
// rend impossible : quelqu'un ajoute (ou remet) `AppConfig.enableRemoteSyncOverride
// = false` après la prise en compte du paramètre, et tous les tests d'envoi
// passent au vert sans qu'un octet ne parte — en affichant « fourni ✓ ».
//
// L'observable est le compteur d'appels à `listParcoursStories()`, l'unique appel
// réseau de `fetchParcoursStories()`, placé juste après son portillon
// `if (!AppConfig.enableRemoteSync) return;`
// (lib/app/core/controllers/app_controller/parcours.dart:69). Portillon fermé →
// compteur à 0 ; ouvert → au moins 1. Deux états, aucun recouvrement.
//
// Pourquoi pas `syncRemoteData`, le chemin « évident » : il ne se termine jamais
// sous un client de test (des dizaines d'appels, des replis temporisés, une file
// d'attente). Mesuré : le test pendait sans jamais rendre la main, y compris avec
// `--timeout 30s`. Un observable qui pend n'est pas un observable — c'est un
// troisième outil menteur, et on n'en ajoute pas.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:karatou/app/core/config/app_config.dart';
import 'package:karatou/app/core/controllers/app_controller.dart';

import '../widget_test_helpers.dart';

void main() {
  tearDown(() {
    resetGetxSingleton();
    // `enableRemoteSyncOverride` est un état global de processus qu'aucun test du
    // dépôt ne restaure. On le rend ici, sinon un `true` contaminerait les
    // fichiers suivants de la même exécution.
    AppConfig.enableRemoteSyncOverride = false;
  });

  testWidgets('par défaut, le portillon reste fermé (compteur à 0)',
      (tester) async {
    final api = CountingApiClient();
    await pumpTestApp(tester,
        child: const SizedBox.shrink(), mockApiClient: api);

    expect(AppConfig.enableRemoteSync, isFalse);
    await Get.find<AppController>().fetchParcoursStories(force: true);

    expect(
      api.listParcoursStoriesCalls,
      0,
      reason: 'Le défaut doit rester local : sinon chaque pumpTestApp part '
          'chercher le réseau, et un test de rendu se met à dépendre du Wi-Fi.',
    );
  });

  testWidgets('enableRemoteSync: true ouvre réellement le chemin réseau',
      (tester) async {
    final api = CountingApiClient();
    await pumpTestApp(
      tester,
      child: const SizedBox.shrink(),
      mockApiClient: api,
      enableRemoteSync: true,
    );

    expect(
      AppConfig.enableRemoteSync,
      isTrue,
      reason:
          "Le paramètre est accepté mais écrasé. Vérifiez qu'il est appliqué "
          'APRÈS setupPlatformChannelMocks(), qui repose l\'override à false.',
    );

    await Get.find<AppController>().fetchParcoursStories(force: true);

    expect(
      api.listParcoursStoriesCalls,
      greaterThanOrEqualTo(1),
      reason:
          'Le portillon est resté fermé alors que le paramètre valait true : '
          "il est ignoré, et tout test qui s'appuie dessus pour prouver un envoi "
          'est un faux témoignage. C\'est exactement le mensonge que ce fichier '
          'existe pour rendre impossible.',
    );
  });

  testWidgets(
      'le paramètre est un booléen explicite, pas un retour au '
      'dart-define', (tester) async {
    // `null` retomberait sur KPB_ENABLE_REMOTE_SYNC : false en CI (le
    // --dart-define de flutter-ci.yml:89), true en local. Le test dirait alors
    // deux choses selon la machine — le pire des deux mondes pour un harnais.
    await pumpTestApp(tester, child: const SizedBox.shrink());
    expect(AppConfig.enableRemoteSync, isFalse);

    await pumpTestApp(
      tester,
      child: const SizedBox.shrink(),
      enableRemoteSync: true,
    );
    expect(AppConfig.enableRemoteSync, isTrue);

    // Et le retour en arrière fonctionne : un test qui passe `true` ne
    // contamine pas le suivant dans le même fichier.
    await pumpTestApp(tester, child: const SizedBox.shrink());
    expect(AppConfig.enableRemoteSync, isFalse);
  });
}
