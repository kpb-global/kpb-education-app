// Rattrapage des signaux d'admission publiés sur les formations importées
// avant que les colonnes n'existent.
//
//   npx ts-node scripts/backfill-eef-admission.ts --dry-run
//   npx ts-node scripts/backfill-eef-admission.ts --apply
//
// Aucun mode par défaut, comme l'import et le rattrapage du cycle. Ne comble
// que les lignes dont les DEUX listes publiées sont vides : il est rejouable,
// et il ne peut pas écraser une correction faite dans l'admin.
//
// Ce qu'il écrit vient des 70 fichiers versionnés — les licences conseillées
// et la modalité de candidature telles que l'établissement les publie — plus
// l'index des domaines, recalculé par la même fonction qui classe déjà les
// intitulés du catalogue. Rien n'est déduit ici que le catalogue ne sache
// déjà.
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  backfillEefAdmissionSignals,
  planAdmissionSignalsBackfill,
  type AdmissionSignalsEntry,
  type AdmissionSignalsWriter,
} from '../src/modules/etudes-en-france/catalog/eef-admission-signals';
import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

const prisma = new PrismaClient();

/// « Les deux listes publiées sont vides ». `recommendedFieldIds` n'entre pas
/// dans la condition : elle est DÉRIVÉE, et une ligne dont les libellés sont
/// là mais dont l'index est vide doit pouvoir être recalculée sans que ce
/// script la considère comme intacte.
const EMPTY_SIGNALS = {
  recommendedBachelors: { isEmpty: true },
  admissionModes: { isEmpty: true },
} as const;

class PrismaAdmissionWriter implements AdmissionSignalsWriter {
  async fillIfEmpty(entry: AdmissionSignalsEntry): Promise<number> {
    const result = await prisma.program.updateMany({
      // La condition de vacuité vit DANS le `WHERE`, pas dans une comparaison
      // en mémoire : entre la lecture du plan et l'écriture, un import peut
      // avoir renseigné la ligne, et seul le `WHERE` ferme cette fenêtre.
      where: { id: entry.id, ...EMPTY_SIGNALS },
      data: {
        recommendedBachelors: entry.recommendedBachelors,
        recommendedFieldIds: entry.recommendedFieldIds,
        admissionModes: entry.admissionModes,
      },
    });
    return result.count;
  }
}

class DryRunAdmissionWriter implements AdmissionSignalsWriter {
  async fillIfEmpty(entry: AdmissionSignalsEntry): Promise<number> {
    // Le dry-run LIT la base : « ce qui serait comblé » doit être un fait, pas
    // une estimation.
    return prisma.program.count({
      where: { id: entry.id, ...EMPTY_SIGNALS },
    });
  }
}

async function main(): Promise<void> {
  const entries = planAdmissionSignalsBackfill(loadEefCatalog());
  const summary = await backfillEefAdmissionSignals(
    entries,
    apply ? new PrismaAdmissionWriter() : new DryRunAdmissionWriter(),
  );
  console.log(
    JSON.stringify({ mode: apply ? 'apply' : 'dry-run', ...summary }, null, 2),
  );
  console.log(
    apply
      ? `\n${summary.filled} formation(s) complétée(s). Les lignes déjà renseignées n'ont pas bougé.`
      : '\nRien écrit.',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
