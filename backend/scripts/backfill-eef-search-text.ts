// Rattrapage du texte cherchable (`Program.searchText`) et du sigle
// (`Institution.acronym`) des lignes importées avant que les colonnes existent.
//
//   npx ts-node scripts/backfill-eef-search-text.ts --dry-run
//   npx ts-node scripts/backfill-eef-search-text.ts --apply
//
// Aucun mode par défaut, comme l'import. Comble les colonnes vides ET répare les
// textes cherchables périmés (un intitulé renommé sans que le texte suive) : ce
// texte est dérivé de la ligne, donc le recalculer est toujours correct. Une
// écriture ne remplace la valeur lue que si la ligne n'a pas bougé depuis
// (comparaison-échange dans le `WHERE`) ; les sigles ne comblent que les vides.
// Rejouable : une ligne à jour n'est pas réécrite. Voir
// `eef-search-text.backfill.ts`.
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { eefProgramWhere } from '../src/common/eef-provenance';
import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';
import {
  planAcronymBackfill,
  planSearchTextBackfill,
} from '../src/modules/etudes-en-france/catalog/eef-search-text.backfill';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

const prisma = new PrismaClient();

/// Par paquets : une transaction de dix mille écritures tient un verrou que rien
/// ne justifie. Chaque paquet est atomique, et le script est rejouable.
const CHUNK = 500;

async function main(): Promise<void> {
  // La condition « la ligne n'a pas bougé » vit dans le WHERE de chaque écriture :
  // entre la lecture du plan et l'écriture, un import, une édition ou un autre
  // passage peut avoir changé la ligne, et seul le WHERE ferme cette fenêtre.
  const rows = await prisma.program.findMany({
    where: eefProgramWhere(),
    select: { id: true, nameFr: true, campusCity: true, searchText: true },
  });
  const programEntries = planSearchTextBackfill(rows);
  const programsMissing = programEntries.filter(
    (entry) => entry.previous === null,
  ).length;

  const acronymEntries = planAcronymBackfill(loadEefCatalog());
  const institutionRows = await prisma.institution.findMany({
    where: { id: { in: acronymEntries.map((entry) => entry.id) }, acronym: null },
    select: { id: true },
  });
  const missing = new Set(institutionRows.map((row) => row.id));
  const acronyms = acronymEntries.filter((entry) => missing.has(entry.id));

  let programsFilled = 0;
  let acronymsFilled = 0;
  if (apply) {
    for (let i = 0; i < programEntries.length; i += CHUNK) {
      const results = await prisma.$transaction(
        programEntries.slice(i, i + CHUNK).map((entry) =>
          prisma.program.updateMany({
            where: {
              id: entry.id,
              nameFr: entry.nameFr,
              campusCity: entry.campusCity,
              searchText: entry.previous,
            },
            data: { searchText: entry.searchText },
          }),
        ),
      );
      programsFilled += results.reduce((sum, result) => sum + result.count, 0);
    }
    for (let i = 0; i < acronyms.length; i += CHUNK) {
      const results = await prisma.$transaction(
        acronyms.slice(i, i + CHUNK).map((entry) =>
          prisma.institution.updateMany({
            where: { id: entry.id, acronym: null },
            data: { acronym: entry.acronym },
          }),
        ),
      );
      acronymsFilled += results.reduce((sum, result) => sum + result.count, 0);
    }
  }

  console.log(
    JSON.stringify(
      {
        mode: apply ? 'apply' : 'dry-run',
        programsWithoutSearchText: programsMissing,
        programsWithStaleSearchText: programEntries.length - programsMissing,
        programsToFill: programEntries.length,
        institutionsWithoutAcronym: acronyms.length,
        ...(apply ? { programsFilled, acronymsFilled } : {}),
      },
      null,
      2,
    ),
  );
  console.log(
    apply
      ? '\nColonnes vides comblées, textes périmés réparés ; le reste n\'a pas bougé.'
      : '\nRien écrit.',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
