// Cliquet LIV-T15 : toute variable lue par `/config/app` doit être RELAYÉE
// dans `docker-compose.yml` et DOCUMENTÉE dans `.env.example`.
//
// ## Le défaut que ce fichier existe pour interdire
//
// `docker-compose.yml` n'a aucun `env_file`. Le `.env` du VPS ne sert qu'à
// l'INTERPOLATION du fichier compose : une variable doit être listée
// explicitement dans le bloc `environment:` du service pour entrer dans le
// conteneur. Rien ne le rappelle, et rien ne le vérifiait.
//
// Mesuré : les cinq variables `KPB_EEF_*` de la Phase 0 « Études en France »
// ont été posées dans `.env.example`, dans `docs/release-ledger.md` et dans
// l'étape d'activation de `docs/cutover-build49.md` — et jamais dans
// `docker-compose.yml`. L'étape d'activation ne pouvait donc pas fonctionner :
// l'opérateur aurait posé les variables, relancé le service, lu
// `eefTeaser: false`, et le runbook l'aurait envoyé chercher une faute de
// frappe dans un fichier qui n'en avait pas. Les onze variables antérieures,
// elles, étaient toutes relayées : le motif était respecté par tous les auteurs
// précédents, et rien ne signalait la rupture.
//
// C'est le genre de défaut qu'un test unitaire ne peut pas voir : le contrôleur
// lit `process.env` correctement, et le prouver en passant l'environnement à la
// main prouve le code, pas le déploiement.
//
// ## Ce que ce cliquet ne prouve pas
//
// Que la valeur posée en production est la bonne. Il prouve que le chemin
// existe. La valeur se vérifie par `curl /config/app` après bascule, ce que
// `scripts/delivery-gate.sh` fait.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `process.env.KPB_QUELQUE_CHOSE` dans la source du contrôleur.
final _envRead = RegExp(r'process\.env\.(KPB_[A-Z0-9_]+)');

/// `      - KPB_QUELQUE_CHOSE=...` dans le bloc environment d'un service.
final _composeRelay = RegExp(r'^\s*-\s+(KPB_[A-Z0-9_]+)=', multiLine: true);

/// `KPB_QUELQUE_CHOSE=` en début de ligne dans `.env.example`, commenté ou non.
final _envExampleDecl = RegExp(r'^\s*#?\s*(KPB_[A-Z0-9_]+)=', multiLine: true);

Set<String> _read(RegExp pattern, String path) {
  final text = File(path).readAsStringSync();
  return pattern.allMatches(text).map((m) => m.group(1)!).toSet();
}

void main() {
  const controllerPath = 'backend/src/modules/config/app-config.controller.ts';

  final read = _read(_envRead, controllerPath);
  final relayed = _read(_composeRelay, 'docker-compose.yml');
  final documented = _read(_envExampleDecl, '.env.example');

  test('l\'extraction lit encore les sources — garde morte, sinon', () {
    // Si le contrôleur est renommé ou l'expression cassée, les trois ensembles
    // deviennent vides et tous les tests ci-dessous passent en ne prouvant
    // rien. C'est le mode d'échec habituel de ce genre de cliquet.
    expect(
      read.length,
      greaterThan(10),
      reason: 'Aucune variable extraite de $controllerPath : garde morte.',
    );
    expect(relayed.length, greaterThan(30),
        reason: 'Aucune variable extraite de docker-compose.yml.');
    expect(documented, isNotEmpty,
        reason: 'Aucune variable extraite de .env.example.');
  });

  test('chaque variable lue par /config/app entre dans le conteneur', () {
    final missing = read.difference(relayed).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Ces variables sont lues par le contrôleur mais ABSENTES du bloc '
          'environment: de docker-compose.yml. Le .env ne sert qu\'à '
          'l\'interpolation — une variable non relayée n\'atteint jamais le '
          'conteneur, et la poser en production n\'a aucun effet :\n'
          '${missing.map((v) => '  - $v').join('\n')}',
    );
  });

  test('chaque variable lue par /config/app est documentée dans .env.example',
      () {
    final missing = read.difference(documented).toList()..sort();
    expect(
      missing,
      isEmpty,
      reason: 'Ces variables gouvernent une surface visible par les '
          'utilisateurs et ne sont documentées nulle part. L\'exploitation ne '
          'peut pas poser ce qu\'elle ne sait pas exister :\n'
          '${missing.map((v) => '  - $v').join('\n')}',
    );
  });

  test('les drapeaux KPB_EEF_* sont fermés par défaut dans compose', () {
    // Le sens de l'échec, figé. Une vitrine allumée par défaut serait
    // impossible à éteindre sans redéploiement du fichier compose, alors que
    // tout l'intérêt de cette architecture est l'inverse.
    final compose = File('docker-compose.yml').readAsStringSync();
    for (final flag in ['KPB_EEF_TEASER_ENABLED', 'KPB_EEF_ENABLED']) {
      expect(
        compose,
        contains('- $flag=\${$flag:-false}'),
        reason: '$flag doit avoir `false` pour défaut dans docker-compose.yml.',
      );
    }
    // Et les dates : défaut VIDE, jamais une date de repli. Une échéance
    // inventée est indistinguable d'une information pour qui la lit.
    for (final date in [
      'KPB_EEF_CAMPAIGN_OPENS_AT',
      'KPB_EEF_CAMPAIGN_CLOSES_AT',
    ]) {
      expect(
        compose,
        contains('- $date=\${$date:-}'),
        reason: '$date doit avoir un défaut VIDE, pas une date.',
      );
    }
  });
}
