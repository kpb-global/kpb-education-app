// ─────────────────────────────────────────────────────────────────────────────
// Correction ponctuelle des niveaux Mundiapolis.
//
// L'import du 16/09 a écrit quatre niveaux hors référentiel, faute de mieux
// dans le CSV source : `normalizeDegreeLevel` laisse passer TEL QUEL ce qu'il
// ne reconnaît pas, donc « Spécialité » et « Prépa » sont arrivés en production
// et s'affichent dans le filtre par niveau de l'app à côté de Bachelor et
// Master.
//
// Les niveaux ci-dessous ne sont PAS déduits : chacun vient d'une page de
// l'université, dont l'URL est reportée dans `sourceUrl` à l'écriture. Le CSV
// disait « Spécialité » ; Mundiapolis dit « Licence … Bac+3 », où « spécialité »
// désigne l'option AU SEIN de la licence, pas un diplôme postérieur. Ma lecture
// initiale penchait vers un niveau Master : elle était fausse.
// ─────────────────────────────────────────────────────────────────────────────

/// Niveaux acceptés par le référentiel, miroir de `normalizeDegreeLevel`.
export const REFERENTIAL_LEVELS = [
  'Bac+2',
  'Bachelor',
  'BBA',
  'Master',
  'MBA / DBA',
  'Doctorat',
] as const;

export type ReferentialLevel = (typeof REFERENTIAL_LEVELS)[number];

export interface LevelCorrection {
  /** Identifiant dérivé à l'import — stable, recalculable. */
  id: string;
  nameFr: string;
  /**
   * Valeur ACTUELLE attendue en base. L'écriture est conditionnée à elle :
   * si quelqu'un a corrigé la fiche entre-temps, le `WHERE` ne trouve rien et
   * on ne l'écrase pas.
   */
  from: string;
  to: ReferentialLevel;
  /** Durée à combler, seulement si la colonne est vide. */
  durationFr: string;
  sourceUrl: string;
}

export const MUNDIAPOLIS_LEVEL_CORRECTIONS: readonly LevelCorrection[] = [
  {
    id: 'partner-p-b79716315cec56d6',
    nameFr: 'Infirmier Polyvalent',
    from: 'Spécialité',
    to: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    sourceUrl:
      'https://www.mundiapolis.ma/ecole-metiers-sante/licence-soins-infirmiers-bac3-infirmier-polyvalent',
  },
  {
    id: 'partner-p-f47106c3aa675d91',
    nameFr: 'Anesthésie et Réanimation',
    from: 'Spécialité',
    to: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    sourceUrl:
      'https://www.mundiapolis.ma/ecole-metiers-sante/licence-soins-infirmiers-bac3-infirmier-anesthesie-reanimation',
  },
  {
    id: 'partner-p-18528b5ab3870496',
    nameFr: "Soins d'Urgences et Soins Intensifs",
    from: 'Spécialité',
    to: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    sourceUrl:
      'https://www.mundiapolis.ma/ecole-metiers-sante/licence-soins-infirmiers-bac3-soins-intensifs-soins-durgence',
  },
  {
    // Cycle préparatoire intégré de 2 ans, suivi de 3 ans de cycle ingénieur.
    // Ce n'est pas un diplôme : `Bac+2` est le seul palier du référentiel qui
    // décrive honnêtement où l'étudiant se trouve à la sortie.
    id: 'partner-p-6e9b344bb0c5c33b',
    nameFr: 'Classes préparatoires intégrées',
    from: 'Prépa',
    to: 'Bac+2',
    durationFr: '2 ans',
    sourceUrl: 'https://www.mundiapolis.ma/pole-ingenierie',
  },
];
