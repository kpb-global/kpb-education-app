import { BadRequestException, Injectable } from '@nestjs/common';
import {
  EvidenceVerificationStatus,
  Prisma,
} from '@prisma/client';

import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  versionConflict,
} from '../common/competition-readiness.errors';
import { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import {
  OUTCOME_TYPES,
  type OutcomeType,
} from '../outcomes/outcomes.service';
import { AdminOutcomesAccessService } from './admin-outcomes-access.service';
import type { ListAdminOutcomesDto } from './dto/list-admin-outcomes.dto';
import type { UpdateOutcomeVerificationDto } from './dto/update-outcome-verification.dto';

const adminEvidenceSelect = {
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
  consentReceipt: { select: { revokedAt: true } },
} satisfies Prisma.OutcomeEvidenceAssetSelect;

const adminWorkspaceSelect = {
  id: true,
  version: true,
  status: true,
  user: { select: { id: true, fullName: true, email: true } },
  scholarship: {
    select: {
      id: true,
      nameFr: true,
      nameEn: true,
      countryId: true,
      countryNameFr: true,
      countryNameEn: true,
    },
  },
} satisfies Prisma.ScholarshipWorkspaceSelect;

const adminSubmissionSelect = {
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
  evidence: { select: adminEvidenceSelect },
  workspace: { select: adminWorkspaceSelect },
} satisfies Prisma.ApplicationSubmissionSelect;

const adminAdmissionSelect = {
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
  evidence: { select: adminEvidenceSelect },
  workspace: { select: adminWorkspaceSelect },
} satisfies Prisma.ApplicationDecisionRecordSelect;

const adminFundingSelect = {
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
  evidence: { select: adminEvidenceSelect },
  workspace: { select: adminWorkspaceSelect },
} satisfies Prisma.FundingDecisionRecordSelect;

type AdminEvidence = Prisma.OutcomeEvidenceAssetGetPayload<{
  select: typeof adminEvidenceSelect;
}>;
type AdminSubmission = Prisma.ApplicationSubmissionGetPayload<{
  select: typeof adminSubmissionSelect;
}>;
type AdminAdmission = Prisma.ApplicationDecisionRecordGetPayload<{
  select: typeof adminAdmissionSelect;
}>;
type AdminFunding = Prisma.FundingDecisionRecordGetPayload<{
  select: typeof adminFundingSelect;
}>;
type AdminOutcome = AdminSubmission | AdminAdmission | AdminFunding;

type ListEntry = {
  type: OutcomeType;
  id: string;
  createdAt: Date;
  row: AdminOutcome;
};

@Injectable()
export class AdminOutcomesService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminOutcomesAccessService,
    private readonly outbox: DomainEventOutboxService,
  ) {}

  async list(actor: AdminSessionUser, query: ListAdminOutcomesDto) {
    this.assertDb();
    const types = query.type ? [query.type] : [...OUTCOME_TYPES];
    const offset = this.decodeCursor(query.cursor);
    const requested = offset + query.limit + 1;
    const groups = await Promise.all(
      types.map((type) => this.listType(actor, type, query, requested)),
    );
    const entries = groups
      .flat()
      .sort(
        (left, right) =>
          right.createdAt.getTime() - left.createdAt.getTime() ||
          right.id.localeCompare(left.id) ||
          right.type.localeCompare(left.type),
      );
    const page = entries.slice(offset, offset + query.limit);
    return {
      items: page.map((entry) => this.serializeListEntry(entry)),
      nextCursor:
        entries.length > offset + query.limit
          ? this.encodeCursor(offset + query.limit)
          : null,
    };
  }

  async detail(
    actor: AdminSessionUser,
    type: OutcomeType,
    outcomeId: string,
  ) {
    this.assertDb();
    const row = await this.findScoped(actor, type, outcomeId);
    if (!row) throw this.forbidden();
    const supplemental = await this.loadSupplemental(type, outcomeId);
    return {
      outcome: this.serializeOutcome(type, row, supplemental),
      evidence: this.serializeEvidenceList(row.evidence, supplemental),
    };
  }

  async verify(
    actor: AdminSessionUser,
    type: OutcomeType,
    outcomeId: string,
    input: UpdateOutcomeVerificationDto,
    requestId: string,
  ) {
    this.assertDb();
    const scoped = await this.findScoped(actor, type, outcomeId);
    if (!scoped) throw this.forbidden();
    if ('isCurrent' in scoped && !scoped.isCurrent) {
      throw new CompetitionReadinessHttpException(
        'OUTCOME_ALREADY_SUPERSEDED',
        409,
        'Only the current decision can be verified.',
      );
    }
    await this.access.assertIndependentVerifier(actor, {
      id: outcomeId,
      workspaceId: scoped.workspaceId,
    });
    this.assertTransition(scoped.verificationStatus, input.status);
    const reasonCode = input.reasonCode?.trim() || null;
    const notes = input.notes?.trim() || null;
    if (
      (input.status === 'needs_information' || input.status === 'rejected') &&
      !reasonCode
    ) {
      throw new BadRequestException(
        'reasonCode is required for needs_information or rejected.',
      );
    }
    this.assertEvidenceVerifiable(scoped.evidence);

    // CR-027 hardening: grant revocation and counsellor assignment are checked
    // immediately before this transaction, but AdminScopeGrant is not yet
    // transactionally versioned. The row-level lock + lockVersion protects the
    // outcome itself; a future policy revision will snapshot grant versions in
    // the same transaction for a zero-window authorization revocation check.
    const result = await this.prismaService.execute((prisma) =>
      prisma.$transaction(async (tx) => {
        const current = await this.loadCurrentForUpdate(tx, type, outcomeId);
        if (!current) throw this.forbidden();
        if (current.lockVersion !== input.expectedVersion) {
          throw versionConflict(current.lockVersion);
        }
        if (!current.isCurrent) {
          throw new CompetitionReadinessHttpException(
            'OUTCOME_ALREADY_SUPERSEDED',
            409,
            'Only the current decision can be verified.',
          );
        }
        this.assertTransition(current.verificationStatus, input.status);
        const now = new Date();
        const update = {
          verificationStatus: input.status,
          verificationNotes: notes,
          verifiedAt: input.status === 'verified' ? now : null,
          verifiedById: input.status === 'verified' ? actor.id : null,
          lockVersion: { increment: 1 },
        };
        const count = await this.updateOutcome(
          tx,
          type,
          outcomeId,
          input.expectedVersion,
          update,
        );
        if (count !== 1) {
          const latest = await this.loadCurrentForUpdate(tx, type, outcomeId);
          throw versionConflict(latest?.lockVersion ?? input.expectedVersion);
        }

        await tx.outcomeVerificationEvent.create({
          data: {
            entityType: type,
            entityId: outcomeId,
            fromStatus: current.verificationStatus,
            toStatus: input.status,
            actorAdminId: actor.id,
            reasonCode,
          },
        });
        await tx.adminAuditEvent.create({
          data: {
            actorAdminId: actor.id,
            action: 'outcome.verification_updated',
            purposeCode: 'outcome_verification',
            entityType: this.aggregateType(type),
            entityId: outcomeId,
            requestId,
            reasonCode,
            result: 'success',
            changes: {
              fromStatus: current.verificationStatus,
              toStatus: input.status,
              notesProvided: Boolean(notes),
            },
          },
        });
        await this.outbox.enqueue(
          {
            eventId: `outcome-verification:${type}:${outcomeId}:${input.expectedVersion + 1}`,
            eventName: this.verificationEventName(type, input.status),
            aggregateType: this.aggregateType(type),
            aggregateId: outcomeId,
            payload: {
              workspaceId: current.workspaceId,
              outcomeType: type,
              outcomeId,
            },
          },
          tx,
        );
        return this.loadById(tx, type, outcomeId);
      }),
    );
    if (!result) throw databaseUnavailable();
    const supplemental = await this.loadSupplemental(type, outcomeId);
    return { outcome: this.serializeOutcome(type, result, supplemental) };
  }

  private async listType(
    actor: AdminSessionUser,
    type: OutcomeType,
    query: ListAdminOutcomesDto,
    take: number,
  ): Promise<ListEntry[]> {
    const scope = await this.access.whereFor(actor, type, query.countryCode);
    const status = query.verificationStatus
      ? { verificationStatus: query.verificationStatus }
      : {};
    if (type === 'submission') {
      const rows = await this.prismaService.execute((prisma) =>
        prisma.applicationSubmission.findMany({
          where: { ...scope, ...status },
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take,
          select: adminSubmissionSelect,
        }),
      );
      if (!rows) throw databaseUnavailable();
      return rows.map((row) => ({
        type,
        id: row.id,
        createdAt: row.createdAt,
        row,
      }));
    }
    if (type === 'admission') {
      const rows = await this.prismaService.execute((prisma) =>
        prisma.applicationDecisionRecord.findMany({
          where: {
            ...(scope as Prisma.ApplicationDecisionRecordWhereInput),
            ...status,
          },
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take,
          select: adminAdmissionSelect,
        }),
      );
      if (!rows) throw databaseUnavailable();
      return rows.map((row) => ({
        type,
        id: row.id,
        createdAt: row.createdAt,
        row,
      }));
    }
    const rows = await this.prismaService.execute((prisma) =>
      prisma.fundingDecisionRecord.findMany({
        where: {
          ...(scope as Prisma.FundingDecisionRecordWhereInput),
          ...status,
        },
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take,
        select: adminFundingSelect,
      }),
    );
    if (!rows) throw databaseUnavailable();
    return rows.map((row) => ({
      type,
      id: row.id,
      createdAt: row.createdAt,
      row,
    }));
  }

  private async findScoped(
    actor: AdminSessionUser,
    type: OutcomeType,
    outcomeId: string,
  ): Promise<AdminOutcome | null> {
    const scope = await this.access.whereFor(actor, type);
    if (type === 'submission') {
      const row = await this.prismaService.execute((prisma) =>
        prisma.applicationSubmission.findFirst({
          where: { ...scope, id: outcomeId },
          select: adminSubmissionSelect,
        }),
      );
      return row ?? null;
    }
    if (type === 'admission') {
      const row = await this.prismaService.execute((prisma) =>
        prisma.applicationDecisionRecord.findFirst({
          where: {
            ...(scope as Prisma.ApplicationDecisionRecordWhereInput),
            id: outcomeId,
          },
          select: adminAdmissionSelect,
        }),
      );
      return row ?? null;
    }
    const row = await this.prismaService.execute((prisma) =>
      prisma.fundingDecisionRecord.findFirst({
        where: {
          ...(scope as Prisma.FundingDecisionRecordWhereInput),
          id: outcomeId,
        },
        select: adminFundingSelect,
      }),
    );
    return row ?? null;
  }

  private async loadSupplemental(type: OutcomeType, outcomeId: string) {
    const rows = await this.prismaService.execute((prisma) =>
      prisma.outcomeEvidenceLink.findMany({
        where: { entityType: type, entityId: outcomeId, isPrimary: false },
        orderBy: { linkedAt: 'asc' },
        select: { evidence: { select: adminEvidenceSelect } },
      }),
    );
    if (!rows) throw databaseUnavailable();
    return rows.map((row) => row.evidence);
  }

  private async loadCurrentForUpdate(
    tx: Prisma.TransactionClient,
    type: OutcomeType,
    outcomeId: string,
  ) {
    await tx.$queryRaw(
      Prisma.sql`SELECT "id" FROM ${Prisma.raw(`"${this.tableName(type)}"`)} WHERE "id" = ${outcomeId} FOR UPDATE`,
    );
    if (type === 'submission') {
      const row = await tx.applicationSubmission.findUnique({
        where: { id: outcomeId },
        select: { workspaceId: true, lockVersion: true, verificationStatus: true },
      });
      return row ? { ...row, isCurrent: true } : null;
    }
    if (type === 'admission') {
      return tx.applicationDecisionRecord.findUnique({
        where: { id: outcomeId },
        select: {
          workspaceId: true,
          lockVersion: true,
          verificationStatus: true,
          isCurrent: true,
        },
      });
    }
    return tx.fundingDecisionRecord.findUnique({
      where: { id: outcomeId },
      select: {
        workspaceId: true,
        lockVersion: true,
        verificationStatus: true,
        isCurrent: true,
      },
    });
  }

  private async updateOutcome(
    tx: Prisma.TransactionClient,
    type: OutcomeType,
    outcomeId: string,
    lockVersion: number,
    data: {
      verificationStatus: EvidenceVerificationStatus;
      verificationNotes: string | null;
      verifiedAt: Date | null;
      verifiedById: string | null;
      lockVersion: { increment: number };
    },
  ) {
    const where = { id: outcomeId, lockVersion };
    const result =
      type === 'submission'
        ? await tx.applicationSubmission.updateMany({ where, data })
        : type === 'admission'
          ? await tx.applicationDecisionRecord.updateMany({ where, data })
          : await tx.fundingDecisionRecord.updateMany({ where, data });
    return result.count;
  }

  private async loadById(
    tx: Prisma.TransactionClient,
    type: OutcomeType,
    outcomeId: string,
  ): Promise<AdminOutcome> {
    const row =
      type === 'submission'
        ? await tx.applicationSubmission.findUnique({
            where: { id: outcomeId },
            select: adminSubmissionSelect,
          })
        : type === 'admission'
          ? await tx.applicationDecisionRecord.findUnique({
              where: { id: outcomeId },
              select: adminAdmissionSelect,
            })
          : await tx.fundingDecisionRecord.findUnique({
              where: { id: outcomeId },
              select: adminFundingSelect,
            });
    if (!row) throw this.forbidden();
    return row;
  }

  private serializeListEntry(entry: ListEntry) {
    const row = entry.row;
    return {
      type: entry.type,
      id: row.id,
      workspaceId: row.workspaceId,
      version: row.version,
      lockVersion: row.lockVersion,
      isCurrent: 'isCurrent' in row ? row.isCurrent : true,
      verificationStatus: row.verificationStatus,
      reportedAt: row.createdAt.toISOString(),
      student: {
        id: row.workspace.user.id,
        fullName: row.workspace.user.fullName,
      },
      scholarship: row.workspace.scholarship,
    };
  }

  private serializeOutcome(
    type: OutcomeType,
    row: AdminOutcome,
    supplemental: AdminEvidence[],
  ) {
    const base = {
      type,
      id: row.id,
      workspaceId: row.workspaceId,
      version: row.version,
      lockVersion: row.lockVersion,
      verificationStatus: row.verificationStatus,
      verificationNotes: row.verificationNotes,
      verifiedAt: row.verifiedAt?.toISOString() ?? null,
      createdAt: row.createdAt.toISOString(),
      updatedAt: row.updatedAt.toISOString(),
      workspace: row.workspace,
      evidence: this.serializeEvidenceList(row.evidence, supplemental),
    };
    if (type === 'submission') {
      const submission = row as AdminSubmission;
      return {
        ...base,
        submittedAt: submission.submittedAt.toISOString(),
        submissionChannel: submission.submissionChannel,
        hasApplicationReference: Boolean(submission.applicationRefHash),
      };
    }
    if (type === 'admission') {
      const decision = row as AdminAdmission;
      return {
        ...base,
        supersedesId: decision.supersedesId,
        isCurrent: decision.isCurrent,
        issuedByName: decision.issuedByName,
        admissionDecision: decision.admissionDecision,
        issuedAt: decision.issuedAt?.toISOString() ?? null,
        receivedAt: decision.receivedAt.toISOString(),
      };
    }
    const funding = row as AdminFunding;
    return {
      ...base,
      admissionDecisionId: funding.admissionDecisionId,
      supersedesId: funding.supersedesId,
      isCurrent: funding.isCurrent,
      issuedByName: funding.issuedByName,
      fundingDecision: funding.fundingDecision,
      fundingAmountMinor: funding.fundingAmountMinor?.toString() ?? null,
      fundingCurrency: funding.fundingCurrency,
      issuedAt: funding.issuedAt?.toISOString() ?? null,
      receivedAt: funding.receivedAt.toISOString(),
    };
  }

  private serializeEvidenceList(
    primary: AdminEvidence,
    supplemental: AdminEvidence[],
  ) {
    return [primary, ...supplemental].map((evidence, index) => ({
      id: evidence.id,
      workspaceId: evidence.workspaceId,
      kind: evidence.kind,
      originalFileName: evidence.originalFileName,
      mimeType: evidence.mimeType,
      sizeBytes: evidence.sizeBytes,
      processingStatus: evidence.processingStatus,
      version: evidence.version,
      isPrimary: index === 0,
      consentActive: evidence.consentReceipt.revokedAt === null,
      uploadedAt: evidence.uploadedAt?.toISOString() ?? null,
      accessPath: `/api/admin/competition-readiness/outcome-evidence/${encodeURIComponent(evidence.id)}/file?purposeCode=outcome_verification`,
    }));
  }

  private assertEvidenceVerifiable(evidence: AdminEvidence) {
    if (
      evidence.processingStatus !== 'clean' ||
      evidence.deletedAt ||
      evidence.consentReceipt.revokedAt ||
      !evidence.uploadedAt
    ) {
      throw new CompetitionReadinessHttpException(
        'EVIDENCE_REJECTED',
        422,
        'Outcome evidence is unavailable for verification.',
      );
    }
  }

  private assertTransition(
    from: EvidenceVerificationStatus,
    to: EvidenceVerificationStatus,
  ) {
    if (to === 'self_reported' || from === to) {
      throw new BadRequestException('Unsupported verification transition.');
    }
    if (from === 'verified' && to !== 'pending') {
      throw new BadRequestException('A verified outcome must be reopened first.');
    }
    if (from === 'rejected' && to !== 'pending') {
      throw new BadRequestException('A rejected outcome must be reopened first.');
    }
  }

  private verificationEventName(
    type: OutcomeType,
    status: EvidenceVerificationStatus,
  ) {
    if (status !== 'verified') return 'outcome_verification_updated';
    if (type === 'submission') return 'application_submission_verified';
    if (type === 'admission') return 'application_decision_verified';
    return 'funding_decision_verified';
  }

  private aggregateType(type: OutcomeType) {
    return type === 'submission'
      ? 'ApplicationSubmission'
      : type === 'admission'
        ? 'ApplicationDecisionRecord'
        : 'FundingDecisionRecord';
  }

  private tableName(type: OutcomeType) {
    return this.aggregateType(type);
  }

  private encodeCursor(offset: number) {
    return Buffer.from(JSON.stringify({ offset }), 'utf8').toString('base64url');
  }

  private decodeCursor(cursor: string | undefined) {
    if (!cursor) return 0;
    try {
      const parsed = JSON.parse(
        Buffer.from(cursor, 'base64url').toString('utf8'),
      ) as { offset?: unknown };
      if (
        !Number.isSafeInteger(parsed.offset) ||
        Number(parsed.offset) < 0 ||
        Number(parsed.offset) > 1_000_000
      ) {
        throw new Error('invalid cursor');
      }
      return Number(parsed.offset);
    } catch {
      throw new BadRequestException('Invalid outcomes cursor.');
    }
  }

  private forbidden() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'Outcome is outside the operator scope.',
    );
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }
}
