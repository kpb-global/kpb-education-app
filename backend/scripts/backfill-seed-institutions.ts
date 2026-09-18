/**
 * Comble les champs vides des établissements « seed » (antérieurs à l'import
 * partenaire). Voir src/modules/catalog/seed-institution-fills.ts pour la
 * table et ses sources.
 *
 * UNE COLONNE = UNE ÉCRITURE = SA PROPRE CONDITION.
 *
 * La première version groupait les paires bilingues : `WHERE overviewFr = ''`
 * écrivait overviewFr ET overviewEn. `updateInstitution` accepte pourtant les
 * deux langues INDÉPENDAMMENT (admin-catalog.service.ts), donc l'état « anglais
 * saisi, français encore vide » est atteignable — et cette écriture écrasait
 * l'anglais saisi à la main. Le symétrique était tout aussi faux : un anglais
 * vide n'était jamais comblé si le français était déjà rempli.
 *
 * La condition vit dans le `WHERE`, jamais dans une lecture préalable : une
 * décision prise sur la lecture laisserait une fenêtre où un administrateur
 * saisit la valeur entre-temps et la voit écrasée.
 *
 * `lastVerifiedAt` n'est PAS posée : la source est inscrite, la vérification
 * humaine reste due.
 *
 *   npm run backfill:seed-institutions                # simulation
 *   npm run backfill:seed-institutions -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { SEED_INSTITUTION_FILLS } from '../src/modules/catalog/seed-institution-fills';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

/** Les colonnes texte, chacune comblée seule. */
const TEXT_COLUMNS = [
  'overviewFr',
  'overviewEn',
  'locationFr',
  'locationEn',
] as const;

async function main() {
  const apply = process.argv.includes('--apply');
  let toWrite = 0;

  console.log(`${SEED_INSTITUTION_FILLS.length} établissement(s) à compléter\n`);

  for (const fill of SEED_INSTITUTION_FILLS) {
    const row = await prisma.institution.findUnique({
      where: { id: fill.id },
      select: {
        id: true,
        nameFr: true,
        overviewFr: true,
        overviewEn: true,
        locationFr: true,
        locationEn: true,
        sourceUrl: true,
      },
    });

    if (!row) {
      console.log(`  ✗ ${fill.id} — introuvable`);
      continue;
    }

    const gaps = TEXT_COLUMNS.filter((c) => !row[c]);
    if (!row.sourceUrl) gaps.push('sourceUrl' as never);

    if (gaps.length === 0) {
      console.log(`  · ${row.nameFr} — déjà complet`);
      continue;
    }

    console.log(`  → ${row.nameFr} : ${gaps.join(', ')}`);
    toWrite += 1;
  }

  console.log(`\nTOTAL : ${toWrite} établissement(s) à compléter.`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  let written = 0;
  for (const fill of SEED_INSTITUTION_FILLS) {
    const filled: string[] = [];

    // Une écriture par colonne : chacune ne s'applique QUE si cette colonne-là
    // est vide, réévalué par la base à l'instant de l'écriture.
    for (const column of TEXT_COLUMNS) {
      const { count } = await prisma.institution.updateMany({
        where: { id: fill.id, [column]: '' },
        data: { [column]: fill[column] },
      });
      if (count) filled.push(column);
    }

    const src = await prisma.institution.updateMany({
      where: { id: fill.id, sourceUrl: null },
      data: { sourceUrl: fill.sourceUrl },
    });
    if (src.count) filled.push('sourceUrl');

    if (filled.length) {
      written += 1;
      console.log(`  ✓ ${fill.id} · ${filled.join(', ')}`);
    } else {
      console.log(`  · ${fill.id} — tout rempli entre-temps, rien écrit`);
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
