import { createHmac } from 'node:crypto';

import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  outboxEventConflict,
  versionConflict,
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
import type { CreateAdmissionDecisionDto } from './dto/create-admission-decision.dto';
import type { CreateFundingDecisionDto } from './dto/create-funding-decision.dto';
import type { CreateSubmissionDto } from './dto/create-submission.dto';
import type { LinkOutcomeEvidenceDto } from './dto/link-outcome-evidence.dto';

export const OUTCOME_TYPES = ['submission', 'admission', 'funding'] as const;
export type OutcomeType = (typeof OUTCOME_TYPES)[number];

const evidenceSummarySelect = {
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
  createdAt: true,
} satisfies Prisma.OutcomeEvidenceAssetSelect;

const submissionSelect = {
  id: true,
  workspaceId: true,
  version: true,
  lockVersion: true,
  submittedAt: true,
  submissionChannel: true,
  applicationRefHash: true,
  verificationStatus: true,
  verificationNotes: true,
  verifiedAt: true,
  createdAt: true,
  updatedAt: true,
  evidence: { select: evidenceSummarySelect },
} satisfies Prisma.ApplicationSubmissionSelect;

const admissionSelect = {
  id: true,
  workspaceId: true,
  supersedesId: true,
  version: true,
  lockVersion: true,
  isCurrent: true,
  issuedByName: true,
  admissionDecision: true,
  issuedAt: true,
  receivedAt: true,
  verificationStatus: true,
  verificationNotes: true,
  verifiedAt: true,
  createdAt: true,
  updatedAt: true,
  evidence: { select: evidenceSummarySelect },
} satisfies Prisma.ApplicationDecisionRecordSelect;

const fundingSelect = {
  id: true,
  workspaceId: true,
  admissionDecisionId: true,
  supersedesId: true,
  version: true,
  lockVersion: true,
  isCurrent: true,
  issuedByName: true,
  fundingDecision: true,
  fundingAmountMinor: true,
  fundingCurrency: true,
  issuedAt: true,
  receivedAt: true,
  verificationStatus: true,
  verificationNotes: true,
  verifiedAt: true,
  createdAt: true,
  updatedAt: true,
  evidence: { select: evidenceSummarySelect },
} satisfies Prisma.FundingDecisionRecordSelect;

type EvidenceSummary = Prisma.OutcomeEvidenceAssetGetPayload<{
  select: typeof evidenceSummarySelect;
}>;
type SubmissionRow = Prisma.ApplicationSubmissionGetPayload<{
  select: typeof submissionSelect;
}>;
type AdmissionRow = Prisma.ApplicationDecisionRecordGetPayload<{
  select: typeof admissionSelect;
}>;
type FundingRow = Prisma.FundingDecisionRecordGetPayload<{
  select: typeof fundingSelect;
}>;

type LockedWorkspace = {
  id: string;
  version: number;
  status: string;
};

