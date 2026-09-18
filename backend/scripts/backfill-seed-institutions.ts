/**
 * Comble les champs vides des institutions « seed » (antérieures à l'import
 * partenaire). Chaque écriture est conditionnée à un champ VIDE — si
 * quelqu'un a rempli le champ depuis l'admin, on ne l'écrase pas.
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

async function main() {
  const apply = process.argv.includes('--apply');
  let toWrite = 0;

  console.log(`${SEED_INSTITUTION_FILLS.length} institution(s) à compléter\n`);

  for (const fill of SEED_INSTITUTION_FILLS) {
    const row = await prisma.institution.findUnique({
      where: { id: fill.id },
      select: {
        id: true,
        nameFr: true,
        overviewFr: true,
        locationFr: true,
        sourceUrl: true,
      },
    });

    if (!row) {
      console.log(`  ✗ ${fill.id} — introuvable`);
      continue;
    }

    const gaps: string[] = [];
    if (!row.overviewFr) gaps.push('overview');
    if (!row.locationFr) gaps.push('location');
    if (!row.sourceUrl) gaps.push('source');

    if (gaps.length === 0) {
      console.log(`  · ${row.nameFr} — déjà complet`);
      continue;
    }

    console.log(`  → ${row.nameFr} : ${gaps.join(', ')} à combler`);
    toWrite += 1;
  }

  console.log(`\nTOTAL : ${toWrite} institution(s) à compléter.`);
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  let written = 0;
  for (const fill of SEED_INSTITUTION_FILLS) {
    let touched = false;

    const ov = await prisma.institution.updateMany({
      where: { id: fill.id, overviewFr: '' },
      data: { overviewFr: fill.overviewFr, overviewEn: fill.overviewEn },
    });
    if (ov.count) touched = true;

    const loc = await prisma.institution.updateMany({
      where: { id: fill.id, locationFr: '' },
      data: { locationFr: fill.locationFr, locationEn: fill.locationEn },
    });
    if (loc.count) touched = true;

    const src = await prisma.institution.updateMany({
      where: { id: fill.id, sourceUrl: null },
      data: { sourceUrl: fill.sourceUrl },
    });
    if (src.count) touched = true;

    if (touched) {
      written += 1;
      console.log(
        `  ✓ ${fill.id}` +
          (ov.count ? ' · overview' : '') +
          (loc.count ? ' · location' : '') +
          (src.count ? ' · source' : ''),
      );
    } else {
      console.log(`  · ${fill.id} — tout rempli entre-temps`);
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
