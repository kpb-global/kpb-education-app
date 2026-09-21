// Rattrapage du `cycle` sur les formations importées avant que la colonne
// n'existe.
//
//   npx ts-node scripts/backfill-eef-cycle.ts --dry-run
//   npx ts-node scripts/backfill-eef-cycle.ts --apply
//
// Aucun mode par défaut, comme l'import. Ne comble que les `NULL` : il est
// rejouable, et il ne peut pas écraser une correction faite dans l'admin.
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  backfillEefCycles,
  planCycleBackfill,
  type CycleBackfillEntry,
  type CycleBackfillWriter,
} from '../src/modules/etudes-en-france/catalog/eef-cycle-backfill';
import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

const prisma = new PrismaClient();

class PrismaCycleWriter implements CycleBackfillWriter {
  async fillIfNull(entry: CycleBackfillEntry): Promise<number> {
    const result = await prisma.program.updateMany({
      // `cycle: null` DANS le WHERE, et pas une comparaison en mémoire : entre
      // la lecture du plan et l'écriture, un import peut avoir renseigné la
      // colonne, et seul le `WHERE` ferme cette fenêtre.
      where: { id: entry.id, cycle: null },
      data: { cycle: entry.cycle },
    });
    return result.count;
  }
}

class DryRunCycleWriter implements CycleBackfillWriter {
  async fillIfNull(entry: CycleBackfillEntry): Promise<number> {
    // Le dry-run LIT la base : « ce qui serait comblé » doit être un fait, pas
    // une estimation.
    const count = await prisma.program.count({
      where: { id: entry.id, cycle: null },
    });
    return count;
  }
}

async function main(): Promise<void> {
  const entries = planCycleBackfill(loadEefCatalog());
  const summary = await backfillEefCycles(
    entries,
    apply ? new PrismaCycleWriter() : new DryRunCycleWriter(),
  );
  console.log(
    JSON.stringify({ mode: apply ? 'apply' : 'dry-run', ...summary }, null, 2),
  );
  console.log(
    apply
      ? `\n${summary.filled} cycle(s) comblé(s). Les lignes déjà renseignées n'ont pas bougé.`
      : '\nRien écrit.',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
