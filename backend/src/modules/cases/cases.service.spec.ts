import { ModuleRef } from '@nestjs/core';

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
