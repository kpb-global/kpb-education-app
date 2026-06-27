import { loadEnvFile } from 'node:process';

import { PrismaClient, Prisma } from '@prisma/client';

import { M5_COUNTRY_SEEDS } from '../src/modules/countries/data/m5-countries.seed';

loadEnvFile?.('.env');

const prisma = new PrismaClient();

async function main() {
  for (const seed of M5_COUNTRY_SEEDS) {
    await prisma.country.upsert({
      where: { id: seed.id },
      update: {
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
        lastVerifiedAt: seed.lastVerifiedAt
          ? new Date(seed.lastVerifiedAt)
          : null,
        sourceUrl: seed.sourceUrl ?? null,
      },
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
        lastVerifiedAt: seed.lastVerifiedAt
          ? new Date(seed.lastVerifiedAt)
          : null,
        sourceUrl: seed.sourceUrl ?? null,
      },
    });

    await prisma.countryEligibilityQuiz.upsert({
      where: { countryId: seed.id },
      update: {
        questions: seed.quiz.questions as unknown as Prisma.InputJsonValue,
        verdicts: seed.quiz.verdicts as unknown as Prisma.InputJsonValue,
      },
      create: {
        countryId: seed.id,
        questions: seed.quiz.questions as unknown as Prisma.InputJsonValue,
        verdicts: seed.quiz.verdicts as unknown as Prisma.InputJsonValue,
      },
    });
  }

  // Deactivate legacy duplicate ids if present.
  await prisma.country.updateMany({
    where: { id: { in: ['france', 'canada', 'uk', 'germany', 'spain'] } },
    data: { isActive: false },
  });

  const count = await prisma.country.count({ where: { isActive: true } });
  // eslint-disable-next-line no-console
  console.log(`M5 countries seeded. Active countries: ${count}`);
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
