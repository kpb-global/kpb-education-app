// Cliquet LIV-T16 : `/config/app` sert la fenêtre de campagne en JOURS nus,
// jamais en instants.
//
// ## Le défaut que ce fichier existe pour interdire
//
// Le client extrayait déjà les composantes `AAAA-MM-JJ` du texte reçu, avant
// toute conversion — correct, et insuffisant. Le serveur, lui, faisait
// `new Date(raw).toISOString()` sur la valeur d'exploitation :
//
//   KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01T00:00:00+02:00   (l'heure de Paris)
//     → servi « 2026-09-30T22:00:00.000Z »
//     → le client extrait « 2026-09-30 », correctement, d'une valeur déjà fausse
//
// L'information était perdue sur le fil : aucun correctif mobile ne pouvait la
// retrouver. Écrire l'heure de Paris est le réflexe naturel pour une procédure
// française, donc ce n'était pas un cas de bord — c'était le cas de production,
// et il donnait la mauvaise date à Dakar, Bamako, Abidjan, Niamey et Douala.
//
// Les tests des deux côtés étaient verts. Ceux du mobile décodaient la valeur
// d'exploitation **directement**, contournant précisément la normalisation
// fautive ; ceux du backend figeaient cette normalisation sous le titre
// « normalizes configured campaign dates to ISO instants ». Chaque côté prouvait
// sa moitié, et le défaut vivait dans la couture.
//
// D'où ce cliquet, qui garde la couture elle-même.
//
// ## Ce qu'il ne prouve pas
//
// Que la valeur posée en production est la bonne : cela se lit par
// `curl /config/app` après bascule. Il prouve que le format du fil ne peut plus
// perdre le jour. Le comportement du décodage mobile est éprouvé, lui, par
// `test/features/etudes_en_france/eef_campaign_day_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// La source, commentaires retirés.
///
/// Nécessaire, et pas par élégance : le premier jet de ce cliquet rougissait sur
/// la documentation de `campaignDay`, qui cite `new Date(raw).toISOString()`
/// pour expliquer le défaut qu'elle remplace. Un cliquet qui interdit de
/// DÉCRIRE le défaut qu'il garde ferait effacer l'explication pour obtenir le
/// vert — l'inverse de ce qu'on veut.
String _code(String source) => source
    // Les blocs `/** … */` et `/* … */`.
    .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
    // Les lignes de commentaire entières. On ne touche pas aux commentaires de
    // fin de ligne, pour ne pas mutiler une URL `https://…` dans une chaîne.
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  const controllerPath = 'backend/src/modules/config/app-config.controller.ts';
  final source = _code(File(controllerPath).readAsStringSync());

  test('la source du contrôleur est bien lue — garde morte, sinon', () {
    // Sans ce témoin, un renommage de fichier — ou un retrait de commentaires
    // trop gourmand — rendrait tous les tests ci-dessous verts sur une chaîne
    // vide. C'est le mode d'échec habituel d'un cliquet qui lit du texte.
    expect(source, contains('eefCampaign'),
        reason: '$controllerPath ne contient plus le bloc eefCampaign : '
            'ce cliquet ne garde plus rien.');
    expect(source, contains('function campaignDay('),
        reason: 'Le corps de campaignDay a disparu du code lu.');
  });

  test('les deux bornes passent par le décodage en jour d\'horloge murale', () {
    for (final variable in const [
      'KPB_EEF_CAMPAIGN_OPENS_AT',
      'KPB_EEF_CAMPAIGN_CLOSES_AT',
    ]) {
      expect(
        source,
        contains('campaignDay(process.env.$variable)'),
        reason: '$variable doit être servie par `campaignDay`, qui lit les '
            'composantes AAAA-MM-JJ du TEXTE. Toute fonction qui construit un '
            '`Date` puis le resérialise détruit le jour dès que '
            'l\'exploitation écrit un décalage explicite.',
      );
    }
  });

  test('aucune valeur servie par /config/app n\'est un instant resérialisé',
      () {
    // LE test. `toISOString()` est la ligne exacte qui a produit le défaut, et
    // sa réapparition dans ce fichier — sur les dates de campagne ou sur
    // n'importe quelle date future servie ici — recréerait la même reprojection.
    expect(
      source,
      isNot(contains('toISOString')),
      reason: 'Une date servie par /config/app se reprojette dans le fuseau du '
          'lecteur. « Le 1er octobre » devient alors « le 30 septembre » pour '
          'une partie du public — ou pour la totalité, si la valeur écrite '
          'porte l\'heure de Paris. Sers un jour nu `AAAA-MM-JJ`.',
    );
  });

  test('`.env.example` recommande la forme sans heure', () {
    // Le format du fil ne suffit pas : l'exploitation doit lire quoi écrire.
    // `campaignDay` tolère une heure et l'ignore, mais une variable qui en porte
    // une laisse croire qu'elle compte.
    final example = File('.env.example').readAsStringSync();
    expect(example, contains('KPB_EEF_CAMPAIGN_OPENS_AT'));
    expect(
      example,
      contains('AAAA-MM-JJ'),
      reason: '.env.example doit dire que ces variables se saisissent en jour '
          'nu, sans heure ni décalage.',
    );
  });
}
