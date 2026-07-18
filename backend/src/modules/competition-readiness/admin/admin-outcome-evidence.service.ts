import {
  createHmac,
  randomUUID,
  timingSafeEqual,
} from 'node:crypto';

import { Injectable, NotFoundException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import { StorageService } from '../../storage/storage.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
} from '../common/competition-readiness.errors';
import {
  OUTCOME_TYPES,
  type OutcomeType,
} from '../outcomes/outcomes.service';
import { AdminOutcomesAccessService } from './admin-outcomes-access.service';

type OutcomeEvidenceToken = {
  actorId: string;
  evidenceId: string;
  purposeCode: 'outcome_verification';
  expiresAt: number;
  nonce: string;
};

const downloadableEvidenceSelect = {
  id: true,
  workspaceId: true,
  originalFileName: true,
  mimeType: true,
  storageKey: true,
  processingStatus: true,
  deletedAt: true,
  consentReceipt: { select: { revokedAt: true } },
} satisfies Prisma.OutcomeEvidenceAssetSelect;

@Injectable()
export class AdminOutcomeEvidenceService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly storage: StorageService,
    private readonly access: AdminOutcomesAccessService,
  ) {}

  async issueAccess(
    actor: AdminSessionUser,
    evidenceId: string,
    requestId: string,
  ) {
    this.assertDb();
    const evidence = await this.findAuthorizedEvidence(actor, evidenceId);
    const expiresAt = new Date(Date.now() + this.ttlSeconds() * 1000);
    const token = this.sign({
      actorId: actor.id,
      evidenceId: evidence.id,
      purposeCode: 'outcome_verification',
      expiresAt: expiresAt.getTime(),
      nonce: randomUUID(),
    });
    const audit = await this.prismaService.execute((prisma) =>
      prisma.adminAuditEvent.create({
        data: {
          actorAdminId: actor.id,
          action: 'outcome.evidence_access_issued',
          purposeCode: 'outcome_verification',
          entityType: 'OutcomeEvidenceAsset',
          entityId: evidence.id,
          requestId,
          result: 'success',
          changes: { expiresAt: expiresAt.toISOString() },
        },
        select: { id: true },
      }),
    );
    if (!audit) throw databaseUnavailable();
    return {
      accessUrl: `/api/admin/competition-readiness/outcome-evidence/${encodeURIComponent(evidence.id)}/download?accessToken=${encodeURIComponent(token)}`,
      expiresAt: expiresAt.toISOString(),
      cacheControl: 'no-store' as const,
      auditEventId: audit.id,
    };
  }

  async download(
    actor: AdminSessionUser,
    evidenceId: string,
    accessToken: string,
    requestId: string,
  ) {
    this.assertDb();
    const payload = this.verify(accessToken);
    if (
      payload.actorId !== actor.id ||
      payload.evidenceId !== evidenceId ||
      payload.purposeCode !== 'outcome_verification'
    ) {
      throw this.forbidden();
    }
    const evidence = await this.findAuthorizedEvidence(actor, evidenceId);
    if (!evidence.storageKey) throw new NotFoundException('Evidence file not found.');
    const object = await this.storage.getObject(evidence.storageKey);
    if (!object) throw new NotFoundException('Evidence file not found.');

    const audit = await this.prismaService.execute((prisma) =>
      prisma.adminAuditEvent.create({
        data: {
          actorAdminId: actor.id,
          action: 'outcome.evidence_downloaded',
          purposeCode: 'outcome_verification',
          entityType: 'OutcomeEvidenceAsset',
          entityId: evidence.id,
          requestId,
          result: 'success',
          changes: {},
        },
        select: { id: true },
      }),
    );
    if (!audit) throw databaseUnavailable();
    return { fileName: evidence.originalFileName, object };
  }

  private async findAuthorizedEvidence(
    actor: AdminSessionUser,
    evidenceId: string,
  ) {
    this.access.assertEnvironment();
    const evidence = await this.prismaService.execute((prisma) =>
      prisma.outcomeEvidenceAsset.findFirst({
        where: {
          id: evidenceId,
          processingStatus: 'clean',
          deletedAt: null,
          storageKey: { not: null },
          consentReceipt: { revokedAt: null },
        },
        select: downloadableEvidenceSelect,
      }),
    );
    if (!evidence) throw this.forbidden();
    const links = await this.prismaService.execute((prisma) =>
      prisma.outcomeEvidenceLink.findMany({
        where: { evidenceId },
        select: { entityType: true, entityId: true },
      }),
    );
    if (links === null) throw databaseUnavailable();

    for (const type of OUTCOME_TYPES) {
      const scope = await this.access.whereFor(actor, type);
      const supplementalIds = links
        .filter((link) => link.entityType === type)
        .map((link) => link.entityId);
      const allowed = await this.hasAccessibleOutcome(
        type,
        scope,
        evidenceId,
        supplementalIds,
      );
      if (allowed) {
        await this.access.assertIndependentVerifier(actor, allowed);
        return evidence;
      }
    }
    throw this.forbidden();
  }

  private async hasAccessibleOutcome(
    type: OutcomeType,
    scope: Prisma.ApplicationSubmissionWhereInput,
    evidenceId: string,
    supplementalIds: string[],
  ) {
    const result = await this.prismaService.execute((prisma) => {
      const idFilter = {
        OR: [
          { evidenceId },
          ...(supplementalIds.length > 0
            ? [{ id: { in: supplementalIds } }]
            : []),
        ],
      };
      if (type === 'submission') {
        return prisma.applicationSubmission.findFirst({
          where: { AND: [scope, idFilter] },
          select: { id: true, workspaceId: true },
        });
      }
      if (type === 'admission') {
        return prisma.applicationDecisionRecord.findFirst({
          where: {
            AND: [
              scope as Prisma.ApplicationDecisionRecordWhereInput,
              idFilter,
            ],
          },
          select: { id: true, workspaceId: true },
        });
      }
      return prisma.fundingDecisionRecord.findFirst({
        where: {
          AND: [scope as Prisma.FundingDecisionRecordWhereInput, idFilter],
        },
        select: { id: true, workspaceId: true },
      });
    });
    return result ?? null;
  }

  private sign(payload: OutcomeEvidenceToken) {
    const encoded = Buffer.from(JSON.stringify(payload), 'utf8').toString(
      'base64url',
    );
    const signature = createHmac('sha256', this.secret())
      .update(encoded)
      .digest('base64url');
    return `${encoded}.${signature}`;
  }

  private verify(token: string): OutcomeEvidenceToken {
    const [encoded, signature, extra] = token.split('.');
    if (!encoded || !signature || extra !== undefined) throw this.forbidden();
    const expected = createHmac('sha256', this.secret())
      .update(encoded)
      .digest('base64url');
    const actualBuffer = Buffer.from(signature);
    const expectedBuffer = Buffer.from(expected);
    if (
      actualBuffer.length !== expectedBuffer.length ||
      !timingSafeEqual(actualBuffer, expectedBuffer)
    ) {
      throw this.forbidden();
    }
    try {
      const payload = JSON.parse(
        Buffer.from(encoded, 'base64url').toString('utf8'),
      ) as Partial<OutcomeEvidenceToken>;
      if (
        typeof payload.actorId !== 'string' ||
        typeof payload.evidenceId !== 'string' ||
        payload.purposeCode !== 'outcome_verification' ||
        typeof payload.expiresAt !== 'number' ||
        payload.expiresAt <= Date.now() ||
        typeof payload.nonce !== 'string'
      ) {
        throw new Error('invalid token');
      }
      return payload as OutcomeEvidenceToken;
    } catch {
      throw this.forbidden();
    }
  }

  private ttlSeconds() {
    const parsed = Number(process.env.KPB_EVIDENCE_ACCESS_TTL_SECONDS ?? '60');
    return Number.isSafeInteger(parsed) && parsed >= 15 && parsed <= 300
      ? parsed
      : 60;
  }

  private secret() {
    const configured = process.env.KPB_EVIDENCE_ACCESS_SECRET?.trim();
    if (configured) return configured;
    if (process.env.NODE_ENV === 'production') throw databaseUnavailable();
    return 'kpb-evidence-access-dev-only';
  }

  private forbidden() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'Outcome evidence access is not authorized.',
    );
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }
}
