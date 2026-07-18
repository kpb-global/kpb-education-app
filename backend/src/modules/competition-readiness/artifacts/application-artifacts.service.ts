import { createHash } from 'node:crypto';

import { Injectable, UnprocessableEntityException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  detectAllowedMime,
  type StoredObject,
  StorageService,
} from '../../storage/storage.service';
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
import { ArtifactPolicyService } from './artifact-policy.service';
import { CreateArtifactUploadIntentDto } from './dto/create-artifact-upload-intent.dto';

const publicVersionSelect = {
  id: true,
  artifactId: true,
  versionNumber: true,
  originalFileName: true,
  mimeType: true,
  sizeBytes: true,
  sha256: true,
  processingStatus: true,
  rejectionCode: true,
  uploadedAt: true,
  deletedAt: true,
  createdAt: true,
} satisfies Prisma.ApplicationArtifactVersionSelect;

const artifactWithVersionsInclude = {
  versions: {
    orderBy: { versionNumber: 'desc' as const },
    select: publicVersionSelect,
  },
} satisfies Prisma.ApplicationArtifactInclude;

type ArtifactWithVersions = Prisma.ApplicationArtifactGetPayload<{
  include: typeof artifactWithVersionsInclude;
}>;

type PublicArtifactVersion = Prisma.ApplicationArtifactVersionGetPayload<{
  select: typeof publicVersionSelect;
}>;

export interface UploadedArtifactFile {
  buffer: Buffer;
  originalname: string;
  mimetype: string;
  size: number;
}

export interface OwnedArtifactDownload {
  fileName: string;
  object: StoredObject;
}

