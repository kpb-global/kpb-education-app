/**
 * Comble logos, description et repère d'admission sur les lignes EEF déjà
 * importées. Voir `eef-catalog.backfill.ts` pour qui fait foi.
 *
 * UNE COLONNE = UNE ÉCRITURE = SA PROPRE CONDITION, réévaluée par la base
 * à l'instant de l'écriture. Exception logo : les trois colonnes voyagent
 * ensemble (URL + source + licence) et ne s'écrivent que si les trois sont
 * encore nulles — une URL sans licence n'est pas affichable.
 *
 *   npm run eef:backfill -- --dry-run
 *   npm run eef:backfill -- --apply
 */
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  planInstitutionLogoBackfill,
  planProgramRequirementsBackfill,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.backfill';
import { planEefImport } from '../src/modules/etudes-en-france/catalog/eef-catalog.importer';
import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';
import { validateEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.validator';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error('Choisir --dry-run OU --apply. Rien n\'a été fait.');
  process.exit(2);
}

const prisma = new PrismaClient();

async function resolveFranceCountryId(): Promise<string> {
  const countries = await prisma.country.findMany({
    where: { isActive: true },
    select: { id: true, code: true },
  });
  const matches = countries.filter(
    (country) => country.code.toUpperCase() === 'FR',
  );
  if (matches.length === 0) {
    throw new Error(
      "Aucun pays actif de code « FR » en base : le catalogue n'a nulle part où "
      + 'se rattacher.',
    );
  }
  if (matches.length > 1) {
    throw new Error(
      `Plusieurs pays actifs de code « FR » : ${matches.map((c) => c.id).join(', ')}.`,
    );
  }
  return matches[0].id;
}

async function main(): Promise<void> {
  const catalog = loadEefCatalog();
  const validation = validateEefCatalog(catalog);
  if (validation.errors.length > 0) {
    console.error(
      `Catalogue invalide (${validation.errors.length} erreurs) : backfill refusé.`,
    );
    for (const error of validation.errors.slice(0, 20)) {
      console.error(`  ✗ ${error}`);
    }
    process.exit(1);
  }

  const countryId = await resolveFranceCountryId();
  const plan = planEefImport(catalog, countryId);

  const institutionRows = await prisma.institution.findMany({
    where: { id: { in: plan.institutions.map((row) => row.id) } },
    select: {
      id: true,
      nameFr: true,
      logoUrl: true,
      logoSourceUrl: true,
      logoLicence: true,
    },
  });
  const institutionsById = new Map(institutionRows.map((row) => [row.id, row]));

  const programRows = await prisma.program.findMany({
    where: { id: { in: plan.programs.map((row) => row.id) } },
    select: {
      id: true,
      isActive: true,
      lastVerifiedAt: true,
      requirementsFr: true,
      requirementsEn: true,
    },
  });
  const programsById = new Map(programRows.map((row) => [row.id, row]));

  let logosToWrite = 0;
  let requirementsToWrite = 0;
  const kept: Record<string, number> = {};
  const bump = (reason: string): void => {
    kept[reason] = (kept[reason] ?? 0) + 1;
  };

  for (const row of plan.institutions) {
    const decision = planInstitutionLogoBackfill(
      row,
      institutionsById.get(row.id) ?? null,
    );
    if (decision.write) logosToWrite += 1;
    else bump(`logo:${decision.keptReason ?? 'none'}`);
  }

  for (const row of plan.programs) {
    const decision = planProgramRequirementsBackfill(
      row,
      programsById.get(row.id) ?? null,
    );
    if (decision.writeFr) requirementsToWrite += 1;
    else bump(`requirementsFr:${decision.keptReasonFr ?? 'none'}`);
    if (decision.writeEn) requirementsToWrite += 1;
    else bump(`requirementsEn:${decision.keptReasonEn ?? 'none'}`);
  }

  console.log(
    JSON.stringify(
      {
        mode: apply ? 'apply' : 'dry-run',
        catalogVersion: plan.catalogVersion,
        logosToWrite,
        requirementColumnsToWrite: requirementsToWrite,
        kept,
      },
      null,
      2,
    ),
  );

  if (!apply) {
    console.log('\n── SIMULATION — aucune écriture. Relancer avec --apply. ──');
    return;
  }

  let logosWritten = 0;
  for (const row of plan.institutions) {
    const decision = planInstitutionLogoBackfill(
      row,
      institutionsById.get(row.id) ?? null,
    );
    if (!decision.write) continue;
    const { count } = await prisma.institution.updateMany({
      where: {
        id: row.id,
        logoUrl: null,
        logoSourceUrl: null,
        logoLicence: null,
      },
      data: {
        logoUrl: decision.write.logoUrl,
        logoSourceUrl: decision.write.logoSourceUrl,
        logoLicence: decision.write.logoLicence,
      },
    });
    if (count) logosWritten += 1;
  }

  let requirementsWritten = 0;
  for (const row of plan.programs) {
    const decision = planProgramRequirementsBackfill(
      row,
      programsById.get(row.id) ?? null,
    );
    if (decision.writeFr && decision.procedureFr && decision.admissionFr) {
      const { count } = await prisma.program.updateMany({
        where: {
          id: row.id,
          isActive: false,
          lastVerifiedAt: null,
          requirementsFr: { has: decision.procedureFr },
          NOT: { requirementsFr: { has: decision.admissionFr } },
        },
        data: { requirementsFr: [...decision.writeFr] },
      });
      if (count) requirementsWritten += 1;
    }
    if (decision.writeEn && decision.procedureEn && decision.admissionEn) {
      const { count } = await prisma.program.updateMany({
        where: {
          id: row.id,
          isActive: false,
          lastVerifiedAt: null,
          requirementsEn: { has: decision.procedureEn },
          NOT: { requirementsEn: { has: decision.admissionEn } },
        },
        data: { requirementsEn: [...decision.writeEn] },
      });
      if (count) requirementsWritten += 1;
    }
  }

  console.log(
    JSON.stringify({ logosWritten, requirementColumnsWritten: requirementsWritten }, null, 2),
  );
  console.log(
    '\nRien n\'a été publié : lastVerifiedAt et isActive n\'ont pas été touchés.',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
