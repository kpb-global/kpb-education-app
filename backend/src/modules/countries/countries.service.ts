import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import type { Country, CountryEligibilityQuiz, Prisma, PrismaClient } from '@prisma/client';

import {
  CATALOG_SOURCE_DATABASE,
  CATALOG_SOURCE_MOCK,
  degradedServiceUnavailable,
  isMockCatalogFallbackAllowed,
  type CatalogSource,
} from '../../common/degraded-mode';
import { PrismaService } from '../prisma/prisma.service';
import { M5_COUNTRY_SEEDS } from './data/m5-countries.seed';

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
    lastVerifiedAt: row.lastVerifiedAt,
    sourceUrl: row.sourceUrl,
    verifiedById: row.verifiedById,
    verifiedByName: row.verifiedByName,
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

/**
 * Bundled M5 fixtures. lastVerifiedAt and sourceUrl stay null on purpose:
 * a seed must never look like a counsellor-verified fiche (TST-T10).
 */
export function seedToCountry(
  seed: (typeof M5_COUNTRY_SEEDS)[number],
): CountryWithQuiz {
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
    lastVerifiedAt: null,
    sourceUrl: null,
    verifiedById: null,
    verifiedByName: null,
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
  private readonly logger = new Logger(CountriesService.name);

  constructor(private readonly prismaService: PrismaService) {}

  async listCountries(activeOnly = true): Promise<{
    items: ReturnType<typeof mapCountry>[];
    source: CatalogSource;
  }> {
    const items = await this.readOrDegrade('countries', (prisma) =>
      prisma.country.findMany({
        where: activeOnly ? { isActive: true } : undefined,
        orderBy: { displayOrder: 'asc' },
      }),
    );

    if (items === null) {
      return {
        items: M5_COUNTRY_SEEDS.map((seed) => mapCountry(seedToCountry(seed))),
        source: CATALOG_SOURCE_MOCK,
      };
    }

    return {
      items: items.map((row) => mapCountry(row)),
      source: CATALOG_SOURCE_DATABASE,
    };
  }

  async getCountryDetail(countryKey: string) {
    const normalized = countryKey.trim().toLowerCase();
    const row = await this.readOrDegrade('country-detail', (prisma) =>
      prisma.country.findFirst({
        where: {
          OR: [{ id: normalized }, { code: normalized.toUpperCase() }],
        },
        include: { eligibilityQuiz: true },
      }),
    );

    if (row) {
      return {
        ...mapCountry(row, row.eligibilityQuiz),
        source: CATALOG_SOURCE_DATABASE,
      };
    }

    // `null` here is either "DB down / not configured" (already thrown in
    // production by readOrDegrade) or "row not in Postgres". Serving an M5
    // seed as a live fiche is only allowed outside production.
    if (!isMockCatalogFallbackAllowed()) {
      throw new NotFoundException('Country not found.');
    }

    const fallbackSeed = M5_COUNTRY_SEEDS.find(
      (seed) =>
        seed.id === normalized || seed.code.toLowerCase() === normalized,
    );
    if (!fallbackSeed) {
      throw new NotFoundException('Country not found.');
    }

    const fallback = seedToCountry(fallbackSeed);
    return {
      ...mapCountry(fallback, fallback.eligibilityQuiz),
      source: CATALOG_SOURCE_MOCK,
    };
  }

  /**
   * Same policy as CatalogService: production never answers with fixtures.
   * `null` means the caller may serve M5 seeds tagged `source: mock`.
   */
  private async readOrDegrade<T>(
    resource: string,
    operation: (prisma: PrismaClient) => Promise<T>,
  ): Promise<T | null> {
    if (!this.prismaService.isEnabled) {
      return this.degrade(resource, 'DATABASE_NOT_CONFIGURED');
    }
    try {
      // `execute` rethrows on query errors. A `null` return here is the
      // operation's own result (e.g. findFirst miss), not "DB down".
      return await this.prismaService.execute(operation);
    } catch {
      return this.degrade(resource, 'DATABASE_ERROR');
    }
  }

  private degrade(resource: string, reason: string): null {
    if (!isMockCatalogFallbackAllowed()) {
      this.logger.error(
        `Countries "${resource}" is unavailable (${reason}). Refusing to serve ` +
          'M5 seeds; answering 503 COUNTRIES_UNAVAILABLE.',
      );
      throw degradedServiceUnavailable(
        'COUNTRIES_UNAVAILABLE',
        'The countries catalog is temporarily unavailable.',
        resource,
      );
    }
    this.logger.warn(
      `Countries "${resource}" is unavailable (${reason}). Serving M5 seeds ` +
        'tagged source="mock" (non-production only).',
    );
    return null;
  }

  // submitQuiz + scoreCountryQuiz removed (KPB-62): the per-country eligibility
  // verdict is computed client-side by the single EligibilityEngine. The quiz
  // questions + verdict copy are still served via getCountryDetail.
}
