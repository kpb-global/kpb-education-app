import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  importScholarshipCatalog,
  type ScholarshipCatalogWriter,
} from '../src/modules/scholarships-index/data/scholarship-catalog.importer';
import type { VerifiedScholarshipCatalogRecord } from '../src/modules/scholarships-index/data/scholarship-catalog.types';
import { SCHOLARSHIP_CATALOG_V1 } from '../src/modules/scholarships-index/data/scholarship-catalog.v1';
import { validateScholarshipCatalog } from '../src/modules/scholarships-index/data/scholarship-catalog.validator';

const apply = process.argv.includes('--apply');
const dryRun = process.argv.includes('--dry-run');

if (apply === dryRun) {
  console.error('Choose exactly one mode: --dry-run or --apply.');
  process.exitCode = 2;
} else {
  const volumeReport = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1);
  const recordReport = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
    includeVolumeTargets: false,
  });
  console.log(JSON.stringify(volumeReport, null, 2));
  if (!recordReport.valid) {
    console.error(
      'Scholarship import refused: resolve every record-level validation issue first.',
    );
    process.exitCode = 1;
  } else if (SCHOLARSHIP_CATALOG_V1.records.length === 0) {
    console.error(
      'Scholarship import refused: the verified catalog contains no importable record yet.',
    );
    process.exitCode = 1;
  } else if (dryRun) {
    console.log(
      JSON.stringify(
        {
          mode: 'dry-run',
          catalogVersion: SCHOLARSHIP_CATALOG_V1.catalogVersion,
          wouldAttempt: SCHOLARSHIP_CATALOG_V1.records.length,
          databaseWrites: 0,
        },
        null,
        2,
      ),
    );
  } else {
    void applyCatalog().catch((error: unknown) => {
      console.error(
        `Scholarship import failed: ${error instanceof Error ? error.message : String(error)}`,
      );
      process.exitCode = 1;
    });
  }
}

async function applyCatalog() {
  if (!process.env.DATABASE_URL && existsSync('.env')) {
    loadEnvFile('.env');
  }
  if (!process.env.DATABASE_URL) {
    throw new Error('DATABASE_URL is required for --apply.');
  }

  const prisma = new PrismaClient();
  const writer: ScholarshipCatalogWriter = {
    async createIfAbsent(record) {
      const existing = await prisma.scholarship.findUnique({
        where: { id: record.scholarship.id },
        select: { id: true },
      });
      if (existing) return 'existing';

      try {
        await prisma.scholarship.create({ data: createData(record) });
        return 'created';
      } catch (error) {
        if (isUniqueConflict(error)) {
          const concurrent = await prisma.scholarship.findUnique({
            where: { id: record.scholarship.id },
            select: { id: true },
          });
          if (concurrent) return 'existing';
        }
        throw error;
      }
    },
  };

  try {
    const summary = await importScholarshipCatalog(
      SCHOLARSHIP_CATALOG_V1,
      writer,
    );
    console.log(JSON.stringify({ mode: 'apply', ...summary }, null, 2));
  } finally {
    await prisma.$disconnect();
  }
}

function createData(record: VerifiedScholarshipCatalogRecord) {
  const scholarship = record.scholarship;
  const deadline =
    record.cycle.dateConfidence === 'confirmed'
      ? record.cycle.closesAt
      : record.cycle.estimatedCloseAt;
  return {
    id: scholarship.id,
    nameFr: scholarship.nameFr,
    nameEn: scholarship.nameEn,
    countryId: scholarship.countryId,
    countryNameFr: scholarship.countryNameFr,
    countryNameEn: scholarship.countryNameEn,
    levelEligibleFr: scholarship.levelEligibleFr,
    levelEligibleEn: scholarship.levelEligibleEn,
    typeOfFundingFr: scholarship.typeOfFundingFr,
    typeOfFundingEn: scholarship.typeOfFundingEn,
    fundingType: scholarship.fundingType,
    applicationRequirement: scholarship.applicationRequirement,
    deadlineLabelFr: scholarship.deadlineLabelFr,
    deadlineLabelEn: scholarship.deadlineLabelEn,
    descriptionFr: scholarship.descriptionFr,
    descriptionEn: scholarship.descriptionEn,
    advantagesFr: scholarship.advantagesFr,
    advantagesEn: scholarship.advantagesEn,
    eligibilityFr: scholarship.eligibilityFr,
    eligibilityEn: scholarship.eligibilityEn,
    keyRequirementsFr: scholarship.keyRequirementsFr,
    keyRequirementsEn: scholarship.keyRequirementsEn,
    relatedFieldIds: scholarship.relatedFieldIds,
    baseMatch: scholarship.baseMatch,
    applicationUrl: scholarship.applicationUrl,
    sourceUrl: scholarship.sourceUrl,
    deadlineAt: deadline ? new Date(deadline) : null,
    lastVerifiedAt: new Date(record.verifiedAt),
    verifiedById: 'catalog-import',
    verifiedByName: record.verifiedBy,
    // Import never publishes. An admin must review and activate the record.
    isActive: false,
    moderationStatus: 'pending' as const,
    tags: [...new Set([...scholarship.tags, `catalog:${SCHOLARSHIP_CATALOG_V1.catalogVersion}`])],
    applicationSteps: {
      create: record.applicationSteps.map((step) => ({
        stepNumber: step.stepNumber,
        titleFr: step.titleFr,
        titleEn: step.titleEn,
        descriptionFr: step.descriptionFr,
        descriptionEn: step.descriptionEn,
        estimatedDurationDays: step.estimatedDurationDays,
      })),
    },
    cycles: {
      create: {
        academicYear: record.cycle.academicYear,
        status: record.cycle.status,
        dateConfidence: record.cycle.dateConfidence,
        estimatedOpenAt: record.cycle.estimatedOpenAt
          ? new Date(record.cycle.estimatedOpenAt)
          : null,
        estimatedCloseAt: record.cycle.estimatedCloseAt
          ? new Date(record.cycle.estimatedCloseAt)
          : null,
        opensAt: record.cycle.opensAt
          ? new Date(record.cycle.opensAt)
          : null,
        closesAt: record.cycle.closesAt
          ? new Date(record.cycle.closesAt)
          : null,
        sourceUrl: record.cycle.sourceUrl,
        verifiedAt: new Date(record.verifiedAt),
      },
    },
  };
}

function isUniqueConflict(error: unknown): boolean {
  return (
    error != null &&
    typeof error === 'object' &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2002'
  );
}
