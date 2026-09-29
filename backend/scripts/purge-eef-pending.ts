// Supprime les lignes de l'import « Études en France » jamais publiées ni
// vérifiées, pour qu'un nouvel `eef:import` les recrée avec les règles corrigées.
// Voir `eef-pending-purge.ts` pour le pourquoi et pour ce qui est protégé.
//
//   npx ts-node scripts/purge-eef-pending.ts --dry-run
//   npx ts-node scripts/purge-eef-pending.ts --apply
//
// Aucun mode par défaut, comme l'import. N'imprime que des décomptes.
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { purgePendingEefRows } from '../src/modules/etudes-en-france/catalog/eef-pending-purge';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error("Choisir --dry-run OU --apply. Rien n'a été fait.");
  process.exit(2);
}

const prisma = new PrismaClient();

async function main(): Promise<void> {
  const s = await purgePendingEefRows(prisma, { apply });
  console.log(apply ? '── APPLICATION ──' : "── SIMULATION (rien n'est écrit) ──");
  console.log(`Formations en attente (eef-prog-, inactives, jamais vérifiées) : ${s.programsPending}`);
  console.log(`  protégées (enregistrées par un utilisateur)                  : ${s.programsProtected.saved}`);
  console.log(`Établissements en attente (eef-univ-, idem)                    : ${s.institutionsPending}`);
  console.log(`  protégés — gardent une formation non supprimée               : ${s.institutionsProtected.keepsNonPendingPrograms}`);
  console.log(`  protégés — accord de partenariat                             : ${s.institutionsProtected.partnerAgreement}`);
  console.log(`  protégés — enregistrés par un utilisateur                    : ${s.institutionsProtected.saved}`);
  if (apply) {
    console.log(`Formations supprimées     : ${s.programsDeleted}`);
    console.log(`Correspondances supprimées : ${s.matchesDeleted}`);
    console.log(`Établissements supprimés   : ${s.institutionsDeleted}`);
    console.log('Relancer ensuite : eef-import (vps-ops), qui recrée les lignes.');
  }
}

main()
  .catch((error: unknown) => {
    console.error(error instanceof Error ? error.message : error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
