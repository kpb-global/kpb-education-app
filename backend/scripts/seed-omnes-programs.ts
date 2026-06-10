/**
 * Seeds OMNES France private-school programs from normalized JSON.
 *
 * Usage:
 *   npm run seed:omnes
 *   ts-node scripts/seed-omnes-programs.ts [path-to-json]
 */
import { loadEnvFile } from 'node:process';
import * as fs from 'node:fs';
import * as path from 'node:path';
import { createHash } from 'node:crypto';

import { PrismaClient } from '@prisma/client';

import { M5_COUNTRY_SEEDS } from '../src/modules/countries/data/m5-countries.seed';

loadEnvFile?.('.env');

const prisma = new PrismaClient();

const FRANCE_COUNTRY_ID = 'fra';
const INSTITUTION_ID_PREFIX = 'omnes-';
const PROGRAM_ID_PREFIX = 'omnes-p-';

type OmnesRow = {
  school: string;
  campus: string;
  programName: string;
  programFamily: string;
  degreeLevel: string;
  admissionLevel: string;
  language: string;
  paymentUpfront: number | null;
  paymentInstallments: number | null;
  intakeDate: string | null;
};

function slugify(value: string, max = 40): string {
  return value
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, max);
}

function institutionId(school: string, campus: string): string {
  return `${INSTITUTION_ID_PREFIX}${slugify(school)}-${slugify(campus)}`;
}

function programId(row: OmnesRow): string {
  const key = `${row.school}|${row.campus}|${row.programName}`;
  const hash = createHash('sha256').update(key).digest('hex').slice(0, 16);
  return `${PROGRAM_ID_PREFIX}${hash}`;
}

function inferFieldId(row: OmnesRow): string {
  const text = `${row.programName} ${row.programFamily}`.toLowerCase();
  if (
    /informat|computer|cyber|data|digital|développeur|developpeur|ia\b|intelligence artificielle|dev\b|software/.test(
      text,
    )
  ) {
    return 'computer_science';
  }
  if (/engineer|ingenier|ingénier|aeronaut|aéronaut/.test(text)) {
    return 'engineering';
  }
  return 'business';
}

function studyLevelsFor(row: OmnesRow): string[] {
  const levels = new Set<string>();
  const family = row.programFamily.toLowerCase();
  if (family.includes('bachelor') || family.includes('bba')) levels.add('Bachelor');
  if (family.includes('msc') || family.includes('master') || family.includes('pge')) {
    levels.add('Master');
  }
  if (family.includes('grande ecole') || family.includes('visa')) {
    levels.add('Master');
    levels.add('Grande École');
  }
  if (levels.size === 0) levels.add(row.programFamily);
  return [...levels];
}

/// Normalise a raw OMNES family + degree level to a clean canonical degree
/// label (Bachelor · BBA · Master · MBA / DBA · Doctorat · Bac+2). Mirrors the
/// Flutter `programLevelLabel` (lib/app/core/utils/study_level.dart) so the
/// catalogue shows consistent, épuré labels instead of "MSc · Bac+5", "PGE"…
function normalizeDegreeLevel(raw: string): string {
  const s = raw.toLowerCase();
  if (s.includes('doctorat') || s.includes('phd') || s.includes('bac+8')) {
    return 'Doctorat';
  }
  if (s.includes('mba') || s.includes('dba')) return 'MBA / DBA';
  if (
    s.includes('bac+5') || s.includes('bac +5') || s.includes('master') ||
    s.includes('msc') || s.includes('pge') || s.includes('grande ecole') ||
    s.includes('grande école') || s.includes('mastere') || s.includes('visa')
  ) {
    return 'Master';
  }
  if (s.includes('bba') || s.includes('bac+4') || s.includes('bac +4')) {
    return 'BBA';
  }
  if (
    s.includes('bac+3') || s.includes('bac +3') || s.includes('bachelor') ||
    s.includes('licence')
  ) {
    return 'Bachelor';
  }
  if (s.includes('bac+2') || s.includes('bac +2')) return 'Bac+2';
  return raw.trim();
}

function formatLevel(row: OmnesRow): { fr: string; en: string } {
  const label = normalizeDegreeLevel(
    `${row.programFamily} ${row.degreeLevel}`.trim(),
  );
  return { fr: label, en: label };
}

