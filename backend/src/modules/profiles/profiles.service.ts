import { createHmac } from 'node:crypto';

import { Injectable, Logger, Optional } from '@nestjs/common';
import type { UserProfile } from '@prisma/client';

import { NewsletterSyncService } from '../newsletter/newsletter-sync.service';
import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { UpdateProfileDto } from './dto/update-profile.dto';

@Injectable()
export class ProfilesService {
  private readonly logger = new Logger(ProfilesService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly storageService: StorageService,
    // Optional so unit tests constructing the service positionally keep
    // working; when absent, the reconciliation cron alone syncs Mautic.
    @Optional() private readonly newsletterSync?: NewsletterSyncService,
  ) {}

  // Returned ONLY when the database is not configured. Kept readonly and never
  // mutated — a previous mutable singleton leaked one user's profile fields
  // into another user's responses (cross-tenant leak + race condition).
  private readonly demoProfile = {
    id: 'demo-user',
    accountType: 'student',
    preferredLanguage: 'fr',
    fullName: 'Aissatou Ibrahim',
    email: 'aissatou@example.com',
    phone: '+22790000000',
    whatsApp: '+22790000000',
    countryOfResidence: 'Niger',
    currentLevel: 'High school',
    targetLevel: 'Bachelor',
    languageLevel: 'Intermediate',
    fieldIds: ['computer_science', 'business'],
    // Active ISO country ids (see seed:countries-m5) — matches the catalog after
    // the canada->can / france->fra remap so coach targeting + UI resolve them.
    targetCountryIds: ['can', 'fra'],
    gradeRange: '12 - 14/20',
    annualTuitionBudgetEur: 7500,
    preferredCurrency: 'XOF',
    wantsScholarshipSupport: true,
    availableDocuments: ['Passport', 'Transcripts'],
    updatedAt: new Date().toISOString(),
  };

  async getMe(userId?: string) {
    const id = userId ?? 'demo-user';
    const dbProfile = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({ where: { id } }),
    );

