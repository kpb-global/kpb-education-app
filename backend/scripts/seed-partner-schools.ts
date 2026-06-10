/**
 * Seeds non-OMNES partner schools and programs (Annexe 05).
 *
 * Usage:
 *   npm run seed:partners
 */
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  PARTNER_INSTITUTION_SEEDS,
  countPartnerPrograms,
} from '../src/modules/catalog/data/partner-schools.seed';

loadEnvFile?.('.env');

const prisma = new PrismaClient();

const INSTITUTION_PREFIX = 'partner-';
const PROGRAM_PREFIX = 'partner-p-';

async function main() {
  await prisma.program.deleteMany({
    where: { id: { startsWith: PROGRAM_PREFIX } },
  });
  await prisma.institution.deleteMany({
    where: { id: { startsWith: INSTITUTION_PREFIX } },
  });

  for (const school of PARTNER_INSTITUTION_SEEDS) {
    const programIds: string[] = [];

    for (const program of school.programs) {
      await prisma.program.create({
        data: {
          id: program.id,
          institutionId: school.id,
          countryId: school.countryId,
          fieldId: program.fieldId,
          nameFr: program.nameFr,
          nameEn: program.nameEn,
          levelFr: program.levelFr,
          levelEn: program.levelEn,
          durationFr: program.durationFr,
          durationEn: program.durationEn,
          tuitionFr: program.tuitionFr,
          tuitionEn: program.tuitionEn,
          languageFr: program.languageFr,
          languageEn: program.languageEn,
          requirementsFr: program.requirementsFr,
          requirementsEn: program.requirementsEn,
        },
      });
      programIds.push(program.id);
    }

    await prisma.institution.create({
      data: {
        id: school.id,
        nameFr: school.nameFr,
        nameEn: school.nameEn,
        countryId: school.countryId,
        locationFr: school.locationFr,
        locationEn: school.locationEn,
        overviewFr: school.overviewFr,
        overviewEn: school.overviewEn,
        studyLevels: school.studyLevels,
        tuitionLabelFr: 'Voir programme',
        tuitionLabelEn: 'See program',
        languageRequirementsFr: 'Selon programme',
        languageRequirementsEn: 'Depending on program',
        intakePeriods: ['Septembre'],
        programIds,
        isPartner: true,
      },
    });
  }

  const programCount = await prisma.program.count({
    where: { id: { startsWith: PROGRAM_PREFIX } },
  });
  const institutionCount = await prisma.institution.count({
    where: { id: { startsWith: INSTITUTION_PREFIX } },
  });
  const omnesCount = await prisma.program.count({
    where: { id: { startsWith: 'omnes-p-' } },
  });
  const totalPrograms = await prisma.program.count();

  // eslint-disable-next-line no-console
  console.log(
    `Partner seed complete: ${programCount} programs (expected ${countPartnerPrograms()}), ${institutionCount} institutions.`,
  );
  // eslint-disable-next-line no-console
  console.log(
    `Catalog totals: ${totalPrograms} programs (${omnesCount} OMNES + ${programCount} partners).`,
  );
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