function formatDuration(row: OmnesRow): { fr: string; en: string } {
  const level = row.degreeLevel.toLowerCase();
  if (level.includes('bac+5') || level.includes('bac +5')) {
    return { fr: '5 ans', en: '5 years' };
  }
  if (level.includes('bac+3') || level.includes('bac +3')) {
    return { fr: '3 ans', en: '3 years' };
  }
  if (level.includes('bac+2') || level.includes('bac +2')) {
    return { fr: '2 ans', en: '2 years' };
  }
  return { fr: row.degreeLevel || '—', en: row.degreeLevel || '—' };
}

function formatTuition(row: OmnesRow): { fr: string; en: string } {
  if (row.paymentUpfront == null) {
    return { fr: 'Sur demande', en: 'On request' };
  }
  const upfront = `${Math.round(row.paymentUpfront).toLocaleString('fr-FR')} €`;
  if (row.paymentInstallments != null) {
    const installments = `${Math.round(row.paymentInstallments).toLocaleString('fr-FR')} €`;
    return {
      fr: `${upfront}/an · Échelonné ${installments}`,
      en: `${upfront}/year · Installments ${installments}`,
    };
  }
  return { fr: `${upfront}/an`, en: `${upfront}/year` };
}

function intakeLabel(intakeDate: string | null): string[] {
  if (!intakeDate) return ['Rentrée automne'];
  return [intakeDate];
}

async function ensureFranceCountry() {
  const seed = M5_COUNTRY_SEEDS.find((item) => item.id === FRANCE_COUNTRY_ID);
  if (!seed) {
    throw new Error(`M5 seed missing for country ${FRANCE_COUNTRY_ID}`);
  }

  await prisma.country.upsert({
    where: { id: seed.id },
    update: {},
    create: {
      id: seed.id,
      code: seed.code,
      flagEmoji: seed.flagEmoji,
      nameFr: seed.nameFr,
      nameEn: seed.nameEn,
      taglineFr: seed.taglineFr,
      taglineEn: seed.taglineEn,
      nextIntakeLabelFr: seed.nextIntakeLabelFr,
      nextIntakeLabelEn: seed.nextIntakeLabelEn,
      mainLanguageFr: seed.mainLanguageFr,
      mainLanguageEn: seed.mainLanguageEn,
      whyStudyFr: seed.whyStudyFr,
      whyStudyEn: seed.whyStudyEn,
      marketingDescriptionFr: seed.marketingDescriptionFr,
      marketingDescriptionEn: seed.marketingDescriptionEn,
      whyStudyBulletsFr: seed.whyStudyBulletsFr,
      whyStudyBulletsEn: seed.whyStudyBulletsEn,
      howItWorksFr: seed.howItWorksFr,
      howItWorksEn: seed.howItWorksEn,
      costsOverviewFr: seed.costsOverviewFr,
      costsOverviewEn: seed.costsOverviewEn,
      languageSectionFr: seed.languageSectionFr,
      languageSectionEn: seed.languageSectionEn,
      partnerSchoolsFr: seed.partnerSchoolsFr,
      partnerSchoolsEn: seed.partnerSchoolsEn,
      scholarshipsSectionFr: seed.scholarshipsSectionFr,
      scholarshipsSectionEn: seed.scholarshipsSectionEn,
      whatsAppPrefillFr: seed.whatsAppPrefillFr,
      whatsAppPrefillEn: seed.whatsAppPrefillEn,
      mvpNoteFr: seed.mvpNoteFr,
      mvpNoteEn: seed.mvpNoteEn,
      tuitionRangeFr: seed.tuitionRangeFr,
      tuitionRangeEn: seed.tuitionRangeEn,
      livingCostRangeFr: seed.livingCostRangeFr,
      livingCostRangeEn: seed.livingCostRangeEn,
      visaOverviewFr: seed.visaOverviewFr,
      visaOverviewEn: seed.visaOverviewEn,
      admissionDifficultyFr: seed.admissionDifficultyFr,
      admissionDifficultyEn: seed.admissionDifficultyEn,
      popularFieldIds: seed.popularFieldIds,
      displayOrder: seed.displayOrder,
      isActive: true,
    },
  });
}

