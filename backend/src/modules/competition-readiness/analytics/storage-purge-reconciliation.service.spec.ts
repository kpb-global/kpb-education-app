import { PrismaService } from '../../prisma/prisma.service';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import { StoragePurgeReconciliationService } from './storage-purge-reconciliation.service';

describe('StoragePurgeReconciliationService', () => {
  it('soft-deletes only abandoned pending uploads and emits durable idempotent purge events', async () => {
    const artifactFindMany = jest.fn().mockResolvedValue([
      {
        id: 'artifact-version-expired',
        artifactId: 'artifact-1',
        storageKey: null,
        artifact: { workspaceId: 'workspace-1' },
      },
      {
        id: 'artifact-version-raced',
        artifactId: 'artifact-2',
        storageKey: null,
        artifact: { workspaceId: 'workspace-2' },
      },
    ]);
    const outcomeFindMany = jest.fn().mockResolvedValue([
      {
        id: 'outcome-evidence-expired',
        workspaceId: 'workspace-1',
        storageKey: null,
      },
    ]);
    const artifactUpdateMany = jest
      .fn()
      .mockResolvedValueOnce({ count: 1 })
      .mockResolvedValueOnce({ count: 0 });
    const outcomeUpdateMany = jest.fn().mockResolvedValue({ count: 1 });
    const tx = {
      applicationArtifactVersion: {
        findMany: artifactFindMany,
        updateMany: artifactUpdateMany,
      },
      outcomeEvidenceAsset: {
        findMany: outcomeFindMany,
        updateMany: outcomeUpdateMany,
      },
    };
    const prisma = {
      isEnabled: true,
      execute: jest.fn(async (operation: (client: object) => Promise<unknown>) =>
        operation({
          $transaction: (callback: (value: typeof tx) => Promise<unknown>) =>
            callback(tx),
        }),
      ),
    } as unknown as PrismaService;
    const enqueue = jest.fn().mockResolvedValue({ created: true });
    const outbox = { enqueue } as unknown as DomainEventOutboxService;
    const service = new StoragePurgeReconciliationService(prisma, outbox);
    const now = new Date('2026-07-18T12:00:00.000Z');

    await expect(
      service.expireAbandonedPendingUploads(now, 25),
    ).resolves.toBe(2);

    const cutoff = new Date('2026-07-17T12:00:00.000Z');
    expect(artifactFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          processingStatus: 'pending_upload',
          deletedAt: null,
          createdAt: { lt: cutoff },
        },
        take: 25,
      }),
    );
    expect(outcomeFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          processingStatus: 'pending_upload',
          deletedAt: null,
          createdAt: { lt: cutoff },
        },
        take: 25,
      }),
    );
    expect(artifactUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'artifact-version-expired',
          processingStatus: 'pending_upload',
        }),
        data: expect.objectContaining({
          processingStatus: 'deleted',
          deletedAt: now,
          rejectionCode: 'upload_expired',
        }),
      }),
    );
    expect(outcomeUpdateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'outcome-evidence-expired',
          processingStatus: 'pending_upload',
        }),
        data: expect.objectContaining({
          processingStatus: 'deleted',
          deletedAt: now,
          rejectionCode: 'upload_expired',
          version: { increment: 1 },
        }),
      }),
    );
    expect(enqueue).toHaveBeenCalledTimes(2);
    expect(enqueue).toHaveBeenNthCalledWith(
      1,
      expect.objectContaining({
        eventId: 'artifact.version.deleted:artifact-version-expired',
        occurredAt: now,
        payload: expect.objectContaining({
          retentionExpired: true,
          storageKey: null,
        }),
      }),
      tx,
    );
    expect(enqueue).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        eventId: 'outcome_evidence.deleted:outcome-evidence-expired',
        occurredAt: now,
        payload: expect.objectContaining({
          retentionExpired: true,
          storageKey: null,
        }),
      }),
      tx,
    );
    expect(enqueue).not.toHaveBeenCalledWith(
      expect.objectContaining({
        eventId: 'artifact.version.deleted:artifact-version-raced',
      }),
      expect.anything(),
    );
  });

  it('recreates only deterministic purge events for discoverable soft deletes', async () => {
    const queryRaw = jest
      .fn()
      .mockResolvedValueOnce([
        {
          id: 'version-1',
          artifactId: 'artifact-1',
          workspaceId: 'workspace-1',
          storageKey:
            '2026-07-16/123e4567-e89b-12d3-a456-426614174000.pdf',
          reasonProvided: false,
        },
      ])
      .mockResolvedValueOnce([
        {
          id: 'evidence-1',
          workspaceId: 'workspace-1',
          storageKey:
            '2026-07-16/223e4567-e89b-12d3-a456-426614174000.pdf',
        },
      ]);
    const prisma = {
      isEnabled: true,
      execute: jest.fn(async (operation: (client: object) => Promise<unknown>) =>
        operation({ $queryRaw: queryRaw }),
      ),
    } as unknown as PrismaService;
    const enqueue = jest.fn().mockResolvedValue({ created: true });
    const outbox = { enqueue } as unknown as DomainEventOutboxService;
    const service = new StoragePurgeReconciliationService(prisma, outbox);

    await expect(service.reconcileOnce(25)).resolves.toBe(2);

    expect(enqueue).toHaveBeenNthCalledWith(1, {
      eventId: 'artifact.version.deleted:version-1',
      eventName: 'artifact.version.deleted',
      aggregateType: 'ApplicationArtifactVersion',
      aggregateId: 'version-1',
      payload: {
        workspaceId: 'workspace-1',
        artifactId: 'artifact-1',
        versionId: 'version-1',
        storageKey:
          '2026-07-16/123e4567-e89b-12d3-a456-426614174000.pdf',
        reasonProvided: false,
        reconciled: true,
      },
    });
    expect(enqueue).toHaveBeenNthCalledWith(2, {
      eventId: 'outcome_evidence.deleted:evidence-1',
      eventName: 'outcome_evidence.deleted',
      aggregateType: 'OutcomeEvidenceAsset',
      aggregateId: 'evidence-1',
      payload: {
        workspaceId: 'workspace-1',
        evidenceId: 'evidence-1',
        storageKey:
          '2026-07-16/223e4567-e89b-12d3-a456-426614174000.pdf',
        reconciled: true,
      },
    });
  });

  it('is a no-op when the durable database is disabled', async () => {
    const prisma = {
      isEnabled: false,
      execute: jest.fn().mockResolvedValue(null),
    } as unknown as PrismaService;
    const outbox = {
      enqueue: jest.fn(),
    } as unknown as DomainEventOutboxService;
    const service = new StoragePurgeReconciliationService(prisma, outbox);

    await service.reconcile();

    expect(prisma.execute).not.toHaveBeenCalled();
  });
});