@Injectable()
export class OutcomesService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly featureAccess: FeatureAccessService,
    private readonly idempotency: IdempotencyService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async createSubmission(
    userId: string,
    workspaceId: string,
    input: CreateSubmissionDto,
    idempotencyKey: string,
  ) {
    await this.assertReady(userId);
    const normalized = {
      expectedWorkspaceVersion: input.expectedWorkspaceVersion,
      submittedAt: new Date(input.submittedAt),
      submissionChannel: this.optionalText(input.submissionChannel),
      applicationRefHash: this.hashApplicationReference(
        input.applicationReference,
      ),
      evidenceId: input.evidenceId.trim(),
    };
    this.assertNotFuture(normalized.submittedAt, 'submittedAt');

    return this.runIdempotent(
      userId,
      'outcome.submission.create',
      idempotencyKey,
      { workspaceId, ...input },
      201,
      async (tx, reservation) => {
        const workspace = await this.lockOwnedWorkspace(
          tx,
          userId,
          workspaceId,
        );
        this.assertWorkspaceVersion(
          workspace,
          normalized.expectedWorkspaceVersion,
        );
        const evidence = await this.requireCleanEvidence(
          tx,
          userId,
          workspaceId,
          normalized.evidenceId,
        );
        this.assertPrimaryEvidenceKind(evidence.kind, [
          'submission_confirmation',
        ]);
        const latest = await tx.applicationSubmission.findFirst({
          where: { workspaceId },
          orderBy: { version: 'desc' },
          select: { version: true },
        });
        const submission = await tx.applicationSubmission.create({
          data: {
            workspaceId,
            version: (latest?.version ?? 0) + 1,
            submittedAt: normalized.submittedAt,
            submissionChannel: normalized.submissionChannel,
            applicationRefHash: normalized.applicationRefHash,
            evidenceId: evidence.id,
          },
          select: submissionSelect,
        });
        await this.createPrimaryEvidenceLink(
          tx,
          userId,
          'submission',
          submission.id,
          evidence.id,
        );
        const updatedWorkspace = await tx.scholarshipWorkspace.update({
          where: { id: workspaceId },
          data: {
            status:
              workspace.status === 'decision_received'
                ? 'decision_received'
                : 'submitted',
            submittedAt: normalized.submittedAt,
            lastActivityAt: new Date(),
            version: { increment: 1 },
          },
          select: { id: true, status: true, version: true },
        });
        await this.enqueueReported(
          tx,
          'application_submission_reported',
          'ApplicationSubmission',
          submission.id,
          workspaceId,
          'submission',
        );
        const body = {
          submission: this.serializeSubmission(submission),
          workspace: updatedWorkspace,
        };
        await this.completeReservation(
          tx,
          reservation,
          body,
          'ApplicationSubmission',
          submission.id,
          submission.lockVersion,
        );
        return body;
      },
    );
  }

  async listSubmissions(userId: string, workspaceId: string) {
    await this.assertReady(userId);
    await this.assertOwnedWorkspace(userId, workspaceId);
    const rows = await this.prismaService.execute((prisma) =>
      prisma.applicationSubmission.findMany({
        where: { workspaceId },
        orderBy: [{ version: 'desc' }, { createdAt: 'desc' }],
        select: submissionSelect,
      }),
    );
    if (!rows) throw databaseUnavailable();
    const supplemental = await this.loadSupplemental(
      'submission',
      rows.map((row) => row.id),
    );
    return {
      items: rows.map((row) =>
        this.serializeSubmission(row, supplemental.get(row.id)),
      ),
    };
  }

  async createAdmissionDecision(
    userId: string,
    workspaceId: string,
    input: CreateAdmissionDecisionDto,
    idempotencyKey: string,
  ) {
    await this.assertReady(userId);
    const issuedByName = this.requiredText(input.issuedByName, 'issuedByName');
    const receivedAt = new Date(input.receivedAt);
    const issuedAt = input.issuedAt ? new Date(input.issuedAt) : null;
    this.assertChronology(issuedAt, receivedAt);
    return this.runIdempotent(
      userId,
      'outcome.admission.create',
      idempotencyKey,
      { workspaceId, ...input, issuedByName },
      201,
      async (tx, reservation) => {
        const workspace = await this.lockOwnedWorkspace(
          tx,
          userId,
          workspaceId,
        );
        this.assertWorkspaceVersion(workspace, input.expectedWorkspaceVersion);
        const evidence = await this.requireCleanEvidence(
          tx,
          userId,
          workspaceId,
          input.evidenceId.trim(),
        );
        this.assertPrimaryEvidenceKind(
          evidence.kind,
          this.admissionEvidenceKinds(input.admissionDecision),
        );
        const current = await tx.applicationDecisionRecord.findFirst({
          where: { workspaceId, isCurrent: true },
          select: { id: true },
        });
        const latest = await tx.applicationDecisionRecord.findFirst({
          where: { workspaceId },
          orderBy: { version: 'desc' },
          select: { version: true },
        });
        if (current) {
          const retired = await tx.applicationDecisionRecord.updateMany({
            where: { id: current.id, isCurrent: true },
            data: { isCurrent: false, lockVersion: { increment: 1 } },
          });
          if (retired.count !== 1) throw this.alreadySuperseded();
        }
        const decision = await tx.applicationDecisionRecord.create({
          data: {
            workspaceId,
            supersedesId: current?.id,
            version: (latest?.version ?? 0) + 1,
            issuedByName,
            admissionDecision: input.admissionDecision,
            issuedAt,
            receivedAt,
            evidenceId: evidence.id,
          },
          select: admissionSelect,
        });
        await this.createPrimaryEvidenceLink(
          tx,
          userId,
          'admission',
          decision.id,
          evidence.id,
        );
        const updatedWorkspace = await tx.scholarshipWorkspace.update({
          where: { id: workspaceId },
          data: {
            status: 'decision_received',
            decisionReceivedAt: receivedAt,
            lastActivityAt: new Date(),
            version: { increment: 1 },
          },
          select: { id: true, status: true, version: true },
        });
        await this.enqueueReported(
          tx,
          'application_decision_reported',
          'ApplicationDecisionRecord',
          decision.id,
          workspaceId,
          'admission',
        );
        const body = {
          decision: this.serializeAdmission(decision),
          workspace: updatedWorkspace,
        };
        await this.completeReservation(
          tx,
          reservation,
          body,
          'ApplicationDecisionRecord',
          decision.id,
          decision.lockVersion,
        );
        return body;
      },
    );
  }

  async createFundingDecision(
    userId: string,
    workspaceId: string,
    input: CreateFundingDecisionDto,
    idempotencyKey: string,
  ) {
    await this.assertReady(userId);
    const issuedByName = this.requiredText(input.issuedByName, 'issuedByName');
    const amount = this.normalizeFunding(input);
    const receivedAt = new Date(input.receivedAt);
    const issuedAt = input.issuedAt ? new Date(input.issuedAt) : null;
    this.assertChronology(issuedAt, receivedAt);
    return this.runIdempotent(
      userId,
      'outcome.funding.create',
      idempotencyKey,
      { workspaceId, ...input, issuedByName },
      201,
      async (tx, reservation) => {
        const workspace = await this.lockOwnedWorkspace(
          tx,
          userId,
          workspaceId,
        );
        this.assertWorkspaceVersion(workspace, input.expectedWorkspaceVersion);
        const evidence = await this.requireCleanEvidence(
          tx,
          userId,
          workspaceId,
          input.evidenceId.trim(),
        );
        this.assertPrimaryEvidenceKind(
          evidence.kind,
          this.fundingEvidenceKinds(input.fundingDecision),
        );
        if (input.admissionDecisionId) {
          const admission = await tx.applicationDecisionRecord.findFirst({
            where: {
              id: input.admissionDecisionId.trim(),
              workspaceId,
            },
            select: { id: true },
          });
          if (!admission) throw workspaceNotFound();
        }
        const current = await tx.fundingDecisionRecord.findFirst({
          where: { workspaceId, isCurrent: true },
          select: { id: true },
        });
        const latest = await tx.fundingDecisionRecord.findFirst({
          where: { workspaceId },
          orderBy: { version: 'desc' },
          select: { version: true },
        });
        if (current) {
          const retired = await tx.fundingDecisionRecord.updateMany({
            where: { id: current.id, isCurrent: true },
            data: { isCurrent: false, lockVersion: { increment: 1 } },
          });
          if (retired.count !== 1) throw this.alreadySuperseded();
        }
        const decision = await tx.fundingDecisionRecord.create({
          data: {
            workspaceId,
            admissionDecisionId: input.admissionDecisionId?.trim(),
            supersedesId: current?.id,
            version: (latest?.version ?? 0) + 1,
            issuedByName,
            fundingDecision: input.fundingDecision,
            fundingAmountMinor: amount.amount,
            fundingCurrency: amount.currency,
            issuedAt,
            receivedAt,
            evidenceId: evidence.id,
          },
          select: fundingSelect,
        });
        await this.createPrimaryEvidenceLink(
          tx,
          userId,
          'funding',
          decision.id,
          evidence.id,
        );
        const updatedWorkspace = await tx.scholarshipWorkspace.update({
          where: { id: workspaceId },
          data: {
            status: 'decision_received',
            decisionReceivedAt: receivedAt,
            lastActivityAt: new Date(),
            version: { increment: 1 },
          },
          select: { id: true, status: true, version: true },
        });
        await this.enqueueReported(
          tx,
          'funding_decision_reported',
          'FundingDecisionRecord',
          decision.id,
          workspaceId,
          'funding',
        );
        const body = {
          decision: this.serializeFunding(decision),
          workspace: updatedWorkspace,
        };
        await this.completeReservation(
          tx,
          reservation,
          body,
          'FundingDecisionRecord',
          decision.id,
          decision.lockVersion,
        );
        return body;
      },
    );
  }

  async getDecisions(userId: string, workspaceId: string) {
    await this.assertReady(userId);
    const workspace = await this.assertOwnedWorkspace(userId, workspaceId);
    const result = await this.prismaService.execute(async (prisma) => {
      const [admission, funding] = await Promise.all([
        prisma.applicationDecisionRecord.findMany({
          where: { workspaceId },
          orderBy: [{ version: 'desc' }, { createdAt: 'desc' }],
          select: admissionSelect,
        }),
        prisma.fundingDecisionRecord.findMany({
          where: { workspaceId },
          orderBy: [{ version: 'desc' }, { createdAt: 'desc' }],
          select: fundingSelect,
        }),
      ]);
      return { admission, funding };
    });
    if (!result) throw databaseUnavailable();
    const [admissionEvidence, fundingEvidence] = await Promise.all([
      this.loadSupplemental(
        'admission',
        result.admission.map((row) => row.id),
      ),
      this.loadSupplemental(
        'funding',
        result.funding.map((row) => row.id),
      ),
    ]);
    const currentAdmission = result.admission.find((row) => row.isCurrent);
    const currentFunding = result.funding.find((row) => row.isCurrent);
    return {
      current: {
        admission: currentAdmission
          ? this.serializeAdmission(
              currentAdmission,
              admissionEvidence.get(currentAdmission.id),
            )
          : null,
        funding: currentFunding
          ? this.serializeFunding(
              currentFunding,
              fundingEvidence.get(currentFunding.id),
            )
          : null,
      },
      history: {
        admission: result.admission
          .filter((row) => !row.isCurrent)
          .map((row) =>
            this.serializeAdmission(row, admissionEvidence.get(row.id)),
          ),
        funding: result.funding
          .filter((row) => !row.isCurrent)
          .map((row) =>
            this.serializeFunding(row, fundingEvidence.get(row.id)),
          ),
      },
      workspaceVersion: workspace.version,
    };
  }

  async linkEvidence(
    userId: string,
    type: OutcomeType,
    outcomeId: string,
    input: LinkOutcomeEvidenceDto,
    idempotencyKey: string,
  ) {
    await this.assertReady(userId);
    return this.runIdempotent(
      userId,
      `outcome.${type}.evidence.link`,
      idempotencyKey,
      { type, outcomeId, ...input },
      200,
      async (tx, reservation) => {
        const target = await this.findOwnedOutcome(tx, userId, type, outcomeId);
        if (!target) throw workspaceNotFound();
        await this.lockOwnedWorkspace(tx, userId, target.workspaceId);
        const refreshed = await this.findOwnedOutcome(
          tx,
          userId,
          type,
          outcomeId,
        );
        if (!refreshed) throw workspaceNotFound();
        if (!refreshed.isCurrent) throw this.alreadySuperseded();
        if (refreshed.lockVersion !== input.expectedVersion) {
          throw versionConflict(refreshed.lockVersion);
        }
        const evidence = await this.requireCleanEvidence(
          tx,
          userId,
          refreshed.workspaceId,
          input.evidenceId.trim(),
        );
        await tx.outcomeEvidenceLink.create({
          data: {
            evidenceId: evidence.id,
            entityType: type,
            entityId: outcomeId,
            linkedByUserId: userId,
          },
        });
        const updated = await this.incrementOutcomeLock(
          tx,
          type,
          outcomeId,
          refreshed.lockVersion,
        );
        if (!updated) throw versionConflict(refreshed.lockVersion);
        await this.outbox.enqueue(
          {
            eventId: `outcome-evidence-linked:${type}:${outcomeId}:${evidence.id}`,
            eventName: 'outcome_evidence_linked',
            aggregateType: this.aggregateType(type),
            aggregateId: outcomeId,
            payload: {
              workspaceId: refreshed.workspaceId,
              outcomeType: type,
              outcomeId,
            },
          },
          tx,
        );
        const outcome = await this.loadSerializedOutcome(
          tx,
          type,
          outcomeId,
        );
        const body = { outcome };
        await this.completeReservation(
          tx,
          reservation,
          body,
          this.aggregateType(type),
          outcomeId,
          refreshed.lockVersion + 1,
          200,
        );
        return body;
      },
    );
  }

  private async runIdempotent<T extends object>(
    userId: string,
    operation: string,
    idempotencyKey: string,
    payload: unknown,
    successStatusCode: 200 | 201,
    mutation: (
      tx: Prisma.TransactionClient,
      reservation: Extract<IdempotencyReservation, { state: 'acquired' }>,
    ) => Promise<T>,
  ): Promise<{ statusCode: number; body: T | Record<string, unknown> }> {
    try {
      const result = await this.prismaService.execute((prisma) =>
        prisma.$transaction(async (tx) => {
          const reservation = await this.idempotency.reserve(
            {
              actorType: 'student',
              actorId: userId,
              operation,
              idempotencyKey,
              payload,
            },
            tx,
          );
          if (reservation.state === 'replay') {
            return {
              statusCode: 200,
              body: this.replayBody(reservation),
            };
          }
          if (reservation.state !== 'acquired') throw idempotencyInProgress();
          const body = await mutation(tx, reservation);
          return { statusCode: successStatusCode, body };
        }),
      );
      if (!result) throw databaseUnavailable();
      return result;
    } catch (error) {
      this.translateInfrastructureError(error);
    }
  }

  private async completeReservation<T extends object>(
    tx: Prisma.TransactionClient,
    reservation: Extract<IdempotencyReservation, { state: 'acquired' }>,
    body: T,
    resourceType: string,
    resourceId: string,
    resultingVersion: number,
    responseCode: 200 | 201 = 201,
  ) {
    await this.idempotency.complete(
      {
        recordId: reservation.recordId,
        responseCode,
        responseSnapshot: body as unknown as Prisma.InputJsonValue,
        resourceType,
        resourceId,
        resultingVersion,
      },
      tx,
    );
  }

  private async lockOwnedWorkspace(
    tx: Prisma.TransactionClient,
    userId: string,
    workspaceId: string,
  ): Promise<LockedWorkspace> {
    const rows = await tx.$queryRaw<LockedWorkspace[]>(Prisma.sql`
      SELECT "id", "version", "status"::text
      FROM "ScholarshipWorkspace"
      WHERE "id" = ${workspaceId}
        AND "userId" = ${userId}
        AND "status" <> 'archived'
      FOR UPDATE
    `);
    const workspace = rows[0];
    if (!workspace) throw workspaceNotFound();
    return workspace;
  }

  private async assertOwnedWorkspace(userId: string, workspaceId: string) {
    const workspace = await this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findFirst({
        where: { id: workspaceId, userId, status: { not: 'archived' } },
        select: { id: true, version: true },
      }),
    );
    if (!workspace) throw workspaceNotFound();
    return workspace;
  }

  private assertWorkspaceVersion(
    workspace: LockedWorkspace,
    expectedVersion: number,
  ) {
    if (workspace.version !== expectedVersion) {
      throw versionConflict(workspace.version);
    }
  }

  private async requireCleanEvidence(
    tx: Prisma.TransactionClient,
    userId: string,
    workspaceId: string,
    evidenceId: string,
  ) {
    const evidence = await tx.outcomeEvidenceAsset.findFirst({
      where: {
        id: evidenceId,
        workspaceId,
        ownerUserId: userId,
        consentReceipt: {
          userId,
          purpose: 'outcome_evidence',
          revokedAt: null,
          notice: { retiredAt: null, effectiveAt: { lte: new Date() } },
        },
      },
      select: {
        id: true,
        kind: true,
        processingStatus: true,
        deletedAt: true,
        storageKey: true,
      },
    });
    if (!evidence) throw this.evidenceRequired();
    if (
      evidence.processingStatus === 'pending_upload' ||
      evidence.processingStatus === 'uploaded' ||
      evidence.processingStatus === 'scanning'
    ) {
      throw new CompetitionReadinessHttpException(
        'EVIDENCE_SCAN_PENDING',
        409,
        'Outcome evidence is not clean yet.',
      );
    }
    if (
      evidence.processingStatus !== 'clean' ||
      evidence.deletedAt ||
      !evidence.storageKey
    ) {
      throw new CompetitionReadinessHttpException(
        'EVIDENCE_REJECTED',
        422,
        'Outcome evidence is not available.',
      );
    }
    return evidence;
  }

  private async createPrimaryEvidenceLink(
    tx: Prisma.TransactionClient,
    userId: string,
    type: OutcomeType,
    entityId: string,
    evidenceId: string,
  ) {
    await tx.outcomeEvidenceLink.create({
      data: {
        evidenceId,
        entityType: type,
        entityId,
        isPrimary: true,
        linkedByUserId: userId,
      },
    });
  }

  private async enqueueReported(
    tx: Prisma.TransactionClient,
    eventName: string,
    aggregateType: string,
    aggregateId: string,
    workspaceId: string,
    outcomeType: OutcomeType,
  ) {
    await this.outbox.enqueue(
      {
        eventId: `${eventName}:${aggregateId}`,
        eventName,
        aggregateType,
        aggregateId,
        payload: { workspaceId, outcomeType, outcomeId: aggregateId },
      },
      tx,
    );
  }

  private async loadSupplemental(type: OutcomeType, entityIds: string[]) {
    const grouped = new Map<string, EvidenceSummary[]>();
    if (entityIds.length === 0) return grouped;
    const links = await this.prismaService.execute((prisma) =>
      prisma.outcomeEvidenceLink.findMany({
        where: {
          entityType: type,
          entityId: { in: entityIds },
          isPrimary: false,
        },
        orderBy: { linkedAt: 'asc' },
        select: {
          entityId: true,
          evidence: { select: evidenceSummarySelect },
        },
      }),
    );
    if (!links) throw databaseUnavailable();
    for (const link of links) {
      const items = grouped.get(link.entityId) ?? [];
      items.push(link.evidence);
      grouped.set(link.entityId, items);
    }
    return grouped;
  }

  private async findOwnedOutcome(
    tx: Prisma.TransactionClient,
    userId: string,
    type: OutcomeType,
    outcomeId: string,
  ) {
    if (type === 'submission') {
      const row = await tx.applicationSubmission.findFirst({
        where: { id: outcomeId, workspace: { userId } },
        select: { workspaceId: true, lockVersion: true },
      });
      return row ? { ...row, isCurrent: true } : null;
    }
    if (type === 'admission') {
      return tx.applicationDecisionRecord.findFirst({
        where: { id: outcomeId, workspace: { userId } },
        select: { workspaceId: true, lockVersion: true, isCurrent: true },
      });
    }
    return tx.fundingDecisionRecord.findFirst({
      where: { id: outcomeId, workspace: { userId } },
      select: { workspaceId: true, lockVersion: true, isCurrent: true },
    });
  }

  private async incrementOutcomeLock(
    tx: Prisma.TransactionClient,
    type: OutcomeType,
    outcomeId: string,
    lockVersion: number,
  ) {
    const data = {
      lockVersion: { increment: 1 },
      verificationStatus: 'pending' as const,
      verifiedAt: null,
      verifiedById: null,
    };
    const where = { id: outcomeId, lockVersion };
    const result =
      type === 'submission'
        ? await tx.applicationSubmission.updateMany({ where, data })
        : type === 'admission'
          ? await tx.applicationDecisionRecord.updateMany({ where, data })
          : await tx.fundingDecisionRecord.updateMany({ where, data });
    return result.count === 1;
  }

  private async loadSerializedOutcome(
    tx: Prisma.TransactionClient,
    type: OutcomeType,
    outcomeId: string,
  ) {
    const links = await tx.outcomeEvidenceLink.findMany({
      where: { entityType: type, entityId: outcomeId, isPrimary: false },
      orderBy: { linkedAt: 'asc' },
      select: { evidence: { select: evidenceSummarySelect } },
    });
    const supplemental = links.map((link) => link.evidence);
    if (type === 'submission') {
      const row = await tx.applicationSubmission.findUnique({
        where: { id: outcomeId },
        select: submissionSelect,
      });
      if (!row) throw workspaceNotFound();
      return this.serializeSubmission(row, supplemental);
    }
    if (type === 'admission') {
      const row = await tx.applicationDecisionRecord.findUnique({
        where: { id: outcomeId },
        select: admissionSelect,
      });
      if (!row) throw workspaceNotFound();
      return this.serializeAdmission(row, supplemental);
    }
    const row = await tx.fundingDecisionRecord.findUnique({
      where: { id: outcomeId },
      select: fundingSelect,
    });
    if (!row) throw workspaceNotFound();
    return this.serializeFunding(row, supplemental);
  }

  private serializeSubmission(
    row: SubmissionRow,
    supplemental: EvidenceSummary[] = [],
  ) {
    return {
      id: row.id,
      workspaceId: row.workspaceId,
      version: row.version,
      lockVersion: row.lockVersion,
      submittedAt: row.submittedAt.toISOString(),
      submissionChannel: row.submissionChannel,
      hasApplicationReference: Boolean(row.applicationRefHash),
      verificationStatus: row.verificationStatus,
      verificationNotes: row.verificationNotes,
      verifiedAt: row.verifiedAt?.toISOString() ?? null,
      evidence: [row.evidence, ...supplemental].map((item) =>
        this.serializeEvidence(item),
      ),
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  private serializeAdmission(
    row: AdmissionRow,
    supplemental: EvidenceSummary[] = [],
  ) {
    return {
      id: row.id,
      workspaceId: row.workspaceId,
      supersedesId: row.supersedesId,
      version: row.version,
      lockVersion: row.lockVersion,
      isCurrent: row.isCurrent,
      issuedByName: row.issuedByName,
      admissionDecision: row.admissionDecision,
      issuedAt: row.issuedAt?.toISOString() ?? null,
      receivedAt: row.receivedAt.toISOString(),
      verificationStatus: row.verificationStatus,
      verificationNotes: row.verificationNotes,
      verifiedAt: row.verifiedAt?.toISOString() ?? null,
      evidence: [row.evidence, ...supplemental].map((item) =>
        this.serializeEvidence(item),
      ),
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  private serializeFunding(
    row: FundingRow,
    supplemental: EvidenceSummary[] = [],
  ) {
    return {
      id: row.id,
      workspaceId: row.workspaceId,
      admissionDecisionId: row.admissionDecisionId,
      supersedesId: row.supersedesId,
      version: row.version,
      lockVersion: row.lockVersion,
      isCurrent: row.isCurrent,
      issuedByName: row.issuedByName,
      fundingDecision: row.fundingDecision,
      fundingAmountMinor: row.fundingAmountMinor?.toString() ?? null,
      fundingCurrency: row.fundingCurrency,
      issuedAt: row.issuedAt?.toISOString() ?? null,
      receivedAt: row.receivedAt.toISOString(),
      verificationStatus: row.verificationStatus,
      verificationNotes: row.verificationNotes,
      verifiedAt: row.verifiedAt?.toISOString() ?? null,
      evidence: [row.evidence, ...supplemental].map((item) =>
        this.serializeEvidence(item),
      ),
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
    };
  }

  private serializeEvidence(item: EvidenceSummary) {
    return {
      id: item.id,
      workspaceId: item.workspaceId,
      kind: item.kind,
      originalFileName: item.originalFileName,
      mimeType: item.mimeType,
      sizeBytes: item.sizeBytes,
      processingStatus: item.processingStatus,
      version: item.version,
      rejectionCode: item.rejectionCode,
      uploadedAt: item.uploadedAt?.toISOString() ?? null,
      createdAt: item.createdAt.toISOString(),
    };
  }

  private normalizeFunding(input: CreateFundingDecisionDto) {
    const funded =
      input.fundingDecision === 'full' ||
      input.fundingDecision === 'partial';
    const hasAmount = input.fundingAmountMinor !== undefined;
    const hasCurrency = input.fundingCurrency !== undefined;
    if (hasAmount !== hasCurrency || (!funded && (hasAmount || hasCurrency))) {
      throw new BadRequestException(
        'Funding amount and currency must be coherent with fundingDecision.',
      );
    }
    return {
      amount: hasAmount ? BigInt(input.fundingAmountMinor!) : null,
      currency: hasCurrency ? input.fundingCurrency!.trim() : null,
    };
  }

  private assertChronology(issuedAt: Date | null, receivedAt: Date) {
    this.assertNotFuture(receivedAt, 'receivedAt');
    if (!issuedAt) return;
    this.assertNotFuture(issuedAt, 'issuedAt');
    if (issuedAt.getTime() > receivedAt.getTime()) {
      throw new BadRequestException('issuedAt must not be after receivedAt.');
    }
  }

  private assertNotFuture(value: Date, field: string) {
    if (value.getTime() > Date.now()) {
      throw new BadRequestException(`${field} must not be in the future.`);
    }
  }

  private admissionEvidenceKinds(decision: string) {
    switch (decision) {
      case 'admitted':
        return ['admission_decision', 'enrollment_confirmation'];
      case 'rejected':
        return ['rejection_decision'];
      case 'waitlisted':
        return ['waitlist_decision'];
      default:
        return ['admission_decision', 'other'];
    }
  }

  private fundingEvidenceKinds(decision: string) {
    if (decision === 'full' || decision === 'partial') {
      return ['funding_award'];
    }
    if (decision === 'none') return ['funding_rejection', 'other'];
    return ['funding_award', 'funding_rejection', 'other'];
  }

  private assertPrimaryEvidenceKind(actual: string, allowed: string[]) {
    if (!allowed.includes(actual)) {
      throw new CompetitionReadinessHttpException(
        'EVIDENCE_REJECTED',
        422,
        'Evidence kind is not compatible with the declared outcome.',
      );
    }
  }

  private hashApplicationReference(value: string | undefined) {
    if (value === undefined) return null;
    const normalized = value
      .normalize('NFKC')
      .trim()
      .replace(/\s+/g, ' ')
      .toUpperCase();
    if (!normalized) throw new BadRequestException('applicationReference is blank.');
    const configured = process.env.KPB_OUTCOME_REFERENCE_HMAC_SECRET?.trim();
    if (!configured && process.env.NODE_ENV === 'production') {
      throw databaseUnavailable();
    }
    return createHmac(
      'sha256',
      configured || 'kpb-outcome-reference-dev-only',
    )
      .update(normalized)
      .digest('hex');
  }

  private requiredText(value: string, field: string) {
    const normalized = value.trim().replace(/\s+/g, ' ');
    if (!normalized) throw new BadRequestException(`${field} is blank.`);
    return normalized;
  }

  private optionalText(value: string | undefined) {
    if (value === undefined) return null;
    const normalized = value.trim().replace(/\s+/g, ' ');
    return normalized || null;
  }

  private replayBody(
    reservation: Extract<IdempotencyReservation, { state: 'replay' }>,
  ) {
    const snapshot = reservation.responseSnapshot;
    if (snapshot === null || Array.isArray(snapshot) || typeof snapshot !== 'object') {
      throw databaseUnavailable();
    }
    return snapshot as Record<string, unknown>;
  }

  private aggregateType(type: OutcomeType) {
    return type === 'submission'
      ? 'ApplicationSubmission'
      : type === 'admission'
        ? 'ApplicationDecisionRecord'
        : 'FundingDecisionRecord';
  }

  private evidenceRequired() {
    return new CompetitionReadinessHttpException(
      'OUTCOME_EVIDENCE_REQUIRED',
      422,
      'Clean, consented outcome evidence is required.',
    );
  }

  private alreadySuperseded() {
    return new CompetitionReadinessHttpException(
      'OUTCOME_ALREADY_SUPERSEDED',
      409,
      'This outcome has already been superseded.',
    );
  }

  private async assertReady(userId: string) {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    const decision = await this.featureAccess.evaluate({
      feature: 'outcome_evidence',
      userId,
    });
    if (!decision.allowed) throw featureDisabled('outcome_evidence');
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
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      throw this.alreadySuperseded();
    }
    throw error;
  }
}
