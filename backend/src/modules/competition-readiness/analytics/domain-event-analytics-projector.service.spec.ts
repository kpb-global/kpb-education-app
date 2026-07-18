import type { DomainEventOutbox } from '@prisma/client';

import { DomainEventAnalyticsProjectorService } from './domain-event-analytics-projector.service';

describe('DomainEventAnalyticsProjectorService', () => {
  it('projects idempotently while excluding private payload fields', async () => {
    const upsert = jest.fn().mockResolvedValue({ id: 'analytics-1' });
    const service = new DomainEventAnalyticsProjectorService();
    const event = outboxEvent({
      eventName: 'study_review.slot_offered',
      aggregateType: 'StudyReviewRequest',
      payload: {
        workspaceId: 'workspace-1',
        scholarshipId: 'scholarship-1',
        status: 'slot_offered',
        version: 2,
        userId: 'private-user-id',
        storageKey: 'private-storage-key',
        freeText: 'must not be copied',
      },
    });

    await service.project(event, { analyticsEvent: { upsert } } as never);

    expect(upsert).toHaveBeenCalledWith({
      where: { eventId: 'event-1' },
      create: expect.objectContaining({
        eventId: 'event-1',
        idempotencyKey: 'outbox:event-1:analytics-v1',
        source: 'competition_readiness_outbox',
        workspaceId: 'workspace-1',
        scholarshipId: 'scholarship-1',
        actorKey: null,
        properties: {
          aggregateType: 'StudyReviewRequest',
          status: 'slot_offered',
          version: 2,
        },
      }),
      update: {},
    });
    const create = upsert.mock.calls[0][0].create as Record<string, unknown>;
    expect(JSON.stringify(create)).not.toContain('private-user-id');
    expect(JSON.stringify(create)).not.toContain('private-storage-key');
    expect(JSON.stringify(create)).not.toContain('must not be copied');
  });

  it('derives workspaceId for workspace aggregate events', async () => {
    const upsert = jest.fn().mockResolvedValue({ id: 'analytics-1' });
    const service = new DomainEventAnalyticsProjectorService();

    await service.project(
      outboxEvent({
        aggregateType: 'ScholarshipWorkspace',
        aggregateId: 'workspace-aggregate',
      }),
      { analyticsEvent: { upsert } } as never,
    );

    expect(upsert.mock.calls[0][0].create.workspaceId).toBe(
      'workspace-aggregate',
    );
  });
});

function outboxEvent(
  overrides: Partial<DomainEventOutbox> = {},
): DomainEventOutbox {
  return {
    id: 'outbox-1',
    eventId: 'event-1',
    eventName: 'workspace.created',
    schemaVersion: 1,
    aggregateType: 'ScholarshipWorkspace',
    aggregateId: 'workspace-1',
    payload: {},
    occurredAt: new Date('2026-07-16T12:00:00.000Z'),
    status: 'processing',
    attemptCount: 0,
    nextAttemptAt: new Date('2026-07-16T12:00:00.000Z'),
    lockedAt: new Date('2026-07-16T12:00:00.000Z'),
    lockedBy: 'worker-1',
    leaseExpiresAt: new Date('2026-07-16T12:05:00.000Z'),
    lastErrorCode: null,
    processedAt: null,
    deadLetteredAt: null,
    createdAt: new Date('2026-07-16T12:00:00.000Z'),
    ...overrides,
  };
}
