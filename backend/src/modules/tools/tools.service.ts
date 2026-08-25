// ─────────────────────────────────────────────────────────────────────────────
// ToolsService — student productivity tools powered by the LLM provider via LlmService.
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
  /// Degree the student is aiming for (e.g. "Master"), when declared.
  targetLevel?: string;
  /// Where the student currently lives — a recruiter reads mobility into it.
  countryOfResidence?: string;
  /// The student's own career-objective sentence, so the summary echoes it
  /// instead of inventing a different ambition.
  objective?: string;
}

export interface LetterPersonalizeDto {
  templateKey: string;
  templateBody: string;
  name: string;
  fieldOfStudy: string;
  targetCountry?: string;
  targetInstitution?: string;
  targetScholarship?: string;
  strengths?: string;
  keyEvent?: string;
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

    // The student's civil name is intentionally omitted. The DTO still
    // accepts `name` (the client form has a name field for the PDF) but it
    // must not reach the LLM provider — that was the leak the consent copy
    // used to deny.
    const context = [
      `Niveau d'études : ${dto.studyLevel}`,
      `Domaine : ${dto.fieldOfStudy}`,
      dto.countryOfResidence
        ? `Pays de résidence : ${dto.countryOfResidence}`
        : '',
      dto.targetCountry ? `Pays cible : ${dto.targetCountry}` : '',
      dto.targetLevel ? `Diplôme visé : ${dto.targetLevel}` : '',
      dto.skills?.length ? `Compétences : ${dto.skills.join(', ')}` : '',
      dto.languages?.length ? `Langues : ${dto.languages.join(', ')}` : '',
      dto.experience ? `Expérience : ${dto.experience}` : '',
      dto.objective ? `Objectif professionnel : ${dto.objective}` : '',
    ]
      .filter(Boolean)
      .join('\n');

    const result = await this.llm.completeJson<{ fr: string; en: string }>({
      system:
        'Tu es un expert en rédaction de CV pour étudiants internationaux. ' +
        'Rédige un paragraphe de présentation professionnelle (5-7 phrases) ' +
        'en français ET en anglais, percutant et adapté au recrutement international. ' +
        'Ne commence pas par "Je suis" / "I am". ' +
        // The client renders this text into a PDF whose built-in Helvetica has
        // no glyph above U+00FF: emoji and typographic dashes/quotes come out as
        // empty boxes. The client sanitises defensively, but not emitting them
        // in the first place keeps the on-screen preview and the PDF identical.
        'N\'utilise AUCUN emoji, pictogramme, puce décorative ni caractère ' +
        'spécial (pas de —, ’, “ ”, …) : uniquement du texte simple avec la ' +
        'ponctuation ASCII et les accents français. ' +
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

    // Civil name is accepted on the DTO (the letter PDF prints it) but must
    // not be copied into the LLM prompt — same IA-T2 rule as cv-summary.
    const context = [
      `Domaine : ${dto.fieldOfStudy}`,
      dto.targetCountry ? `Pays cible : ${dto.targetCountry}` : '',
      dto.targetInstitution ? `Établissement : ${dto.targetInstitution}` : '',
      dto.targetScholarship ? `Bourse visée : ${dto.targetScholarship}` : '',
      dto.strengths ? `Points forts : ${dto.strengths}` : '',
      dto.keyEvent ? `Événement marquant : ${dto.keyEvent}` : '',
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
