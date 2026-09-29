// Supprime les avis conseillers ORPHELINS : sans auteur, dont le dossier a
// disparu ou n'a jamais été renseigné. Voir `orphan-reviews.ts` pour le pourquoi.
//
//   npx ts-node scripts/purge-orphan-reviews.ts --dry-run
//   npx ts-node scripts/purge-orphan-reviews.ts --apply
//
// Aucun mode par défaut, comme l'import. N'imprime que des décomptes — ni nom,
// ni texte, ni identifiant d'utilisateur.
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { purgeOrphanReviews } from '../src/modules/counsellors/orphan-reviews';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const summary = await purgeOrphanReviews(prisma, { apply });
  console.log(apply ? '── APPLICATION ──' : "── SIMULATION (rien n'est écrit) ──");
  console.log(`Avis sans auteur examinés           : ${summary.unauthored}`);
  console.log(
    `  dont orphelins (dossier disparu)  : ${summary.orphans} `
      + `(publiés : ${summary.orphansPublished})`,
  );
  console.log(
    `  laissés (dossier encore présent)  : ${summary.keptBecauseCaseExists}`,
  );
  console.log(`Conseillers concernés               : ${summary.counsellorsAffected}`);
  if (apply) console.log(`Avis supprimés                      : ${summary.deleted}`);
}

main()
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
