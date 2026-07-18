import type { LlmService } from "../../ai/llm.service";
import type { PrismaService } from "../../prisma/prisma.service";
import type { FeatureAccessService } from "../common/feature-access.service";
import {
  IdempotencyPayloadMismatchError,
  type IdempotencyService,
} from "../common/idempotency.service";
import type { AiBudgetService } from "./ai-budget.service";
import { AiDiagnosticsService } from "./ai-diagnostics.service";

describe("AiDiagnosticsService", () => {
  const previousEnv = {
    model: process.env.KPB_AI_DIAGNOSTIC_MODEL,
    study: process.env.KPB_STUDY_REVIEW_ENABLED,
  };
  const now = new Date("2026-07-17T12:00:00.000Z");
  const workspace = {
    id: "workspace-1",
    userId: "student-1",
    scholarshipId: "scholarship-1",
    scholarshipCycleId: "cycle-1",
    status: "preparing",
    version: 3,
    readinessPercent: 25,
    startedAt: now,
    lastActivityAt: now,
    submittedAt: null,
    decisionReceivedAt: null,
    archivedAt: null,
    createdAt: now,
    updatedAt: now,
    user: {
      fullName: "Student Test",
      email: "student@example.com",
      phone: "+22790000000",
      whatsApp: null,
      guardianName: null,
      guardianContact: null,
    },
    scholarship: {
      id: "scholarship-1",
      eligibilityFr: ["Leadership démontré"],
      eligibilityEn: ["Demonstrated leadership"],
      sourceUrl: "https://official.example",
      lastVerifiedAt: now,
      moderationStatus: "approved",
      updatedAt: now,
    },
    steps: [
      {
        id: "step-1",
        workspaceId: "workspace-1",
        sourceStepId: null,
        code: "prepare-cv",
        titleFr: "Préparer mon CV",
        titleEn: "Prepare my CV",
        category: "documents",
        weight: 40,
        isRequired: true,
        templateVersion: "success-lab-v1",
        status: "in_progress",
        notApplicableReason: null,
        completedAt: null,
        createdAt: now,
        updatedAt: now,
      },
    ],
  };

  beforeEach(() => {
    delete process.env.KPB_AI_DIAGNOSTIC_MODEL;
    process.env.KPB_STUDY_REVIEW_ENABLED = "true";
  });

  afterAll(() => {
    restore("KPB_AI_DIAGNOSTIC_MODEL", previousEnv.model);
    restore("KPB_STUDY_REVIEW_ENABLED", previousEnv.study);
  });

  it("stores one deterministic fallback without calling a provider when unconfigured", async () => {
    const created = diagnosticRow({ status: "pending" });
    const updates: Array<Record<string, unknown>> = [];
    const client = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue(workspace),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue({ id: "consent-1" }),
      },
      aiDiagnostic: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue(created),
        update: jest
          .fn()
          .mockImplementation(({ data }: { data: Record<string, unknown> }) => {
            updates.push(data);
            return Promise.resolve(
              diagnosticRow({
                ...data,
                status: data.status as string,
                completedAt: data.completedAt as Date,
              }),
            );
          }),
      },
    };
    const execute = jest.fn(
      async (operation: (value: typeof client) => Promise<unknown>) =>
        operation(client),
    );
    const reserve = jest.fn();
    const completeStructured = jest.fn();
    const idempotency = acquiredIdempotency();
    const service = new AiDiagnosticsService(
      { isEnabled: true, execute } as unknown as PrismaService,
      {
        evaluate: jest.fn().mockResolvedValue({
          allowed: true,
          feature: "ai_diagnostic",
        }),
      } as unknown as FeatureAccessService,
      { reserve } as unknown as AiBudgetService,
      { isConfigured: false, completeStructured } as unknown as LlmService,
      idempotency.service,
    );

    const result = await service.create(
      "student-1",
      "workspace-1",
      {
        language: "fr",
        consentReceiptId: "consent-1",
        applicationExcerpt: "Student Test student@example.com",
      },
      "diagnostic-key-1",
    );

    expect(result.statusCode).toBe(201);
    expect(result.body).toMatchObject({
      status: "deterministic_fallback",
      fallbackReason: "provider_unconfigured",
      result: {
        priorityImprovement: expect.stringContaining("Préparer mon CV"),
      },
      reviewInvitation: { available: true },
    });
    expect(updates).toContainEqual(
      expect.objectContaining({ status: "deterministic_fallback" }),
    );
    expect(reserve).not.toHaveBeenCalled();
    expect(completeStructured).not.toHaveBeenCalled();
    expect(idempotency.complete).toHaveBeenCalledWith(
      expect.objectContaining({
        recordId: "idempotency-1",
        resourceType: "AiDiagnostic",
        resourceId: "diagnostic-1",
      }),
    );
  });

  it("returns the completed entitlement without reserving a second attempt", async () => {
    const existing = diagnosticRow({ status: "succeeded" });
    const client = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue(workspace),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue({ id: "consent-1" }),
      },
      aiDiagnostic: { findUnique: jest.fn().mockResolvedValue(existing) },
    };
    const reserve = jest.fn();
    const idempotency = acquiredIdempotency();
    const service = new AiDiagnosticsService(
      {
        isEnabled: true,
        execute: jest.fn(
          async (operation: (value: typeof client) => Promise<unknown>) =>
            operation(client),
        ),
      } as unknown as PrismaService,
      {
        evaluate: jest.fn().mockResolvedValue({
          allowed: true,
          feature: "ai_diagnostic",
        }),
      } as unknown as FeatureAccessService,
      { reserve } as unknown as AiBudgetService,
      { isConfigured: true } as unknown as LlmService,
      idempotency.service,
    );

    const result = await service.create(
      "student-1",
      "workspace-1",
      {
        language: "fr",
        consentReceiptId: "consent-1",
      },
      "diagnostic-key-cached",
    );

    expect(result.statusCode).toBe(200);
    expect(result.body).toMatchObject({ id: existing.id, status: "succeeded" });
    expect(reserve).not.toHaveBeenCalled();
    expect(idempotency.complete).toHaveBeenCalled();
  });

  it("replays a completed idempotency response without creating an entitlement", async () => {
    const client = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue(workspace),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue({ id: "consent-1" }),
      },
      aiDiagnostic: { findUnique: jest.fn() },
    };
    const idempotency = acquiredIdempotency();
    idempotency.reserve.mockResolvedValue({
      state: "replay",
      recordId: "idempotency-1",
      payloadHash: "hash",
      responseCode: 201,
      responseSnapshot: { id: "diagnostic-replayed", status: "succeeded" },
      resourceType: "AiDiagnostic",
      resourceId: "diagnostic-replayed",
      resultingVersion: null,
      expiresAt: new Date("2026-07-18T12:00:00.000Z"),
    });
    const service = new AiDiagnosticsService(
      {
        isEnabled: true,
        execute: jest.fn(
          async (operation: (value: typeof client) => Promise<unknown>) =>
            operation(client),
        ),
      } as unknown as PrismaService,
      {
        evaluate: jest.fn().mockResolvedValue({
          allowed: true,
          feature: "ai_diagnostic",
        }),
      } as unknown as FeatureAccessService,
      { reserve: jest.fn() } as unknown as AiBudgetService,
      { isConfigured: true } as unknown as LlmService,
      idempotency.service,
    );

    const result = await service.create(
      "student-1",
      "workspace-1",
      { language: "fr", consentReceiptId: "consent-1" },
      "diagnostic-key-replay",
    );

    expect(result).toEqual({
      statusCode: 201,
      body: { id: "diagnostic-replayed", status: "succeeded" },
    });
    expect(client.aiDiagnostic.findUnique).not.toHaveBeenCalled();
  });

  it("maps a reused key with another payload to the stable mismatch error", async () => {
    const client = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue(workspace),
      },
      consentReceipt: {
        findFirst: jest.fn().mockResolvedValue({ id: "consent-1" }),
      },
    };
    const idempotency = acquiredIdempotency();
    idempotency.reserve.mockRejectedValue(
      new IdempotencyPayloadMismatchError(),
    );
    const service = new AiDiagnosticsService(
      {
        isEnabled: true,
        execute: jest.fn(
          async (operation: (value: typeof client) => Promise<unknown>) =>
            operation(client),
        ),
      } as unknown as PrismaService,
      {
        evaluate: jest.fn().mockResolvedValue({
          allowed: true,
          feature: "ai_diagnostic",
        }),
      } as unknown as FeatureAccessService,
      { reserve: jest.fn() } as unknown as AiBudgetService,
      { isConfigured: true } as unknown as LlmService,
      idempotency.service,
    );

    await expect(
      service.create(
        "student-1",
        "workspace-1",
        { language: "en", consentReceiptId: "consent-1" },
        "diagnostic-key-reused",
      ),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({
        code: "IDEMPOTENCY_PAYLOAD_MISMATCH",
      }),
    });
  });
});

