import { Injectable, NotFoundException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ORIENTATION_FIELD_BY_ID,
  ORIENTATION_FIELDS,
} from './orientation-fields.data';
import { ORIENTATION_QUESTIONS } from './orientation-questions.data';
import {
  compareScoredFields,
  matchPercentByField,
  normalizeStoredScore,
  prioritizesIaResilience,
  scoreOrientationAnswers,
} from './orientation-scorer';

type Answers = Record<string, string[]>;

type RecommendationDto = {
  fieldId: string;
  score: number;
  explanation: { fr: string; en: string };
  jobs: { fr: string[]; en: string[] };
  iaResilience: 'high' | 'medium' | 'low';
  partnerCountryIds: string[];
};

type OrientationSessionDto = {
  id: string;
  completedAt: string;
  answers: Answers;
  recommendations: RecommendationDto[];
  iaModelUsed: string;
  nextActions: { fr: string; en: string };
};

type StoredOrientationSession = OrientationSessionDto & {
  userId: string | null;
};

/** Field ids declared in a client-supplied profile, ignoring anything else. */
function readFieldIds(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value.filter((item): item is string => typeof item === 'string');
}

function readAnswers(value: unknown): Answers {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return {};
  const answers: Answers = {};
  for (const [questionId, selected] of Object.entries(value)) {
    if (!Array.isArray(selected)) continue;
    answers[questionId] = selected.filter(
      (item): item is string => typeof item === 'string',
    );
  }
  return answers;
}

/**
 * Re-scores a session read back from storage so its percentages are on the
 * current normalised scale.
 *
 * Sessions written before the fix hold `rawPoints * 10` floored at 55 — up to
 * 260, which is how a result card ended up reading "160 %". Recomputing from the
 * stored answers is idempotent for sessions written after the fix, needs no
 * migration, and never rewrites what is in the database.
 *
 * They are also re-ranked: the old ordering put AI resilience before the score,
 * so the first recommendation — the one the app badges "best match" — was not
 * necessarily the highest scoring one.
 */
function normalizeRecommendationScores(
  storedAnswers: unknown,
  storedRecommendations: unknown,
): unknown {
  if (!Array.isArray(storedRecommendations)) return storedRecommendations;

  const answers = readAnswers(storedAnswers);
  const percentByField = matchPercentByField(answers);

  const rescored = storedRecommendations.map((recommendation) => {
    const isObject =
      !!recommendation &&
      typeof recommendation === 'object' &&
      !Array.isArray(recommendation);
    const record = isObject
      ? (recommendation as Record<string, unknown>)
      : null;
    const fieldId = typeof record?.fieldId === 'string' ? record.fieldId : null;
    if (!record || fieldId === null) {
      return { fieldId: '', score: 0, recomputed: false, recommendation };
    }
    const score = normalizeStoredScore(fieldId, record.score, percentByField);
    return {
      fieldId,
      score,
      recomputed: percentByField.has(fieldId),
      recommendation: { ...record, score },
    };
  });

  // Re-rank only when every score came from the same (recomputed) scale —
  // mixing a recomputed percentage with a clamped legacy one would invent an
  // ordering. Sessions written after the fix are already in this order, so the
  // sort is a no-op for them.
  if (!rescored.every((entry) => entry.recomputed)) {
    return rescored.map((entry) => entry.recommendation);
  }
  return [...rescored]
    .sort(compareScoredFields(prioritizesIaResilience(answers)))
    .map((entry) => entry.recommendation);
}

@Injectable()
export class OrientationService {
  /**
   * In-memory store. Source of truth only when the database is unavailable
   * (no `DATABASE_URL`); otherwise sessions live in Postgres and this array is
   * a best-effort mirror.
   */
  private readonly sessions: StoredOrientationSession[] = [];

  constructor(
    private readonly llmService: LlmService,
    private readonly prisma: PrismaService,
  ) {}

  getQuestions() {
    return {
      count: ORIENTATION_QUESTIONS.length,
      fields: ORIENTATION_FIELDS,
      // Exposed so the questionnaire the server scores with can be diffed
      // against the one the app ships, instead of the two drifting silently.
      questions: ORIENTATION_QUESTIONS,
      note: 'Mobile app ships the full questionnaire (wording + translations) locally; backend scoring uses the answer option ids and the weights returned here.',
    };
  }

