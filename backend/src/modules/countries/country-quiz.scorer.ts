import type { EligibilityVerdictKey } from './country-quiz.types';

function pick(
  answers: Record<string, string>,
  key: string,
): string | undefined {
  return answers[key]?.trim();
}

function inValues(value: string | undefined, allowed: string[]): boolean {
  return value != null && allowed.includes(value);
}

export function scoreCountryQuiz(
  countryId: string,
  answers: Record<string, string>,
): EligibilityVerdictKey {
  switch (countryId) {
    case 'fra':
      return scoreFrance(answers);
    case 'deu':
      return scoreGermany(answers);
    case 'usa':
      return scoreUsa(answers);
    case 'can':
      return scoreCanada(answers);
    case 'mar':
      return scoreMorocco(answers);
    case 'tur':
      return scoreTurkey(answers);
    case 'are':
      return scoreUae(answers);
    case 'gbr':
      return scoreUk(answers);
    case 'esp':
      return scoreSpain(answers);
    default:
      return 'eligible_with_conditions';
  }
}

function scoreFrance(answers: Record<string, string>): EligibilityVerdictKey {
  const diploma = pick(answers, 'q2_diploma');
  const french = pick(answers, 'q5_french_level');
  const funds = pick(answers, 'q7_financial_proof');
  const visa = pick(answers, 'q6_visa_history');

  if (diploma === 'no') return 'not_eligible';
  if (french === 'basic' && funds === 'no') return 'not_eligible';
  if (
    inValues(diploma, ['yes_obtained', 'yes_this_year']) &&
    inValues(french, ['native', 'fluent', 'intermediate']) &&
    funds !== 'no' &&
    visa !== 'yes_recent'
  ) {
    return 'eligible';
  }
  if (
    inValues(diploma, ['yes_obtained', 'yes_this_year']) &&
    (french === 'basic' || funds === 'no' || visa === 'yes_recent')
  ) {
    return 'eligible_with_conditions';
  }
  return 'eligible_with_conditions';
}

function scoreGermany(answers: Record<string, string>): EligibilityVerdictKey {
  const german = pick(answers, 'q2_german_level');
  const track = pick(answers, 'q4_language_track');
  const blocked = pick(answers, 'q5_blocked_account');

  if (blocked === 'no' && track === 'no_only_english') return 'not_eligible';
  if (blocked === 'no') return 'not_eligible';
  if (track === 'yes_partial' && blocked === 'yes_difficult') {
    return 'eligible_with_conditions';
  }
  if (
    german === 'advanced' ||
    (track != null && track !== 'no_only_english')
  ) {
    return 'eligible';
  }
  return 'eligible_with_conditions';
}

function scoreUsa(answers: Record<string, string>): EligibilityVerdictKey {
  const english = pick(answers, 'q3_english_level');
  const budget = pick(answers, 'q4_budget');
  const diploma = pick(answers, 'q2_diploma');

  if (diploma === 'no') return 'not_eligible';
  if (budget === 'low') return 'not_eligible';
  if (english === 'advanced' && budget !== 'low') return 'eligible';
  if (english === 'intermediate' || budget === 'medium') {
    return 'eligible_with_conditions';
  }
  return 'eligible_with_conditions';
}

function scoreCanada(answers: Record<string, string>): EligibilityVerdictKey {
  const diploma = pick(answers, 'q2_diploma');
  const english = pick(answers, 'q3_english_level');
  const budget = pick(answers, 'q4_budget');

  if (diploma === 'no') return 'not_eligible';
  if (budget === 'low') return 'not_eligible';
  if (
    inValues(diploma, ['yes_obtained', 'yes_this_year']) &&
    inValues(english, ['advanced', 'intermediate']) &&
    budget !== 'low'
  ) {
    return 'eligible';
  }
  return 'eligible_with_conditions';
}

function scoreMorocco(answers: Record<string, string>): EligibilityVerdictKey {
  const diploma = pick(answers, 'q2_diploma');
  const french = pick(answers, 'q3_french_level');
  const budget = pick(answers, 'q4_budget');

  if (diploma === 'no' && budget === 'low') return 'not_eligible';
  if (
    inValues(diploma, ['yes_obtained', 'yes_this_year']) &&
    inValues(french, ['native', 'fluent', 'intermediate'])
  ) {
    return 'eligible';
  }
  if (french === 'basic' || budget === 'low') {
    return 'eligible_with_conditions';
  }
  return 'eligible_with_conditions';
}

function scoreTurkey(answers: Record<string, string>): EligibilityVerdictKey {
  const english = pick(answers, 'q3_english_level');
  const budget = pick(answers, 'q4_budget');
  const diploma = pick(answers, 'q2_diploma');

  if (diploma === 'no') return 'not_eligible';
  if (budget === 'low') return 'eligible_with_conditions';
  if (inValues(english, ['advanced', 'intermediate']) && budget !== 'low') {
    return 'eligible';
  }
  return 'eligible_with_conditions';
}

function scoreUae(answers: Record<string, string>): EligibilityVerdictKey {
  const english = pick(answers, 'q3_english_level');
  const budget = pick(answers, 'q4_budget');

  if (budget === 'low') return 'not_eligible';
  if (english === 'advanced' && budget !== 'low') return 'eligible';
  return 'eligible_with_conditions';
}

function scoreUk(answers: Record<string, string>): EligibilityVerdictKey {
  const english = pick(answers, 'q3_english_level');
  const budget = pick(answers, 'q4_budget');
  const diploma = pick(answers, 'q2_diploma');

  if (diploma === 'no') return 'not_eligible';
  if (budget === 'low') return 'not_eligible';
  if (english === 'advanced') return 'eligible';
  return 'eligible_with_conditions';
}

function scoreSpain(answers: Record<string, string>): EligibilityVerdictKey {
  const english = pick(answers, 'q3_english_level');
  const budget = pick(answers, 'q4_budget');
  const diploma = pick(answers, 'q2_diploma');

  if (diploma === 'no') return 'not_eligible';
  if (inValues(english, ['advanced', 'intermediate']) && budget !== 'low') {
    return 'eligible';
  }
  if (budget === 'low' || english === 'basic') {
    return 'eligible_with_conditions';
  }
  return 'eligible_with_conditions';
}
