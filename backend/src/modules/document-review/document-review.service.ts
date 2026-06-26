import { Injectable } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';

export type DocumentKind = 'motivation' | 'cv';
export type DocumentReviewLanguage = 'fr' | 'en';

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
    language: DocumentReviewLanguage = 'fr',
  ): Promise<{ review: DocumentReview; model: string }> {
    const en = language === 'en';
    const fallback: DocumentReview = en
      ? {
          ...FALLBACK,
          summary:
            'Automatic review is temporarily unavailable. A KPB advisor can review your document.',
        }
      : FALLBACK;

    const clean = (text ?? '').trim();
    if (clean.length < 80) {
      return {
        review: {
          ...fallback,
          summary: en
            ? 'Text too short for a useful review — paste your full draft.'
            : 'Texte trop court pour une relecture utile — colle ton brouillon complet.',
        },
        model: 'local-fallback',
      };
    }

    const docLabel = en
      ? kind === 'cv'
        ? 'CV / résumé'
        : 'motivation letter'
      : kind === 'cv'
        ? 'CV'
        : 'lettre de motivation';
    const system = en
      ? `You are a KPB Education expert reviewing the ${docLabel} of an African student applying to study abroad.
Evaluate constructively, concretely and kindly, in English.
Reply with a JSON object having EXACTLY these keys:
- "score": integer 0-100 (overall quality for a competitive application)
- "summary": 1 to 2 sentences of synthesis
- "strengths": array of strings (concrete strengths)
- "improvements": array of objects { "point": the problem, "suggestion": the concrete fix }
- "missing": array of strings (expected but absent elements)
Base yourself ONLY on the provided content. Do not invent any information about the student. No legal advice.`
      : `Tu es un expert KPB Education qui relit la ${docLabel} d'un étudiant africain candidat aux études à l'étranger.
Évalue de façon constructive, concrète et bienveillante, en français.
Réponds avec un objet JSON ayant EXACTEMENT ces clés:
- "score": entier 0-100 (qualité globale pour une candidature compétitive)
- "summary": 1 à 2 phrases de synthèse
- "strengths": tableau de chaînes (points forts concrets)
- "improvements": tableau d'objets { "point": le problème, "suggestion": la correction concrète }
- "missing": tableau de chaînes (éléments attendus mais absents)
Base-toi UNIQUEMENT sur le contenu fourni. N'invente aucune information sur l'étudiant. Pas de conseil juridique.`;
    const user = en
      ? `Document type: ${docLabel}\n\nContent:\n"""\n${clean.slice(0, 6000)}\n"""`
      : `Type de document: ${docLabel}\n\nContenu:\n"""\n${clean.slice(0, 6000)}\n"""`;

    const { data, model } = await this.llm.completeJson<DocumentReview>({
      system,
      user,
      maxTokens: 1200,
      fallback,
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
      summary: typeof data.summary === 'string' ? data.summary : fallback.summary,
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
