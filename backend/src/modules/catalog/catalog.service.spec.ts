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
    const countries = [{ id: 'france', name: { fr: 'France', en: 'France' } }];
    mockPrismaService.tryExecute.mockResolvedValueOnce(countries);

    const result = await service.getCountries();

    expect(result.items).toEqual(countries);
  });

  it('falls back to mock scholarships when prisma returns null', async () => {
    mockPrismaService.tryExecute.mockResolvedValueOnce(null);

    const result = await service.getScholarships();

    expect(result.items).toEqual(mockCatalog.scholarships);
  });
});
