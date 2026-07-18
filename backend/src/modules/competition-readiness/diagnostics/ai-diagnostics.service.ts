import { createHash } from "node:crypto";

import { Injectable } from "@nestjs/common";
import { Prisma, type ApplicationArtifactKind } from "@prisma/client";

import { LlmService } from "../../ai/llm.service";
import { PrismaService } from "../../prisma/prisma.service";
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
  idempotencyInProgress,
  idempotencyPayloadMismatch,
  workspaceNotFound,
} from "../common/competition-readiness.errors";
import { FeatureAccessService } from "../common/feature-access.service";
import {
  IdempotencyPayloadMismatchError,
  IdempotencyService,
  IdempotencyStorageUnavailableError,
} from "../common/idempotency.service";
import { AiBudgetService } from "./ai-budget.service";
import {
  buildDeterministicDiagnostic,
  diagnosticInputFingerprint,
  isSuccessLabDiagnosticOutput,
  redactDiagnosticInput,
  SUCCESS_LAB_DIAGNOSTIC_SCHEMA,
  type DiagnosticCriterion,
  type DiagnosticStep,
  type SuccessLabDiagnosticOutput,
} from "./ai-diagnostic.policy";
import { buildDiagnosticPrompt } from "./diagnostic-prompt.builder";
import type { CreateAiDiagnosticDto } from "./dto/create-ai-diagnostic.dto";

const PROMPT_VERSION_FALLBACK = "success-lab-v1";
const PROVIDER = "groq";
const ALLOWED_DOCUMENT_KINDS = new Set<ApplicationArtifactKind>([
  "cv",
  "motivation_letter",
  "essay",
]);

const diagnosticSelect = {
  id: true,
  workspaceId: true,
  artifactVersionId: true,
  entitlementKey: true,
  status: true,
  documentKind: true,
  generatedLanguage: true,
  strength: true,
  priorityImprovement: true,
  rationale: true,
  nextAction: true,
  criterionReferences: true,
  inputFingerprint: true,
  workspaceVersion: true,
  criteriaVersion: true,
  artifactSha256: true,
  provider: true,
  model: true,
  promptVersion: true,
  fallbackReason: true,
  startedAt: true,
  completedAt: true,
  createdAt: true,
  updatedAt: true,
} satisfies Prisma.AiDiagnosticSelect;

type DiagnosticRow = Prisma.AiDiagnosticGetPayload<{
  select: typeof diagnosticSelect;
}>;

