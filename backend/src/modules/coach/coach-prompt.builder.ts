export type CoachLanguage = 'fr' | 'en';

type CoachProfileContext = {
  fullName?: string;
  currentLevel?: string;
  targetCountryIds?: string[];
  monthlyBudgetEur?: number;
  openCases?: string[];
  /// Verified catalog facts retrieved for this question (RAG). When present,
  /// the model must use ONLY these for any figure/date/eligibility claim.
  verifiedContext?: string;
  /// Student's UI / preferred language. The coach must answer in this language
  /// so Anglophone students are not served French (and vice-versa).
  language?: CoachLanguage;
};

/// Normalize an arbitrary locale-ish string ('en', 'en_US', 'EN', …) to a
/// supported coach language, defaulting to French.
export function resolveCoachLanguage(raw?: string | null): CoachLanguage {
  return String(raw ?? '').trim().toLowerCase().startsWith('en') ? 'en' : 'fr';
}

/// Pseudonymize the monthly budget into a coarse range before it leaves the
/// server for the LLM. We never send the exact euro figure (a re-identifying
/// data point); a bucket is enough for budget-aware guidance.
export function budgetBucket(
  eur: number | undefined,
  lang: CoachLanguage,
): string {
  if (!eur || eur <= 0) return lang === 'en' ? 'not specified' : 'non renseigné';
  let range: string;
  if (eur < 500) range = '< 500';
  else if (eur < 1000) range = '500–1000';
  else if (eur < 2000) range = '1000–2000';
  else range = '> 2000';
  return lang === 'en' ? `${range} €/month (range)` : `${range} €/mois (tranche)`;
}

/// Output guardrail: returns a localized caveat to append when the reply
/// states a concrete figure (currency amount or percentage) but NO verified
/// context grounded it. Conservative by design — only fires when grounding was
/// entirely absent, so it never second-guesses a properly-sourced figure.
export function unsourcedFigureCaveat(
  reply: string,
  verifiedContext: string,
  lang: CoachLanguage,
): string | null {
  if ((verifiedContext ?? '').trim().length > 0) return null;
  const hasFigure =
    /(€|\$|£)\s?\d|\d[\d  .,]*\s?(€|\$|£|eur|usd|cad|gbp|%)/i.test(reply);
  if (!hasFigure) return null;
  return lang === 'en'
    ? '\n\n⚠️ The figures above are not from the verified KPB catalogue — confirm them with a KPB advisor.'
    : '\n\n⚠️ Les chiffres ci-dessus ne proviennent pas du catalogue vérifié KPB — confirme-les avec un conseiller KPB.';
}

export function buildCoachSystemPrompt(profile: CoachProfileContext): string {
  const lang: CoachLanguage = profile.language === 'en' ? 'en' : 'fr';
  const verified = profile.verifiedContext?.trim();
  const hasVerified = !!verified && verified.length > 0;

  if (lang === 'en') {
    const countries =
      (profile.targetCountryIds ?? []).join(', ') || 'not specified';
    const budget = budgetBucket(profile.monthlyBudgetEur, 'en');
    const cases = (profile.openCases ?? []).join(', ') || 'none';

    // PII minimization: the student's name is deliberately NOT sent to the LLM.
    return `You are KPB Coach, a study-abroad guidance assistant for African students.
Student context (pseudonymized — no name is shared):
- Level: ${profile.currentLevel ?? 'not specified'}
- Target countries: ${countries}
- Indicative budget: ${budget}
- Open cases: ${cases}

VERIFIED CONTEXT (KPB catalogue data):
${hasVerified ? verified : 'No verified data available for this question.'}

Rules:
- Reply in English, max 4 sentences.
- For ANY figure or date (fees, amounts, deadlines, eligibility conditions), use ONLY the VERIFIED CONTEXT above and cite the source in brackets (e.g. [source: ...]). NEVER invent a figure, a date or a condition.
- If the requested information is not in the VERIFIED CONTEXT, say so plainly and invite the student to confirm with a KPB advisor — do not guess.
- Recommend only the 9 KPB destinations (France, Canada, USA, UK, Germany, Spain, Morocco, Turkey, UAE).
- Mention KPB partner schools when relevant.
- No personalized legal/financial advice.
- If the student is in distress, point them to a human KPB advisor.
- End with: "For important decisions, contact a KPB advisor."`;
  }

  const countries =
    (profile.targetCountryIds ?? []).join(', ') || 'non renseignés';
  const budget = budgetBucket(profile.monthlyBudgetEur, 'fr');
  const cases = (profile.openCases ?? []).join(', ') || 'aucune';

  // Minimisation : le nom de l'étudiant n'est volontairement PAS envoyé au LLM.
  return `Tu es Coach KPB, assistant d'orientation pour étudiants francophones d'Afrique.
Contexte étudiant (pseudonymisé — aucun nom n'est transmis):
- Niveau: ${profile.currentLevel ?? 'non renseigné'}
- Pays visés: ${countries}
- Budget indicatif: ${budget}
- Demandes en cours: ${cases}

CONTEXTE VÉRIFIÉ (données du catalogue KPB) :
${hasVerified ? verified : 'Aucune donnée vérifiée disponible pour cette question.'}

Règles:
- Réponds en français, max 4 phrases.
- Pour TOUT fait chiffré ou daté (frais, montant, date limite, condition d'éligibilité), utilise UNIQUEMENT le CONTEXTE VÉRIFIÉ ci-dessus, et cite la source entre crochets (ex. [source: ...]). N'invente JAMAIS un chiffre, une date ou une condition.
- Si l'information demandée n'est pas dans le CONTEXTE VÉRIFIÉ, dis-le franchement et invite à confirmer avec un conseiller KPB — ne devine pas.
- Recommande uniquement les 9 destinations KPB (France, Canada, USA, UK, Allemagne, Espagne, Maroc, Turquie, EAU).
- Mentionne les écoles partenaires KPB quand pertinent.
- Pas de conseil juridique/financier personnalisé.
- En cas de détresse, oriente vers un conseiller humain KPB.
- Termine par: "Pour les décisions importantes, contacte un conseiller KPB."`;
}

export function buildCoachSuggestions(profile: CoachProfileContext): string[] {
  const lang: CoachLanguage = profile.language === 'en' ? 'en' : 'fr';
  const targets = profile.targetCountryIds ?? [];

  if (lang === 'en') {
    const suggestions = [
      'Which schools fit my budget?',
      'How do I apply to private schools in France?',
      'Which countries for computer science?',
    ];
    if (targets.includes('fra')) {
      suggestions[1] = 'OMNES vs ICN: which should I choose?';
    }
    return suggestions;
  }

  const suggestions = [
    'Quelles écoles pour mon budget ?',
    'Comment postuler en France privé ?',
    'Quels pays pour l’informatique ?',
  ];
  if (targets.includes('fra')) {
    suggestions[1] = 'OMNES vs ICN : que choisir ?';
  }
  return suggestions;
}
