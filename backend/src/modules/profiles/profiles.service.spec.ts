import { PrismaService } from '../prisma/prisma.service';
import { ProfilesService } from './profiles.service';

/**
 * Guards the GDPR / store-required account deletion (KPB-67): the purge must run
 * as one transaction in FK-safe order (case children → case-referencing rows →
 * cases → other user-owned rows → profile last), and must not delete the
 * Supabase auth identity unless the service-role secret is configured.
 */
describe('ProfilesService — account deletion & export', () => {
  const MODELS = [
    'userProfile',
    'case',
    'caseMessage',
    'caseTimelineEvent',
    'caseTask',
    'caseDocument',
    'caseInternalNote',
    'notificationDelivery',
    'appointment',
    'servicePurchase',
    'paymentIntent',
    'savedItem',
    'academyPurchase',
    'salonRegistration',
    'coachConversation',
    'orientationSession',
    'parentChildLink',
    'deviceToken',
    'partnerLead',
    'studentCredential',
  ] as const;

  function makeFakePrisma(profile: unknown) {
    const calls: string[] = [];
    const client: Record<string, unknown> = {
      $transaction: async (ops: unknown[]) => ops,
    };
    for (const model of MODELS) {
      client[model] = {
        findUnique: async () => (model === 'userProfile' ? profile : null),
        findMany: async () => [],
        deleteMany: () => {
          calls.push(`${model}.deleteMany`);
          return { __op: `${model}.deleteMany` };
        },
        delete: () => {
          calls.push(`${model}.delete`);
          return { __op: `${model}.delete` };
        },
      };
    }
    // magicLinkToken is keyed by email and only ever deleteMany'd.
    client.magicLinkToken = {
      deleteMany: () => {
        calls.push('magicLinkToken.deleteMany');
        return { __op: 'magicLinkToken.deleteMany' };
      },
    };
    return { client, calls };
  }

  beforeEach(() => {
    delete process.env.SUPABASE_URL;
    delete process.env.SUPABASE_SERVICE_ROLE_KEY;
  });

  it('purges all rows in FK-safe order, profile last, auth identity skipped without secret', async () => {
    const { client, calls } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: 'sup-123',
    });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma);

    const result = await service.deleteMe('user-1');

    expect(result).toEqual({ deleted: true, authIdentityRemoved: false });
    // Profile is deleted last.
    expect(calls[calls.length - 1]).toBe('userProfile.delete');
    // Case children precede the Case delete.
    expect(calls.indexOf('caseMessage.deleteMany')).toBeLessThan(
      calls.indexOf('case.deleteMany'),
    );
    // ServicePurchase (FK → PaymentIntent) precedes PaymentIntent.
    expect(calls.indexOf('servicePurchase.deleteMany')).toBeLessThan(
      calls.indexOf('paymentIntent.deleteMany'),
    );
    // Rows referencing Case precede the Case delete.
    expect(calls.indexOf('appointment.deleteMany')).toBeLessThan(
      calls.indexOf('case.deleteMany'),
    );
    expect(calls.indexOf('paymentIntent.deleteMany')).toBeLessThan(
      calls.indexOf('case.deleteMany'),
    );
  });

  it('reports not-deleted when there is no database', async () => {
    const prisma = {
      execute: async () => null,
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma);
    expect(await service.deleteMe('user-1')).toEqual({
      deleted: false,
      authIdentityRemoved: false,
    });
  });

  it('exports the profile and related collections as one document', async () => {
    const { client } = makeFakePrisma({ id: 'user-1', email: 'a@b.com' });
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma);

    const out = await service.exportMe('user-1');
    expect(out.exportedAt).toBeDefined();
    expect((out as { profile?: unknown }).profile).toMatchObject({ id: 'user-1' });
    expect((out as { cases?: unknown }).cases).toEqual([]);
  });
});
