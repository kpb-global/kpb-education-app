export type OrientationFieldMeta = {
  id: string;
  nameFr: string;
  nameEn: string;
  iaResilience: 'high' | 'medium' | 'low';
  sampleJobsFr: string[];
  sampleJobsEn: string[];
  partnerCountryIds: string[];
};

export const ORIENTATION_FIELDS: OrientationFieldMeta[] = [
  {
    id: 'd01',
    nameFr: 'Informatique & Intelligence Artificielle',
    nameEn: 'Computer Science & AI',
    iaResilience: 'high',
    sampleJobsFr: ['Développeur', 'Data engineer', 'Expert cybersécurité'],
    sampleJobsEn: ['Developer', 'Data engineer', 'Cybersecurity specialist'],
    partnerCountryIds: ['fra', 'can', 'usa', 'deu'],
  },
  {
    id: 'd02',
    nameFr: 'Commerce & Management',
    nameEn: 'Business & Management',
    iaResilience: 'medium',
    sampleJobsFr: ['Consultant', 'Chef de produit', 'Entrepreneur'],
    sampleJobsEn: ['Consultant', 'Product manager', 'Entrepreneur'],
    partnerCountryIds: ['fra', 'mar', 'can', 'gbr'],
  },
  {
    id: 'd03',
    nameFr: 'Ingénierie & Sciences',
    nameEn: 'Engineering & Sciences',
    iaResilience: 'high',
    sampleJobsFr: ['Ingénieur', 'Chercheur R&D', 'Architecte solutions'],
    sampleJobsEn: ['Engineer', 'R&D researcher', 'Solutions architect'],
    partnerCountryIds: ['deu', 'fra', 'can', 'tur'],
  },
  {
    id: 'd04',
    nameFr: 'Santé & Sciences de la Vie',
    nameEn: 'Health & Life Sciences',
    iaResilience: 'high',
    sampleJobsFr: ['Médecin', 'Infirmier spécialisé', 'Pharmacien'],
    sampleJobsEn: ['Doctor', 'Specialized nurse', 'Pharmacist'],
    partnerCountryIds: ['fra', 'mar', 'tur', 'can'],
  },
  {
    id: 'd05',
    nameFr: 'Architecture & BTP',
    nameEn: 'Architecture & Construction',
    iaResilience: 'medium',
    sampleJobsFr: ['Architecte', 'Chef de chantier', 'Urbaniste'],
    sampleJobsEn: ['Architect', 'Site manager', 'Urban planner'],
    partnerCountryIds: ['fra', 'deu', 'are', 'tur'],
  },
  {
    id: 'd06',
    nameFr: 'Design, Médias & Communication',
    nameEn: 'Design, Media & Communication',
    iaResilience: 'medium',
    sampleJobsFr: ['Designer UX', 'Réalisateur', 'Community manager'],
    sampleJobsEn: ['UX designer', 'Director', 'Community manager'],
    partnerCountryIds: ['fra', 'gbr', 'esp', 'can'],
  },
  {
    id: 'd07',
    nameFr: 'Droit & Relations Internationales',
    nameEn: 'Law & International Relations',
    iaResilience: 'high',
    sampleJobsFr: ['Juriste', 'Diplomate', 'Analyste politique'],
    sampleJobsEn: ['Lawyer', 'Diplomat', 'Policy analyst'],
    partnerCountryIds: ['fra', 'gbr', 'usa', 'mar'],
  },
  {
    id: 'd08',
    nameFr: 'Environnement & Agriculture',
    nameEn: 'Environment & Agriculture',
    iaResilience: 'high',
    sampleJobsFr: ['Ingénieur agronome', 'Consultant RSE', 'Écologue'],
    sampleJobsEn: ['Agronomist', 'CSR consultant', 'Ecologist'],
    partnerCountryIds: ['can', 'fra', 'deu', 'mar'],
  },
  {
    id: 'd09',
    nameFr: 'Sciences Humaines & Éducation',
    nameEn: 'Humanities & Education',
    iaResilience: 'medium',
    sampleJobsFr: ['Enseignant', 'Psychologue', 'Chercheur'],
    sampleJobsEn: ['Teacher', 'Psychologist', 'Researcher'],
    partnerCountryIds: ['fra', 'can', 'mar', 'gbr'],
  },
  {
    id: 'd10',
    nameFr: 'Hôtellerie & Tourisme',
    nameEn: 'Hospitality & Tourism',
    iaResilience: 'low',
    sampleJobsFr: ['Manager hôtelier', 'Chef de projet événementiel'],
    sampleJobsEn: ['Hotel manager', 'Event project manager'],
    partnerCountryIds: ['fra', 'mar', 'are', 'esp'],
  },
  {
    id: 'd11',
    nameFr: 'Arts & Culture',
    nameEn: 'Arts & Culture',
    iaResilience: 'medium',
    sampleJobsFr: ['Artiste', 'Conservateur', 'Producteur culturel'],
    sampleJobsEn: ['Artist', 'Curator', 'Cultural producer'],
    partnerCountryIds: ['fra', 'esp', 'gbr', 'usa'],
  },
  {
    id: 'd12',
    nameFr: 'Logistique & Supply Chain',
    nameEn: 'Logistics & Supply Chain',
    iaResilience: 'medium',
    sampleJobsFr: ['Supply chain manager', 'Responsable export'],
    sampleJobsEn: ['Supply chain manager', 'Export manager'],
    partnerCountryIds: ['mar', 'tur', 'deu', 'are'],
  },
];

export const ORIENTATION_FIELD_BY_ID = new Map(
  ORIENTATION_FIELDS.map((field) => [field.id, field]),
);
