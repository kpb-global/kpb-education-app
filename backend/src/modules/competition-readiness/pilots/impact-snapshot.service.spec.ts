import { BadRequestException } from '@nestjs/common';

import type { PrismaService } from '../../prisma/prisma.service';
import type { AdminImpactAccessService } from '../admin/admin-impact-access.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { IdempotencyService } from '../common/idempotency.service';
import {
  ImpactSnapshotService,
  serializeExport,
  suppressSmallCell,
} from './impact-snapshot.service';

function service(prisma: Partial<PrismaService> = {}) {
  return new ImpactSnapshotService(
    prisma as PrismaService,
    {} as AdminImpactAccessService,
    {} as IdempotencyService,
    {} as DomainEventOutboxService,
  );
}

describe('ImpactSnapshotService trustworthy aggregates', () => {
  it('suppresses public cells below n=20', () => {
    expect(
      suppressSmallCell({
        metricKey: 'verified_admissions',
        metricVersion: 1,
        label: 'Admissions',
        value: 2,
        numerator: 2,
        denominator: 12,
        sampleSize: 12,
        coveragePercent: 16.67,
        caveat: null,
      }),
    ).toMatchObject({
      value: null,
      numerator: null,
      denominator: null,
      caveat: 'Suppressed: sample size below 20.',
    });
  });

  it('never exposes manifest or storageKey on an export receipt', () => {
    const receipt = serializeExport({
      id: 'export-1',
      pilotId: 'pilot-1',
      snapshotId: 'snapshot-1',
      purposeCode: 'competition_due_diligence',
      format: 'json',
      sha256: 'a'.repeat(64),
      expiresAt: null,
      createdAt: new Date('2026-07-18T00:00:00.000Z'),
    });
    expect(receipt).not.toHaveProperty('manifest');
    expect(receipt).not.toHaveProperty('storageKey');
    expect(receipt.available).toBe(false);
  });

  it('requires pilotId instead of falling back to an unscoped global report', async () => {
    const target = service({ isEnabled: true });
    await expect(
      target.report(
        {
          id: 'admin-1',
          fullName: 'Admin',
          email: 'admin@example.test',
          role: 'admin',
          languageScope: ['fr'],
        },
        {},
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      target.listDataRoomExports(
        {
          id: 'admin-1',
          fullName: 'Admin',
          email: 'admin@example.test',
          role: 'admin',
          languageScope: ['fr'],
        },
        {},
      ),
    ).rejects.toThrow('pilotId is required');
  });

  it('bounds outcomes to the period and deduplicates submission workspaces', async () => {
    const submissionFindMany = jest.fn().mockResolvedValue([{ workspaceId: 'ws-1' }]);
    const membershipFindMany = jest.fn().mockResolvedValue([
      {
        workspaceId: 'ws-1',
        user: {
          id: 'adult-1',
          birthDate: new Date('2000-01-01T00:00:00.000Z'),
        },
        consentReceipt: {
          grantedAt: new Date('2026-01-01T00:00:00.000Z'),
          revokedAt: null,
          purpose: 'pilot_research',
          notice: {
            purpose: 'pilot_research',
            effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
            retiredAt: null,
          },
          guardianAuthorization: null,
        },
      },
      {
        workspaceId: 'ws-revoked',
        user: {
          id: 'adult-revoked',
          birthDate: new Date('2000-01-01T00:00:00.000Z'),
        },
        consentReceipt: {
          grantedAt: new Date('2026-01-01T00:00:00.000Z'),
          revokedAt: new Date('2026-02-01T00:00:00.000Z'),
          purpose: 'pilot_research',
          notice: {
            purpose: 'pilot_research',
            effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
            retiredAt: null,
          },
          guardianAuthorization: null,
        },
      },
      {
        workspaceId: 'ws-minor-revoked-guardian',
        user: {
          id: 'minor-1',
          birthDate: new Date('2012-01-01T00:00:00.000Z'),
        },
        consentReceipt: {
          grantedAt: new Date('2026-01-01T00:00:00.000Z'),
          revokedAt: null,
          purpose: 'pilot_research',
          notice: {
            purpose: 'pilot_research',
            effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
            retiredAt: null,
          },
          guardianAuthorization: {
            minorUserId: 'minor-1',
            status: 'verified',
            verifiedAt: new Date('2025-12-15T00:00:00.000Z'),
            expiresAt: null,
            revokedAt: new Date('2026-07-02T00:00:00.000Z'),
          },
        },
      },
    ]);
    const tx = {
      impactCohortMembership: { findMany: membershipFindMany },
      applicationSubmission: { findMany: submissionFindMany },
      applicationDecisionRecord: { count: jest.fn().mockResolvedValue(1) },
      fundingDecisionRecord: { count: jest.fn().mockResolvedValue(1) },
    };
    const target = service() as unknown as {
      computeMetrics(
        client: typeof tx,
        pilotId: string,
        periodStart: Date,
        periodEnd: Date,
        watermark: Date,
      ): Promise<Array<{ metricKey: string; value: number | null }>>;
    };
    const periodStart = new Date('2026-01-01T00:00:00.000Z');
    const periodEnd = new Date('2026-06-30T23:59:59.000Z');
    const watermark = new Date('2026-07-05T00:00:00.000Z');
    const metrics = await target.computeMetrics(
      tx,
      'pilot-1',
      periodStart,
      periodEnd,
      watermark,
    );

    expect(membershipFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          enrolledAt: { lte: periodEnd },
          OR: [{ withdrawnAt: null }, { withdrawnAt: { gte: periodStart } }],
        }),
      }),
    );
    expect(submissionFindMany).toHaveBeenCalledWith({
      where: expect.objectContaining({
        workspaceId: { in: ['ws-1'] },
        submittedAt: { gte: periodStart, lte: periodEnd },
        verifiedAt: { not: null, lte: watermark },
      }),
      distinct: ['workspaceId'],
      select: { workspaceId: true },
    });
    expect(metrics.find((metric) => metric.metricKey === 'verified_submissions')?.value).toBe(1);
    expect(metrics.find((metric) => metric.metricKey === 'pilot_participants')?.value).toBe(1);
  });
});
