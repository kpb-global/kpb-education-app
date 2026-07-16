import { ModuleRef } from '@nestjs/core';
import { NotFoundException } from '@nestjs/common';

import { OneSignalSenderService } from '../notifications/onesignal-sender.service';
import { PrismaService } from '../prisma/prisma.service';
import { CasesService } from './cases.service';

function makeService(): CasesService {
  const prisma = {
    isEnabled: true,
    execute: async (fn: (p: any) => Promise<any>) => {
      return fn({
        $transaction: async (fn2: (tx: any) => Promise<any>) => {
          const msg = { id: 'msg-1', senderName: '', senderRole: '', body: '', createdAt: new Date() };
          return fn2({
            caseMessage: {
              create: async ({ data }: { data: any }) => ({ ...msg, ...data }),
            },
            caseTimelineEvent: { create: async () => ({}) },
            case: {
              findUnique: async () => ({ id: 'case-1', userId: 'user-1', status: 'submitted', updatedAt: new Date() }),
              update: async () => ({}),
            },
          });
        },
      });
    },
    tryExecute: async () => null,
  } as unknown as PrismaService;

  const push = {
    sendToUser: async () => {},
  } as unknown as OneSignalSenderService;

  // Stub requireDbCase to succeed for 'case-1' owned by 'user-1'
  const moduleRef = { get: () => null } as unknown as ModuleRef;

  const svc = new CasesService(prisma, moduleRef, push);

  // Patch requireDbCase so the test doesn't need a real Prisma setup
  (svc as any).requireDbCase = async (_id: string, ownerUserId?: string) => {
    if (ownerUserId && ownerUserId !== 'user-1') {
      throw new Error('not found');
    }
    return { id: 'case-1', userId: 'user-1', status: 'submitted' };
  };

  return svc;
}

describe('CasesService — createMessage role enforcement', () => {
  it('stores senderRole as "student" regardless of input when called from the student path', async () => {
    const svc = makeService();
    const result = await svc.createMessage(
      'case-1',
      { body: 'hello', senderRole: 'advisor', senderName: 'KPB Advisor' },
      'user-1',
    );
    expect(result.senderRole).toBe('student');
  });
});

describe('CasesService — referral crediting is fire-and-forget (KPB-77)', () => {
  it('still returns the created case even when crediting throws', async () => {
    const prisma = {
      isEnabled: true,
      // create() awaits this and treats the result as the persisted case.
      execute: async () => ({ id: 'case-1' }),
    } as unknown as PrismaService;
    const push = { sendToUser: async () => {} } as unknown as OneSignalSenderService;
    // The credits service blows up — the case path must not.
    const moduleRef = {
      get: () => ({
        creditReferrerForFirstCase: async () => {
          throw new Error('boom');
        },
      }),
    } as unknown as ModuleRef;

    const svc = new CasesService(prisma, moduleRef, push);
    (svc as any).mapDbCase = () => ({ id: 'case-1', assignedAdvisorName: 'KPB' });

    const result = await svc.create(
      { type: 'study_abroad', title: 'x', description: 'y' } as any,
      'user-1',
    );
    expect(result.id).toBe('case-1');
  });
});

describe('CasesService — private document ownership', () => {
  it('queries a document through both the case id and its student owner', async () => {
    let receivedWhere: any;
    const prisma = {
      isEnabled: true,
      execute: async (operation: (client: any) => Promise<any>) =>
        operation({
          caseDocument: {
            findFirst: async ({ where }: { where: any }) => {
              receivedWhere = where;
              return {
                id: 'doc-1',
                title: 'Passport',
                fileUrl: 'storage://2026-07-11/123e4567-e89b-12d3-a456-426614174000.pdf',
              };
            },
          },
        }),
    } as unknown as PrismaService;
    const service = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as OneSignalSenderService,
    );

    await expect(
      service.getOwnedDocument('case-1', 'doc-1', 'student-1'),
    ).resolves.toMatchObject({ id: 'doc-1' });
    expect(receivedWhere).toEqual({
      id: 'doc-1',
      caseId: 'case-1',
      case: { userId: 'student-1' },
    });
  });

  it('allows only an assigned counsellor or administrator to read document bytes', async () => {
    const prisma = {
      isEnabled: true,
      execute: async (operation: (client: any) => Promise<any>) =>
        operation({
          caseDocument: {
            findFirst: async () => ({
              id: 'doc-1',
              title: 'Passport',
              fileUrl: 'storage://2026-07-11/123e4567-e89b-12d3-a456-426614174000.pdf',
              case: { assignedAdvisorName: 'Awa KPB' },
            }),
          },
        }),
    } as unknown as PrismaService;
    const service = new CasesService(
      prisma,
      { get: () => null } as unknown as ModuleRef,
      { sendToUser: async () => {} } as unknown as OneSignalSenderService,
    );

    await expect(
      service.getInternalDocument('case-1', 'doc-1', {
        role: 'counselor',
        fullName: 'awa kpb',
      }),
    ).resolves.toMatchObject({ id: 'doc-1' });
    await expect(
      service.getInternalDocument('case-1', 'doc-1', {
        role: 'counselor',
        fullName: 'Other advisor',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
