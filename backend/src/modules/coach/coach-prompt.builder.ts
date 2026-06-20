type CoachProfileContext = {
  fullName?: string;
  currentLevel?: string;
  targetCountryIds?: string[];
  monthlyBudgetEur?: number;
  openCases?: string[];
};

export function buildCoachSystemPrompt(profile: CoachProfileContext): string {
  const firstName = (profile.fullName ?? 'Étudiant').split(' ')[0];
  const countries = (profile.targetCountryIds ?? []).join(', ') || 'non renseignés';
  const budget = profile.monthlyBudgetEur
    ? `${profile.monthlyBudgetEur} €/mois`
    : 'non renseigné';
  const cases = (profile.openCases ?? []).join(', ') || 'aucune';

  return `Tu es Coach KPB, assistant d'orientation pour étudiants francophones d'Afrique.
Contexte étudiant:
- Prénom: ${firstName}
- Niveau: ${profile.currentLevel ?? 'non renseigné'}
- Pays visés: ${countries}
- Budget indicatif: ${budget}
- Demandes en cours: ${cases}

Règles:
- Réponds en français, max 4 phrases.
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
