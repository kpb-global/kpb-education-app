import { Injectable, NotFoundException } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  ORIENTATION_FIELD_BY_ID,
  ORIENTATION_FIELDS,
} from './orientation-fields.data';
import { scoreOrientationAnswers } from './orientation-scorer';

type Answers = Record<string, string[]>;

type RecommendationDto = {
  fieldId: string;
  score: number;
  explanation: { fr: string; en: string };
  jobs: { fr: string[]; en: string[] };
  iaResilience: 'high' | 'medium' | 'low';
  partnerCountryIds: string[];
};

@Injectable()
export class OrientationService {
  /**
   * In-memory store. Source of truth only when the database is unavailable
   * (no `DATABASE_URL`); otherwise sessions live in Postgres and this array is
   * a best-effort mirror.
   */
  private readonly sessions: Array<Record<string, unknown>> = [];

  constructor(
    private readonly llmService: LlmService,
    private readonly prisma: PrismaService,
  ) {}

  getQuestions() {
    return {
      count: 10,
      fields: ORIENTATION_FIELDS,
      note: 'Mobile app ships the full questionnaire locally; backend scoring uses answer option ids.',
    };
  }

  async createSession(body: Record<string, unknown>) {
    const answers = (body.answers as Answers | undefined) ?? {};
    const profile = (body.profile as Record<string, unknown> | undefined) ?? {};
    const prioritizeIaResilience = (answers.ai_concern ?? []).includes('ai_yes');

    const ranked = scoreOrientationAnswers(answers, { prioritizeIaResilience });
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
      completedAt: new Date().toISOString(),
      answers,
      recommendations,
      iaModelUsed: llmPayload.model,
      nextActions,
    };

    this.sessions.unshift(session);
    return session;
  }

  async getResults(id: string) {
    const persisted = await this.prisma.tryExecute((client) =>
      client.orientationSession.findUnique({ where: { id } }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        completedAt: persisted.completedAt.toISOString(),
        answers: persisted.answers,
        recommendations: persisted.recommendations,
        iaModelUsed: persisted.iaModelUsed,
        nextActions: persisted.nextActions,
      };
    }

    const session = this.sessions.find((item) => item.id === id);
    if (!session) {
      throw new NotFoundException(`Orientation session ${id} not found.`);
    }
    return session;
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
      score: Math.max(score, 55),
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
