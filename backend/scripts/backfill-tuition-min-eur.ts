/**
 * Renseigne `Program.tuitionMinEur` à partir du libellé `tuitionFr`.
 *
 * Pourquoi : les 628 programmes de production ont cette colonne à `null`.
 * matches.service.ts la lit pour le score budgétaire ; sans elle, le facteur
 * est neutralisé à 0,5 et CHAQUE match servi par l'app est marqué `isEstimate`.
 * Or 350 programmes portent déjà un montant en euros dans `tuitionFr` — il n'y
 * a rien à convertir, seulement à lire.
 *
 * Ne touche QUE les lignes où la colonne est nulle, et le vérifie à l'instant
 * de l'écriture (`WHERE tuitionMinEur IS NULL`) : une valeur saisie à la main
 * entre la lecture et l'écriture ne doit jamais être écrasée — leçon de #272.
 *
 *   npm run backfill:tuition-eur                # simulation
 *   npm run backfill:tuition-eur -- --apply     # écrit
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { tuitionToEur } from '../src/modules/catalog/tuition-eur';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

async function main() {
  const apply = process.argv.includes('--apply');

  const rows = await prisma.program.findMany({
    where: { tuitionMinEur: null },
    select: {
      id: true,
      nameFr: true,
      tuitionFr: true,
      countryId: true,
      institutionId: true,
    },
  });
  console.log(`${rows.length} programme(s) sans tuitionMinEur\n`);

  const planned: { id: string; eur: number; exact: boolean; currency: string }[] = [];
  const refused: Record<string, number> = {};
  const byCurrency: Record<string, { n: number; exact: boolean }> = {};

  for (const r of rows) {
    // L'établissement compte : un taux sourcé ne vaut que pour celui qui le
    // publie. Voir INSTITUTION_RATES.
    const parsed = tuitionToEur(r.tuitionFr ?? '', r.institutionId);
    if (!parsed.ok) {
      const key = parsed.currency
        ? `${parsed.reason} (${parsed.currency})`
        : parsed.reason;
      refused[key] = (refused[key] ?? 0) + 1;
      continue;
    }
    planned.push({ id: r.id, eur: parsed.eur, exact: parsed.exact, currency: parsed.currency });
    const b = (byCurrency[parsed.currency] ??= { n: 0, exact: parsed.exact });
    b.n += 1;
  }

  console.log('CONVERTIBLES');
  for (const [cur, b] of Object.entries(byCurrency).sort((a, c) => c[1].n - a[1].n)) {
    console.log(`  ${String(b.n).padStart(4)}  ${cur}  ${b.exact ? '(exact)' : '(taux sourcé)'}`);
  }
  console.log(`  ${String(planned.length).padStart(4)}  TOTAL\n`);

  console.log('LAISSÉS À NULL');
  for (const [reason, n] of Object.entries(refused).sort((a, c) => c[1] - a[1])) {
    console.log(`  ${String(n).padStart(4)}  ${reason}`);
  }
  console.log();

  if (!apply) {
    console.log('── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  let written = 0;
  let raced = 0;
  for (const p of planned) {
    // `WHERE tuitionMinEur IS NULL` réévalué par la base : si la valeur a été
    // saisie depuis la lecture, le WHERE ne trouve rien et on ne l'écrase pas.
    const { count } = await prisma.program.updateMany({
      where: { id: p.id, tuitionMinEur: null },
      data: { tuitionMinEur: p.eur },
    });
    if (count) written += 1;
    else raced += 1;
  }
  console.log(`── ÉCRIT : ${written} ──`);
  if (raced) console.log(`   ${raced} renseigné(s) entre-temps, laissé(s) intact(s)`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
