/**
 * Crée Universiapolis et ses 6 formations (voir
 * src/modules/catalog/universiapolis-programs.ts pour la table et ses sources).
 *
 * Écartée de l'import CSV du 16/09 : ses 15 lignes étaient des ANNÉES D'ENTRÉE
 * tarifées, pas des formations. Cette table est le résultat du regroupement,
 * avec les diplômes relevés sur les pages de l'université.
 *
 * `tuitionMinEur` est calculé par `tuitionToEur`, qui n'applique le taux dirham
 * que pour les établissements le citant en source — `partner-universiapolis` en
 * fait partie. C'est la première fois que ce taux sert : jusqu'ici il ne
 * couvrait aucune ligne en base.
 *
 * Idempotent : identifiants dérivés, `upsert` à partie `update` VIDE. Relancer
 * ne crée rien et n'écrase jamais une fiche retouchée à la main.
 *
 *   npm run import:universiapolis                # simulation
 *   npm run import:universiapolis -- --apply     # écrit
 */
import { createHash } from 'node:crypto';
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import { tuitionToEur } from '../src/modules/catalog/tuition-eur';
import {
  UNIVERSIAPOLIS_INSTITUTION as INST,
  UNIVERSIAPOLIS_PROGRAMS,
} from '../src/modules/catalog/universiapolis-programs';

if (existsSync('.env')) loadEnvFile?.('.env');

const prisma = new PrismaClient();

/** Même dérivation que l'import partenaires : `partner-p-<sha256(inst|nom)>`. */
function programId(nameFr: string): string {
  return `partner-p-${createHash('sha256')
    .update(`${INST.id}|${nameFr}`)
    .digest('hex')
    .slice(0, 16)}`;
}

async function main() {
  const apply = process.argv.includes('--apply');

  const existing = await prisma.institution.findUnique({
    where: { id: INST.id },
    select: { id: true },
  });
  const present = new Set(
    (
      await prisma.program.findMany({
        where: { institutionId: INST.id },
        select: { nameFr: true },
      })
    ).map((p) => p.nameFr),
  );

  console.log(
    `── ${INST.id}  [${existing ? 'établissement existant' : 'À CRÉER'}]  pays=${INST.countryId}\n`,
  );

  const planned = UNIVERSIAPOLIS_PROGRAMS.filter((p) => !present.has(p.nameFr));
  for (const p of UNIVERSIAPOLIS_PROGRAMS) {
    const eur = tuitionToEur(p.tuitionFr, INST.id);
    const money = eur.ok
      ? `${eur.eur} €${eur.exact ? '' : ' (taux sourcé)'}`
      : `null (${eur.reason})`;
    const state = present.has(p.nameFr) ? 'déjà présent' : 'à créer';
    console.log(`  ${p.levelFr.padEnd(8)} ${p.nameFr}`);
    console.log(
      `           ${state} · ${p.tuitionFr} ⇒ ${money} · regroupe ${p.mergedYears.length} année(s)`,
    );
  }

  console.log(
    `\nTOTAL : ${planned.length} formation(s) à créer, ${UNIVERSIAPOLIS_PROGRAMS.length - planned.length} ignorée(s).`,
  );
  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  await prisma.institution.upsert({
    where: { id: INST.id },
    // Jamais d'écrasement d'une fiche retouchée à la main.
    update: {},
    create: {
      id: INST.id,
      nameFr: INST.nameFr,
      nameEn: INST.nameEn,
      countryId: INST.countryId,
      locationFr: INST.locationFr,
      locationEn: INST.locationFr,
      overviewFr: INST.overviewFr,
      overviewEn: INST.overviewFr,
      studyLevels: [...new Set(UNIVERSIAPOLIS_PROGRAMS.map((p) => p.levelFr))],
      tuitionLabelFr: '',
      tuitionLabelEn: '',
      languageRequirementsFr: '',
      languageRequirementsEn: '',
      intakePeriods: [...INST.intakePeriods],
      programIds: [],
      isPartner: INST.isPartner,
    },
  });

  let written = 0;
  for (const p of planned) {
    const eur = tuitionToEur(p.tuitionFr, INST.id);
    await prisma.program.upsert({
      where: { id: programId(p.nameFr) },
      update: {},
      create: {
        id: programId(p.nameFr),
        institutionId: INST.id,
        countryId: INST.countryId,
        fieldId: p.fieldId,
        nameFr: p.nameFr,
        nameEn: p.nameFr,
        levelFr: p.levelFr,
        levelEn: p.levelFr,
        durationFr: p.durationFr,
        durationEn: p.durationFr,
        tuitionFr: p.tuitionFr,
        tuitionEn: p.tuitionFr,
        languageFr: '',
        languageEn: '',
        requirementsFr: [],
        requirementsEn: [],
        teachingLanguages: [],
        sourceUrl: p.sourceUrl,
        ...(eur.ok ? { tuitionMinEur: eur.eur } : {}),
      },
    });
    written += 1;
    console.log(`  ✓ ${p.nameFr}`);
  }
  console.log(`\n── ÉCRIT : ${written} ──`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
