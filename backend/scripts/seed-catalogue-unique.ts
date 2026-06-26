/**
 * Seeds the "catalogue unique" GENERAL (non-partner) catalogue into Postgres:
 *   - d01..d12 fields (taxonomy used by these programs, the orientation engine
 *     and the mobile app — the base mock-catalog only seeds 3 demo fields)
 *   - Senegal country (authored; the deliverable only carried name/iso/currency)
 *   - 53 institutions + 212 programs across canada/germany/morocco/senegal/uk/usa
 *
 * Partner schools and their 94 programs are intentionally NOT seeded here — they
 * already live in src/modules/catalog/data/partner-schools.seed.ts.
 *
 * Idempotent: every record is upserted by id, so re-running is safe.
 *
 * Usage:
 *   npm run seed:catalogue-unique
 *   ts-node scripts/seed-catalogue-unique.ts
 */
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  catalogueUniqueInstitutions,
  catalogueUniquePrograms,
} from '../src/common/data/catalogue-unique.seed';
import { ORIENTATION_FIELDS } from '../src/modules/orientation/orientation-fields.data';

loadEnvFile?.('.env');

const prisma = new PrismaClient();

// The catalogue-unique deliverable was authored with human-readable country ids
// (canada/germany/morocco/uk), but the canonical M5 countries use ISO codes
// (can/deu/mar/gbr). Without this remap the institutions/programs link to a
// non-existent country (germany, morocco → orphaned) or to the inactive legacy
// rows (canada, uk), so they never surface under their active country page.
// usa and senegal already match active country ids, so they pass through.
const COUNTRY_ID_REMAP: Record<string, string> = {
  morocco: 'mar',
  germany: 'deu',
  canada: 'can',
  uk: 'gbr',
};
const canonicalCountryId = (id: string): string => COUNTRY_ID_REMAP[id] ?? id;

// Senegal — authored locally (FR primary). Refine marketing copy as needed.
const SENEGAL = {
  code: 'SN',
  flagEmoji: '🇸🇳',
  nameFr: 'Sénégal',
  nameEn: 'Senegal',
  taglineFr: 'Étudier près de chez soi, dans un hub francophone en pleine croissance',
  taglineEn: 'Study close to home, in a fast-growing Francophone hub',
  nextIntakeLabelFr: 'Rentrée septembre 2026',
  nextIntakeLabelEn: 'September 2026 intake',
  mainLanguageFr: 'Français',
  mainLanguageEn: 'French',
  whyStudyFr:
    "Le Sénégal abrite un secteur privé de l'enseignement supérieur dynamique, surtout à Dakar, avec des écoles de management, de technologie et de communication reconnues dans la sous-région.",
  whyStudyEn:
    'Senegal has a dynamic private higher-education sector, especially in Dakar, with management, technology and communication schools well known across the region.',
  marketingDescriptionFr:
    "Une option d'études de qualité, proche culturellement et financièrement accessible, idéale pour démarrer un parcours avant une éventuelle mobilité internationale.",
  marketingDescriptionEn:
    'A quality study option that is culturally close and financially accessible — ideal to start a path before a possible international move.',
  whyStudyBulletsFr: [
    'Proximité géographique et culturelle',
    'Frais de scolarité abordables en zone XOF',
    'Écoles privées orientées employabilité',
  ],
  whyStudyBulletsEn: [
    'Geographic and cultural proximity',
    'Affordable tuition in the XOF zone',
    'Employability-focused private schools',
  ],
  costsOverviewFr:
    'Frais de scolarité et coût de la vie nettement inférieurs aux destinations européennes ou nord-américaines.',
  costsOverviewEn:
    'Tuition and living costs are well below European or North American destinations.',
  languageSectionFr: 'Enseignement majoritairement en français ; quelques programmes en anglais.',
  languageSectionEn: 'Teaching is mostly in French; a few programs are in English.',
  partnerSchoolsFr: '',
  partnerSchoolsEn: '',
  scholarshipsSectionFr: 'Bourses et facilités de paiement selon les établissements (à confirmer).',
  scholarshipsSectionEn: 'Scholarships and payment plans vary by institution (to be confirmed).',
  whatsAppPrefillFr:
    'Bonjour KPB Education, je souhaite être accompagné(e) pour étudier au Sénégal.',
  whatsAppPrefillEn:
    'Hello KPB Education, I would like guidance to study in Senegal.',
  tuitionRangeFr: '800 000 – 2 500 000 XOF/an (indicatif)',
  tuitionRangeEn: 'XOF 800,000 – 2,500,000/yr (indicative)',
  livingCostRangeFr: '100 000 – 250 000 XOF/mois (indicatif)',
  livingCostRangeEn: 'XOF 100,000 – 250,000/month (indicative)',
  visaOverviewFr:
    "Pas de visa étudiant requis pour les ressortissants de la CEDEAO ; titre de séjour selon la nationalité.",
  visaOverviewEn:
    'No student visa required for ECOWAS nationals; residence permit depending on nationality.',
  admissionDifficultyFr: 'Accessible (dossier + niveau requis selon le programme)',
  admissionDifficultyEn: 'Accessible (application + program-specific requirements)',
  popularFieldIds: ['d02', 'd01', 'd06'],
  displayOrder: 50,
  isActive: true,
};

async function main() {
  // 1) Field taxonomy d01..d12 (mapped from the orientation field metadata).
  for (const f of ORIENTATION_FIELDS) {
    const data = {
      nameFr: f.nameFr,
      nameEn: f.nameEn,
      descriptionFr: '',
      descriptionEn: '',
      subjectsFr: [],
      subjectsEn: [],
      careersFr: f.sampleJobsFr ?? [],
      careersEn: f.sampleJobsEn ?? [],
      dailyLifeFr: [],
      dailyLifeEn: [],
      skillsFr: [],
      skillsEn: [],
      personalityTraitsFr: [],
      personalityTraitsEn: [],
      relatedCountryIds: [],
      relatedScholarshipIds: [],
    };
    await prisma.field.upsert({
      where: { id: f.id },
      update: data,
      create: { id: f.id, ...data },
    });
  }

  // 2) Senegal country.
  await prisma.country.upsert({
    where: { id: 'senegal' },
    update: SENEGAL,
    create: { id: 'senegal', ...SENEGAL },
  });

  // 3) Institutions (countryId remapped to the canonical M5 ISO id).
  for (const inst of catalogueUniqueInstitutions) {
    const data = { ...inst, countryId: canonicalCountryId(inst.countryId) };
    await prisma.institution.upsert({
      where: { id: inst.id },
      update: data,
      create: data,
    });
  }

  // 4) Programs (countryId remapped to the canonical M5 ISO id).
  for (const prog of catalogueUniquePrograms) {
    const data = { ...prog, countryId: canonicalCountryId(prog.countryId) };
    await prisma.program.upsert({
      where: { id: prog.id },
      update: data,
      create: data,
    });
  }

  console.log(
    `Seeded catalogue unique: ${ORIENTATION_FIELDS.length} fields, ` +
      `1 country (senegal), ${catalogueUniqueInstitutions.length} institutions, ` +
      `${catalogueUniquePrograms.length} programs.`,
  );
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
