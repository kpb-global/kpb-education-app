import { HttpException, HttpStatus, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CountriesService, seedToCountry } from './countries.service';
import { M5_COUNTRY_SEEDS } from './data/m5-countries.seed';

const franceRow = {
  id: 'france',
  code: 'FR',
  nameFr: 'France',
  nameEn: 'France',
  lastVerifiedAt: new Date('2026-01-15T00:00:00.000Z'),
  sourceUrl: 'https://example.org/france',
  flagEmoji: '🇫🇷',
  taglineFr: '',
  taglineEn: '',
  nextIntakeLabelFr: '',
  nextIntakeLabelEn: '',
  mainLanguageFr: '',
  mainLanguageEn: '',
  whyStudyFr: '',
  whyStudyEn: '',
  marketingDescriptionFr: '',
  marketingDescriptionEn: '',
  whyStudyBulletsFr: [],
  whyStudyBulletsEn: [],
  howItWorksFr: '',
  howItWorksEn: '',
  costsOverviewFr: '',
  costsOverviewEn: '',
  languageSectionFr: '',
  languageSectionEn: '',
  partnerSchoolsFr: '',
  partnerSchoolsEn: '',
  scholarshipsSectionFr: '',
  scholarshipsSectionEn: '',
  whatsAppPrefillFr: '',
  whatsAppPrefillEn: '',
  mvpNoteFr: '',
  mvpNoteEn: '',
  tuitionRangeFr: '',
  tuitionRangeEn: '',
  livingCostRangeFr: '',
  livingCostRangeEn: '',
  visaOverviewFr: '',
  visaOverviewEn: '',
  admissionDifficultyFr: '',
  admissionDifficultyEn: '',
  popularFieldIds: [],
  displayOrder: 1,
  isActive: true,
};

describe('CountriesService degraded mode (TST-T10)', () => {
  const previousNodeEnv = process.env.NODE_ENV;
  const previousFallbackFlag = process.env.KPB_CATALOG_MOCK_FALLBACK;

  afterEach(() => {
    process.env.NODE_ENV = previousNodeEnv;
    if (previousFallbackFlag === undefined) {
      delete process.env.KPB_CATALOG_MOCK_FALLBACK;
    } else {
      process.env.KPB_CATALOG_MOCK_FALLBACK = previousFallbackFlag;
    }
  });

  function makeService(opts: {
    isEnabled: boolean;
    execute?: jest.Mock;
  }) {
    const prisma = {
      isEnabled: opts.isEnabled,
      execute: opts.execute ?? jest.fn(),
    } as unknown as PrismaService;
    return new CountriesService(prisma);
  }

  it('tags database rows with source=database', async () => {
    process.env.NODE_ENV = 'test';
    const execute = jest.fn().mockImplementation(async (op: (c: unknown) => unknown) =>
      op({
        country: { findMany: async () => [franceRow] },
      }),
    );
    const service = makeService({ isEnabled: true, execute });
    const result = await service.listCountries();
    expect(result.source).toBe('database');
    expect(result.items).toHaveLength(1);
    expect(result.items[0].id).toBe('france');
    expect(result.items[0].lastVerifiedAt).toEqual(franceRow.lastVerifiedAt);
  });

  it('serves M5 seeds tagged source=mock when the DB is down outside production', async () => {
    process.env.NODE_ENV = 'test';
    delete process.env.KPB_CATALOG_MOCK_FALLBACK;
    const service = makeService({ isEnabled: false });
    const result = await service.listCountries();
    expect(result.source).toBe('mock');
    expect(result.items.length).toBeGreaterThan(0);
    expect(result.items[0].lastVerifiedAt).toBeNull();
    expect(result.items[0].sourceUrl).toBeNull();
  });

  it('answers 503 COUNTRIES_UNAVAILABLE in production instead of seeds', async () => {
    process.env.NODE_ENV = 'production';
    const service = makeService({ isEnabled: false });
    try {
      await service.listCountries();
      fail('expected 503');
    } catch (error) {
      expect(error).toBeInstanceOf(HttpException);
      expect((error as HttpException).getStatus()).toBe(
        HttpStatus.SERVICE_UNAVAILABLE,
      );
      expect((error as HttpException).getResponse()).toMatchObject({
        code: 'COUNTRIES_UNAVAILABLE',
      });
    }
  });

  it('does not dress a seed up as a verified fiche', () => {
    const seeded = seedToCountry(M5_COUNTRY_SEEDS[0]);
    expect(seeded.lastVerifiedAt).toBeNull();
    expect(seeded.sourceUrl).toBeNull();
    expect(seeded.verifiedById).toBeNull();
    expect(seeded.verifiedByName).toBeNull();
  });

  it('404s a missing country in production rather than inventing a seed', async () => {
    process.env.NODE_ENV = 'production';
    const execute = jest.fn().mockImplementation(async (op: (c: unknown) => unknown) =>
      op({
        country: { findFirst: async () => null },
      }),
    );
    const service = makeService({ isEnabled: true, execute });
    await expect(service.getCountryDetail('narnia')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });
});
