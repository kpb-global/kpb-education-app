import {
  BadRequestException,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';

import { AdminCatalogService } from './admin-catalog.service';
import { PrismaService } from '../prisma/prisma.service';

type Entity = 'program' | 'institution' | 'scholarship' | 'country' | 'field';

function makeDb() {
  const entity = () => ({
    create: jest.fn(),
    update: jest.fn(),
    delete: jest.fn(),
    count: jest.fn(),
    findMany: jest.fn(),
  });
  return {
    program: entity(),
    institution: entity(),
    scholarship: entity(),
    country: entity(),
    field: entity(),
    $transaction: jest.fn(),
  } as Record<Entity, ReturnType<typeof entity>> & {
    $transaction: jest.Mock;
  };
}

describe('AdminCatalogService', () => {
  let service: AdminCatalogService;
  let db: ReturnType<typeof makeDb>;
  const prismaMock = {
    isEnabled: true,
    execute: jest.fn(),
  };

  beforeEach(async () => {
    db = makeDb();
    prismaMock.isEnabled = true;
    prismaMock.execute.mockImplementation(
      (operation: (client: unknown) => unknown) => operation(db),
    );

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AdminCatalogService,
        { provide: PrismaService, useValue: prismaMock },
      ],
    }).compile();

    service = module.get<AdminCatalogService>(AdminCatalogService);
    jest.clearAllMocks();
    prismaMock.execute.mockImplementation(
      (operation: (client: unknown) => unknown) => operation(db),
    );
  });

  // ── Programs ───────────────────────────────────────────────────────────
  it('normalizes the degree level and fills defaults on createProgram', async () => {
    db.program.create.mockResolvedValue({ id: 'p1' });

    await service.createProgram({
      institutionId: 'i1',
      countryId: 'c1',
      fieldId: 'f1',
      nameFr: 'Programme Grande École',
      levelFr: 'MSc · Bac+5',
    });

    const data = db.program.create.mock.calls[0][0].data;
    expect(data.levelFr).toBe('Master');
    expect(data.nameEn).toBe('Programme Grande École'); // falls back to FR
    expect(data.requirementsFr).toEqual([]);
  });

  it('rejects createProgram when a required field is missing', async () => {
    await expect(
      service.createProgram({ institutionId: 'i1', countryId: 'c1' }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(db.program.create).not.toHaveBeenCalled();
  });

  it('only updates provided fields and normalizes level on updateProgram', async () => {
    db.program.update.mockResolvedValue({ id: 'p1' });

    await service.updateProgram('p1', { nameFr: 'X', levelFr: 'BBA' });

    const arg = db.program.update.mock.calls[0][0];
    expect(arg.where).toEqual({ id: 'p1' });
    expect(arg.data).toEqual({ nameFr: 'X', levelFr: 'BBA' });
  });

  it('maps a Prisma P2025 to NotFoundException on updateProgram', async () => {
    db.program.update.mockRejectedValue({ code: 'P2025' });

    await expect(
      service.updateProgram('missing', { nameFr: 'X' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('returns a deleted marker on deleteProgram', async () => {
    db.program.delete.mockResolvedValue({ id: 'p1' });

    await expect(service.deleteProgram('p1')).resolves.toEqual({
      id: 'p1',
      deleted: true,
    });
  });

  // ── Institutions ───────────────────────────────────────────────────────
  it('normalizes every study level on createInstitution', async () => {
    db.institution.create.mockResolvedValue({ id: 'i1' });

    await service.createInstitution({
      nameFr: 'ECE Lyon',
      countryId: 'c1',
      studyLevels: ['MSc · Bac+5', 'Bac+3'],
    });

    const data = db.institution.create.mock.calls[0][0].data;
    expect(data.studyLevels).toEqual(['Master', 'Bachelor']);
  });

  it('refuses to delete an institution that still has programs', async () => {
    db.program.count.mockResolvedValue(3);

    await expect(service.deleteInstitution('i1')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(db.institution.delete).not.toHaveBeenCalled();
  });

  it('deletes an institution with no programs', async () => {
    db.program.count.mockResolvedValue(0);
    db.institution.delete.mockResolvedValue({ id: 'i1' });

    await expect(service.deleteInstitution('i1')).resolves.toEqual({
      id: 'i1',
      deleted: true,
    });
  });

  // ── Scholarships ─────────────────────────────────────────────────────────
  it('creates a manual scholarship without a sourceKey and with defaults', async () => {
    db.scholarship.create.mockResolvedValue({ id: 's1' });

    await service.createScholarship({ nameFr: 'McCall MacBain', countryId: 'c1' });

    const data = db.scholarship.create.mock.calls[0][0].data;
    expect(data.sourceKey).toBeUndefined();
    expect(data.baseMatch).toBe(30);
    expect(data.isActive).toBe(true);
  });

  // ── Countries ────────────────────────────────────────────────────────────
  it('refuses to delete a country still referenced by institutions', async () => {
    db.program.count.mockResolvedValue(0);
    db.institution.count.mockResolvedValue(1);

    await expect(service.deleteCountry('c1')).rejects.toBeInstanceOf(
      BadRequestException,
    );
    expect(db.country.delete).not.toHaveBeenCalled();
  });

  // ── Guards / read ──────────────────────────────────────────────────────
  it('throws ServiceUnavailable when the database is disabled', async () => {
    prismaMock.isEnabled = false;

    await expect(
      service.createProgram({
        institutionId: 'i1',
        countryId: 'c1',
        fieldId: 'f1',
        nameFr: 'X',
      }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('clamps the program list limit and returns the paginated shape', async () => {
    db.$transaction.mockResolvedValue([[{ id: 'p1' }], 1]);

    const result = await service.listPrograms({ limit: 9999, q: 'business' });

    expect(result).toEqual({ items: [{ id: 'p1' }], total: 1, limit: 500, offset: 0 });
  });

  it('returns scholarships from listScholarships', async () => {
    db.scholarship.findMany.mockResolvedValue([{ id: 's1' }]);

    const result = await service.listScholarships();

    expect(result).toEqual({ items: [{ id: 's1' }], total: 1 });
  });
});
