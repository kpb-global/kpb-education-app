export const mockCatalog = {
  fields: [
    {
      id: 'computer_science',
      name: { fr: 'Informatique', en: 'Computer Science' },
      description: {
        fr: 'Programmes orientés logiciel, data et produits numériques.',
        en: 'Programs focused on software, data, and digital products.',
      },
    },
    {
      id: 'business',
      name: { fr: 'Business', en: 'Business' },
      description: {
        fr: 'Gestion, stratégie, entrepreneuriat et finance.',
        en: 'Management, strategy, entrepreneurship, and finance.',
      },
    },
    {
      id: 'engineering',
      name: { fr: 'Ingénierie', en: 'Engineering' },
      description: {
        fr: 'Filières techniques pour concevoir et optimiser des systèmes.',
        en: 'Technical tracks for designing and optimizing systems.',
      },
    },
  ],
  countries: [
    {
      id: 'canada',
      name: { fr: 'Canada', en: 'Canada' },
      tuitionRange: { fr: '8 000 - 24 000 CAD/an', en: '8,000 - 24,000 CAD/year' },
      livingCostRange: { fr: '900 - 1 800 CAD/mois', en: '900 - 1,800 CAD/month' },
    },
    {
      id: 'france',
      name: { fr: 'France', en: 'France' },
      tuitionRange: { fr: '2 700 - 12 000 EUR/an', en: '2,700 - 12,000 EUR/year' },
      livingCostRange: { fr: '700 - 1 500 EUR/mois', en: '700 - 1,500 EUR/month' },
    },
    {
      id: 'uk',
      name: { fr: 'Royaume-Uni', en: 'United Kingdom' },
      tuitionRange: { fr: '12 000 - 28 000 GBP/an', en: '12,000 - 28,000 GBP/year' },
      livingCostRange: { fr: '900 - 1 900 GBP/mois', en: '900 - 1,900 GBP/month' },
    },
  ],
  institutions: [
    {
      id: 'uottawa',
      name: { fr: "Université d'Ottawa", en: 'University of Ottawa' },
      countryId: 'canada',
      levels: ['Bachelor', 'Master'],
      partner: true,
    },
    {
      id: 'essec',
      name: { fr: 'ESSEC Business School', en: 'ESSEC Business School' },
      countryId: 'france',
      levels: ['Master'],
      partner: false,
    },
  ],
  programs: [
    {
      id: 'uottawa-cs',
      institutionId: 'uottawa',
      countryId: 'canada',
      fieldId: 'computer_science',
      name: { fr: 'Bachelor en informatique', en: 'Bachelor in Computer Science' },
      level: { fr: 'Licence', en: 'Bachelor' },
    },
    {
      id: 'essec-mim',
      institutionId: 'essec',
      countryId: 'france',
      fieldId: 'business',
      name: { fr: 'Master in Management', en: 'Master in Management' },
      level: { fr: 'Master', en: 'Master' },
    },
  ],
  scholarships: [
    {
      id: 'canada_future',
      name: { fr: 'Canada Future Leaders', en: 'Canada Future Leaders' },
      countryId: 'canada',
      levelEligible: { fr: 'Licence / Master', en: 'Bachelor / Master' },
      typeOfFunding: { fr: 'Partielle', en: 'Partial' },
      deadlineLabel: { fr: 'Mai 2026', en: 'May 2026' },
    },
    {
      id: 'france_excellence',
      name: { fr: 'France Excellence', en: 'France Excellence' },
      countryId: 'france',
      levelEligible: { fr: 'Master', en: 'Master' },
      typeOfFunding: { fr: 'Complète', en: 'Full' },
      deadlineLabel: { fr: 'Juin 2026', en: 'June 2026' },
    },
  ],
};
