import { randomUUID } from "node:crypto";

import {
  AccountType,
  AdmissionDecision,
  AiDiagnosticStatus,
  ArtifactProcessingStatus,
  ConsentPurpose,
  EvidenceVerificationStatus,
  FundingDecision,
  OutcomeEvidenceKind,
  PrismaClient,
} from "@prisma/client";

import type { PrismaService } from "../prisma/prisma.service";
import type { StorageService } from "../storage/storage.service";
import { ProfilesService } from "./profiles.service";

const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === "true"
    ? describe
    : describe.skip;

describePostgres("ProfilesService — PostgreSQL privacy integration", () => {
  const prisma = new PrismaClient();
  const suffix = randomUUID();
  const userId = `privacy-user-${suffix}`;
  const scholarshipId = `privacy-scholarship-${suffix}`;
  const cycleId = `privacy-cycle-${suffix}`;
  const workspaceId = `privacy-workspace-${suffix}`;
  const noticeId = `privacy-notice-${suffix}`;
  const consentId = `privacy-consent-${suffix}`;
  const diagnosticId = `privacy-diagnostic-${suffix}`;
  const budgetPeriodId = `privacy-budget-${suffix}`;
  const pilotId = `privacy-pilot-${suffix}`;
  const cohortId = `privacy-cohort-${suffix}`;
  const membershipId = `privacy-membership-${suffix}`;
  const assessmentId = `privacy-assessment-${suffix}`;
  const assignmentId = `privacy-assignment-${suffix}`;
  const pilotIdempotencyIds = [
    `privacy-idempotency-membership-${suffix}`,
    `privacy-idempotency-assessment-${suffix}`,
    `privacy-idempotency-assignment-${suffix}`,
  ];
  const evidenceIds = {
    submission: `privacy-evidence-submission-${suffix}`,
    admission: `privacy-evidence-admission-${suffix}`,
    funding: `privacy-evidence-funding-${suffix}`,
  };
  const entityIds = {
    submission: `privacy-submission-${suffix}`,
    admission: `privacy-admission-${suffix}`,
    funding: `privacy-funding-${suffix}`,
  };
  const storageKeys = [
    `2026-07-18/${randomUUID()}.pdf`,
    `2026-07-18/${randomUUID()}.pdf`,
    `2026-07-18/${randomUUID()}.pdf`,
  ];

  const deleteObject = jest.fn().mockResolvedValue(undefined);
  const storage = {
    keyFromUrl: () => null,
    delete: deleteObject,
  } as unknown as StorageService;
  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as PrismaService;

  beforeAll(async () => {
    const now = new Date();
    await prisma.userProfile.create({
      data: {
        id: userId,
        accountType: AccountType.student,
        preferredLanguage: "fr",
        fullName: "Privacy Integration Student",
        email: `privacy-${suffix}@example.test`,
        phone: "+22790000000",
        countryOfResidence: "Niger",
      },
    });
    await prisma.scholarship.create({
      data: {
        id: scholarshipId,
        nameFr: "Bourse test confidentialité",
        nameEn: "Privacy test scholarship",
        countryId: "test",
        levelEligibleFr: "Master",
        levelEligibleEn: "Master",
        typeOfFundingFr: "Complète",
        typeOfFundingEn: "Full",
        deadlineLabelFr: "Test",
        deadlineLabelEn: "Test",
        keyRequirementsFr: [],
        keyRequirementsEn: [],
        relatedFieldIds: [],
        sourceKey: `privacy-${suffix}`,
      },
    });
    await prisma.scholarshipCycle.create({
      data: {
        id: cycleId,
        scholarshipId,
        academicYear: `privacy-${suffix}`,
      },
    });
    await prisma.consentNotice.create({
      data: {
        id: noticeId,
        purpose: ConsentPurpose.outcome_evidence,
        version: `privacy-${suffix}`,
        languageCode: "fr",
        contentHash: "a".repeat(64),
        effectiveAt: new Date(now.getTime() - 60_000),
      },
    });
    await prisma.consentReceipt.create({
      data: {
        id: consentId,
        userId,
        purpose: ConsentPurpose.outcome_evidence,
        noticeId,
        languageCode: "fr",
        channel: "integration_test",
        grantedAt: now,
      },
    });
    await prisma.scholarshipWorkspace.create({
      data: {
        id: workspaceId,
        userId,
        scholarshipId,
        scholarshipCycleId: cycleId,
      },
    });
    await prisma.impactPilot.create({
      data: {
        id: pilotId,
        code: `privacy-${suffix}`,
        name: "Privacy integration pilot",
        hypothesis: "Account erasure removes pilot research data.",
        countryCodes: ["NE"],
        targetPopulation: { studyLevel: "master" },
        primaryMetrics: { keys: ["verified_admissions"] },
        guardrailMetrics: { keys: ["withdrawals"] },
        protocolVersion: "privacy-v1",
        ownerAdminId: `privacy-admin-${suffix}`,
      },
    });
    await prisma.impactCohort.create({
      data: {
        id: cohortId,
        pilotId,
        code: "privacy-cohort",
        label: "Privacy cohort",
        cohortType: "treatment",
        inclusionRules: {},
        exclusionRules: {},
      },
    });
    await prisma.impactCohortMembership.create({
      data: {
        id: membershipId,
        cohortId,
        userId,
        workspaceId,
        consentReceiptId: consentId,
        countryCodeLocked: "NE",
        profileRubricVersion: "privacy-v1",
        baselineSnapshot: { privateNeed: "financial_support" },
      },
    });
    await prisma.pilotAssessment.create({
      data: {
        id: assessmentId,
        membershipId,
        assessmentType: "baseline",
        instrumentVersion: "privacy-v1",
        answers: { privateAnswer: "student-specific response" },
        score: 5,
      },
    });
    await prisma.experimentAssignment.create({
      data: {
        id: assignmentId,
        membershipId,
        experimentKey: `privacy-${suffix}`,
        experimentVersion: "v1",
        armCode: "treatment",
        assignmentSeedHash: "d".repeat(64),
      },
    });
    for (const [index, resourceType, resourceId, responseSnapshot] of [
      [
        0,
        "ImpactCohortMembership",
        membershipId,
        {
          userId,
          workspaceId,
          baselineSnapshot: { privateNeed: "financial_support" },
        },
      ],
      [
        1,
        "PilotRecord",
        assessmentId,
        {
          membershipId,
          answers: { privateAnswer: "student-specific response" },
        },
      ],
      [2, "PilotRecord", assignmentId, { membershipId, armCode: "treatment" }],
    ] as const) {
      await prisma.idempotencyRecord.create({
        data: {
          id: pilotIdempotencyIds[index],
          actorType: "admin",
          actorId: `privacy-admin-${suffix}`,
          operation: `privacy-pilot-operation-${index}-${suffix}`,
          idempotencyKey: `privacy-pilot-key-${index}-${suffix}`,
          payloadHash: "e".repeat(64),
          status: "completed",
          resourceType,
          resourceId,
          responseCode: 201,
          responseSnapshot,
          completedAt: now,
          expiresAt: new Date(now.getTime() + 86_400_000),
        },
      });
    }

    const evidenceFixtures = [
      [
        evidenceIds.submission,
        OutcomeEvidenceKind.submission_confirmation,
        storageKeys[0],
      ],
      [
        evidenceIds.admission,
        OutcomeEvidenceKind.admission_decision,
        storageKeys[1],
      ],
      [evidenceIds.funding, OutcomeEvidenceKind.funding_award, storageKeys[2]],
    ] as const;
    for (const [id, kind, storageKey] of evidenceFixtures) {
      await prisma.outcomeEvidenceAsset.create({
        data: {
          id,
          workspaceId,
          ownerUserId: userId,
          consentReceiptId: consentId,
          kind,
          storageKey,
          originalFileName: `${kind}.pdf`,
          mimeType: "application/pdf",
          sizeBytes: 128,
          sha256: "b".repeat(64),
          processingStatus: ArtifactProcessingStatus.clean,
          uploadedAt: now,
        },
      });
    }

    await prisma.applicationSubmission.create({
      data: {
        id: entityIds.submission,
        workspaceId,
        version: 1,
        submittedAt: now,
        applicationRefHash: "c".repeat(64),
        evidenceId: evidenceIds.submission,
        verificationStatus: EvidenceVerificationStatus.self_reported,
      },
    });
    await prisma.applicationDecisionRecord.create({
      data: {
        id: entityIds.admission,
        workspaceId,
        version: 1,
        issuedByName: "Privacy Test University",
        admissionDecision: AdmissionDecision.admitted,
        receivedAt: now,
        evidenceId: evidenceIds.admission,
        verificationStatus: EvidenceVerificationStatus.self_reported,
      },
    });
    await prisma.fundingDecisionRecord.create({
      data: {
        id: entityIds.funding,
        workspaceId,
        admissionDecisionId: entityIds.admission,
        version: 1,
        issuedByName: "Privacy Test University",
        fundingDecision: FundingDecision.full,
        fundingAmountMinor: 1_000_000n,
        fundingCurrency: "XOF",
        receivedAt: now,
        evidenceId: evidenceIds.funding,
        verificationStatus: EvidenceVerificationStatus.self_reported,
      },
    });
    for (const [entityType, entityId, evidenceId] of [
      ["submission", entityIds.submission, evidenceIds.submission],
      ["admission", entityIds.admission, evidenceIds.admission],
      ["funding", entityIds.funding, evidenceIds.funding],
    ] as const) {
      await prisma.outcomeEvidenceLink.create({
        data: {
          id: `privacy-link-${entityType}-${suffix}`,
          entityType,
          entityId,
          evidenceId,
          linkedByUserId: userId,
          isPrimary: true,
        },
      });
    }

    await prisma.aiDiagnostic.create({
      data: {
        id: diagnosticId,
        workspaceId,
        entitlementKey: `privacy-entitlement-${suffix}`,
        status: AiDiagnosticStatus.succeeded,
        promptVersion: "privacy-v1",
      },
    });
    await prisma.aiUsageAttempt.create({
      data: {
        diagnosticId,
        attemptKey: `privacy-attempt-${suffix}`,
        attemptNumber: 1,
        feature: "success_lab",
        provider: "test",
        model: "test",
        promptVersion: "privacy-v1",
        actorKey: `actor-${userId}`,
        providerRequestId: `provider-${userId}`,
        outcome: "success",
        estimatedCostMicrosUsd: 12n,
      },
    });
    await prisma.aiBudgetPeriod.create({
      data: {
        id: budgetPeriodId,
        feature: `privacy-${suffix}`,
        periodKey: `privacy-${suffix}`,
        budgetMicrosUsd: 1_000n,
        startsAt: new Date(now.getTime() - 60_000),
        endsAt: new Date(now.getTime() + 60_000),
      },
    });
    await prisma.aiBudgetTransaction.create({
      data: {
        budgetPeriodId,
        diagnosticId,
        dedupeKey: `privacy-budget-transaction-${suffix}`,
        reason: "privacy_test",
        spentDeltaMicrosUsd: 12n,
      },
    });
    await prisma.analyticsEvent.create({
      data: {
        eventId: `privacy-event-${suffix}`,
        idempotencyKey: `privacy-event-${suffix}`,
        eventName: "privacy.integration.created",
        schemaVersion: 1,
        occurredAt: now,
        source: "integration_test",
        workspaceId,
        properties: { userProvided: true },
      },
    });
  });

  afterAll(async () => {
    // Production deliberately makes pilot records append-only. The temporary
    // integration fixture must therefore bypass triggers only while cleaning
    // its uniquely-prefixed rows, then immediately restore normal semantics.
    await prisma.$executeRawUnsafe("SET session_replication_role = replica");
    try {
      await prisma.idempotencyRecord.deleteMany({
        where: { id: { in: pilotIdempotencyIds } },
      });
      await prisma.impactCohortMembership.deleteMany({
        where: { id: membershipId },
      });
      await prisma.impactCohort.deleteMany({ where: { id: cohortId } });
      await prisma.impactPilot.deleteMany({ where: { id: pilotId } });
      await prisma.outcomeEvidenceLink.deleteMany({
        where: { linkedByUserId: userId },
      });
      await prisma.fundingDecisionRecord.updateMany({
        where: { workspaceId },
        data: { supersedesId: null, admissionDecisionId: null },
      });
      await prisma.fundingDecisionRecord.deleteMany({ where: { workspaceId } });
      await prisma.applicationDecisionRecord.updateMany({
        where: { workspaceId },
        data: { supersedesId: null },
      });
      await prisma.applicationDecisionRecord.deleteMany({
        where: { workspaceId },
      });
      await prisma.applicationSubmission.deleteMany({ where: { workspaceId } });
      await prisma.outcomeEvidenceAsset.deleteMany({ where: { workspaceId } });
      await prisma.aiUsageAttempt.updateMany({
        where: { diagnosticId },
        data: { diagnosticId: null, actorKey: null, providerRequestId: null },
      });
      await prisma.aiBudgetTransaction.updateMany({
        where: { diagnosticId },
        data: { diagnosticId: null },
      });
      await prisma.analyticsEvent.deleteMany({ where: { workspaceId } });
      await prisma.scholarshipWorkspace.deleteMany({
        where: { id: workspaceId },
      });
      await prisma.consentReceipt.deleteMany({ where: { id: consentId } });
      await prisma.userProfile.deleteMany({ where: { id: userId } });
      await prisma.aiBudgetTransaction.deleteMany({
        where: { budgetPeriodId },
      });
      await prisma.aiBudgetPeriod.deleteMany({ where: { id: budgetPeriodId } });
      await prisma.aiUsageAttempt.deleteMany({
        where: { attemptKey: `privacy-attempt-${suffix}` },
      });
      await prisma.scholarship.deleteMany({ where: { id: scholarshipId } });
      await prisma.consentNotice.deleteMany({ where: { id: noticeId } });
    } finally {
      await prisma.$executeRawUnsafe("SET session_replication_role = origin");
      await prisma.$disconnect();
    }
  });

  it("exports all private outcome data and deletes it in FK-safe order", async () => {
    const service = new ProfilesService(prismaService, storage);

    const exported = await service.exportMe(userId);
    const exportRecord = exported as typeof exported & Record<string, unknown>;
    const workspaces = exportRecord.scholarshipWorkspaces as Array<{
      diagnostics: unknown[];
      outcomeEvidence: unknown[];
      submissions: unknown[];
      admissionDecisions: unknown[];
      fundingDecisions: Array<{ fundingAmountMinor: string }>;
    }>;
    expect(workspaces).toHaveLength(1);
    expect(workspaces[0].diagnostics).toHaveLength(1);
    expect(workspaces[0].outcomeEvidence).toHaveLength(3);
    expect(workspaces[0].submissions).toHaveLength(1);
    expect(workspaces[0].admissionDecisions).toHaveLength(1);
    expect(workspaces[0].fundingDecisions).toHaveLength(1);
    expect(workspaces[0].fundingDecisions[0].fundingAmountMinor).toBe(
      "1000000",
    );
    expect(exportRecord.analyticsEvents).toHaveLength(1);
    expect(exportRecord.impactCohortMemberships).toEqual([
      expect.objectContaining({
        id: membershipId,
        assessments: [expect.objectContaining({ id: assessmentId })],
        experimentAssignment: expect.objectContaining({ id: assignmentId }),
      }),
    ]);
    expect(() => JSON.stringify(exported)).not.toThrow();

    await expect(service.deleteMe(userId)).resolves.toEqual({
      deleted: true,
      authIdentityRemoved: false,
    });

    expect(
      await prisma.userProfile.findUnique({ where: { id: userId } }),
    ).toBeNull();
    expect(
      await prisma.scholarshipWorkspace.count({ where: { id: workspaceId } }),
    ).toBe(0);
    expect(
      await prisma.outcomeEvidenceAsset.count({
        where: { ownerUserId: userId },
      }),
    ).toBe(0);
    expect(await prisma.consentReceipt.count({ where: { userId } })).toBe(0);
    expect(await prisma.analyticsEvent.count({ where: { workspaceId } })).toBe(
      0,
    );
    expect(
      await prisma.idempotencyRecord.count({
        where: { id: { in: pilotIdempotencyIds } },
      }),
    ).toBe(0);

    const retainedUsage = await prisma.aiUsageAttempt.findUnique({
      where: { attemptKey: `privacy-attempt-${suffix}` },
    });
    expect(retainedUsage).toMatchObject({
      diagnosticId: null,
      actorKey: null,
      providerRequestId: null,
    });
    const retainedBudget = await prisma.aiBudgetTransaction.findUnique({
      where: { dedupeKey: `privacy-budget-transaction-${suffix}` },
    });
    expect(retainedBudget?.diagnosticId).toBeNull();
    expect(deleteObject.mock.calls.map(([key]) => key).sort()).toEqual(
      [...storageKeys].sort(),
    );
  });
});