  async createSession(body: Record<string, unknown>) {
    const answers = (body.answers as Answers | undefined) ?? {};
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    const ranked = scoreOrientationAnswers(answers, {
      prioritizeIaResilience: prioritizesIaResilience(answers),
      declaredFieldIds: readFieldIds(profile.fieldIds),
    });
    const fallbackRecommendations = ranked.map((entry) =>
      this.buildRecommendation(entry.fieldId, entry.score, answers, profile),
    );

    const llmPayload = await this.llmService.completeJson<{
      recommendations?: Array<{
        fieldId: string;
        explanationFr?: string;
        explanationEn?: string;
      }>;
    }>({
      system:
        'Tu es l\'orientation IA KPB. Réponds UNIQUEMENT en JSON valide avec recommendations[].fieldId (d01-d12), explanationFr, explanationEn (2 phrases max, personnalisées).',
      user: JSON.stringify({
        answers,
        profile,
        topFields: ranked.slice(0, 5),
      }),
      fallback: { recommendations: [] },
    });

    const llmByField = new Map(
      (llmPayload.data.recommendations ?? []).map((item) => [item.fieldId, item]),
    );

    const recommendations: RecommendationDto[] = fallbackRecommendations.map(
      (rec) => {
        const llm = llmByField.get(rec.fieldId);
        if (!llm?.explanationFr) return rec;
        return {
          ...rec,
          explanation: {
            fr: llm.explanationFr,
            en: llm.explanationEn ?? llm.explanationFr,
          },
        };
      },
    );

    const userId =
      typeof profile.id === 'string'
        ? profile.id
        : typeof body.userId === 'string'
          ? (body.userId as string)
          : null;
    const nextActions = {
      fr: 'Explore les écoles qui enseignent ces filières et demande un accompagnement KPB.',
      en: 'Explore schools teaching these fields and request KPB support.',
    };

    // ── Persist to Postgres when available ──────────────────────────────────
    const persisted = await this.prisma.tryExecute((client) =>
      client.orientationSession.create({
        data: {
          userId,
          answers: answers as unknown as Prisma.InputJsonValue,
          recommendations: recommendations as unknown as Prisma.InputJsonValue,
          iaModelUsed: llmPayload.model,
          nextActions: nextActions as unknown as Prisma.InputJsonValue,
        },
      }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        completedAt: persisted.completedAt.toISOString(),
        answers,
        recommendations,
        iaModelUsed: persisted.iaModelUsed,
        nextActions,
      };
    }

    // ── In-memory fallback ──────────────────────────────────────────────────
    const session = {
      id: `orientation-${Date.now()}`,
      userId,
      completedAt: new Date().toISOString(),
      answers,
      recommendations,
      iaModelUsed: llmPayload.model,
      nextActions,
    };

    this.sessions.unshift(session);
    return this.toPublicSession(session);
  }

  async getResults(id: string, userId: string) {
    const persisted = await this.prisma.tryExecute((client) =>
      client.orientationSession.findFirst({ where: { id, userId } }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        completedAt: persisted.completedAt.toISOString(),
        answers: persisted.answers,
        recommendations: normalizeRecommendationScores(
          persisted.answers,
          persisted.recommendations,
        ),
        iaModelUsed: persisted.iaModelUsed,
        nextActions: persisted.nextActions,
      };
    }

    const session = this.sessions.find(
      (item) => item.id === id && item.userId === userId,
    );
    if (!session) {
      throw new NotFoundException(`Orientation session ${id} not found.`);
    }
    return this.toPublicSession(session);
  }

  private toPublicSession(session: StoredOrientationSession): OrientationSessionDto {
    const { userId: _userId, ...publicSession } = session;
    return {
      ...publicSession,
      recommendations: normalizeRecommendationScores(
        publicSession.answers,
        publicSession.recommendations,
      ) as RecommendationDto[],
    };
  }

  private buildRecommendation(
    fieldId: string,
    score: number,
    answers: Answers,
    profile: Record<string, unknown>,
  ): RecommendationDto {
    const meta = ORIENTATION_FIELD_BY_ID.get(fieldId);
    const firstName = String(profile.fullName ?? '').split(' ')[0] || 'Ton profil';
    const fieldName = meta?.nameFr ?? fieldId;

    return {
      fieldId,
      // `score` is already the normalised percentage from the scorer. It used to
      // be floored at 55, which collapsed every weak match onto one value and
      // made two unrelated fields display the same number.
      score,
      explanation: {
        fr: `${firstName}, ${fieldName} ressort fortement d'après tes réponses. Ce domaine correspond à tes centres d'intérêt et ouvre des débouchés concrets chez nos écoles partenaires KPB.`,
        en: `${firstName}, ${meta?.nameEn ?? fieldId} stands out based on your answers. This field matches your interests and opens concrete pathways through KPB partner schools.`,
      },
      jobs: {
        fr: meta?.sampleJobsFr ?? [],
        en: meta?.sampleJobsEn ?? [],
      },
      iaResilience: meta?.iaResilience ?? 'medium',
      partnerCountryIds: meta?.partnerCountryIds ?? [],
    };
  }
}
