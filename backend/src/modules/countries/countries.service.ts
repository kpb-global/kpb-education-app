import { Injectable, NotFoundException } from '@nestjs/common';
import type { Country, CountryEligibilityQuiz, Prisma } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { M5_COUNTRY_SEEDS } from './data/m5-countries.seed';
import { scoreCountryQuiz } from './country-quiz.scorer';
import type { EligibilityVerdictKey } from './country-quiz.types';

type CountryWithQuiz = Country & {
  eligibilityQuiz: CountryEligibilityQuiz | null;
};

function mapCountry(
  row: Country,
  quiz?: CountryEligibilityQuiz | null,
) {
  return {
    id: row.id,
    code: row.code,
    flagEmoji: row.flagEmoji,
    name: { fr: row.nameFr, en: row.nameEn },
    tagline: { fr: row.taglineFr, en: row.taglineEn },
    nextIntakeLabel: { fr: row.nextIntakeLabelFr, en: row.nextIntakeLabelEn },
    mainLanguage: { fr: row.mainLanguageFr, en: row.mainLanguageEn },
    whyStudy: { fr: row.whyStudyFr, en: row.whyStudyEn },
    marketingDescription: {
      fr: row.marketingDescriptionFr,
      en: row.marketingDescriptionEn,
    },
    whyStudyBullets: {
      fr: row.whyStudyBulletsFr,
      en: row.whyStudyBulletsEn,
    },
    howItWorks: { fr: row.howItWorksFr, en: row.howItWorksEn },
    costsOverview: { fr: row.costsOverviewFr, en: row.costsOverviewEn },
    languageSection: {
      fr: row.languageSectionFr,
      en: row.languageSectionEn,
    },
    partnerSchools: { fr: row.partnerSchoolsFr, en: row.partnerSchoolsEn },
    scholarshipsSection: {
      fr: row.scholarshipsSectionFr,
      en: row.scholarshipsSectionEn,
    },
    whatsAppPrefill: {
      fr: row.whatsAppPrefillFr,
      en: row.whatsAppPrefillEn,
    },
    mvpNote: { fr: row.mvpNoteFr, en: row.mvpNoteEn },
    tuitionRange: { fr: row.tuitionRangeFr, en: row.tuitionRangeEn },
    livingCostRange: {
      fr: row.livingCostRangeFr,
      en: row.livingCostRangeEn,
    },
    visaOverview: { fr: row.visaOverviewFr, en: row.visaOverviewEn },
    admissionDifficulty: {
      fr: row.admissionDifficultyFr,
      en: row.admissionDifficultyEn,
    },
    popularFieldIds: row.popularFieldIds,
    displayOrder: row.displayOrder,
    isActive: row.isActive,
    nameFr: row.nameFr,
    nameEn: row.nameEn,
    taglineFr: row.taglineFr,
    taglineEn: row.taglineEn,
    nextIntakeLabelFr: row.nextIntakeLabelFr,
    nextIntakeLabelEn: row.nextIntakeLabelEn,
    whyStudyFr: row.whyStudyFr,
    whyStudyEn: row.whyStudyEn,
    tuitionRangeFr: row.tuitionRangeFr,
    tuitionRangeEn: row.tuitionRangeEn,
    livingCostRangeFr: row.livingCostRangeFr,
    livingCostRangeEn: row.livingCostRangeEn,
    visaOverviewFr: row.visaOverviewFr,
    visaOverviewEn: row.visaOverviewEn,
    admissionDifficultyFr: row.admissionDifficultyFr,
    admissionDifficultyEn: row.admissionDifficultyEn,
    ...(quiz
      ? {
          eligibilityQuiz: {
            questions: quiz.questions,
            verdicts: quiz.verdicts,
          },
        }
      : {}),
  };
}

function seedToCountry(seed: (typeof M5_COUNTRY_SEEDS)[number]): CountryWithQuiz {
  const now = new Date();
  return {
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
    createdAt: now,
    updatedAt: now,
    eligibilityQuiz: {
      id: `${seed.id}-quiz`,
      countryId: seed.id,
      questions: seed.quiz.questions as unknown as Prisma.JsonValue,
      verdicts: seed.quiz.verdicts as unknown as Prisma.JsonValue,
      createdAt: now,
      updatedAt: now,
    },
  };
}

@Injectable()
export class CountriesService {
  constructor(private readonly prismaService: PrismaService) {}

  async listCountries(activeOnly = true) {
    const items = await this.prismaService.tryExecute((prisma) =>
      prisma.country.findMany({
        where: activeOnly ? { isActive: true } : undefined,
        orderBy: { displayOrder: 'asc' },
      }),
    );

    if (!items?.length) {
      return {
        items: M5_COUNTRY_SEEDS.map((seed) => mapCountry(seedToCountry(seed))),
      };
    }

    return { items: items.map((row) => mapCountry(row)) };
  }

  async getCountryDetail(countryKey: string) {
    const normalized = countryKey.trim().toLowerCase();
    const row = await this.prismaService.tryExecute((prisma) =>
      prisma.country.findFirst({
        where: {
          OR: [{ id: normalized }, { code: normalized.toUpperCase() }],
        },
        include: { eligibilityQuiz: true },
      }),
    );

    if (row) {
      return mapCountry(row, row.eligibilityQuiz);
    }

    const fallbackSeed = M5_COUNTRY_SEEDS.find(
      (seed) =>
        seed.id === normalized || seed.code.toLowerCase() === normalized,
    );
    if (!fallbackSeed) {
      throw new NotFoundException('Country not found.');
    }

    const fallback = seedToCountry(fallbackSeed);
    return mapCountry(fallback, fallback.eligibilityQuiz);
  }

  async submitQuiz(countryKey: string, answers: Record<string, string>) {
    const detail = await this.getCountryDetail(countryKey);
    const verdictKey = scoreCountryQuiz(detail.id, answers);
    const quiz = detail.eligibilityQuiz as {
      verdicts: Record<
        EligibilityVerdictKey,
        {
          titleFr: string;
          titleEn: string;
          messageFr: string;
          messageEn: string;
          ctaFr: string;
          ctaEn: string;
          alternativeCountryIds?: string[];
        }
      >;
    } | undefined;

    const copy = quiz?.verdicts?.[verdictKey];
    if (!copy) {
      return {
        verdict: verdictKey,
        verdictTitle: verdictKey,
        verdictMessage: '',
        ctaLabel: 'Continuer',
        alternativeCountryIds: [] as string[],
        countryId: detail.id,
      };
    }

    return {
      verdict: verdictKey,
      verdictTitle: copy.titleFr,
      verdictTitleEn: copy.titleEn,
      verdictMessage: copy.messageFr,
      verdictMessageEn: copy.messageEn,
      ctaLabel: copy.ctaFr,
      ctaLabelEn: copy.ctaEn,
      alternativeCountryIds: copy.alternativeCountryIds ?? [],
      countryId: detail.id,
    };
  }
}
