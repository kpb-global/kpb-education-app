export interface SeedInstitutionFill {
  id: string;
  overviewFr: string;
  overviewEn: string;
  locationFr: string;
  locationEn: string;
}

export const SEED_INSTITUTION_FILLS: readonly SeedInstitutionFill[] = [
  {
    id: 'essec',
    overviewFr:
      'Grande école de commerce française, membre de la Conférence des grandes écoles. ' +
      'Programmes en management, finance et entrepreneuriat, avec un réseau de campus en France et à Singapour.',
    overviewEn:
      'Leading French business school and member of the Conférence des grandes écoles. ' +
      'Programs in management, finance and entrepreneurship, with campuses in France and Singapore.',
    locationFr: 'Cergy, Île-de-France',
    locationEn: 'Cergy, Île-de-France',
  },
  {
    id: 'uottawa',
    overviewFr:
      "Université bilingue (français-anglais) fondée en 1848, la plus grande université bilingue au monde. " +
      "Programmes variés en sciences, génie, droit et sciences sociales au cœur de la capitale canadienne.",
    overviewEn:
      'Bilingual (French-English) university founded in 1848, the largest bilingual university in the world. ' +
      'Diverse programs in science, engineering, law and social sciences in the heart of the Canadian capital.',
    locationFr: 'Ottawa, Ontario',
    locationEn: 'Ottawa, Ontario',
  },
];