@Injectable()
export class AiDiagnosticsService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly featureAccess: FeatureAccessService,
    private readonly budget: AiBudgetService,
    private readonly llm: LlmService,
    private readonly idempotency: IdempotencyService,
  ) {}

  async getExisting(userId: string, workspaceId: string) {
    this.assertDb();
    await this.assertSuccessLabAccess(userId);
    const workspace = await this.loadWorkspace(userId, workspaceId);
    if (!workspace) throw workspaceNotFound();
    const diagnostic = await this.prismaService.execute((prisma) =>
      prisma.aiDiagnostic.findUnique({
        where: { entitlementKey: this.entitlementKey(workspaceId) },
        select: diagnosticSelect,
      }),
    );
    if (!diagnostic) {
      return {
        schemaVersion: 1,
        diagnostic: null,
        entitlement: { available: true, keyVersion: 1 },
      };
    }

    return {
      schemaVersion: 1,
      diagnostic: this.serialize(
        diagnostic,
        this.isStale(diagnostic, workspace),
      ),
      entitlement: {
        available: !this.closesEntitlement(diagnostic.status),
        keyVersion: 1,
      },
    };
  }

  async create(
    userId: string,
    workspaceId: string,
    input: CreateAiDiagnosticDto,
    idempotencyKey: string,
  ): Promise<{ statusCode: number; body: unknown }> {
    this.assertDb();
    await this.assertAiAccess(userId);
    const workspace = await this.loadWorkspace(userId, workspaceId);
    if (!workspace) throw workspaceNotFound();
    await this.assertConsentReceipt(userId, input.consentReceiptId);

    let reservation;
    try {
      reservation = await this.idempotency.reserve({
        actorType: "student",
        actorId: userId,
        operation: "ai-diagnostic.create",
        idempotencyKey,
        payload: { workspaceId, ...input },
      });
    } catch (error) {
      if (error instanceof IdempotencyPayloadMismatchError) {
        throw idempotencyPayloadMismatch();
      }
      if (error instanceof IdempotencyStorageUnavailableError) {
        throw databaseUnavailable();
      }
      throw error;
    }
    if (reservation.state === "replay") {
      if (reservation.responseSnapshot === null) throw databaseUnavailable();
      return {
        statusCode: reservation.responseCode ?? 200,
        body: reservation.responseSnapshot,
      };
    }
    if (reservation.state !== "acquired") throw idempotencyInProgress();

    try {
      const result = await this.createOnce(userId, workspaceId, input);
      const body = JSON.parse(
        JSON.stringify(result.body),
      ) as Prisma.InputJsonValue;
      const resourceId =
        typeof result.body === "object" &&
        result.body !== null &&
        "id" in result.body &&
        typeof result.body.id === "string"
          ? result.body.id
          : undefined;
      await this.idempotency.complete({
        recordId: reservation.recordId,
        responseCode: result.statusCode,
        responseSnapshot: body,
        resourceType: "AiDiagnostic",
        resourceId,
      });
      return result;
    } catch (error) {
      try {
        await this.idempotency.markFailed(reservation.recordId);
      } catch {
        // Preserve the domain/provider error. A retry can still recover from
        // the unique entitlement even if the failure marker could not persist.
      }
      throw error;
    }
  }

  private async createOnce(
    userId: string,
    workspaceId: string,
    input: CreateAiDiagnosticDto,
  ): Promise<{ statusCode: number; body: unknown }> {
    const workspace = await this.loadWorkspace(userId, workspaceId);
    if (!workspace) throw workspaceNotFound();

    const existing = await this.findEntitlement(workspaceId);
    if (existing) return this.cached(existing, workspace);

    const promptVersion =
      process.env.KPB_AI_DIAGNOSTIC_PROMPT_VERSION?.trim() ||
      PROMPT_VERSION_FALLBACK;
    const criteria = this.verifiedCriteria(workspace, input.language);
    const criteriaVersion = this.criteriaVersion(workspace);
    const steps = this.steps(workspace, input.language);
    const artifact = input.artifactVersionId
      ? await this.loadOwnedArtifact(
          userId,
          workspaceId,
          input.artifactVersionId,
        )
      : null;
    const maxInputChars = this.positiveInteger(
      process.env.KPB_AI_DIAGNOSTIC_MAX_INPUT_CHARS,
      8000,
    );
    const rawExcerpt =
      artifact?.extractedText || input.applicationExcerpt || "";
    const excerpt = redactDiagnosticInput(
      rawExcerpt,
      [
        workspace.user.fullName,
        workspace.user.email,
        workspace.user.phone,
        workspace.user.whatsApp ?? "",
        workspace.user.guardianName ?? "",
        workspace.user.guardianContact ?? "",
      ],
      maxInputChars,
    );
    const fallback = buildDeterministicDiagnostic({
      language: input.language,
      steps,
      criteria,
    });
    const fingerprint = diagnosticInputFingerprint({
      promptVersion,
      language: input.language,
      workspaceVersion: workspace.version,
      criteriaVersion,
      artifactSha256: artifact?.sha256,
    });

    let diagnostic: DiagnosticRow;
    try {
      const created = await this.prismaService.execute((prisma) =>
        prisma.aiDiagnostic.create({
          data: {
            workspaceId,
            artifactVersionId: artifact?.id,
            entitlementKey: this.entitlementKey(workspaceId),
            status: "pending",
            documentKind: artifact?.artifact.kind,
            generatedLanguage: input.language,
            inputFingerprint: fingerprint,
            workspaceVersion: workspace.version,
            criteriaVersion,
            artifactSha256: artifact?.sha256,
            promptVersion,
          },
          select: diagnosticSelect,
        }),
      );
      if (!created) throw databaseUnavailable();
      diagnostic = created;
    } catch (error) {
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === "P2002"
      ) {
        const raced = await this.findEntitlement(workspaceId);
        if (raced) return this.cached(raced, workspace);
      }
      throw error;
    }

    const model = process.env.KPB_AI_DIAGNOSTIC_MODEL?.trim() ?? "";
    if (!model || !this.llm.isConfigured || criteria.length === 0) {
      const reason =
        !model || !this.llm.isConfigured
          ? "provider_unconfigured"
          : "criteria_not_verified";
      const completed = await this.completeFallback(
        diagnostic.id,
        fallback,
        reason,
      );
      return { statusCode: 201, body: this.serialize(completed, false) };
    }

    const attemptKey = `${diagnostic.id}:1`;
    const reservation = await this.budget.reserve({
      userId,
      diagnosticId: diagnostic.id,
      attemptKey,
      attemptNumber: 1,
      provider: PROVIDER,
      model,
      promptVersion,
    });
    if (!reservation.allowed) {
      const completed = await this.completeFallback(
        diagnostic.id,
        fallback,
        reservation.reason,
      );
      return { statusCode: 201, body: this.serialize(completed, false) };
    }

    await this.prismaService.execute((prisma) =>
      prisma.aiDiagnostic.update({
        where: { id: diagnostic.id },
        data: {
          status: "running",
          provider: PROVIDER,
          model,
          startedAt: new Date(),
        },
      }),
    );
    const prompt = buildDiagnosticPrompt({
      language: input.language,
      criteria,
      steps,
      artifactExcerpt: excerpt || null,
    });
    const allowedCriterionCodes = new Set(
      criteria.map((criterion) => criterion.code),
    );
    const result =
      await this.llm.completeStructured<SuccessLabDiagnosticOutput>({
        feature: "success_lab_diagnostic",
        attemptKey,
        system: prompt.system,
        user: prompt.user,
        responseSchema: SUCCESS_LAB_DIAGNOSTIC_SCHEMA,
        validate: (value): value is SuccessLabDiagnosticOutput =>
          isSuccessLabDiagnosticOutput(value, allowedCriterionCodes),
        fallback,
        temperature: 0.1,
        maxTokens: this.positiveInteger(
          process.env.KPB_AI_DIAGNOSTIC_MAX_OUTPUT_TOKENS,
          220,
        ),
        promptVersion,
        model,
      });

    try {
      await this.budget.settle(reservation, result);
    } catch {
      await this.markFailed(diagnostic.id, "budget_settlement_failed");
      throw new CompetitionReadinessHttpException(
        "AI_TEMPORARILY_UNAVAILABLE",
        503,
        "The diagnostic is temporarily unavailable.",
      );
    }
    const completed = await this.completeResult(diagnostic.id, result);
    return { statusCode: 201, body: this.serialize(completed, false) };
  }

  private async loadWorkspace(userId: string, workspaceId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.scholarshipWorkspace.findFirst({
        where: { id: workspaceId, userId, status: { not: "archived" } },
        include: {
          user: {
            select: {
              fullName: true,
              email: true,
              phone: true,
              whatsApp: true,
              guardianName: true,
              guardianContact: true,
            },
          },
          scholarship: {
            select: {
              id: true,
              eligibilityFr: true,
              eligibilityEn: true,
              sourceUrl: true,
              lastVerifiedAt: true,
              moderationStatus: true,
              updatedAt: true,
            },
          },
          steps: { orderBy: [{ category: "asc" }, { code: "asc" }] },
        },
      }),
    );
  }

  private async loadOwnedArtifact(
    userId: string,
    workspaceId: string,
    artifactVersionId: string,
  ) {
    const artifact = await this.prismaService.execute((prisma) =>
      prisma.applicationArtifactVersion.findFirst({
        where: {
          id: artifactVersionId,
          processingStatus: "clean",
          deletedAt: null,
          artifact: {
            workspaceId,
            workspace: { userId },
            currentVersionId: artifactVersionId,
            kind: { in: [...ALLOWED_DOCUMENT_KINDS] },
          },
        },
        include: { artifact: { select: { kind: true } } },
      }),
    );
    if (!artifact) {
      throw new CompetitionReadinessHttpException(
        "EVIDENCE_REJECTED",
        422,
        "The selected artifact is unavailable for an AI diagnostic.",
      );
    }
    return artifact;
  }

  private async assertConsentReceipt(userId: string, receiptId?: string) {
    const receipt = await this.prismaService.execute((prisma) =>
      prisma.consentReceipt.findFirst({
        where: {
          ...(receiptId ? { id: receiptId } : {}),
          userId,
          purpose: "ai_third_party",
          revokedAt: null,
          grantedAt: { lte: new Date() },
          notice: {
            effectiveAt: { lte: new Date() },
            retiredAt: null,
          },
        },
        orderBy: { grantedAt: "desc" },
        select: { id: true },
      }),
    );
    if (!receipt) {
      throw new CompetitionReadinessHttpException(
        "AI_CONSENT_REQUIRED",
        403,
        "A current AI processing consent receipt is required.",
      );
    }
  }

  private verifiedCriteria(
    workspace: NonNullable<
      Awaited<ReturnType<AiDiagnosticsService["loadWorkspace"]>>
    >,
    language: "fr" | "en",
  ): DiagnosticCriterion[] {
    const maxAgeDays = this.positiveInteger(
      process.env.KPB_AI_DIAGNOSTIC_CRITERIA_MAX_AGE_DAYS,
      180,
    );
    const verifiedAfter = new Date(
      Date.now() - maxAgeDays * 24 * 60 * 60 * 1000,
    );
    if (
      workspace.scholarship.moderationStatus !== "approved" ||
      !workspace.scholarship.sourceUrl ||
      !workspace.scholarship.lastVerifiedAt ||
      workspace.scholarship.lastVerifiedAt < verifiedAfter
    ) {
      return [];
    }
    const labels =
      language === "en"
        ? workspace.scholarship.eligibilityEn
        : workspace.scholarship.eligibilityFr;
    return labels
      .map((label, index) => ({
        code: `eligibility-${String(index + 1).padStart(3, "0")}`,
        label: label.trim().slice(0, 240),
      }))
      .filter((criterion) => criterion.label.length >= 3)
      .slice(0, 20);
  }

  private steps(
    workspace: NonNullable<
      Awaited<ReturnType<AiDiagnosticsService["loadWorkspace"]>>
    >,
    language: "fr" | "en",
  ): DiagnosticStep[] {
    return workspace.steps.slice(0, 20).map((step) => ({
      code: step.code,
      title: language === "en" ? step.titleEn : step.titleFr,
      status: step.status,
      isRequired: step.isRequired,
    }));
  }

  private criteriaVersion(
    workspace: NonNullable<
      Awaited<ReturnType<AiDiagnosticsService["loadWorkspace"]>>
    >,
  ): string {
    return createHash("sha256")
      .update(
        JSON.stringify({
          scholarshipId: workspace.scholarship.id,
          eligibilityFr: workspace.scholarship.eligibilityFr,
          eligibilityEn: workspace.scholarship.eligibilityEn,
          sourceUrl: workspace.scholarship.sourceUrl,
          lastVerifiedAt:
            workspace.scholarship.lastVerifiedAt?.toISOString() ?? null,
          updatedAt: workspace.scholarship.updatedAt.toISOString(),
        }),
      )
      .digest("hex");
  }

  private async findEntitlement(workspaceId: string) {
    return this.prismaService.execute((prisma) =>
      prisma.aiDiagnostic.findUnique({
        where: { entitlementKey: this.entitlementKey(workspaceId) },
        select: diagnosticSelect,
      }),
    );
  }

  private cached(
    diagnostic: DiagnosticRow,
    workspace: NonNullable<
      Awaited<ReturnType<AiDiagnosticsService["loadWorkspace"]>>
    >,
  ) {
    return {
      statusCode:
        diagnostic.status === "pending" || diagnostic.status === "running"
          ? 202
          : 200,
      body: this.serialize(diagnostic, this.isStale(diagnostic, workspace)),
    };
  }

  private async completeFallback(
    diagnosticId: string,
    fallback: SuccessLabDiagnosticOutput,
    fallbackReason: string,
  ) {
    const completedAt = new Date();
    const result = await this.prismaService.execute((prisma) =>
      prisma.aiDiagnostic.update({
        where: { id: diagnosticId },
        data: {
          status: "deterministic_fallback",
          strength: fallback.strength,
          priorityImprovement: fallback.priorityImprovement,
          rationale: fallback.rationale,
          nextAction: fallback.nextAction,
          criterionReferences:
            fallback.criterionReferences as Prisma.InputJsonValue,
          provider: "local",
          model: "deterministic-fallback",
          fallbackReason,
          completedAt,
        },
        select: diagnosticSelect,
      }),
    );
    if (!result) throw databaseUnavailable();
    return result;
  }

  private async completeResult(
    diagnosticId: string,
    result: Awaited<ReturnType<LlmService["completeStructured"]>>,
  ) {
    const data = result.data as SuccessLabDiagnosticOutput;
    const succeeded = result.outcome === "success";
    const completed = await this.prismaService.execute((prisma) =>
      prisma.aiDiagnostic.update({
        where: { id: diagnosticId },
        data: {
          status: succeeded ? "succeeded" : "deterministic_fallback",
          strength: data.strength,
          priorityImprovement: data.priorityImprovement,
          rationale: data.rationale,
          nextAction: data.nextAction,
          criterionReferences:
            data.criterionReferences as Prisma.InputJsonValue,
          provider: result.provider,
          model: result.model,
          fallbackReason: result.fallbackReason,
          completedAt: new Date(),
        },
        select: diagnosticSelect,
      }),
    );
    if (!completed) throw databaseUnavailable();
    return completed;
  }

  private async markFailed(diagnosticId: string, reason: string) {
    await this.prismaService.execute((prisma) =>
      prisma.aiDiagnostic.update({
        where: { id: diagnosticId },
        data: { status: "failed", fallbackReason: reason },
      }),
    );
  }

  private serialize(diagnostic: DiagnosticRow, stale: boolean) {
    const hasResult = this.closesEntitlement(diagnostic.status);
    return {
      schemaVersion: 1,
      id: diagnostic.id,
      workspaceId: diagnostic.workspaceId,
      status: diagnostic.status,
      generatedLanguage: diagnostic.generatedLanguage,
      result: hasResult
        ? {
            strength: diagnostic.strength,
            priorityImprovement: diagnostic.priorityImprovement,
            rationale: diagnostic.rationale,
            nextAction: diagnostic.nextAction,
            criterionReferences: diagnostic.criterionReferences ?? [],
          }
        : null,
      stale,
      provider: diagnostic.provider,
      model: diagnostic.model,
      promptVersion: diagnostic.promptVersion,
      fallbackReason: diagnostic.fallbackReason,
      completedAt: diagnostic.completedAt?.toISOString() ?? null,
      reviewInvitation: {
        available:
          process.env.KPB_STUDY_REVIEW_ENABLED?.trim().toLowerCase() === "true",
        label: "Faire étudier mon dossier par un conseiller KPB",
      },
    };
  }

  private isStale(
    diagnostic: DiagnosticRow,
    workspace: NonNullable<
      Awaited<ReturnType<AiDiagnosticsService["loadWorkspace"]>>
    >,
  ) {
    return (
      diagnostic.workspaceVersion !== workspace.version ||
      diagnostic.criteriaVersion !== this.criteriaVersion(workspace)
    );
  }

  private entitlementKey(workspaceId: string) {
    return `workspace:${workspaceId}:free-diagnostic:v1`;
  }

  private closesEntitlement(status: string) {
    return status === "succeeded" || status === "deterministic_fallback";
  }

  private assertDb() {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
  }

  private async assertSuccessLabAccess(userId: string) {
    const decision = await this.featureAccess.evaluate({
      feature: "success_lab",
      userId,
    });
    if (!decision.allowed) throw featureDisabled("success_lab");
  }

  private async assertAiAccess(userId: string) {
    const decision = await this.featureAccess.evaluate({
      feature: "ai_diagnostic",
      userId,
    });
    if (decision.allowed) return;
    if (decision.reason === "consent_required") {
      throw new CompetitionReadinessHttpException(
        "AI_CONSENT_REQUIRED",
        403,
        "AI processing consent is required.",
      );
    }
    if (
      decision.reason === "guardian_authorization_required" ||
      decision.reason === "birth_date_required" ||
      decision.reason === "age_below_minimum"
    ) {
      throw new CompetitionReadinessHttpException(
        "GUARDIAN_CONSENT_REQUIRED",
        403,
        "Guardian authorization or an eligible age is required.",
      );
    }
    throw featureDisabled("ai_diagnostic");
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