async function main() {
  const jsonPath =
    process.argv[2] ??
    path.resolve(__dirname, 'output', 'omnes-programs-normalized.json');

  if (!fs.existsSync(jsonPath)) {
    throw new Error(
      `OMNES JSON not found at ${jsonPath}. Run npm run import:omnes first.`,
    );
  }

  const rows = JSON.parse(fs.readFileSync(jsonPath, 'utf-8')) as OmnesRow[];
  if (!rows.length) throw new Error('OMNES JSON is empty.');

  await ensureFranceCountry();

  // Remove previous OMNES seed so re-runs stay idempotent.
  await prisma.program.deleteMany({
    where: { id: { startsWith: PROGRAM_ID_PREFIX } },
  });
  await prisma.institution.deleteMany({
    where: { id: { startsWith: INSTITUTION_ID_PREFIX } },
  });

  const institutionProgramIds = new Map<string, Set<string>>();
  const institutionMeta = new Map<
    string,
    { school: string; campus: string; levels: Set<string>; intakes: Set<string> }
  >();

  for (const row of rows) {
    const instId = institutionId(row.school, row.campus);
    institutionProgramIds.set(instId, institutionProgramIds.get(instId) ?? new Set());
    institutionProgramIds.get(instId)!.add(programId(row));

    const meta = institutionMeta.get(instId) ?? {
      school: row.school,
      campus: row.campus,
      levels: new Set<string>(),
      intakes: new Set<string>(),
    };
    studyLevelsFor(row).forEach((level) => meta.levels.add(level));
    intakeLabel(row.intakeDate).forEach((intake) => meta.intakes.add(intake));
    institutionMeta.set(instId, meta);
  }

  for (const [instId, meta] of institutionMeta.entries()) {
    const displayName = `${meta.school} — ${meta.campus}`;
    await prisma.institution.create({
      data: {
        id: instId,
        nameFr: displayName,
        nameEn: displayName,
        countryId: FRANCE_COUNTRY_ID,
        locationFr: meta.campus,
        locationEn: meta.campus,
        overviewFr: `Campus ${meta.campus} du réseau ${meta.school} (OMNES Education), partenaire KPB.`,
        overviewEn: `${meta.school} ${meta.campus} campus (OMNES Education), KPB partner.`,
        studyLevels: [...meta.levels],
        tuitionLabelFr: 'Voir programme',
        tuitionLabelEn: 'See program',
        languageRequirementsFr: 'Français ou Anglais selon programme',
        languageRequirementsEn: 'French or English depending on program',
        intakePeriods: [...meta.intakes],
        programIds: [...(institutionProgramIds.get(instId) ?? [])],
        isPartner: true,
      },
    });
  }

  const batchSize = 50;
  for (let i = 0; i < rows.length; i += batchSize) {
    const batch = rows.slice(i, i + batchSize);
    await prisma.$transaction(
      batch.map((row) => {
        const level = formatLevel(row);
        const duration = formatDuration(row);
        const tuition = formatTuition(row);
        const requirementsFr = row.admissionLevel
          ? [row.admissionLevel]
          : [];
        const requirementsEn = requirementsFr;

        return prisma.program.create({
          data: {
            id: programId(row),
            institutionId: institutionId(row.school, row.campus),
            countryId: FRANCE_COUNTRY_ID,
            fieldId: inferFieldId(row),
            nameFr: row.programName,
            nameEn: row.programName,
            levelFr: level.fr,
            levelEn: level.en,
            durationFr: duration.fr,
            durationEn: duration.en,
            tuitionFr: tuition.fr,
            tuitionEn: tuition.en,
            languageFr: row.language,
            languageEn: row.language,
            requirementsFr,
            requirementsEn,
          },
        });
      }),
    );
  }

  const programCount = await prisma.program.count({
    where: { id: { startsWith: PROGRAM_ID_PREFIX } },
  });
  const institutionCount = await prisma.institution.count({
    where: { id: { startsWith: INSTITUTION_ID_PREFIX } },
  });

  // eslint-disable-next-line no-console
  console.log(
    `OMNES seed complete: ${programCount} programs, ${institutionCount} institutions (France / ${FRANCE_COUNTRY_ID}).`,
  );
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
