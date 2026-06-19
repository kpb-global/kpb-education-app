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
      // ── Flagship scholarship highlighted at MVP launch (Canada) ───────────
      id: 'mccall_macbain',
      name: {
        fr: 'Bourse McCall MacBain (Université McGill)',
        en: 'McCall MacBain Scholarship (McGill University)',
      },
      countryId: 'canada',
      countryName: { fr: 'Canada', en: 'Canada' },
      levelEligible: {
        fr: 'Master / Études professionnelles',
        en: "Master's / Professional studies",
      },
      typeOfFunding: { fr: 'Complète', en: 'Full' },
      fundingType: 'fully_funded',
      deadlineLabel: { fr: 'Août 2026', en: 'August 2026' },
      description: {
        fr: "La bourse McCall MacBain finance intégralement un master à l'Université McGill (Montréal) et y ajoute un programme de leadership, de mentorat et de développement personnel. C'est la bourse phare mise en avant au lancement de KPB pour le Canada.",
        en: 'The McCall MacBain Scholarship fully funds a master’s degree at McGill University (Montreal) and adds a leadership, mentorship and personal-development program. It is the flagship scholarship featured at KPB’s launch for Canada.',
      },
      advantages: [
        {
          fr: 'Frais de scolarité et frais obligatoires entièrement couverts',
          en: 'Full tuition and mandatory fees covered',
        },
        {
          fr: 'Allocation de subsistance mensuelle',
          en: 'Monthly living stipend',
        },
        {
          fr: 'Programme de leadership, mentorat et coaching',
          en: 'Leadership, mentorship and coaching program',
        },
        {
          fr: 'Financement de la réinstallation et des voyages du programme',
          en: 'Relocation and program travel funding',
        },
      ],
      eligibility: [
        {
          fr: 'Diplôme de premier cycle obtenu (ou en cours) reconnu',
          en: 'Completed (or final-year) recognised undergraduate degree',
        },
        {
          fr: 'Admissible à un programme de master éligible à McGill',
          en: 'Eligible for a qualifying McGill master’s program',
        },
        {
          fr: 'Leadership démontré et engagement communautaire',
          en: 'Demonstrated leadership and community engagement',
        },
      ],
      keyRequirements: [
        {
          fr: 'Candidature en ligne avec essais',
          en: 'Online application with essays',
        },
        {
          fr: 'Lettres de référence',
          en: 'Reference letters',
        },
        {
          fr: 'Entretiens régionaux et finalistes',
          en: 'Regional and finalist interviews',
        },
      ],
      relatedFieldIds: [],
      baseMatch: 60,
      applicationUrl: 'https://mccallmacbainscholars.org/',
      sourceUrl: 'https://mccallmacbainscholars.org/',
      tags: ['flagship', 'fully_funded', 'canada', 'mcgill'],
      isActive: true,
    },
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
    {
      id: 'rhodes_oxford',
      name: {
        fr: "Bourse Rhodes (Université d'Oxford)",
        en: 'Rhodes Scholarship (University of Oxford)',
      },
      countryId: 'uk',
      countryName: { fr: 'Royaume-Uni', en: 'United Kingdom' },
      levelEligible: {
        fr: 'Master / MPhil / Doctorat (DPhil)',
        en: "Master's / MPhil / DPhil",
      },
      typeOfFunding: { fr: 'Complète', en: 'Full' },
      fundingType: 'fully_funded',
      deadlineLabel: { fr: 'Juin – août 2026 (selon le pays)', en: 'June – August 2026 (by country)' },
      description: {
        fr: "La bourse Rhodes finance intégralement des études supérieures à l'Université d'Oxford et s'adresse à des profils d'excellence académique alliant leadership et engagement. L'éligibilité dépend de la « constituency » (pays/région) du candidat.",
        en: 'The Rhodes Scholarship fully funds postgraduate study at the University of Oxford for outstanding students combining academic excellence with leadership and service. Eligibility depends on the candidate’s country/region constituency.',
      },
      advantages: [
        { fr: "Frais de scolarité d'Oxford entièrement couverts", en: 'Full University of Oxford tuition covered' },
        { fr: 'Allocation de subsistance annuelle (~£20 400)', en: 'Annual living stipend (~£20,400)' },
        { fr: 'Visa étudiant et surcharge santé (IHS) pris en charge', en: 'Student visa and health surcharge (IHS) covered' },
        { fr: "Deux billets d'avion aller-retour", en: 'Two return airfares' },
      ],
      eligibility: [
        { fr: "Avoir (ou être en train d'obtenir) une licence solide", en: 'Hold (or be completing) a strong undergraduate degree' },
        { fr: 'Avoir entre 18 et 23 ans (exceptions jusqu’à 27 ans)', en: 'Be aged 18–23 (exceptions up to 27)' },
        { fr: 'Excellence académique (mention équivalent First Class)', en: 'Academic excellence (First-Class-equivalent honours)' },
        { fr: "Maîtrise de l'anglais (IELTS/TOEFL si requis)", en: 'English proficiency (IELTS/TOEFL where required)' },
        { fr: "Être citoyen ou résident d'une constituency Rhodes éligible", en: 'Be a citizen or resident of an eligible Rhodes constituency' },
      ],
      keyRequirements: [
        { fr: 'Candidature en ligne avec déclaration personnelle', en: 'Online application with personal statement' },
        { fr: 'Lettres de référence', en: 'Reference letters' },
        { fr: 'Entretiens de sélection', en: 'Selection interviews' },
      ],
      relatedFieldIds: [],
      baseMatch: 25,
      applicationUrl: 'https://www.rhodeshouse.ox.ac.uk/scholarships/applications/',
      sourceUrl: 'https://www.mastere.tn/programme-de-bourses-rhodes-de-luniversite-doxford-2022/',
      tags: ['fully_funded', 'uk', 'oxford', 'flagship'],
      isActive: true,
    },
    {
      id: 'knight_hennessy_stanford',
      name: {
        fr: 'Bourse Knight-Hennessy (Université Stanford)',
        en: 'Knight-Hennessy Scholars (Stanford University)',
      },
      countryId: 'usa',
      countryName: { fr: 'États-Unis', en: 'United States' },
      levelEligible: {
        fr: 'Tout diplôme de cycle supérieur (Master, MBA, PhD, JD, MD…)',
        en: 'Any graduate degree (Master, MBA, PhD, JD, MD…)',
      },
      typeOfFunding: { fr: 'Complète', en: 'Full' },
      fundingType: 'fully_funded',
      deadlineLabel: { fr: 'Octobre 2026', en: 'October 2026' },
      description: {
        fr: "Knight-Hennessy finance intégralement (jusqu'à 3 ans) n'importe quel programme de cycle supérieur à Stanford, en plus d'un programme de leadership. Ouvert à toutes les nationalités, sans limite d'âge.",
        en: 'Knight-Hennessy fully funds (up to 3 years) any graduate program at Stanford plus a leadership development program. Open to all nationalities, with no age limit.',
      },
      advantages: [
        { fr: 'Frais de scolarité entièrement couverts', en: 'Full tuition covered' },
        { fr: 'Allocation de subsistance mensuelle', en: 'Monthly living stipend' },
        { fr: "Billet d'avion aller-retour annuel", en: 'Annual round-trip airfare' },
        { fr: 'Indemnité de réinstallation', en: 'Relocation allowance' },
      ],
      eligibility: [
        { fr: 'Licence obtenue en janvier 2020 ou après', en: "Bachelor's degree earned January 2020 or later" },
        { fr: 'Postuler en parallèle à un programme de cycle supérieur de Stanford', en: 'Apply simultaneously to a Stanford graduate program' },
        { fr: 'Ouvert à toutes les nationalités, sans limite d’âge', en: 'Open to all nationalities, no age limit' },
      ],
      keyRequirements: [
        { fr: 'Candidature en ligne Knight-Hennessy + essais', en: 'Online Knight-Hennessy application + essays' },
        { fr: 'Candidature simultanée au programme Stanford visé', en: 'Simultaneous application to the target Stanford program' },
        { fr: 'Lettres de recommandation', en: 'Letters of recommendation' },
      ],
      relatedFieldIds: [],
      baseMatch: 25,
      applicationUrl: 'https://apply.knight-hennessy.stanford.edu/apply/',
      sourceUrl: 'https://www.mastere.tn/bourse-knight-hennessy/',
      tags: ['fully_funded', 'usa', 'stanford', 'flagship'],
      isActive: true,
    },
    {
      id: 'helmut_schmidt_daad',
      name: {
        fr: 'Programme de bourses Helmut-Schmidt (DAAD)',
        en: 'Helmut-Schmidt Programme (DAAD)',
      },
      countryId: 'germany',
      countryName: { fr: 'Allemagne', en: 'Germany' },
      levelEligible: {
        fr: 'Master (politiques publiques / gouvernance)',
        en: "Master's (public policy / governance)",
      },
      typeOfFunding: { fr: 'Complète', en: 'Full' },
      fundingType: 'fully_funded',
      deadlineLabel: { fr: 'Juin – juillet 2026', en: 'June – July 2026' },
      description: {
        fr: "Le programme Helmut-Schmidt (DAAD) finance un master en politiques publiques et bonne gouvernance dans des universités allemandes partenaires. Il cible spécifiquement les ressortissants de pays en développement et émergents (liste DAC) — une excellente option pour les candidats africains.",
        en: 'The Helmut-Schmidt Programme (DAAD) funds a master’s in public policy and good governance at partner German universities. It specifically targets nationals of developing and emerging (DAC-listed) countries — a strong fit for African applicants.',
      },
      advantages: [
        { fr: 'Allocation mensuelle (~992 €) + frais de scolarité couverts', en: 'Monthly stipend (~€992) + tuition covered' },
        { fr: 'Assurances santé, accident et responsabilité civile', en: 'Health, accident and liability insurance' },
        { fr: "Cours d'allemand (jusqu'à 6 mois) et remboursement de voyage", en: 'German language course (up to 6 months) and travel reimbursement' },
        { fr: 'Allocations familiales possibles', en: 'Family allowances available' },
      ],
      eligibility: [
        { fr: 'Licence en sciences politiques, droit, économie ou administration publique (obtenue après janvier 2020)', en: "Bachelor's in political science, law, economics or public administration (earned after January 2020)" },
        { fr: 'Classé dans le premier tiers de sa promotion', en: 'Graduated in the top third of the class' },
        { fr: "Être ressortissant d'un pays en développement/émergent (liste DAC)", en: 'Be a national of a developing/emerging (DAC-listed) country' },
        { fr: 'Expérience pratique démontrée (emploi, stage, bénévolat, engagement civique)', en: 'Demonstrated practical experience (work, internship, volunteering, civic engagement)' },
      ],
      keyRequirements: [
        { fr: 'Candidature directe auprès d’une université partenaire', en: 'Apply directly to a partner university' },
        { fr: 'Au maximum 2 candidatures classées par ordre de préférence', en: 'At most 2 applications, ranked by preference' },
        { fr: 'Lettre de motivation et références', en: 'Motivation letter and references' },
      ],
      relatedFieldIds: ['d07'],
      baseMatch: 45,
      applicationUrl:
        'https://www2.daad.de/deutschland/stipendium/datenbank/en/21148-scholarship-database/?detail=50026397',
      sourceUrl:
        'https://www.mastere.tn/programme-de-bourses-helmut-schmidt-pour-etudier-en-allemagne/',
      tags: ['fully_funded', 'germany', 'daad', 'public_policy', 'africa'],
      isActive: true,
    },
  ],
};
