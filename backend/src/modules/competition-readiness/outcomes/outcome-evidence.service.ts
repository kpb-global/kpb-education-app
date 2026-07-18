import { createHash } from 'node:crypto';

import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  detectAllowedMime,
  StorageService,
} from '../../storage/storage.service';
import {
  DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
  effectiveArtifactMaxBytes,
} from '../artifacts/artifact-policy.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  workspaceNotFound,
} from '../common/competition-readiness.errors';
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from '../common/domain-event-outbox.service';
import { FeatureAccessService } from '../common/feature-access.service';
import {
  IdempotencyPayloadMismatchError,
  type IdempotencyReservation,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from '../common/idempotency.service';
import type { CreateOutcomeUploadIntentDto } from './dto/create-outcome-upload-intent.dto';

const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
]);

const publicEvidenceSelect = {
  id: true,
  workspaceId: true,
  kind: true,
  originalFileName: true,
  mimeType: true,
  sizeBytes: true,
  processingStatus: true,
  version: true,
  rejectionCode: true,
  uploadedAt: true,
  deletedAt: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.OutcomeEvidenceAssetSelect;

type PublicEvidence = Prisma.OutcomeEvidenceAssetGetPayload<{
  select: typeof publicEvidenceSelect;
}>;

export interface UploadedOutcomeEvidenceFile {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
  size: number;
}

@Injectable()
export class OutcomeEvidenceService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly storage: StorageService,
    private readonly featureAccess: FeatureAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async initiateUpload(
    userId: string,
    workspaceId: string,
    input: CreateOutcomeUploadIntentDto,
    idempotencyKey: string,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const metadata = this.normalizeIntent(input);

    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: 'outcome.evidence.upload.initiate',
              idempotencyKey,
              payload: { workspaceId, ...metadata },
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return {
              statusCode: 200,
              intent: this.replayIntent(reservation),
            };
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          const workspace = await tx.scholarshipWorkspace.findFirst({
            where: { id: workspaceId, userId, status: { not: 'archived' } },
            select: { id: true },
          });
          if (!workspace) throw workspaceNotFound();
          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "ScholarshipWorkspace" WHERE "id" = ${workspaceId} FOR UPDATE`,
          );
          const pendingCount = await tx.outcomeEvidenceAsset.count({
            where: {
              workspaceId,
              ownerUserId: userId,
              processingStatus: 'pending_upload',
              deletedAt: null,
            },
          });
          if (pendingCount >= this.maxPendingPerWorkspace()) {
            throw new CompetitionReadinessHttpException(
              'RATE_LIMITED',
              429,
              'Too many pending outcome-evidence uploads.',
              { maxPending: this.maxPendingPerWorkspace() },
            );
          }

          const receipt = await tx.consentReceipt.findFirst({
            where: {
              id: metadata.consentReceiptId,
              userId,
              purpose: 'outcome_evidence',
              revokedAt: null,
              notice: { effectiveAt: { lte: new Date() }, retiredAt: null },
            },
            select: { id: true },
          });
          if (!receipt) throw this.evidenceRequired();

          const evidence = await tx.outcomeEvidenceAsset.create({
            data: {
              workspaceId,
              ownerUserId: userId,
              consentReceiptId: receipt.id,
              kind: metadata.kind,
              originalFileName: metadata.originalFileName,
              mimeType: metadata.mimeType,
              sizeBytes: metadata.sizeBytes,
              sha256: metadata.sha256,
            },
            select: publicEvidenceSelect,
          });
          const intent = this.serializeIntent(evidence);
          await this.outbox.enqueue(
            {
              eventId: `outcome-evidence-upload-initiated:${evidence.id}`,
              eventName: 'outcome_evidence_upload_initiated',
              aggregateType: 'OutcomeEvidenceAsset',
              aggregateId: evidence.id,
              payload: { workspaceId, evidenceId: evidence.id },
            },
            tx,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: intent as unknown as Prisma.InputJsonValue,
              resourceType: 'OutcomeEvidenceAsset',
              resourceId: evidence.id,
              resultingVersion: evidence.version,
            },
            tx,
          );
          return { statusCode: 201, intent };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  async completeUpload(
    userId: string,
    evidenceId: string,
    file: UploadedOutcomeEvidenceFile,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const evidence = await this.findOwnedEvidence(userId, evidenceId);
    if (!evidence) throw workspaceNotFound();
    if (evidence.workspace.status === 'archived') {
      throw workspaceNotFound();
    }
    if (evidence.processingStatus === 'clean') {
      return this.serializeEvidence(evidence);
    }
    if (evidence.processingStatus !== 'pending_upload') {
      throw this.rejectedEvidence();
    }

    const detectedMimeType = detectAllowedMime(file.buffer);
    const actualSha256 = createHash('sha256').update(file.buffer).digest('hex');
    if (
      !detectedMimeType ||
      !ALLOWED_MIME_TYPES.has(detectedMimeType) ||
      detectedMimeType !== evidence.mimeType ||
      file.buffer.byteLength !== evidence.sizeBytes ||
      actualSha256 !== evidence.sha256
    ) {
      await this.rejectPending(evidenceId, 'validation_rejected');
      throw this.rejectedEvidence();
    }

    this.assertProductionScannerReady();
    let stored;
    try {
      stored = await this.storage.save(
        file.buffer,
        evidence.originalFileName,
        evidence.mimeType,
      );
    } catch (error) {
      if (error instanceof UnprocessableEntityException) {
        await this.rejectPending(evidenceId, 'antivirus_rejected');
      }
      throw error;
    }

    try {
      const finalized = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const claimed = await tx.outcomeEvidenceAsset.updateMany({
            where: {
              id: evidenceId,
              ownerUserId: userId,
              workspaceId: evidence.workspaceId,
              processingStatus: 'pending_upload',
              deletedAt: null,
            },
            data: {
              storageKey: stored.key,
              mimeType: stored.mimeType,
              sizeBytes: stored.sizeBytes,
              processingStatus: 'clean',
              rejectionCode: null,
              uploadedAt: new Date(),
              version: { increment: 1 },
            },
          });
          if (claimed.count === 0) {
            const current = await tx.outcomeEvidenceAsset.findUnique({
              where: { id: evidenceId },
              select: publicEvidenceSelect,
            });
            if (current?.processingStatus === 'clean') {
              return { duplicate: true, evidence: current };
            }
            throw this.rejectedEvidence();
          }
          await this.outbox.enqueue(
            {
              eventId: `outcome-evidence-clean:${evidenceId}`,
              eventName: 'outcome_evidence_clean',
              aggregateType: 'OutcomeEvidenceAsset',
              aggregateId: evidenceId,
              payload: { workspaceId: evidence.workspaceId, evidenceId },
            },
            tx,
          );
          const current = await tx.outcomeEvidenceAsset.findUnique({
            where: { id: evidenceId },
            select: publicEvidenceSelect,
          });
          if (!current) throw workspaceNotFound();
          return { duplicate: false, evidence: current };
        }),
      );
      if (!finalized) throw databaseUnavailable();
      if (finalized.duplicate) await this.storage.delete(stored.key);
      return this.serializeEvidence(finalized.evidence);
    } catch (error) {
      await this.storage.delete(stored.key);
      this.translateInfrastructureError(error);
    }
  }

  private normalizeIntent(input: CreateOutcomeUploadIntentDto) {
    const originalFileName = input.originalFileName
      .replace(/\\/g, '/')
      .split('/')
      .at(-1)
      ?.replace(/[\u0000-\u001f\u007f]/g, '')
      .trim();
    const mimeType = input.mimeType.trim().toLowerCase();
    if (!originalFileName || !ALLOWED_MIME_TYPES.has(mimeType)) {
      throw this.rejectedEvidence();
    }
    const maxBytes = effectiveArtifactMaxBytes(
      DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
    );
    if (input.sizeBytes > maxBytes) {
      throw new CompetitionReadinessHttpException(
        'ARTIFACT_TOO_LARGE',
        413,
        'Outcome evidence exceeds the configured size limit.',
        { maxBytes },
      );
    }
    return {
      kind: input.kind,
      originalFileName,
      mimeType,
      sizeBytes: input.sizeBytes,
      sha256: input.sha256.toLowerCase(),
      consentReceiptId: input.consentReceiptId.trim(),
    };
  }

  private async findOwnedEvidence(userId: string, evidenceId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.outcomeEvidenceAsset.findFirst({
        where: { id: evidenceId, ownerUserId: userId },
        include: { workspace: { select: { id: true, status: true } } },
      }),
    );
  }

  private async rejectPending(evidenceId: string, rejectionCode: string) {
    const result = await this.prismaService.execute((prisma) =>
      prisma.outcomeEvidenceAsset.updateMany({
        where: { id: evidenceId, processingStatus: 'pending_upload' },
        data: {
          processingStatus: 'rejected',
          rejectionCode,
          version: { increment: 1 },
        },
      }),
    );
    if (!result) throw databaseUnavailable();
  }

  serializeEvidence(evidence: PublicEvidence) {
    return {
      id: evidence.id,
      workspaceId: evidence.workspaceId,
      kind: evidence.kind,
      originalFileName: evidence.originalFileName,
      mimeType: evidence.mimeType,
      sizeBytes: evidence.sizeBytes,
      processingStatus: evidence.processingStatus,
      version: evidence.version,
      rejectionCode: evidence.rejectionCode,
      uploadedAt: evidence.uploadedAt?.toISOString() ?? null,
      deletedAt: evidence.deletedAt?.toISOString() ?? null,
      createdAt: evidence.createdAt.toISOString(),
      updatedAt: evidence.updatedAt.toISOString(),
    };
  }

  private serializeIntent(evidence: PublicEvidence) {
    return {
      uploadMode: 'multipart' as const,
      uploadUrl: `/api/competition-readiness/outcome-evidence/${evidence.id}/complete`,
      expiresAt: null,
      evidence: this.serializeEvidence(evidence),
    };
  }

  private replayIntent(
    reservation: Extract<IdempotencyReservation, { state: 'replay' }>,
  ): ReturnType<OutcomeEvidenceService['serializeIntent']> {
    const snapshot = reservation.responseSnapshot;
    if (
      snapshot === null ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      snapshot.uploadMode !== 'multipart' ||
      typeof snapshot.uploadUrl !== 'string' ||
      snapshot.evidence === null ||
      Array.isArray(snapshot.evidence) ||
      typeof snapshot.evidence !== 'object' ||
      typeof snapshot.evidence.id !== 'string'
    ) {
      throw databaseUnavailable();
    }
    return snapshot as unknown as ReturnType<
      OutcomeEvidenceService['serializeIntent']
    >;
  }

  private evidenceRequired() {
    return new CompetitionReadinessHttpException(
      'OUTCOME_EVIDENCE_REQUIRED',
      422,
      'Active outcome-evidence consent is required.',
    );
  }

  private rejectedEvidence() {
    return new CompetitionReadinessHttpException(
      'EVIDENCE_REJECTED',
      422,
      'Outcome evidence is not available.',
    );
  }

  private assertProductionScannerReady() {
    if (
      process.env.NODE_ENV === 'production' &&
      !process.env.CLAMAV_HOST?.trim()
    ) {
      throw new CompetitionReadinessHttpException(
        'DATABASE_UNAVAILABLE',
        503,
        'Evidence scanning is temporarily unavailable.',
      );
    }
  }

  private maxPendingPerWorkspace() {
    const parsed = Number(
      process.env.KPB_OUTCOME_EVIDENCE_MAX_PENDING_PER_WORKSPACE ?? '20',
    );
    return Number.isSafeInteger(parsed) && parsed >= 1 && parsed <= 100
      ? parsed
      : 20;
  }

  private async assertFeatureAccess(userId: string) {
    const decision = await this.featureAccess.evaluate({
      feature: 'outcome_evidence',
      userId,
    });
    if (!decision.allowed) throw featureDisabled('outcome_evidence');
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private translateInfrastructureError(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) {
      throw idempotencyPayloadMismatch();
    }
    if (error instanceof IdempotencyStorageUnavailableError) {
      throw databaseUnavailable();
    }
    if (error instanceof DomainEventConflictError) throw outboxEventConflict();
    if (error instanceof DomainEventOutboxUnavailableError) {
      throw databaseUnavailable();
    }
    throw error;
  }
}
