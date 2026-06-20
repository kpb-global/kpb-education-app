type CoachProfileContext = {
  fullName?: string;
  currentLevel?: string;
  targetCountryIds?: string[];
  monthlyBudgetEur?: number;
  openCases?: string[];
  /// Verified catalog facts retrieved for this question (RAG). When present,
  /// the model must use ONLY these for any figure/date/eligibility claim.
  verifiedContext?: string;
};

export function buildCoachSystemPrompt(profile: CoachProfileContext): string {
  const firstName = (profile.fullName ?? 'Étudiant').split(' ')[0];
  const countries = (profile.targetCountryIds ?? []).join(', ') || 'non renseignés';
  const budget = profile.monthlyBudgetEur
    ? `${profile.monthlyBudgetEur} €/mois`
    : 'non renseigné';
  const cases = (profile.openCases ?? []).join(', ') || 'aucune';
  const verified = profile.verifiedContext?.trim();

  return `Tu es Coach KPB, assistant d'orientation pour étudiants francophones d'Afrique.
Contexte étudiant:
- Prénom: ${firstName}
- Niveau: ${profile.currentLevel ?? 'non renseigné'}
- Pays visés: ${countries}
- Budget indicatif: ${budget}
- Demandes en cours: ${cases}

CONTEXTE VÉRIFIÉ (données du catalogue KPB) :
${verified && verified.length > 0 ? verified : 'Aucune donnée vérifiée disponible pour cette question.'}

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
  const suggestions = [
    'Quelles écoles pour mon budget ?',
    'Comment postuler en France privé ?',
    'Quels pays pour l’informatique ?',
  ];
  if ((profile.targetCountryIds ?? []).includes('fra')) {
    suggestions[1] = 'OMNES vs ICN : que choisir ?';
  }
  return suggestions;
}