    return dbProfile ? this.mapDbProfile(dbProfile) : this.demoProfile;
  }

  async updateMe(input: UpdateProfileDto, userId?: string) {
    const id = userId ?? 'demo-user';

    // Newsletter consent transition: stamp the GDPR proof only when the flag
    // actually flips to true — re-sending true must not rewrite the original
    // consent timestamp.
    let stampNewsletterConsent = false;
    if (input.scholarshipNewsletterOptIn === true) {
      const current = await this.prismaService.execute((prisma) =>
        prisma.userProfile.findUnique({
          where: { id },
          select: { newsletterOptIn: true },
        }),
      );
      stampNewsletterConsent = current ? !current.newsletterOptIn : false;
    }

    const updated = await this.prismaService.execute((prisma) =>
      prisma.userProfile.update({
        where: { id },
        data: {
          ...(input.fullName ? { fullName: input.fullName } : {}),
          ...(input.phone ? { phone: input.phone } : {}),
          ...(input.whatsApp !== undefined
            ? { whatsApp: input.whatsApp }
            : {}),
          ...(input.preferredLanguage
            ? { preferredLanguage: input.preferredLanguage }
            : {}),
          ...(input.countryOfResidence
            ? { countryOfResidence: input.countryOfResidence }
            : {}),
          ...(input.currentLevel
            ? { currentLevel: input.currentLevel }
            : {}),
          ...(input.targetLevel ? { targetLevel: input.targetLevel } : {}),
          ...(input.languageLevel
            ? { languageLevel: input.languageLevel }
            : {}),
          ...(input.gradeRange ? { gradeRange: input.gradeRange } : {}),
          ...(input.monthlyBudgetEur !== undefined
            ? { monthlyBudgetEur: input.monthlyBudgetEur }
            : {}),
          ...(input.annualTuitionBudgetEur !== undefined
            ? { annualTuitionBudgetEur: input.annualTuitionBudgetEur }
            : {}),
          ...(input.preferredCurrency
            ? { preferredCurrency: input.preferredCurrency }
            : {}),
          ...(input.wantsScholarshipSupport !== undefined
            ? { wantsScholarship: input.wantsScholarshipSupport }
            : {}),
          ...(input.scholarshipNewsletterOptIn !== undefined
            ? { newsletterOptIn: input.scholarshipNewsletterOptIn }
            : {}),
          ...(input.dailyScholarshipOptOut !== undefined
            ? { dailyScholarshipOptOut: input.dailyScholarshipOptOut }
            : {}),
          ...(stampNewsletterConsent
            ? { newsletterConsentedAt: new Date() }
            : {}),
          ...(input.fieldIds ? { fieldIds: input.fieldIds } : {}),
          ...(input.targetCountryIds
            ? { targetCountryIds: input.targetCountryIds }
            : {}),
          ...(input.availableDocuments
            ? { availableDocuments: input.availableDocuments }
            : {}),
          ...(input.aiConsentedAt !== undefined
            ? { aiConsentedAt: new Date(input.aiConsentedAt) }
            : {}),
          ...(input.birthDate !== undefined
            ? { birthDate: new Date(input.birthDate) }
            : {}),
          ...(input.guardianName !== undefined
            ? { guardianName: input.guardianName }
            : {}),
          ...(input.guardianContact !== undefined
            ? { guardianContact: input.guardianContact }
            : {}),
          ...(input.guardianConsentedAt !== undefined
            ? { guardianConsentedAt: new Date(input.guardianConsentedAt) }
            : {}),
        },
      }),
    );

    if (updated) {
      // Fire-and-forget: low-latency Mautic push. A failure here is fine —
      // the state stays desired≠synced and the reconciliation cron retries.
      if (input.scholarshipNewsletterOptIn !== undefined) {
        void this.newsletterSync?.syncProfile(updated.id);
      }
      return this.mapDbProfile(updated);
    }

    // No database: return a per-request merge of the demo profile without
    // mutating any shared state.
    return {
      ...this.demoProfile,
      ...input,
      updatedAt: new Date().toISOString(),
    };
  }

  /// GDPR / store-required account deletion. Hard-deletes every user-owned row
  /// in one transaction (FK-safe order: case children → case-referencing rows →
  /// cases → other user-owned rows → profile), then best-effort deletes the
  /// Supabase auth identity. Returns flags so the client can report honestly.
  async deleteMe(
    userId?: string,
  ): Promise<{ deleted: boolean; authIdentityRemoved: boolean }> {
    const id = userId ?? 'demo-user';
    const actorKey = this.analyticsActorKey(id);

    const purged = await this.prismaService.execute(async (prisma) => {
      const profile = await prisma.userProfile.findUnique({
        where: { id },
        select: { email: true, supabaseUserId: true },
      });
      if (!profile) return null;

      const cases = await prisma.case.findMany({
        where: { userId: id },
        select: { id: true },
      });
      const caseIds = cases.map((c) => c.id);
      const workspaces = await prisma.scholarshipWorkspace.findMany({
        where: { userId: id },
        select: { id: true },
      });
      const workspaceIds = workspaces.map((workspace) => workspace.id);
      const artifactVersions = await prisma.applicationArtifactVersion.findMany({
        where: { artifact: { workspaceId: { in: workspaceIds } } },
        select: { id: true, storageKey: true },
      });
      const reviewRequests = await prisma.studyReviewRequest.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const outcomeEvidence = await prisma.outcomeEvidenceAsset.findMany({
        where: { ownerUserId: id },
        select: { id: true, storageKey: true },
      });
      const submissions = await prisma.applicationSubmission.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const admissionDecisions =
        await prisma.applicationDecisionRecord.findMany({
          where: { workspaceId: { in: workspaceIds } },
          select: { id: true },
        });
      const fundingDecisions = await prisma.fundingDecisionRecord.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const diagnostics = await prisma.aiDiagnostic.findMany({
        where: { workspaceId: { in: workspaceIds } },
        select: { id: true },
      });
      const guardianAuthorizations =
        await prisma.guardianAuthorization.findMany({
          where: { OR: [{ minorUserId: id }, { guardianUserId: id }] },
          select: { evidenceStorageKey: true },
        });
      // Pilot enrolment/assessment mutations are initiated by an admin, so
      // their idempotency rows are owned by that admin rather than by the
      // participant. Collect the created resource ids before the membership
      // cascade so account deletion also erases response snapshots containing
      // the participant id, workspace id or research answers.
      const impactMemberships =
        await prisma.impactCohortMembership.findMany({
          where: { userId: id },
          select: {
            id: true,
            assessments: { select: { id: true } },
            experimentAssignment: { select: { id: true } },
          },
        });
      const artifactVersionIds = artifactVersions.map((version) => version.id);
      const reviewRequestIds = reviewRequests.map((request) => request.id);
      const evidenceIds = outcomeEvidence.map((evidence) => evidence.id);
      const submissionIds = submissions.map((submission) => submission.id);
      const admissionDecisionIds = admissionDecisions.map(
        (decision) => decision.id,
      );
      const fundingDecisionIds = fundingDecisions.map(
        (decision) => decision.id,
      );
      const diagnosticIds = diagnostics.map((diagnostic) => diagnostic.id);
      const impactMembershipIds = impactMemberships.map(
        (membership) => membership.id,
      );
      const impactMembershipChildIds = impactMemberships.flatMap(
        (membership) => [
          ...membership.assessments.map((assessment) => assessment.id),
          ...(membership.experimentAssignment
            ? [membership.experimentAssignment.id]
            : []),
        ],
      );
      const artifactStorageKeys = artifactVersions
        .map((version) => version.storageKey)
        .filter((key): key is string => Boolean(key));
      const outcomeStorageKeys = outcomeEvidence
        .map((evidence) => evidence.storageKey)
        .filter((key): key is string => Boolean(key));
      const guardianEvidenceStorageKeys = guardianAuthorizations
        .map((authorization) => authorization.evidenceStorageKey)
        .filter((key): key is string => Boolean(key));

      // Collect uploaded document URLs before deleting the rows, so we can also
      // remove the underlying files from object storage (GDPR right to erasure).
      const documents = await prisma.caseDocument.findMany({
        where: { caseId: { in: caseIds } },
        select: { fileUrl: true },
      });
      const fileUrls = documents
        .map((d: { fileUrl: string | null }) => d.fileUrl)
        .filter((u: string | null): u is string => !!u);

      await prisma.$transaction([
        // Children of Case (no cascade defined).
        prisma.caseMessage.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseTimelineEvent.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        prisma.caseTask.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseDocument.deleteMany({ where: { caseId: { in: caseIds } } }),
        prisma.caseInternalNote.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        prisma.notificationDelivery.deleteMany({
          where: { caseId: { in: caseIds } },
        }),
        // Rows that reference Case (must precede Case).
        prisma.appointment.deleteMany({ where: { userId: id } }),
        // ServicePurchase references PaymentIntent → delete it first.
        prisma.servicePurchase.deleteMany({ where: { userId: id } }),
        prisma.paymentIntent.deleteMany({ where: { userId: id } }),
        prisma.case.deleteMany({ where: { userId: id } }),
        // Other user-owned rows.
        prisma.savedItem.deleteMany({ where: { userId: id } }),
        prisma.academyPurchase.deleteMany({ where: { userId: id } }),
        prisma.salonRegistration.deleteMany({ where: { userId: id } }),
        // CoachMessage cascades from CoachConversation (onDelete: Cascade).
        prisma.coachConversation.deleteMany({ where: { userId: id } }),
        prisma.orientationSession.deleteMany({ where: { userId: id } }),
        prisma.parentChildLink.deleteMany({
          where: { OR: [{ parentId: id }, { childId: id }] },
        }),
        prisma.referral.deleteMany({
          where: { OR: [{ referrerId: id }, { refereeProfileId: id }] },
        }),
        // Referral-reward ledger (KPB-77) — FK is ON DELETE RESTRICT.
        prisma.creditTransaction.deleteMany({ where: { profileId: id } }),
        // Competition Readiness technical records do not all have an FK to the
        // profile. Purge them explicitly before the workspace/profile cascade.
        prisma.analyticsEvent.deleteMany({
          where: {
            OR: [
              { workspaceId: { in: workspaceIds } },
              ...(actorKey ? [{ actorKey }] : []),
            ],
          },
        }),
        prisma.domainEventOutbox.deleteMany({
          where: {
            OR: [
              {
                aggregateType: 'ScholarshipWorkspace',
                aggregateId: { in: workspaceIds },
              },
              {
                aggregateType: 'ApplicationArtifactVersion',
                aggregateId: { in: artifactVersionIds },
              },
              {
                aggregateType: 'StudyReviewRequest',
                aggregateId: { in: reviewRequestIds },
              },
              {
                aggregateType: 'OutcomeEvidenceAsset',
                aggregateId: { in: evidenceIds },
              },
              {
                aggregateType: 'ApplicationSubmission',
                aggregateId: { in: submissionIds },
              },
              {
                aggregateType: 'ApplicationDecisionRecord',
                aggregateId: { in: admissionDecisionIds },
              },
              {
                aggregateType: 'FundingDecisionRecord',
                aggregateId: { in: fundingDecisionIds },
              },
              {
                aggregateType: 'AiDiagnostic',
                aggregateId: { in: diagnosticIds },
              },
            ],
          },
        }),
        prisma.idempotencyRecord.deleteMany({
          where: {
            OR: [
              // Student-owned operations.
              { actorId: id },
              // Admin-owned pilot operations whose replay snapshot contains
              // this student's research or membership data.
              ...(impactMembershipIds.length > 0
                ? [
                    {
                      resourceType: 'ImpactCohortMembership',
                      resourceId: { in: impactMembershipIds },
                    },
                  ]
                : []),
              ...(impactMembershipChildIds.length > 0
                ? [
                    {
                      resourceType: 'PilotRecord',
                      resourceId: { in: impactMembershipChildIds },
                    },
                  ]
                : []),
            ],
          },
        }),
        // Shares restrict deletion of both consent receipts and artifact
        // versions, so they must be removed before the workspace cascade.
        prisma.studyReviewArtifactShare.deleteMany({
          where: { reviewRequestId: { in: reviewRequestIds } },
        }),
        // Outcome records use RESTRICT for immutable evidence and revision
        // chains. Break optional history links, then remove children before the
        // evidence and consent receipts they reference.
        prisma.outcomeVerificationEvent.deleteMany({
          where: {
            OR: [
              { entityType: 'submission', entityId: { in: submissionIds } },
              {
                entityType: 'admission',
                entityId: { in: admissionDecisionIds },
              },
              {
                entityType: 'funding',
                entityId: { in: fundingDecisionIds },
              },
            ],
          },
        }),
        prisma.outcomeEvidenceLink.deleteMany({
          where: {
            OR: [
              { evidenceId: { in: evidenceIds } },
              { linkedByUserId: id },
            ],
          },
        }),
        prisma.fundingDecisionRecord.updateMany({
          where: { workspaceId: { in: workspaceIds } },
          data: { supersedesId: null, admissionDecisionId: null },
        }),
        prisma.fundingDecisionRecord.deleteMany({
          where: { workspaceId: { in: workspaceIds } },
        }),
        prisma.applicationDecisionRecord.updateMany({
          where: { workspaceId: { in: workspaceIds } },
          data: { supersedesId: null },
        }),
        prisma.applicationDecisionRecord.deleteMany({
          where: { workspaceId: { in: workspaceIds } },
        }),
        prisma.applicationSubmission.deleteMany({
          where: { workspaceId: { in: workspaceIds } },
        }),
        // Preserve aggregate AI accounting while severing every user link.
        prisma.aiUsageAttempt.updateMany({
          where: { diagnosticId: { in: diagnosticIds } },
          data: {
            diagnosticId: null,
            actorKey: null,
            providerRequestId: null,
          },
        }),
        prisma.aiBudgetTransaction.updateMany({
          where: { diagnosticId: { in: diagnosticIds } },
          data: { diagnosticId: null },
        }),
        prisma.outcomeEvidenceAsset.deleteMany({
          where: { id: { in: evidenceIds } },
        }),
        // Pilot memberships also RESTRICT their explicit research receipt.
        // Assessments and assignments cascade from the membership.
        prisma.impactCohortMembership.deleteMany({ where: { userId: id } }),
        // Receipts must precede GuardianAuthorization because that relation is
        // RESTRICT; workspaces themselves cascade from UserProfile.
        prisma.consentReceipt.deleteMany({ where: { userId: id } }),
        prisma.guardianAuthorization.deleteMany({
          where: { OR: [{ minorUserId: id }, { guardianUserId: id }] },
        }),
        prisma.deviceToken.deleteMany({ where: { userProfileId: id } }),
        prisma.partnerLead.deleteMany({ where: { userId: id } }),
        prisma.studentCredential.deleteMany({ where: { userProfileId: id } }),
        prisma.magicLinkToken.deleteMany({ where: { email: profile.email } }),
        prisma.userProfile.delete({ where: { id } }),
      ]);

      return {
        supabaseUserId: profile.supabaseUserId,
        fileUrls,
        artifactStorageKeys,
        outcomeStorageKeys,
        guardianEvidenceStorageKeys,
      };
    });

    if (!purged) {
      // No DB (demo mode) or no such profile — nothing to purge server-side.
      return { deleted: false, authIdentityRemoved: false };
    }

    // Best-effort deletion of the uploaded files (passports, transcripts) from
    // object storage. Never abort the deletion outcome if a file delete fails —
    // StorageService.delete already swallows and logs its own errors.
    for (const url of purged.fileUrls) {
      const key = this.storageService.keyFromUrl(url);
      if (key) await this.storageService.delete(key);
    }
    for (const key of purged.artifactStorageKeys) {
      await this.storageService.delete(key);
    }
    for (const key of purged.outcomeStorageKeys) {
      await this.storageService.delete(key);
    }
    for (const key of purged.guardianEvidenceStorageKeys) {
      await this.storageService.delete(key);
    }

    const authIdentityRemoved = await this.deleteSupabaseAuthUser(
      purged.supabaseUserId,
    );
    return { deleted: true, authIdentityRemoved };
  }

  /// Best-effort deletion of the Supabase Auth identity via the Admin REST API.
  /// Requires SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY in the deploy env; if
  /// they are absent we log loudly and return false (Postgres data is still
  /// purged, but the auth identity survives — set the secret for full store
  /// compliance). Never throws: a failure here must not abort the data purge.
  private async deleteSupabaseAuthUser(
    supabaseUserId: string | null,
  ): Promise<boolean> {
    if (!supabaseUserId) return false;
    const url = process.env.SUPABASE_URL?.trim();
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY?.trim();
    if (!url || !key) {
      this.logger.warn(
        'Account data purged but the Supabase auth identity was NOT removed: ' +
          'set SUPABASE_URL + SUPABASE_SERVICE_ROLE_KEY to fully satisfy store ' +
          'account-deletion requirements.',
      );
      return false;
    }
    try {
      const res = await fetch(
        `${url.replace(/\/$/, '')}/auth/v1/admin/users/${supabaseUserId}`,
        {
          method: 'DELETE',
          headers: { apikey: key, authorization: `Bearer ${key}` },
        },
      );
      if (!res.ok) {
        this.logger.error(
          `Supabase admin deleteUser failed with status ${res.status}.`,
        );
        return false;
      }
      return true;
    } catch {
      // Provider error bodies and URLs can contain tokens or user identifiers.
      this.logger.error('Supabase admin deleteUser request failed.');
      return false;
    }
  }

  /// GDPR data export (portability): aggregate every user-owned record into one
  /// JSON document. Uploaded document files are referenced by URL, not embedded.
  async exportMe(userId?: string) {
    const id = userId ?? 'demo-user';
    const actorKey = this.analyticsActorKey(id);

    const data = await this.prismaService.execute(async (prisma) => {
      const profile = await prisma.userProfile.findUnique({ where: { id } });
      if (!profile) return null;

      const [
        cases,
        savedItems,
        appointments,
        academyPurchases,
        servicePurchases,
        salonRegistrations,
        coachConversations,
        orientationSessions,
        parentLinksAsParent,
        parentLinksAsChild,
        scholarshipWorkspaces,
        consentReceipts,
        aiQuotaBuckets,
        impactCohortMemberships,
      ] = await Promise.all([
        prisma.case.findMany({
          where: { userId: id },
          include: { messages: true, timelineEvents: true, documents: true },
        }),
        prisma.savedItem.findMany({ where: { userId: id } }),
        prisma.appointment.findMany({ where: { userId: id } }),
        prisma.academyPurchase.findMany({ where: { userId: id } }),
        prisma.servicePurchase.findMany({ where: { userId: id } }),
        prisma.salonRegistration.findMany({ where: { userId: id } }),
        prisma.coachConversation.findMany({
          where: { userId: id },
          include: { messages: true },
        }),
        prisma.orientationSession.findMany({ where: { userId: id } }),
        prisma.parentChildLink.findMany({ where: { parentId: id } }),
        prisma.parentChildLink.findMany({ where: { childId: id } }),
        prisma.scholarshipWorkspace.findMany({
          where: { userId: id },
          include: {
            steps: true,
            artifacts: {
              orderBy: [{ kind: 'asc' }, { createdAt: 'asc' }],
              select: {
                id: true,
                workspaceId: true,
                kind: true,
                title: true,
                currentVersionId: true,
                createdAt: true,
                updatedAt: true,
                versions: {
                  orderBy: { versionNumber: 'asc' },
                  select: {
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
                  },
                },
              },
            },
            reviewRequests: {
              orderBy: { requestNumber: 'asc' },
              include: {
                artifactShares: {
                  select: {
                    id: true,
                    artifactVersionId: true,
                    consentReceiptId: true,
                    grantedAt: true,
                    revokedAt: true,
                  },
                },
              },
            },
            diagnostics: {
              orderBy: { createdAt: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                artifactVersionId: true,
                status: true,
                documentKind: true,
                generatedLanguage: true,
                strength: true,
                priorityImprovement: true,
                rationale: true,
                nextAction: true,
                criterionReferences: true,
                workspaceVersion: true,
                criteriaVersion: true,
                promptVersion: true,
                fallbackReason: true,
                startedAt: true,
                completedAt: true,
                createdAt: true,
                updatedAt: true,
                usageAttempts: {
                  orderBy: { attemptNumber: 'asc' },
                  select: {
                    id: true,
                    attemptNumber: true,
                    feature: true,
                    provider: true,
                    model: true,
                    promptVersion: true,
                    priceVersion: true,
                    usageSource: true,
                    inputTokens: true,
                    cachedInputTokens: true,
                    outputTokens: true,
                    totalTokens: true,
                    latencyMs: true,
                    estimatedCostMicrosUsd: true,
                    outcome: true,
                    errorCode: true,
                    startedAt: true,
                    completedAt: true,
                    createdAt: true,
                  },
                },
              },
            },
            outcomeEvidence: {
              orderBy: { createdAt: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                kind: true,
                originalFileName: true,
                mimeType: true,
                sizeBytes: true,
                sha256: true,
                processingStatus: true,
                version: true,
                rejectionCode: true,
                retentionClass: true,
                uploadedAt: true,
                deletedAt: true,
                createdAt: true,
                updatedAt: true,
                links: {
                  orderBy: { linkedAt: 'asc' },
                  select: {
                    id: true,
                    entityType: true,
                    entityId: true,
                    isPrimary: true,
                    linkedAt: true,
                  },
                },
              },
            },
            submissions: {
              orderBy: { version: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                version: true,
                submittedAt: true,
                submissionChannel: true,
                applicationRefHash: true,
                evidenceId: true,
                verificationStatus: true,
                verificationNotes: true,
                verifiedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
            admissionDecisions: {
              orderBy: { version: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                supersedesId: true,
                version: true,
                isCurrent: true,
                issuedByName: true,
                admissionDecision: true,
                issuedAt: true,
                receivedAt: true,
                evidenceId: true,
                verificationStatus: true,
                verificationNotes: true,
                verifiedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
            fundingDecisions: {
              orderBy: { version: 'asc' },
              select: {
                id: true,
                workspaceId: true,
                admissionDecisionId: true,
                supersedesId: true,
                version: true,
                isCurrent: true,
                issuedByName: true,
                fundingDecision: true,
                fundingAmountMinor: true,
                fundingCurrency: true,
                issuedAt: true,
                receivedAt: true,
                evidenceId: true,
                verificationStatus: true,
                verificationNotes: true,
                verifiedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
          },
          orderBy: { lastActivityAt: 'desc' },
        }),
        prisma.consentReceipt.findMany({
          where: { userId: id },
          select: {
            id: true,
            userId: true,
            purpose: true,
            noticeId: true,
            languageCode: true,
            channel: true,
            grantedAt: true,
            revokedAt: true,
            guardianAuthorizationId: true,
            ipHash: true,
            userAgentClass: true,
            createdAt: true,
            notice: {
              select: {
                id: true,
                purpose: true,
                version: true,
                languageCode: true,
                contentHash: true,
                effectiveAt: true,
                retiredAt: true,
              },
            },
            guardianAuthorization: {
              select: {
                id: true,
                minorUserId: true,
                guardianUserId: true,
                relationshipCode: true,
                verificationMethod: true,
                status: true,
                verifiedAt: true,
                expiresAt: true,
                revokedAt: true,
                createdAt: true,
                updatedAt: true,
              },
            },
          },
          orderBy: { grantedAt: 'desc' },
        }),
        prisma.aiQuotaBucket.findMany({
          where: { userId: id },
          select: {
            id: true,
            feature: true,
            periodKey: true,
            quotaLimit: true,
            used: true,
            resetsAt: true,
            createdAt: true,
            updatedAt: true,
          },
          orderBy: { createdAt: 'asc' },
        }),
        prisma.impactCohortMembership.findMany({
          where: { userId: id },
          select: {
            id: true,
            cohortId: true,
            workspaceId: true,
            consentReceiptId: true,
            version: true,
            status: true,
            enrolledAt: true,
            withdrawnAt: true,
            exitReason: true,
            countryCodeLocked: true,
            studyLevelLocked: true,
            genderCodeLocked: true,
            deviceClassLocked: true,
            connectivityLocked: true,
            profileRubricVersion: true,
            matchingAlgorithmVersion: true,
            baselineSnapshot: true,
            cohort: {
              select: {
                id: true,
                code: true,
                version: true,
                label: true,
                cohortType: true,
                pilot: {
                  select: {
                    id: true,
                    code: true,
                    version: true,
                    name: true,
                    hypothesis: true,
                    protocolVersion: true,
                    status: true,
                  },
                },
              },
            },
            assessments: {
              orderBy: { administeredAt: 'asc' },
              select: {
                id: true,
                assessmentType: true,
                instrumentVersion: true,
                answers: true,
                score: true,
                administeredAt: true,
              },
            },
            experimentAssignment: {
              select: {
                id: true,
                experimentKey: true,
                experimentVersion: true,
                armCode: true,
                assignedAt: true,
              },
            },
          },
          orderBy: { enrolledAt: 'asc' },
        }),
      ]);

      const workspaceIds = scholarshipWorkspaces.map(
        (workspace) => workspace.id,
      );
      const analyticsEvents = await prisma.analyticsEvent.findMany({
        where: {
          OR: [
            { workspaceId: { in: workspaceIds } },
            ...(actorKey ? [{ actorKey }] : []),
          ],
        },
        select: {
          eventId: true,
          eventName: true,
          schemaVersion: true,
          occurredAt: true,
          receivedAt: true,
          source: true,
          pilotId: true,
          cohortId: true,
          countryCodeLocked: true,
          scholarshipId: true,
          cycleId: true,
          workspaceId: true,
          properties: true,
          isTest: true,
        },
        orderBy: { occurredAt: 'asc' },
      });

      return {
        profile,
        cases,
        savedItems,
        appointments,
        academyPurchases,
        servicePurchases,
        salonRegistrations,
        coachConversations,
        orientationSessions,
        parentLinks: { asParent: parentLinksAsParent, asChild: parentLinksAsChild },
        scholarshipWorkspaces,
        consentReceipts,
        aiQuotaBuckets,
        analyticsEvents,
        impactCohortMemberships,
      };
    });

    const portable = data
      ? this.toPortableObject(data)
      : { profile: this.demoProfile };
    return {
      exportedAt: new Date().toISOString(),
      note: 'Export of your KPB Education data. Uploaded document binaries and private storage keys are not embedded.',
      ...portable,
    };
  }

  private toPortableObject(value: unknown): Record<string, unknown> {
    return JSON.parse(
      JSON.stringify(value, (_key, current) =>
        typeof current === 'bigint' ? current.toString() : current,
      ),
    ) as Record<string, unknown>;
  }

  private analyticsActorKey(userId: string): string | null {
    const secret = process.env.KPB_ANALYTICS_ACTOR_SECRET?.trim();
    return secret
      ? createHmac('sha256', secret).update(userId).digest('hex')
      : null;
  }

  private mapDbProfile(p: UserProfile) {
    return {
      id: p.id,
      accountType: p.accountType,
      preferredLanguage: p.preferredLanguage,
      fullName: p.fullName,
      email: p.email,
      phone: p.phone,
      whatsApp: p.whatsApp,
      countryOfResidence: p.countryOfResidence,
      currentLevel: p.currentLevel,
      targetLevel: p.targetLevel,
      languageLevel: p.languageLevel,
      gradeRange: p.gradeRange,
      annualTuitionBudgetEur: p.annualTuitionBudgetEur,
      monthlyBudgetEur: p.monthlyBudgetEur,
      preferredCurrency: p.preferredCurrency,
      wantsScholarshipSupport: p.wantsScholarship,
      scholarshipNewsletterOptIn: p.newsletterOptIn,
      dailyScholarshipOptOut: p.dailyScholarshipOptOut,
      fieldIds: p.fieldIds,
      targetCountryIds: p.targetCountryIds,
      availableDocuments: p.availableDocuments,
      aiConsentedAt: p.aiConsentedAt ? p.aiConsentedAt.toISOString() : null,
      birthDate: p.birthDate ? p.birthDate.toISOString() : null,
      guardianName: p.guardianName,
      guardianContact: p.guardianContact,
      guardianConsentedAt: p.guardianConsentedAt
        ? p.guardianConsentedAt.toISOString()
        : null,
      updatedAt: p.updatedAt.toISOString(),
    };
  }
}