function acquiredIdempotency() {
  const reserve = jest.fn();
  reserve.mockResolvedValue({
    state: "acquired",
    recordId: "idempotency-1",
    payloadHash: "hash",
    expiresAt: new Date("2026-07-18T12:00:00.000Z"),
  });
  const complete = jest.fn();
  const markFailed = jest.fn();
  return {
    reserve,
    complete,
    markFailed,
    service: { reserve, complete, markFailed } as unknown as IdempotencyService,
  };
}

function diagnosticRow(overrides: Record<string, unknown> = {}) {
  const now = new Date("2026-07-17T12:00:00.000Z");
  return {
    id: "diagnostic-1",
    workspaceId: "workspace-1",
    artifactVersionId: null,
    entitlementKey: "workspace:workspace-1:free-diagnostic:v1",
    status: "succeeded",
    documentKind: null,
    generatedLanguage: "fr",
    strength: "Ton dossier contient une base claire et exploitable.",
    priorityImprovement: "Ajoute une preuve mesurable de ton leadership.",
    rationale: "Le critère demande un exemple concret et vérifiable.",
    nextAction: "Ajoute un résultat chiffré à ton premier exemple.",
    criterionReferences: ["eligibility-001"],
    inputFingerprint: "fingerprint",
    workspaceVersion: 3,
    criteriaVersion: "stale-version-is-acceptable-in-this-unit-test",
    artifactSha256: null,
    provider: "local",
    model: "deterministic-fallback",
    promptVersion: "success-lab-v1",
    fallbackReason: null,
    startedAt: now,
    completedAt: now,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function restore(key: string, value: string | undefined) {
  if (value === undefined) delete process.env[key];
  else process.env[key] = value;
}
