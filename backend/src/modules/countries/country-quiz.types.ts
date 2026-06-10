export type EligibilityVerdictKey =
  | 'eligible'
  | 'eligible_with_conditions'
  | 'not_eligible';

export interface QuizOption {
  value: string;
  labelFr: string;
  labelEn: string;
}

export interface QuizQuestion {
  id: string;
  textFr: string;
  textEn: string;
  type: 'single_select';
  options: QuizOption[];
}

export interface QuizVerdictCopy {
  titleFr: string;
  titleEn: string;
  messageFr: string;
  messageEn: string;
  ctaFr: string;
  ctaEn: string;
  alternativeCountryIds?: string[];
}

export interface CountryQuizDefinition {
  questions: QuizQuestion[];
  verdicts: Record<EligibilityVerdictKey, QuizVerdictCopy>;
}