@Injectable()
export class ApplicationArtifactsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly storage: StorageService,
    private readonly policy: ArtifactPolicyService,
    private readonly featureAccess: FeatureAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async list(userId: string, workspaceId: string) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const workspace = await this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findFirst({
        where: { id: workspaceId, userId },
        select: { id: true },
      }),
    );
    if (!workspace) throw workspaceNotFound();

    const artifacts = await this.prismaService.execute((prisma) =>
      prisma.applicationArtifact.findMany({
        where: { workspaceId },
        orderBy: [{ kind: 'asc' }, { createdAt: 'asc' }],
        include: artifactWithVersionsInclude,
      }),
    );
    if (!artifacts) throw databaseUnavailable();
    return { items: artifacts.map((artifact) => this.serializeArtifact(artifact)) };
  }

  async initiateUpload(
    userId: string,
    workspaceId: string,
    input: CreateArtifactUploadIntentDto,
    idempotencyKey: string,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const metadata = this.policy.normalizeIntent(input);

    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation: 'artifact.upload.initiate',
              idempotencyKey,
              payload: { workspaceId, ...metadata },
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return {
              statusCode: reservation.responseCode === 201 ? 201 : 200,
              intent: this.replayIntent(reservation),
            };
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();

          const workspace = await tx.scholarshipWorkspace.findFirst({
            where: { id: workspaceId, userId, status: { not: 'archived' } },
            select: { id: true },
          });
          if (!workspace) throw workspaceNotFound();

          const artifact = await tx.applicationArtifact.upsert({
            where: {
              workspaceId_kind_title: {
                workspaceId,
                kind: metadata.kind,
                title: metadata.title,
              },
            },
            create: {
              workspaceId,
              kind: metadata.kind,
              title: metadata.title,
            },
            update: {},
          });

          // Serializes version-number allocation for different idempotency keys
          // targeting the same logical artifact.
          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "ApplicationArtifact" WHERE "id" = ${artifact.id} FOR UPDATE`,
          );
          const latest = await tx.applicationArtifactVersion.findFirst({
            where: { artifactId: artifact.id },
            orderBy: { versionNumber: 'desc' },
            select: { versionNumber: true },
          });
          const version = await tx.applicationArtifactVersion.create({
            data: {
              artifactId: artifact.id,
              versionNumber: (latest?.versionNumber ?? 0) + 1,
              originalFileName: metadata.originalFileName,
              mimeType: metadata.mimeType,
              sizeBytes: metadata.sizeBytes,
              sha256: metadata.sha256,
            },
            select: publicVersionSelect,
          });
          const intent = this.serializeIntent(artifact, version);

          await this.outbox.enqueue(
            {
              eventId: `artifact.upload.initiated:${version.id}`,
              eventName: 'artifact.upload.initiated',
              aggregateType: 'ApplicationArtifactVersion',
              aggregateId: version.id,
              payload: {
                workspaceId,
                artifactId: artifact.id,
                versionId: version.id,
                versionNumber: version.versionNumber,
              },
            },
            tx,
          );
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: intent as unknown as Prisma.InputJsonValue,
              resourceType: 'ApplicationArtifactVersion',
              resourceId: version.id,
              resultingVersion: version.versionNumber,
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
    versionId: string,
    file: UploadedArtifactFile,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const version = await this.findOwnedVersion(userId, versionId);
    if (!version) throw workspaceNotFound();
    if (version.artifact.workspace.status === 'archived') {
      throw new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        409,
        'Archived workspaces cannot accept artifact uploads.',
      );
    }
    if (version.processingStatus === 'clean') {
      return this.serializeVersion(version);
    }
    if (version.processingStatus !== 'pending_upload') {
      throw this.rejectedVersion();
    }

    const detectedMimeType = detectAllowedMime(file.buffer);
    const actualSha256 = createHash('sha256').update(file.buffer).digest('hex');
    try {
      this.policy.assertCompletion({
        expectedMimeType: version.mimeType,
        expectedSizeBytes: version.sizeBytes,
        expectedSha256: version.sha256,
        actualMimeType: detectedMimeType,
        actualSizeBytes: file.buffer.byteLength,
        actualSha256,
      });
    } catch (error) {
      await this.rejectPendingVersion(versionId, this.rejectionCode(error));
      throw error;
    }

    this.assertProductionScannerReady();
    let stored;
    try {
      stored = await this.storage.save(
        file.buffer,
        version.originalFileName,
        version.mimeType,
      );
    } catch (error) {
      if (error instanceof UnprocessableEntityException) {
        await this.rejectPendingVersion(versionId, 'antivirus_rejected');
      }
      throw error;
    }

    try {
      const finalized = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const claimed = await tx.applicationArtifactVersion.updateMany({
            where: {
              id: versionId,
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
            },
          });
          if (claimed.count === 0) {
            const existing = await tx.applicationArtifactVersion.findUnique({
              where: { id: versionId },
              select: publicVersionSelect,
            });
            if (existing?.processingStatus === 'clean') {
              return { duplicate: true, version: this.serializeVersion(existing) };
            }
            throw this.rejectedVersion();
          }

          await tx.applicationArtifact.update({
            where: { id: version.artifactId },
            data: { currentVersionId: versionId },
          });
          await tx.scholarshipWorkspace.update({
            where: { id: version.artifact.workspace.id },
            data: {
              ...(version.artifact.workspace.status === 'started'
                ? { status: 'preparing' }
                : {}),
              version: { increment: 1 },
              lastActivityAt: new Date(),
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `artifact.version.clean:${versionId}`,
              eventName: 'artifact.version.clean',
              aggregateType: 'ApplicationArtifactVersion',
              aggregateId: versionId,
              payload: {
                workspaceId: version.artifact.workspace.id,
                artifactId: version.artifactId,
                versionId,
                versionNumber: version.versionNumber,
              },
            },
            tx,
          );
          const updated = await tx.applicationArtifactVersion.findUnique({
            where: { id: versionId },
            select: publicVersionSelect,
          });
          if (!updated) throw workspaceNotFound();
          return { duplicate: false, version: this.serializeVersion(updated) };
        }),
      );
      if (!finalized) throw databaseUnavailable();
      if (finalized.duplicate) await this.storage.delete(stored.key);
      return finalized.version;
    } catch (error) {
      await this.storage.delete(stored.key);
      this.translateInfrastructureError(error);
    }
  }

  async getDownload(
    userId: string,
    versionId: string,
  ): Promise<OwnedArtifactDownload> {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const version = await this.findOwnedVersion(userId, versionId);
    if (!version) throw workspaceNotFound();
    if (version.processingStatus === 'pending_upload') {
      throw new CompetitionReadinessHttpException(
        'EVIDENCE_SCAN_PENDING',
        409,
        'Artifact is not ready for download.',
      );
    }
    if (
      version.processingStatus !== 'clean' ||
      version.deletedAt ||
      !version.storageKey
    ) {
      throw this.rejectedVersion();
    }
    const object = await this.storage.getObject(version.storageKey);
    if (!object) throw workspaceNotFound();
    return { fileName: version.originalFileName, object };
  }

  async deleteVersion(userId: string, versionId: string, reason?: string) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const version = await tx.applicationArtifactVersion.findFirst({
            where: {
              id: versionId,
              artifact: { workspace: { userId } },
            },
            include: {
              artifact: {
                select: { id: true, currentVersionId: true, workspaceId: true },
              },
            },
          });
          if (!version) throw workspaceNotFound();

          // Shares and deletion serialize on the same workspace lock. This
          // prevents a review from snapshotting a version while it is deleted.
          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "ScholarshipWorkspace" WHERE "id" = ${version.artifact.workspaceId} FOR UPDATE`,
          );
          if (version.processingStatus === 'deleted') {
            return { storageKey: version.storageKey };
          }
          const activeShare = await tx.studyReviewArtifactShare.findFirst({
            where: {
              artifactVersionId: versionId,
              revokedAt: null,
              reviewRequest: { status: { not: 'closed' } },
            },
            select: { id: true },
          });
          if (activeShare) {
            throw new CompetitionReadinessHttpException(
              'FORBIDDEN_SCOPE',
              409,
              'Artifact is currently shared with an open review request.',
            );
          }

          const deletedAt = new Date();
          await tx.applicationArtifactVersion.update({
            where: { id: versionId },
            data: {
              processingStatus: 'deleted',
              deletedAt,
              rejectionCode: reason?.trim() ? 'user_deleted' : null,
            },
          });
          if (version.artifact.currentVersionId === versionId) {
            const fallbackVersion =
              await tx.applicationArtifactVersion.findFirst({
                where: {
                  artifactId: version.artifact.id,
                  id: { not: versionId },
                  processingStatus: 'clean',
                  deletedAt: null,
                  storageKey: { not: null },
                },
                orderBy: { versionNumber: 'desc' },
                select: { id: true },
              });
            await tx.applicationArtifact.update({
              where: { id: version.artifact.id },
              data: { currentVersionId: fallbackVersion?.id ?? null },
            });
          }
          await this.outbox.enqueue(
            {
              eventId: `artifact.version.deleted:${versionId}`,
              eventName: 'artifact.version.deleted',
              aggregateType: 'ApplicationArtifactVersion',
              aggregateId: versionId,
              payload: {
                workspaceId: version.artifact.workspaceId,
                artifactId: version.artifact.id,
                versionId,
                storageKey: version.storageKey,
                reasonProvided: Boolean(reason?.trim()),
              },
            },
            tx,
          );
          return { storageKey: version.storageKey };
        }),
      );
      if (!result) throw databaseUnavailable();
      if (result.storageKey) await this.storage.delete(result.storageKey);
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  private async findOwnedVersion(userId: string, versionId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.applicationArtifactVersion.findFirst({
        where: { id: versionId, artifact: { workspace: { userId } } },
        include: {
          artifact: {
            include: {
              workspace: { select: { id: true, userId: true, status: true } },
            },
          },
        },
      }),
    );
  }

  private async rejectPendingVersion(versionId: string, rejectionCode: string) {
    const result = await this.prismaService.execute((prisma) =>
      prisma.applicationArtifactVersion.updateMany({
        where: { id: versionId, processingStatus: 'pending_upload' },
        data: { processingStatus: 'rejected', rejectionCode },
      }),
    );
    if (!result) throw databaseUnavailable();
  }

  private serializeArtifact(artifact: ArtifactWithVersions) {
    return {
      id: artifact.id,
      workspaceId: artifact.workspaceId,
      kind: artifact.kind,
      title: artifact.title,
      currentVersionId: artifact.currentVersionId,
      createdAt: artifact.createdAt.toISOString(),
      updatedAt: artifact.updatedAt.toISOString(),
      versions: artifact.versions.map((version) => this.serializeVersion(version)),
    };
  }

  private serializeVersion(version: PublicArtifactVersion) {
    return {
      id: version.id,
      artifactId: version.artifactId,
      versionNumber: version.versionNumber,
      originalFileName: version.originalFileName,
      mimeType: version.mimeType,
      sizeBytes: version.sizeBytes,
      sha256: version.sha256,
      processingStatus: version.processingStatus,
      rejectionCode: version.rejectionCode,
      uploadedAt: version.uploadedAt?.toISOString() ?? null,
      deletedAt: version.deletedAt?.toISOString() ?? null,
      createdAt: version.createdAt.toISOString(),
    };
  }

  private serializeIntent(
    artifact: { id: string; workspaceId: string; kind: string; title: string },
    version: PublicArtifactVersion,
  ) {
    return {
      uploadMode: 'multipart' as const,
      uploadUrl: `/api/competition-readiness/artifact-versions/${version.id}/complete`,
      expiresAt: null,
      artifact: {
        id: artifact.id,
        workspaceId: artifact.workspaceId,
        kind: artifact.kind,
        title: artifact.title,
      },
      version: this.serializeVersion(version),
    };
  }

  private replayIntent(
    reservation: Extract<IdempotencyReservation, { state: 'replay' }>,
  ): ReturnType<ApplicationArtifactsService['serializeIntent']> {
    const snapshot = reservation.responseSnapshot;
    if (
      snapshot === null ||
      Array.isArray(snapshot) ||
      typeof snapshot !== 'object' ||
      snapshot.uploadMode !== 'multipart' ||
      typeof snapshot.uploadUrl !== 'string' ||
      snapshot.version === null ||
      Array.isArray(snapshot.version) ||
      typeof snapshot.version !== 'object' ||
      typeof snapshot.version.id !== 'string'
    ) {
      throw databaseUnavailable();
    }
    return snapshot as unknown as ReturnType<
      ApplicationArtifactsService['serializeIntent']
    >;
  }

  private rejectionCode(error: unknown): string {
    if (error instanceof CompetitionReadinessHttpException) {
      const response = error.getResponse();
      if (typeof response === 'object' && response && 'code' in response) {
        return String(response.code).toLowerCase();
      }
    }
    return 'validation_rejected';
  }

  private rejectedVersion() {
    return new CompetitionReadinessHttpException(
      'EVIDENCE_REJECTED',
      422,
      'Artifact is not available.',
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
        'Artifact scanning is temporarily unavailable.',
      );
    }
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private async assertFeatureAccess(userId: string) {
    if (
      process.env.KPB_APPLICATION_ARTIFACTS_ENABLED?.trim().toLowerCase() !==
      'true'
    ) {
      throw featureDisabled('application_artifacts');
    }
    const decision = await this.featureAccess.evaluate({
      feature: 'success_lab',
      userId,
    });
    if (!decision.allowed) throw featureDisabled('success_lab');
  }

  private translateInfrastructureError(error: unknown): never {
    if (error instanceof IdempotencyPayloadMismatchError) {
      throw idempotencyPayloadMismatch();
    }
    if (error instanceof IdempotencyStorageUnavailableError) {
      throw databaseUnavailable();
    }
    if (error instanceof DomainEventConflictError) {
      throw outboxEventConflict();
    }
    if (error instanceof DomainEventOutboxUnavailableError) {
      throw databaseUnavailable();
    }
    throw error;
  }
}
