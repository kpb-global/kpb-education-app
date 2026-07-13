import { BadRequestException, NotFoundException } from '@nestjs/common';

import { CasesService } from '../cases/cases.service';
import { PrismaService } from '../prisma/prisma.service';
import { CommercialService } from './commercial.service';

/**
 * Feature D — per-document review. The counsellor sets a verdict on an
 * uploaded case document; the service validates the status, stamps who/when,
 * and returns the updated document. Invalid statuses and unknown ids are
 * rejected without touching the row.
 */
describe('CommercialService — reviewDocument', () => {
  const existingDoc = {
    id: 'doc-1',
    caseId: 'case-1',
    title: 'Passeport',
    isProvided: true,
    uploadedAt: new Date('2026-07-10T09:00:00.000Z'),
    reviewStatus: null as string | null,
    reviewedByName: null as string | null,
    reviewedAt: null as Date | null,
  };

  function makeService(opts: { existing?: unknown } = {}) {
    const updates: Array<Record<string, unknown>> = [];
    const client = {
      caseDocument: {
        findUnique: async () =>
          'existing' in opts ? opts.existing : existingDoc,
        update: async ({
          data,
        }: {
          where: { id: string };
          data: Record<string, unknown>;
        }) => {
          updates.push(data);
          return { ...existingDoc, ...data };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const cases = {} as unknown as CasesService;
    return { service: new CommercialService(prisma, cases), updates };
  }

  it('records a valid verdict and stamps reviewer + timestamp', async () => {
    const { service, updates } = makeService();
    const result = await service.reviewDocument('doc-1', 'validated', 'Idriss');

    expect(updates).toHaveLength(1);
    expect(updates[0].reviewStatus).toBe('validated');
    expect(updates[0].reviewedByName).toBe('Idriss');
    expect(updates[0].reviewedAt).toBeInstanceOf(Date);

    expect(result.reviewStatus).toBe('validated');
    expect(result.reviewedByName).toBe('Idriss');
    expect(result.reviewedAt).not.toBeNull();
    expect(result.id).toBe('doc-1');
  });

  it.each(['redo', 'doubtful'])('accepts the "%s" verdict', async (status) => {
    const { service, updates } = makeService();
    const result = await service.reviewDocument('doc-1', status, 'Idriss');
    expect(updates[0].reviewStatus).toBe(status);
    expect(result.reviewStatus).toBe(status);
  });

  it('rejects an invalid status without updating the document', async () => {
    const { service, updates } = makeService();
    await expect(
      service.reviewDocument('doc-1', 'approved', 'Idriss'),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(updates).toHaveLength(0);
  });

  it('rejects an unknown document id', async () => {
    const { service } = makeService({ existing: null });
    await expect(
      service.reviewDocument('missing', 'validated', 'Idriss'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
