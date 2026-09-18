// ─────────────────────────────────────────────────────────────────────────────
// Comble les champs vides des deux établissements « seed », antérieurs à
// l'import partenaire du 16/09 : ESSEC et l'Université d'Ottawa n'avaient ni
// description ni lieu, et leur fiche s'ouvrait donc vide dans l'app.
//
// Les faits ci-dessous ne sont PAS écrits de mémoire :
//
// • ESSEC — vérifié sur essec.edu le 18/09/2026 : quatre campus (Paris La
//   Défense, Cergy, Rabat, Singapour). La mention de RABAT est délibérée. Une
//   première rédaction ne citait que la France et Singapour, ce qui, pour un
//   étudiant ouest-africain, passe sous silence le campus le plus accessible.
//
// • Université d'Ottawa — uottawa.ca refuse la récupération automatique (402) ;
//   les faits sont corroborés par U15 Canada (association des universités de
//   recherche) et Parcs Canada : fondée en 1848 sous le nom de Collège de
//   Bytown, plus grande université bilingue au monde, neuf facultés.
//
// `lastVerifiedAt` n'est volontairement PAS posée par le script : la source est
// inscrite, mais la vérification humaine reste due. Un script qui se déclare
// vérifié sortirait ces fiches de la file de contrôle sans que personne ne les
// ait regardées — même raisonnement que pour les niveaux Mundiapolis.
// ─────────────────────────────────────────────────────────────────────────────

export interface SeedInstitutionFill {
  id: string;
  overviewFr: string;
  overviewEn: string;
  locationFr: string;
  locationEn: string;
  sourceUrl: string;
}

export const SEED_INSTITUTION_FILLS: readonly SeedInstitutionFill[] = [
  {
    id: 'essec',
    overviewFr:
      'Grande école de commerce française, membre de la Conférence des grandes écoles. ' +
      'Programmes en management, finance et entrepreneuriat, du Global BBA au doctorat. ' +
      'Quatre campus : Cergy et Paris La Défense en France, Rabat au Maroc, et Singapour.',
    overviewEn:
      'Leading French business school and member of the Conférence des grandes écoles. ' +
      'Programs in management, finance and entrepreneurship, from the Global BBA to the PhD. ' +
      'Four campuses: Cergy and Paris La Défense in France, Rabat in Morocco, and Singapore.',
    locationFr: 'Cergy, Île-de-France',
    locationEn: 'Cergy, Île-de-France',
    sourceUrl: 'https://www.essec.edu/fr/',
  },
  {
    id: 'uottawa',
    overviewFr:
      'Fondée en 1848, la plus grande université bilingue (français-anglais) au monde. ' +
      'Neuf facultés et plus de 550 programmes en sciences, génie, droit, santé et ' +
      'sciences sociales, au cœur de la capitale canadienne.',
    overviewEn:
      'Founded in 1848, the largest bilingual (French-English) university in the world. ' +
      'Nine faculties and over 550 programs in science, engineering, law, health and ' +
      'social sciences, in the heart of the Canadian capital.',
    locationFr: 'Ottawa, Ontario',
    locationEn: 'Ottawa, Ontario',
    sourceUrl: 'https://www.uottawa.ca/fr',
  },
];
