import { Test, TestingModule } from '@nestjs/testing';

import { CatalogService } from './catalog.service';
import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';

const mockPrismaService = {
  tryExecute: jest.fn(),
};

describe('CatalogService', () => {
  let service: CatalogService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CatalogService,
        {
          provide: PrismaService,
          useValue: mockPrismaService,
        },
      ],
    }).compile();

    service = module.get<CatalogService>(CatalogService);
    jest.clearAllMocks();
  });

  it('falls back to mock catalog fields when database is unavailable', async () => {
    mockPrismaService.tryExecute.mockResolvedValueOnce(null);

    const result = await service.getFields();

    expect(result.items).toEqual(mockCatalog.fields);
  });

  it('returns database countries when available', async () => {
    const countries = [
      {
        id: 'france',
        code: 'FR',
        flagEmoji: '🇫🇷',
        nameFr: 'France',
        nameEn: 'France',
        taglineFr: 'Étudier en France',
        taglineEn: 'Study in France',
        nextIntakeLabelFr: 'Septembre',
        nextIntakeLabelEn: 'September',
        mainLanguageFr: 'Français',
        mainLanguageEn: 'French',
        whyStudyFr: 'Qualité académique',
        whyStudyEn: 'Academic quality',
        marketingDescriptionFr: 'Description',
        marketingDescriptionEn: 'Description',
        whyStudyBulletsFr: ['Bon réseau'],
        whyStudyBulletsEn: ['Strong network'],
        howItWorksFr: 'Processus',
        howItWorksEn: 'Process',
        costsOverviewFr: 'Coûts',
        costsOverviewEn: 'Costs',
        languageSectionFr: 'Langue',
        languageSectionEn: 'Language',
        partnerSchoolsFr: 'Écoles',
        partnerSchoolsEn: 'Schools',
        scholarshipsSectionFr: 'Bourses',
        scholarshipsSectionEn: 'Scholarships',
        whatsAppPrefillFr: 'Bonjour',
        whatsAppPrefillEn: 'Hello',
        mvpNoteFr: 'Note',
        mvpNoteEn: 'Note',
        tuitionRangeFr: '3 000 - 8 000 €',
        tuitionRangeEn: '€3,000 - €8,000',
        livingCostRangeFr: '700 - 1 000 €',
        livingCostRangeEn: '€700 - €1,000',
        visaOverviewFr: 'Visa étudiant',
        visaOverviewEn: 'Student visa',
        admissionDifficultyFr: 'Moyenne',
        admissionDifficultyEn: 'Medium',
        popularFieldIds: ['d01'],
        displayOrder: 1,
        isActive: true,
      },
    ];
    mockPrismaService.tryExecute.mockResolvedValueOnce(countries);

    const result = await service.getCountries();

    expect(result.items).toHaveLength(1);
    expect(result.items[0]).toMatchObject({
      id: 'france',
      code: 'FR',
      flagEmoji: '🇫🇷',
      name: { fr: 'France', en: 'France' },
      tagline: { fr: 'Étudier en France', en: 'Study in France' },
      popularFieldIds: ['d01'],
      displayOrder: 1,
      isActive: true,
    });
  });

  it('falls back to mock scholarships when prisma returns null', async () => {
    mockPrismaService.tryExecute.mockResolvedValueOnce(null);

    const result = await service.getScholarships();

    expect(result.items).toEqual(mockCatalog.scholarships);
  });
});
