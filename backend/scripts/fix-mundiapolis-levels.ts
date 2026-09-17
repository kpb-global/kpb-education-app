/**
 * Applique les corrections de niveau Mundiapolis (voir
 * src/modules/catalog/mundiapolis-levels.ts pour la table et ses sources).
 *
 * Trois garanties, chacune tirée d'un défaut rencontré cette semaine :
 *
 * • L'écriture est CONDITIONNÉE à la valeur actuelle (`WHERE levelFr = from`).
 *   Si quelqu'un a corrigé la fiche depuis, le WHERE ne trouve rien et on ne
 *   l'écrase pas. Rejouable sans risque.
 * • `durationFr` n'est comblée que si elle est VIDE — jamais un remplacement.
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
      select: { durationFr: true, sourceUrl: true, nameFr: true },
    });
    if (!current || current.nameFr !== fix.nameFr) continue;

    const { count } = await prisma.program.updateMany({
      // `levelFr: fix.from` est la garde : réévaluée par la base à l'instant de
      // l'écriture, elle rend l'opération rejouable et non destructive.
      where: { id: fix.id, levelFr: fix.from },
      data: {
        levelFr: fix.to,
        levelEn: fix.to,
        ...(current.durationFr ? {} : { durationFr: fix.durationFr, durationEn: fix.durationFr }),
        ...(current.sourceUrl ? {} : { sourceUrl: fix.sourceUrl }),
      },
    });
    if (count) {
      written += 1;
      console.log(`  ✓ ${fix.nameFr}`);
    } else {
      console.log(`  · ${fix.nameFr} — modifié entre-temps, laissé intact`);
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
