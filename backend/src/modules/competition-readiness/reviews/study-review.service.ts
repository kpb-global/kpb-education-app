import { Injectable } from "@nestjs/common";
import { Prisma } from "@prisma/client";

import { PrismaService } from "../../prisma/prisma.service";
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  workspaceNotFound,
} from "../common/competition-readiness.errors";
import {
  DomainEventConflictError,
  DomainEventOutboxService,
  DomainEventOutboxUnavailableError,
} from "../common/domain-event-outbox.service";
import { FeatureAccessService } from "../common/feature-access.service";
import {
  IdempotencyPayloadMismatchError,
  type IdempotencyReservation,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from "../common/idempotency.service";
import { COMPETITION_READINESS_SCHEMA_VERSION } from "../common/competition-readiness.contract";
import { CreateStudyReviewRequestDto } from "./dto/create-study-review-request.dto";
import { UpdateStudyReviewRequestDto } from "./dto/update-study-review-request.dto";

const reviewInclude = {
  artifactShares: {
    orderBy: { grantedAt: "asc" as const },
    select: {
      id: true,
      artifactVersionId: true,
      consentReceiptId: true,
      grantedAt: true,
      revokedAt: true,
      artifactVersion: {
        select: {
          id: true,
          versionNumber: true,
          originalFileName: true,
          mimeType: true,
          sizeBytes: true,
          sha256: true,
          processingStatus: true,
          uploadedAt: true,
          artifact: {
            select: { id: true, kind: true, title: true, workspaceId: true },
          },
        },
      },
    },
  },
} satisfies Prisma.StudyReviewRequestInclude;

type ReviewWithShares = Prisma.StudyReviewRequestGetPayload<{
  include: typeof reviewInclude;
}>;

@Injectable()
export class StudyReviewService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly featureAccess: FeatureAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async create(
    userId: string,
    workspaceId: string,
    input: CreateStudyReviewRequestDto,
    idempotencyKey: string,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    this.assertAvailability(input.availability);

    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: "student",
              actorId: userId,
              operation: "study-review.create",
              idempotencyKey,
              payload: { workspaceId, ...input },
            },
            tx,
          );
          if (reservation.state === "replay") {
            return {
              statusCode: reservation.responseCode ?? 201,
              reviewRequest: this.replayReview(reservation),
            };
          }
          if (reservation.state !== "acquired") throw idempotencyInProgress();

          const workspace = await tx.scholarshipWorkspace.findFirst({
            where: { id: workspaceId, userId, status: { not: "archived" } },
            select: { id: true, status: true },
          });
          if (!workspace) throw workspaceNotFound();

          // Locks request-number allocation and open-request checks per workspace.
          await tx.$queryRaw(
            Prisma.sql`SELECT "id" FROM "ScholarshipWorkspace" WHERE "id" = ${workspaceId} FOR UPDATE`,
          );
          const openRequest = await tx.studyReviewRequest.findFirst({
            where: { workspaceId, status: { not: "closed" } },
            select: { id: true },
          });
          if (openRequest) throw this.reviewAlreadyOpen();
          if (
            ![
              "started",
              "preparing",
              "ready_for_review",
              "review_requested",
            ].includes(workspace.status)
          ) {
            throw new CompetitionReadinessHttpException(
              "FORBIDDEN_SCOPE",
              409,
              "Workspace cannot enter review from its current state.",
            );
          }

          const consentCheckedAt = new Date();
          const consent = await tx.consentReceipt.findFirst({
            where: {
              id: input.consentReceiptId,
              userId,
              purpose: "advisor_document_share",
              revokedAt: null,
              grantedAt: { lte: consentCheckedAt },
              notice: {
                effectiveAt: { lte: consentCheckedAt },
                retiredAt: null,
              },
            },
            select: {
              id: true,
              user: { select: { birthDate: true } },
              guardianAuthorization: {
                select: {
                  status: true,
                  verifiedAt: true,
                  expiresAt: true,
                  revokedAt: true,
                },
              },
            },
          });
          if (!consent) {
            throw new CompetitionReadinessHttpException(
              "PROFILE_INCOMPLETE",
              422,
              "An active document-sharing consent receipt is required.",
            );
          }
          if (!consent.user.birthDate) {
            throw new CompetitionReadinessHttpException(
              "PROFILE_INCOMPLETE",
              422,
              "Birth date is required before sharing private documents.",
            );
          }
          if (
            this.isMinorAt(consent.user.birthDate, consentCheckedAt) &&
            !this.hasValidGuardianAuthorization(
              consent.guardianAuthorization,
              consentCheckedAt,
            )
          ) {
            throw new CompetitionReadinessHttpException(
              "GUARDIAN_CONSENT_REQUIRED",
              403,
              "Verified guardian authorization is required.",
            );
          }

          const versions = await tx.applicationArtifactVersion.findMany({
            where: {
              id: { in: input.artifactVersionIds },
              processingStatus: "clean",
              deletedAt: null,
              artifact: { workspaceId },
            },
            select: { id: true },
          });
          if (versions.length !== input.artifactVersionIds.length) {
            throw new CompetitionReadinessHttpException(
              "EVIDENCE_REJECTED",
              422,
              "Every shared artifact version must be clean and belong to the workspace.",
            );
          }

          const latest = await tx.studyReviewRequest.findFirst({
            where: { workspaceId },
            orderBy: { requestNumber: "desc" },
            select: { requestNumber: true },
          });
          const submittedAt = new Date();
          const review = await tx.studyReviewRequest.create({
            data: {
              workspaceId,
              requestNumber: (latest?.requestNumber ?? 0) + 1,
              status: "submitted",
              studentMessage: input.studentMessage?.trim() || null,
              preferredContact: input.preferredContact ?? null,
              timezone: input.timezone ?? "UTC",
              availability: input.availability as
                Prisma.InputJsonValue | undefined,
              submittedAt,
              artifactShares: {
                create: input.artifactVersionIds.map((artifactVersionId) => ({
                  artifactVersionId,
                  consentReceiptId: consent.id,
                  grantedByUserId: userId,
                  grantedAt: submittedAt,
                })),
              },
            },
            include: reviewInclude,
          });
          await tx.scholarshipWorkspace.update({
            where: { id: workspaceId },
            data: {
              status: "review_requested",
              version: { increment: 1 },
              lastActivityAt: submittedAt,
            },
          });
          await this.outbox.enqueue(
            {
              eventId: `study-review.submitted:${review.id}`,
              eventName: "study-review.submitted",
              aggregateType: "StudyReviewRequest",
              aggregateId: review.id,
              occurredAt: submittedAt,
              payload: {
                reviewRequestId: review.id,
                workspaceId,
                requestNumber: review.requestNumber,
                sharedArtifactVersionIds: input.artifactVersionIds,
              },
            },
            tx,
          );
          const serialized = this.serialize(review);
          await this.idempotency.complete(
            {
              recordId: reservation.recordId,
              responseCode: 201,
              responseSnapshot: serialized as unknown as Prisma.InputJsonValue,
              resourceType: "StudyReviewRequest",
              resourceId: review.id,
              resultingVersion: review.version,
            },
            tx,
          );
          return { statusCode: 201, reviewRequest: serialized };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        throw this.reviewAlreadyOpen();
      }
      this.translateInfrastructureError(error);
    }
  }

  async getOne(userId: string, reviewRequestId: string) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const review = await this.prismaService.execute((prisma) =>
      prisma.studyReviewRequest.findFirst({
        where: { id: reviewRequestId, workspace: { userId } },
        include: reviewInclude,
      }),
    );
    if (!review) throw workspaceNotFound();
    return this.serialize(review);
  }

  async getActive(userId: string, workspaceId: string) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    const result = await this.prismaService.execute(async (prisma) => {
      const workspace = await prisma.scholarshipWorkspace.findFirst({
        where: { id: workspaceId, userId, status: { not: "archived" } },
        select: { id: true },
      });
      if (!workspace) return { workspaceFound: false as const, review: null };
      const review = await prisma.studyReviewRequest.findFirst({
        where: { workspaceId, status: { not: "closed" } },
        orderBy: [{ requestNumber: "desc" }, { id: "desc" }],
        include: reviewInclude,
      });
      return { workspaceFound: true as const, review };
    });
    if (!result) throw databaseUnavailable();
    if (!result.workspaceFound) throw workspaceNotFound();
    return {
      schemaVersion: COMPETITION_READINESS_SCHEMA_VERSION,
      reviewRequest: result.review ? this.serialize(result.review) : null,
    };
  }

  async update(
    userId: string,
    reviewRequestId: string,
    input: UpdateStudyReviewRequestDto,
    requestId: string,
  ) {
    this.assertDb();
    await this.assertFeatureAccess(userId);
    this.assertAvailability(input.availability);
    if (input.timezone) this.assertTimezone(input.timezone);
    if ((input.artifactVersionIds?.length ?? 0) > 0 && !input.consentReceiptId) {
      throw new CompetitionReadinessHttpException(
        "PROFILE_INCOMPLETE",
        422,
        "A document-sharing consent receipt is required.",
      );
    }

    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        await tx.$queryRaw(
          Prisma.sql`SELECT "id" FROM "StudyReviewRequest" WHERE "id" = ${reviewRequestId} FOR UPDATE`,
        );
        const current = await tx.studyReviewRequest.findUnique({
          where: { id: reviewRequestId },
          select: {
            id: true,
            workspaceId: true,
            version: true,
            status: true,
            workspace: { select: { userId: true } },
          },
        });
        if (!current || current.workspace.userId !== userId) {
          throw workspaceNotFound();
        }
        if (current.version !== input.expectedVersion) {
          throw new CompetitionReadinessHttpException(
            "VERSION_CONFLICT",
            409,
            "Resource version is stale.",
            { currentVersion: current.version },
          );
        }
        if (current.status !== "more_information_needed") {
          throw new CompetitionReadinessHttpException(
            "REVIEW_REQUEST_NOT_TRIAGED",
            409,
            "Only a request awaiting more information can be resubmitted.",
          );
        }

        const now = new Date();
        if (input.artifactVersionIds !== undefined) {
          await this.replaceSharedVersions(
            tx,
            userId,
            current.workspaceId,
            reviewRequestId,
            input.artifactVersionIds,
            input.consentReceiptId,
            now,
          );
        }
        const updated = await tx.studyReviewRequest.updateMany({
          where: {
            id: reviewRequestId,
            version: input.expectedVersion,
            status: "more_information_needed",
          },
          data: {
            status: "submitted",
            version: { increment: 1 },
            submittedAt: now,
            missingItems: Prisma.JsonNull,
            ...(input.studentMessage !== undefined
              ? { studentMessage: input.studentMessage.trim() || null }
              : {}),
            ...(input.preferredContact !== undefined
              ? { preferredContact: input.preferredContact }
              : {}),
            ...(input.timezone !== undefined
              ? { timezone: input.timezone }
              : {}),
            ...(input.availability !== undefined
              ? { availability: input.availability as Prisma.InputJsonValue }
              : {}),
          },
        });
        if (updated.count !== 1) {
          const latest = await tx.studyReviewRequest.findUnique({
            where: { id: reviewRequestId },
            select: { version: true },
          });
          throw new CompetitionReadinessHttpException(
            "VERSION_CONFLICT",
            409,
            "Resource version is stale.",
            { currentVersion: latest?.version ?? current.version },
          );
        }
        await tx.scholarshipWorkspace.update({
          where: { id: current.workspaceId },
          data: {
            status: "review_requested",
            version: { increment: 1 },
            lastActivityAt: now,
          },
        });
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: null,
            action: "study_review.resubmitted",
            purposeCode: "review_request_completion",
            entityType: "StudyReviewRequest",
            entityId: reviewRequestId,
            requestId,
            result: "success",
            changes: {
              previousVersion: current.version,
              nextVersion: current.version + 1,
              sharedArtifactVersionIds: input.artifactVersionIds ?? null,
            },
          },
        });
        await this.outbox.enqueue(
          {
            eventId: `study_review.resubmitted:${reviewRequestId}:${current.version + 1}`,
            eventName: "study_review.resubmitted",
            aggregateType: "StudyReviewRequest",
            aggregateId: reviewRequestId,
            occurredAt: now,
            payload: {
              reviewRequestId,
              workspaceId: current.workspaceId,
              version: current.version + 1,
              sharedArtifactVersionIds: input.artifactVersionIds ?? [],
            },
          },
          tx,
        );
        const review = await tx.studyReviewRequest.findUnique({
          where: { id: reviewRequestId },
          include: reviewInclude,
        });
        if (!review) throw workspaceNotFound();
        return this.serialize(review);
      }),
    );
    if (!result) throw databaseUnavailable();
    return result;
  }

  private serialize(review: ReviewWithShares) {
    return {
      id: review.id,
      workspaceId: review.workspaceId,
      requestNumber: review.requestNumber,
      version: review.version,
      status: review.status,
      studentMessage: review.studentMessage,
      preferredContact: review.preferredContact,
      timezone: review.timezone,
      availability: review.availability,
      missingItems: this.normalizeMissingItems(review.missingItems),
      nextAction: this.nextAction(review.status),
      submittedAt: review.submittedAt?.toISOString() ?? null,
      triagedAt: review.triagedAt?.toISOString() ?? null,
      closedAt: review.closedAt?.toISOString() ?? null,
      createdAt: review.createdAt.toISOString(),
      updatedAt: review.updatedAt.toISOString(),
      sharedVersions: review.artifactShares.map((share) => ({
        shareId: share.id,
        artifactVersionId: share.artifactVersionId,
        consentReceiptId: share.consentReceiptId,
        grantedAt: share.grantedAt.toISOString(),
        revokedAt: share.revokedAt?.toISOString() ?? null,
        artifact: {
          id: share.artifactVersion.artifact.id,
          kind: share.artifactVersion.artifact.kind,
          title: share.artifactVersion.artifact.title,
        },
        version: {
          id: share.artifactVersion.id,
          versionNumber: share.artifactVersion.versionNumber,
          originalFileName: share.artifactVersion.originalFileName,
          mimeType: share.artifactVersion.mimeType,
          sizeBytes: share.artifactVersion.sizeBytes,
          sha256: share.artifactVersion.sha256,
          processingStatus: share.artifactVersion.processingStatus,
          uploadedAt: share.artifactVersion.uploadedAt?.toISOString() ?? null,
        },
      })),
    };
  }

  private replayReview(
    reservation: Extract<IdempotencyReservation, { state: "replay" }>,
  ): ReturnType<StudyReviewService["serialize"]> {
    const snapshot = reservation.responseSnapshot;
    if (
      snapshot === null ||
      Array.isArray(snapshot) ||
      typeof snapshot !== "object" ||
      typeof snapshot.id !== "string" ||
      !Array.isArray(snapshot.sharedVersions)
    ) {
      throw databaseUnavailable();
    }
    const replay = snapshot as unknown as ReturnType<
      StudyReviewService["serialize"]
    >;
    return {
      ...replay,
      missingItems: this.normalizeMissingItems(replay.missingItems),
      nextAction: this.nextAction(replay.status),
    };
  }

  private async replaceSharedVersions(
    tx: Prisma.TransactionClient,
    userId: string,
    workspaceId: string,
    reviewRequestId: string,
    artifactVersionIds: string[],
    consentReceiptId: string | undefined,
    now: Date,
  ) {
    if (artifactVersionIds.length === 0) {
      await tx.studyReviewArtifactShare.updateMany({
        where: { reviewRequestId, revokedAt: null },
        data: { revokedAt: now },
      });
      return;
    }
    if (!consentReceiptId) {
      throw new CompetitionReadinessHttpException(
        "PROFILE_INCOMPLETE",
        422,
        "A document-sharing consent receipt is required.",
      );
    }
    const consent = await tx.consentReceipt.findFirst({
      where: {
        id: consentReceiptId,
        userId,
        purpose: "advisor_document_share",
        revokedAt: null,
        grantedAt: { lte: now },
        notice: { effectiveAt: { lte: now }, retiredAt: null },
      },
      select: {
        id: true,
        user: { select: { birthDate: true } },
        guardianAuthorization: {
          select: {
            status: true,
            verifiedAt: true,
            expiresAt: true,
            revokedAt: true,
          },
        },
      },
    });
    if (!consent || !consent.user.birthDate) {
      throw new CompetitionReadinessHttpException(
        "PROFILE_INCOMPLETE",
        422,
        "An active document-sharing consent and birth date are required.",
      );
    }
    if (
      this.isMinorAt(consent.user.birthDate, now) &&
      !this.hasValidGuardianAuthorization(consent.guardianAuthorization, now)
    ) {
      throw new CompetitionReadinessHttpException(
        "GUARDIAN_CONSENT_REQUIRED",
        403,
        "Verified guardian authorization is required.",
      );
    }
    const versions = await tx.applicationArtifactVersion.findMany({
      where: {
        id: { in: artifactVersionIds },
        processingStatus: "clean",
        deletedAt: null,
        artifact: { workspaceId },
      },
      select: { id: true },
    });
    if (versions.length !== artifactVersionIds.length) {
      throw new CompetitionReadinessHttpException(
        "EVIDENCE_REJECTED",
        422,
        "Every shared artifact version must be clean and belong to the workspace.",
      );
    }
    await tx.studyReviewArtifactShare.updateMany({
      where: {
        reviewRequestId,
        revokedAt: null,
        artifactVersionId: { notIn: artifactVersionIds },
      },
      data: { revokedAt: now },
    });
    for (const artifactVersionId of artifactVersionIds) {
      await tx.studyReviewArtifactShare.upsert({
        where: {
          reviewRequestId_artifactVersionId: {
            reviewRequestId,
            artifactVersionId,
          },
        },
        create: {
          reviewRequestId,
          artifactVersionId,
          consentReceiptId: consent.id,
          grantedByUserId: userId,
          grantedAt: now,
        },
        update: {
          consentReceiptId: consent.id,
          grantedByUserId: userId,
          grantedAt: now,
          revokedAt: null,
        },
      });
    }
  }

  private normalizeMissingItems(value: Prisma.JsonValue | null): string[] | null {
    if (!Array.isArray(value)) return null;
    const items = value.filter(
      (item): item is string => typeof item === "string" && item.trim().length > 0,
    );
    return items.length === value.length ? items : null;
  }

  private nextAction(status: string) {
    const actions: Record<string, string> = {
      draft: "complete_request",
      submitted: "wait_for_triage",
      triaged: "wait_for_slot_offer",
      more_information_needed: "provide_more_information",
      call_offered: "choose_slot",
      scheduled: "appointment_scheduled",
      converted_to_case: "case_created",
      autonomy_recommended: "continue_autonomously",
      declined: "none",
      closed: "none",
    };
    return actions[status] ?? "none";
  }

  private assertTimezone(timezone: string) {
    try {
      new Intl.DateTimeFormat("en-US", { timeZone: timezone }).format();
    } catch {
      throw new CompetitionReadinessHttpException(
        "PROFILE_INCOMPLETE",
        422,
        "Invalid IANA timezone.",
      );
    }
  }

  private assertAvailability(value: Record<string, unknown> | undefined) {
    if (value && JSON.stringify(value).length > 10_000) {
      throw new CompetitionReadinessHttpException(
        "PROFILE_INCOMPLETE",
        422,
        "Availability payload is too large.",
      );
    }
  }

  private isMinorAt(birthDate: Date, now: Date): boolean {
    const adultThreshold = new Date(now);
    adultThreshold.setUTCFullYear(adultThreshold.getUTCFullYear() - 18);
    return birthDate > adultThreshold;
  }

  private hasValidGuardianAuthorization(
    authorization: {
      status: string;
      verifiedAt: Date | null;
      expiresAt: Date | null;
      revokedAt: Date | null;
    } | null,
    now: Date,
  ): boolean {
    return Boolean(
      authorization &&
      authorization.status === "verified" &&
      authorization.verifiedAt &&
      authorization.verifiedAt <= now &&
      authorization.revokedAt === null &&
      (authorization.expiresAt === null || authorization.expiresAt > now),
    );
  }

  private reviewAlreadyOpen() {
    return new CompetitionReadinessHttpException(
      "REVIEW_REQUEST_ALREADY_OPEN",
      409,
      "This workspace already has an open review request.",
    );
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private async assertFeatureAccess(userId: string) {
    if (process.env.KPB_STUDY_REVIEW_ENABLED?.trim().toLowerCase() !== "true") {
      throw featureDisabled("study_review");
    }
    const decision = await this.featureAccess.evaluate({
      feature: "success_lab",
      userId,
    });
    if (!decision.allowed) throw featureDisabled("success_lab");
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
