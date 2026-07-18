import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

// No files in these fixtures (caseDocument.findMany → []), so the stub is never
// actually exercised; it only satisfies the constructor signature.
const fakeStorage = {
  keyFromUrl: () => null,
  delete: async () => undefined,
} as unknown as StorageService;

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
    'scholarshipWorkspace',
    'applicationArtifactVersion',
    'studyReviewRequest',
    'studyReviewArtifactShare',
    'outcomeEvidenceAsset',
    'outcomeEvidenceLink',
    'applicationSubmission',
    'applicationDecisionRecord',
    'fundingDecisionRecord',
    'outcomeVerificationEvent',
    'aiDiagnostic',
    'aiUsageAttempt',
    'aiBudgetTransaction',
    'aiQuotaBucket',
    'impactCohortMembership',
    'analyticsEvent',
    'domainEventOutbox',
    'idempotencyRecord',
    'consentReceipt',
    'guardianAuthorization',
    'parentChildLink',
    'referral',
    'creditTransaction',
    'deviceToken',
    'partnerLead',
    'studentCredential',
  ] as const;

  function makeFakePrisma(profile: unknown) {
    const calls: string[] = [];
    const deleteManyArguments: Record<string, unknown[]> = {};
    const client: Record<string, unknown> = {
      $transaction: async (ops: unknown[]) => ops,
    };
    for (const model of MODELS) {
      client[model] = {
        findUnique: async () => (model === 'userProfile' ? profile : null),
        findMany: async () => [],
        deleteMany: (args: unknown) => {
          calls.push(`${model}.deleteMany`);
          (deleteManyArguments[model] ??= []).push(args);
          return { __op: `${model}.deleteMany` };
        },
        updateMany: () => {
          calls.push(`${model}.updateMany`);
          return { __op: `${model}.updateMany` };
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
    return { client, calls, deleteManyArguments };
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
    const service = new ProfilesService(prisma, fakeStorage);

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
    expect(calls).toContain('idempotencyRecord.deleteMany');
    expect(calls.indexOf('studyReviewArtifactShare.deleteMany')).toBeLessThan(
      calls.indexOf('consentReceipt.deleteMany'),
    );
    expect(calls.indexOf('outcomeEvidenceLink.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('fundingDecisionRecord.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('applicationDecisionRecord.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('applicationSubmission.deleteMany')).toBeLessThan(
      calls.indexOf('outcomeEvidenceAsset.deleteMany'),
    );
    expect(calls.indexOf('outcomeEvidenceAsset.deleteMany')).toBeLessThan(
      calls.indexOf('consentReceipt.deleteMany'),
    );
    expect(calls.indexOf('consentReceipt.deleteMany')).toBeLessThan(
      calls.indexOf('guardianAuthorization.deleteMany'),
    );
  });

  it('removes private artifact objects after the database purge', async () => {
    const { client } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: null,
    });
    (client.scholarshipWorkspace as { findMany: () => Promise<unknown[]> }).findMany =
      async () => [{ id: 'workspace-1' }];
    (
      client.applicationArtifactVersion as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      { id: 'version-1', storageKey: '2026-07-17/file.pdf' },
    ];
    (
      client.outcomeEvidenceAsset as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      { id: 'evidence-1', storageKey: '2026-07-17/outcome.pdf' },
    ];
    (
      client.guardianAuthorization as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      { evidenceStorageKey: '2026-07-17/guardian.pdf' },
    ];
    const deleteFile = jest.fn().mockResolvedValue(undefined);
    const storage = {
      keyFromUrl: () => null,
      delete: deleteFile,
    } as unknown as StorageService;
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    const service = new ProfilesService(prisma, storage);
    await service.deleteMe('user-1');

    expect(deleteFile).toHaveBeenCalledWith('2026-07-17/file.pdf');
    expect(deleteFile).toHaveBeenCalledWith('2026-07-17/outcome.pdf');
    expect(deleteFile).toHaveBeenCalledWith('2026-07-17/guardian.pdf');
  });

  it('purges admin-owned pilot idempotency snapshots by participant resource ids', async () => {
    const { client, deleteManyArguments } = makeFakePrisma({
      email: 'a@b.com',
      supabaseUserId: null,
    });
    (
      client.impactCohortMembership as {
        findMany: () => Promise<unknown[]>;
      }
    ).findMany = async () => [
      {
        id: 'membership-1',
        assessments: [{ id: 'assessment-1' }, { id: 'assessment-2' }],
        experimentAssignment: { id: 'assignment-1' },
      },
    ];
    const prisma = {
      execute: async (fn: (c: unknown) => unknown) => fn(client),
    } as unknown as PrismaService;

    await new ProfilesService(prisma, fakeStorage).deleteMe('user-1');

    expect(deleteManyArguments.idempotencyRecord).toEqual([
      {
        where: {
          OR: [
            { actorId: 'user-1' },
            {
              resourceType: 'ImpactCohortMembership',
              resourceId: { in: ['membership-1'] },
            },
            {
              resourceType: 'PilotRecord',
              resourceId: {
                in: ['assessment-1', 'assessment-2', 'assignment-1'],
              },
            },
          ],
        },
      },
    ]);
  });

  it('reports not-deleted when there is no database', async () => {
    const prisma = {
      execute: async () => null,
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma, fakeStorage);
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
    const service = new ProfilesService(prisma, fakeStorage);

    const out = await service.exportMe('user-1');
    expect(out.exportedAt).toBeDefined();
    expect((out as { profile?: unknown }).profile).toMatchObject({
      id: 'user-1',
    });
    expect((out as { cases?: unknown }).cases).toEqual([]);
    expect(
      (out as { scholarshipWorkspaces?: unknown }).scholarshipWorkspaces,
    ).toEqual([]);
    expect((out as { consentReceipts?: unknown }).consentReceipts).toEqual([]);
    expect((out as { aiQuotaBuckets?: unknown }).aiQuotaBuckets).toEqual([]);
    expect((out as { analyticsEvents?: unknown }).analyticsEvents).toEqual([]);
  });
});
