import {
  createHmac,
  randomUUID,
  timingSafeEqual,
} from 'node:crypto';

import { Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../../prisma/prisma.service';
import { StorageService } from '../../storage/storage.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
} from '../common/competition-readiness.errors';
import {
  AdminReviewAccessService,
  type AdminReviewActor,
} from './admin-review-access.service';

type EvidenceTokenPayload = {
  actorId: string;
  versionId: string;
  shareId: string;
  purposeCode: 'study_review_document';
  expiresAt: number;
  nonce: string;
};

const evidenceShareSelect = {
  id: true,
  reviewRequestId: true,
  artifactVersionId: true,
  reviewRequest: {
    select: {
      id: true,
      assignedCounsellorId: true,
      workspace: {
        select: {
          scholarshipId: true,
          scholarship: { select: { id: true, countryId: true } },
        },
      },
    },
  },
  artifactVersion: {
    select: {
      id: true,
      originalFileName: true,
      mimeType: true,
      storageKey: true,
    },
  },
} as const;

@Injectable()
export class AdminEvidenceService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly storage: StorageService,
    private readonly access: AdminReviewAccessService,
  ) {}

  async issueAccess(
    actor: AdminReviewActor,
    versionId: string,
    purposeCode: 'study_review_document',
    requestId: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const share = await this.findAuthorizedShare(actor, versionId);
    const expiresAt = new Date(Date.now() + this.ttlSeconds() * 1000);
    const auditEventId = randomUUID();
    const token = this.sign({
      actorId: actor.id,
      versionId,
      shareId: share.id,
      purposeCode,
      expiresAt: expiresAt.getTime(),
      nonce: randomUUID(),
    });
    const audited = await this.prismaService.execute((prisma) =>
      prisma.adminAuditEvent.create({
        data: {
          id: auditEventId,
          actorAdminId: actor.id,
          action: 'study_review.evidence_access_issued',
          purposeCode,
          entityType: 'ApplicationArtifactVersion',
          entityId: versionId,
          requestId,
          result: 'success',
          changes: {
            reviewRequestId: share.reviewRequestId,
            shareId: share.id,
            expiresAt: expiresAt.toISOString(),
          },
        },
        select: { id: true },
      }),
    );
    if (!audited) throw databaseUnavailable();
    return {
      accessUrl: `/api/admin/competition-readiness/evidence/${encodeURIComponent(versionId)}/download?accessToken=${encodeURIComponent(token)}`,
      expiresAt: expiresAt.toISOString(),
      cacheControl: 'no-store' as const,
      auditEventId: audited.id,
    };
  }

  async download(
    actor: AdminReviewActor,
    versionId: string,
    accessToken: string,
    requestId: string,
  ) {
    this.assertDb();
    this.access.assertReviewFeatureEnabled();
    const payload = this.verify(accessToken);
    if (
      payload.actorId !== actor.id ||
      payload.versionId !== versionId ||
      payload.purposeCode !== 'study_review_document'
    ) {
      throw this.forbidden();
    }
    const share = await this.loadShare(payload.shareId, versionId);
    if (!share) throw this.forbidden();
    await this.access.assertCanOpenEvidence(actor, share.reviewRequest);
    const storageKey = share.artifactVersion.storageKey;
    if (!storageKey) throw new NotFoundException('Evidence file not found.');
    const object = await this.storage.getObject(storageKey);
    if (!object) throw new NotFoundException('Evidence file not found.');

    const audited = await this.prismaService.execute((prisma) =>
      prisma.adminAuditEvent.create({
        data: {
          actorAdminId: actor.id,
          action: 'study_review.evidence_downloaded',
          purposeCode: payload.purposeCode,
          entityType: 'ApplicationArtifactVersion',
          entityId: versionId,
          requestId,
          result: 'success',
          changes: {
            reviewRequestId: share.reviewRequestId,
            shareId: share.id,
          },
        },
        select: { id: true },
      }),
    );
    if (!audited) throw databaseUnavailable();
    return {
      fileName: share.artifactVersion.originalFileName,
      mimeType: share.artifactVersion.mimeType,
      object,
    };
  }

  private async findAuthorizedShare(
    actor: AdminReviewActor,
    versionId: string,
  ) {
    const shares = await this.prismaService.execute((prisma) =>
      prisma.studyReviewArtifactShare.findMany({
        where: {
          artifactVersionId: versionId,
          revokedAt: null,
          consentReceipt: { revokedAt: null },
          artifactVersion: {
            processingStatus: 'clean',
            deletedAt: null,
            storageKey: { not: null },
          },
        },
        orderBy: { grantedAt: 'desc' },
        select: evidenceShareSelect,
      }),
    );
    if (!shares) throw databaseUnavailable();
    for (const share of shares) {
      try {
        await this.access.assertCanOpenEvidence(actor, share.reviewRequest);
        return share;
      } catch (error) {
        if (!this.isForbiddenScope(error)) throw error;
      }
    }
    throw this.forbidden();
  }

  private async loadShare(shareId: string, versionId: string) {
    const share = await this.prismaService.execute((prisma) =>
      prisma.studyReviewArtifactShare.findFirst({
        where: {
          id: shareId,
          artifactVersionId: versionId,
          revokedAt: null,
          consentReceipt: { revokedAt: null },
          artifactVersion: {
            processingStatus: 'clean',
            deletedAt: null,
            storageKey: { not: null },
          },
        },
        select: evidenceShareSelect,
      }),
    );
    return share ?? null;
  }

  private sign(payload: EvidenceTokenPayload): string {
    const encoded = Buffer.from(JSON.stringify(payload), 'utf8').toString(
      'base64url',
    );
    const signature = createHmac('sha256', this.secret())
      .update(encoded)
      .digest('base64url');
    return `${encoded}.${signature}`;
  }

  private verify(token: string): EvidenceTokenPayload {
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
      ) as Partial<EvidenceTokenPayload>;
      if (
        typeof payload.actorId !== 'string' ||
        typeof payload.versionId !== 'string' ||
        typeof payload.shareId !== 'string' ||
        payload.purposeCode !== 'study_review_document' ||
        typeof payload.expiresAt !== 'number' ||
        payload.expiresAt <= Date.now() ||
        typeof payload.nonce !== 'string'
      ) {
        throw new Error('invalid token');
      }
      return payload as EvidenceTokenPayload;
    } catch {
      throw this.forbidden();
    }
  }

  private ttlSeconds(): number {
    const parsed = Number(process.env.KPB_EVIDENCE_ACCESS_TTL_SECONDS ?? '60');
    return Number.isSafeInteger(parsed) && parsed >= 15 && parsed <= 300
      ? parsed
      : 60;
  }

  private secret(): string {
    const configured = process.env.KPB_EVIDENCE_ACCESS_SECRET?.trim();
    if (configured) return configured;
    if (process.env.NODE_ENV === 'production') {
      throw databaseUnavailable();
    }
    return 'kpb-evidence-access-dev-only';
  }

  private isForbiddenScope(error: unknown): boolean {
    if (!(error instanceof CompetitionReadinessHttpException)) return false;
    const response = error.getResponse();
    return (
      typeof response === 'object' &&
      response !== null &&
      'code' in response &&
      response.code === 'FORBIDDEN_SCOPE'
    );
  }

  private forbidden() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'Evidence access is not authorized.',
    );
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }
}
