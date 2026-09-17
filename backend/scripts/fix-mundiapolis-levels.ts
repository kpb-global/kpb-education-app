/**
 * Applique les corrections de niveau Mundiapolis (voir
 * src/modules/catalog/mundiapolis-levels.ts pour la table et ses sources).
 *
 * Trois garanties, chacune tirée d'un défaut rencontré cette semaine :
 *
 * • L'écriture est CONDITIONNÉE à la valeur actuelle (`WHERE levelFr = from`).
 *   Si quelqu'un a corrigé la fiche depuis, le WHERE ne trouve rien et on ne
 *   l'écrase pas. Rejouable sans risque.
 * • `durationFr` et `sourceUrl` ne sont comblées que si elles sont VIDES, et la
 *   condition vit dans le `WHERE` de leur propre écriture — pas dans une
 *   lecture préalable, qui laisserait une fenêtre d'écrasement.
 * • `lastVerifiedAt` n'est PAS posée. La source est inscrite dans `sourceUrl`,
 *   mais la vérification humaine reste due : un script qui se déclare vérifié
 *   sortirait ces fiches de la file de contrôle sans que personne ne les ait
 *   regardées.
 *
 *   npm run fix:mundiapolis-levels                # simulation
 *   npm run fix:mundiapolis-levels -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { MUNDIAPOLIS_LEVEL_CORRECTIONS } from '../src/modules/catalog/mundiapolis-levels';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

async function main() {
  const apply = process.argv.includes('--apply');
  let toWrite = 0;

  console.log(`${MUNDIAPOLIS_LEVEL_CORRECTIONS.length} correction(s) prévue(s)\n`);

  for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
    const row = await prisma.program.findUnique({
      where: { id: fix.id },
      select: {
        id: true,
        nameFr: true,
        levelFr: true,
        durationFr: true,
        sourceUrl: true,
      },
    });

    if (!row) {
      console.log(`  ✗ ${fix.nameFr} — introuvable (${fix.id})`);
      continue;
    }
    // Le nom sert de contrôle croisé : un identifiant seul pourrait viser une
    // autre fiche si la dérivation changeait un jour.
    if (row.nameFr !== fix.nameFr) {
      console.log(
        `  ✗ ${fix.nameFr} — l'identifiant pointe sur « ${row.nameFr} », abandon`,
      );
      continue;
    }
    if (row.levelFr !== fix.from) {
      console.log(
        `  · ${fix.nameFr} — niveau déjà « ${row.levelFr} », rien à faire`,
      );
      continue;
    }
    console.log(
      `  → ${fix.nameFr} : « ${fix.from} » ⇒ « ${fix.to} »` +
        (row.durationFr ? '' : ` · durée « ${fix.durationFr} »`) +
        (row.sourceUrl ? '' : ' · source'),
    );
    toWrite += 1;
  }

  console.log(`\nTOTAL : ${toWrite} fiche(s) à corriger.`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  let written = 0;
  for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
    const current = await prisma.program.findUnique({
      where: { id: fix.id },
      select: { nameFr: true },
    });
    if (!current || current.nameFr !== fix.nameFr) continue;

    // TROIS écritures séparées, et non une seule bâtie sur la lecture ci-dessus.
    //
    // Chaque champ porte SA propre condition dans le `WHERE`, réévaluée par la
    // base à l'instant de l'écriture. Une lecture préalable qui déciderait
    // « durationFr est vide, donc je la remplis » laisserait une fenêtre : un
    // administrateur qui saisit la durée entre-temps la verrait écrasée, alors
    // que le script promet de ne jamais remplacer. C'est le constat P2 de la
    // revue de #272, reproduit ici — la garde était sur `levelFr` seulement.
    const { count } = await prisma.program.updateMany({
      where: { id: fix.id, levelFr: fix.from },
      data: { levelFr: fix.to, levelEn: fix.to },
    });

    const duration = await prisma.program.updateMany({
      where: { id: fix.id, durationFr: '' },
      data: { durationFr: fix.durationFr, durationEn: fix.durationFr },
    });

    const source = await prisma.program.updateMany({
      where: { id: fix.id, sourceUrl: null },
      data: { sourceUrl: fix.sourceUrl },
    });

    if (count) {
      written += 1;
      console.log(
        `  ✓ ${fix.nameFr}` +
          (duration.count ? ' · durée comblée' : '') +
          (source.count ? ' · source inscrite' : ''),
      );
    } else {
      console.log(`  · ${fix.nameFr} — niveau modifié entre-temps, laissé intact`);
    }
  }
  console.log(`\n── ÉCRIT : ${written} ──`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
