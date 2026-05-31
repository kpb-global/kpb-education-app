// ─────────────────────────────────────────────────────────────────────────────
// ToolsService — student productivity tools powered by Groq via LlmService.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { LlmService } from '../ai/llm.service';

export interface CvSummaryDto {
  name: string;
  studyLevel: string;
  fieldOfStudy: string;
  targetCountry?: string;
  skills?: string[];
  languages?: string[];
  experience?: string;
}

export interface LetterPersonalizeDto {
  templateKey: string;
  templateBody: string;
  name: string;
  fieldOfStudy: string;
  targetCountry?: string;
  targetInstitution?: string;
  targetScholarship?: string;
}

export interface InterviewQuestionsDto {
  type: 'visa' | 'admission' | 'scholarship';
  fieldOfStudy?: string;
  targetCountry?: string;
  language?: 'fr' | 'en';
}

export interface InterviewFeedbackDto {
  type: 'visa' | 'admission' | 'scholarship';
  question: string;
  answer: string;
  language?: 'fr' | 'en';
}

export interface InterviewFeedback {
  score: number; // 0-100
  strengths: string[];
  improvements: string[];
  modelAnswer: string;
}

@Injectable()
export class ToolsService {
  private readonly logger = new Logger(ToolsService.name);

  constructor(private readonly llm: LlmService) {}

  // ── 1. CV summary (FR + EN) ───────────────────────────────────────────────

  async generateCvSummary(
    dto: CvSummaryDto,
  ): Promise<{ fr: string; en: string }> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    const context = [
      `Nom : ${dto.name}`,
      `Niveau d'études : ${dto.studyLevel}`,
      `Domaine : ${dto.fieldOfStudy}`,
      dto.targetCountry ? `Pays cible : ${dto.targetCountry}` : '',
      dto.skills?.length ? `Compétences : ${dto.skills.join(', ')}` : '',
      dto.languages?.length ? `Langues : ${dto.languages.join(', ')}` : '',
      dto.experience ? `Expérience : ${dto.experience}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    const result = await this.llm.completeJson<{ fr: string; en: string }>({
      system:
        'Tu es un expert en rédaction de CV pour étudiants internationaux. ' +
        'Rédige un paragraphe de présentation professionnelle (5-7 phrases) ' +
        'en français ET en anglais, percutant et adapté au recrutement international. ' +
        'Ne commence pas par "Je suis" / "I am". ' +
        'Retourne un JSON { "fr": "...", "en": "..." }.',
      user: context,
      maxTokens: 600,
      fallback: {
        fr: 'Étudiant(e) motivé(e) avec une solide formation.',
        en: 'Motivated student with a solid academic background.',
      },
    });

    return result.data;
  }

  // ── 2. Letter personalisation (FR + EN) ───────────────────────────────────

  async personalizeLetters(
    dto: LetterPersonalizeDto,
  ): Promise<{ fr: string; en: string }> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    const context = [
      `Nom : ${dto.name}`,
      `Domaine : ${dto.fieldOfStudy}`,
      dto.targetCountry ? `Pays cible : ${dto.targetCountry}` : '',
      dto.targetInstitution ? `Établissement : ${dto.targetInstitution}` : '',
      dto.targetScholarship ? `Bourse visée : ${dto.targetScholarship}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    const result = await this.llm.completeJson<{ fr: string; en: string }>({
      system:
        'Tu es un expert en rédaction de lettres de motivation pour étudiants internationaux. ' +
        'Personnalise le modèle fourni avec les informations de l\'étudiant. ' +
        'Garde la structure, améliore la formulation, rends-la authentique. ' +
        'Fournis la version française ET une traduction/adaptation anglaise. ' +
        'Retourne un JSON { "fr": "...", "en": "..." }.',
      user: `Informations étudiant :\n${context}\n\nModèle à personnaliser :\n${dto.templateBody}`,
      maxTokens: 1500,
      fallback: { fr: dto.templateBody, en: dto.templateBody },
    });

    return result.data;
  }

  // ── 3. Interview simulator ──────────────────────────────────────────────────

  async getInterviewQuestions(
    dto: InterviewQuestionsDto,
  ): Promise<{ questions: string[] }> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    const en = dto.language === 'en';
    const typeLabel = {
      visa: en ? 'student visa interview' : 'entretien de visa étudiant',
      admission: en ? 'university admission interview' : 'entretien d\'admission universitaire',
      scholarship: en ? 'scholarship interview' : 'entretien de bourse d\'études',
    }[dto.type];

    const result = await this.llm.completeJson<{ questions: string[] }>({
      system: en
        ? `You are an experienced interviewer conducting a ${typeLabel}. ` +
          'Generate 6 realistic, progressively harder interview questions. ' +
          'Return JSON { "questions": ["...", ...] }.'
        : `Tu es un examinateur expérimenté qui mène un ${typeLabel}. ` +
          'Génère 6 questions réalistes, de difficulté progressive. ' +
          'Retourne un JSON { "questions": ["...", ...] }.',
      user: [
        dto.fieldOfStudy ? `Domaine : ${dto.fieldOfStudy}` : '',
        dto.targetCountry ? `Pays : ${dto.targetCountry}` : '',
      ]
        .filter(Boolean)
        .join('\n'),
      maxTokens: 600,
      fallback: {
        questions: en
          ? [
              'Why did you choose this country for your studies?',
              'How will you finance your studies and living costs?',
              'What are your plans after graduation?',
              'Why this specific programme and university?',
              'What ties do you have to your home country?',
              'How does this fit your long-term career goals?',
            ]
          : [
              'Pourquoi avoir choisi ce pays pour vos études ?',
              'Comment financerez-vous vos études et votre séjour ?',
              'Quels sont vos projets après l\'obtention du diplôme ?',
              'Pourquoi ce programme et cette université précisément ?',
              'Quels liens conservez-vous avec votre pays d\'origine ?',
              'En quoi cela s\'inscrit-il dans votre projet professionnel ?',
            ],
      },
    });

    return result.data;
  }

  async evaluateInterviewAnswer(
    dto: InterviewFeedbackDto,
  ): Promise<InterviewFeedback> {
    if (!this.llm.isConfigured) {
      throw new ServiceUnavailableException('AI not configured.');
    }

    const en = dto.language === 'en';

    const result = await this.llm.completeJson<InterviewFeedback>({
      system: en
        ? 'You are a strict but supportive interview coach. Evaluate the candidate answer. ' +
          'Return JSON { "score": 0-100, "strengths": ["..."], "improvements": ["..."], "modelAnswer": "..." }.'
        : 'Tu es un coach d\'entretien exigeant mais bienveillant. Évalue la réponse du candidat. ' +
          'Retourne un JSON { "score": 0-100, "strengths": ["..."], "improvements": ["..."], "modelAnswer": "..." }.',
      user: `Question : ${dto.question}\n\nRéponse du candidat : ${dto.answer}`,
      maxTokens: 700,
      fallback: {
        score: 70,
        strengths: en ? ['Clear answer.'] : ['Réponse claire.'],
        improvements: en
          ? ['Add concrete examples.']
          : ['Ajoutez des exemples concrets.'],
        modelAnswer: '',
      },
    });

    return result.data;
  }
}
