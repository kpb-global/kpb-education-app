/**
 * Réaligne `Institution.programIds` sur les lignes `Program` réellement
 * présentes.
 *
 * Cette liste dénormalisée est LUE par six écrans de l'app : le nombre de
 * formations affiché, l'aperçu des trois premières, la navigation depuis une
 * fiche pays (désactivée quand la liste est vide), le comparateur qui compte et
 * trie dessus, la première formation du profil, et le filtrage de la recherche.
 * Rien en base ne la lie aux lignes `Program` — une formation peut donc exister
 * sans être atteignable, ce qui n'apparaît dans aucune erreur.
 *
 * Mesuré le 18/09 : 3 établissements sur 68 dans ce cas, soit 48 formations
 * invisibles, dont les 46 de Mundiapolis créées par l'import du 16/09.
 *
 *   npm run reconcile:program-ids                # simulation
 *   npm run reconcile:program-ids -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

async function main() {
  const apply = process.argv.includes('--apply');

  const institutions = await prisma.institution.findMany({
    select: { id: true, nameFr: true, programIds: true },
    orderBy: { id: 'asc' },
  });

  const drifted: { id: string; nameFr: string; listed: number; actual: string[] }[] = [];
  for (const inst of institutions) {
    const actual = (
      await prisma.program.findMany({
        where: { institutionId: inst.id },
        select: { id: true },
        orderBy: { id: 'asc' },
      })
    ).map((p) => p.id);
    const listed = [...inst.programIds].sort();
    if (JSON.stringify(listed) !== JSON.stringify([...actual].sort())) {
      drifted.push({ id: inst.id, nameFr: inst.nameFr, listed: inst.programIds.length, actual });
    }
  }

  console.log(`${institutions.length} établissement(s) · ${drifted.length} à réaligner\n`);
  for (const d of drifted) {
    const invisible = d.listed === 0 ? ' — toutes invisibles dans l’app' : '';
    console.log(
      `  ${d.nameFr.slice(0, 40).padEnd(40)} liste=${d.listed} → ${d.actual.length}${invisible}`,
    );
  }

  if (!drifted.length) {
    console.log('\nRien à faire.');
    return;
  }
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  for (const d of drifted) {
    await prisma.institution.update({
      where: { id: d.id },
      data: { programIds: d.actual },
    });
    console.log(`  ✓ ${d.nameFr.slice(0, 40)} · ${d.actual.length} formation(s)`);
  }
  console.log(`\n── ÉCRIT : ${drifted.length} ──`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
