import { Injectable } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';

export type DocumentKind = 'motivation' | 'cv';

export type DocumentReview = {
  score: number;
  summary: string;
  strengths: string[];
  improvements: { point: string; suggestion: string }[];
  missing: string[];
};

const FALLBACK: DocumentReview = {
  score: 0,
  summary:
    "La relecture automatique est momentanément indisponible. Un conseiller KPB peut relire ton document.",
  strengths: [],
  improvements: [],
  missing: [],
};

/**
 * Sprint 10 — AI review of a student's motivation letter / CV. Productizes the
 * "Dossier prêt" service as instant, structured, on-rubric feedback. Reuses the
 * grounded JSON LLM helper; degrades gracefully when Groq is unconfigured.
 */
@Injectable()
export class DocumentReviewService {
  constructor(private readonly llm: LlmService) {}

  async review(
    kind: DocumentKind,
    text: string,
  ): Promise<{ review: DocumentReview; model: string }> {
    const clean = (text ?? '').trim();
    if (clean.length < 80) {
      return {
        review: {
          ...FALLBACK,
          summary:
            'Texte trop court pour une relecture utile — colle ton brouillon complet.',
        },
        model: 'local-fallback',
      };
    }

    const docLabel = kind === 'cv' ? 'CV' : 'lettre de motivation';
    const system = `Tu es un expert KPB Education qui relit la ${docLabel} d'un étudiant africain candidat aux études à l'étranger.
Évalue de façon constructive, concrète et bienveillante, en français.
Réponds avec un objet JSON ayant EXACTEMENT ces clés:
- "score": entier 0-100 (qualité globale pour une candidature compétitive)
- "summary": 1 à 2 phrases de synthèse
- "strengths": tableau de chaînes (points forts concrets)
- "improvements": tableau d'objets { "point": le problème, "suggestion": la correction concrète }
- "missing": tableau de chaînes (éléments attendus mais absents)
Base-toi UNIQUEMENT sur le contenu fourni. N'invente aucune information sur l'étudiant. Pas de conseil juridique.`;
    const user = `Type de document: ${docLabel}\n\nContenu:\n"""\n${clean.slice(0, 6000)}\n"""`;

    const { data, model } = await this.llm.completeJson<DocumentReview>({
      system,
      user,
      maxTokens: 1200,
      fallback: FALLBACK,
    });

    // Guard the model's shape before returning it to the client.
    const strList = (v: unknown): string[] =>
      Array.isArray(v)
        ? v.filter((x): x is string => typeof x === 'string').slice(0, 8)
        : [];
    const review: DocumentReview = {
      score:
        typeof data.score === 'number' && Number.isFinite(data.score)
          ? Math.max(0, Math.min(100, Math.round(data.score)))
          : 0,
      summary: typeof data.summary === 'string' ? data.summary : FALLBACK.summary,
      strengths: strList(data.strengths),
      improvements: Array.isArray(data.improvements)
        ? data.improvements
            .filter(
              (i): i is { point: string; suggestion: string } =>
                !!i &&
                typeof i.point === 'string' &&
                typeof i.suggestion === 'string',
            )
            .slice(0, 8)
        : [],
      missing: strList(data.missing),
    };
    return { review, model };
  }
}
