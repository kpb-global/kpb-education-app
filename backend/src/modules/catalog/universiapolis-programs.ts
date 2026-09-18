// ─────────────────────────────────────────────────────────────────────────────
// Universiapolis — Université Internationale d'Agadir.
//
// Écartée de l'import CSV du 16/09, et pour une bonne raison : ses 15 lignes
// ne sont pas 15 formations mais des ANNÉES D'ENTRÉE tarifées. Le CSV porte
// « 1re année », « 2e année »… dans la colonne Niveau — des années d'étude, pas
// des diplômes. `normalizeDegreeLevel` les aurait laissées passer telles quelles
// et l'app aurait affiché « 2e année » comme un niveau, avec le même programme
// répété jusqu'à quatre fois.
//
// Cette table est le résultat du regroupement : UN cursus, UN diplôme. Les
// niveaux viennent des pages de l'université, pas d'une déduction — le CSV ne
// contient tout simplement pas l'information.
//
// Deux corrections que le CSV portait :
//
//  • « SUP'H COM — Droit privé » attribue le droit à Sup'H.Com. Ce sont DEUX
//    établissements distincts du groupe : Sup'H.Com fait communication, tourisme
//    et hôtellerie ; Sup'H.Droit fait le droit. Le libellé est rectifié.
//  • « SUP'H COM — Droit privé » (2e, 3e année) et « SUP'H COM — Droit »
//    (4e année) sont le MÊME cursus sous deux noms : ils fusionnent.
// ─────────────────────────────────────────────────────────────────────────────

export const UNIVERSIAPOLIS_INSTITUTION = {
  // Identifiant fixé : `INSTITUTION_RATES` (tuition-eur.ts) y rattache déjà le
  // taux dirham sourcé sur les fiches « Coût des études » de l'université. Le
  // changer ici couperait silencieusement la conversion en euros.
  id: 'partner-universiapolis',
  nameFr: "Universiapolis — Université Internationale d'Agadir",
  nameEn: 'Universiapolis — International University of Agadir',
  countryId: 'mar',
  locationFr: 'Agadir',
  overviewFr:
    "Université internationale privée à Agadir regroupant cinq établissements : ingénierie (École Polytechnique), management (ISIAM), droit (Sup'H.Droit), tourisme et communication (Sup'H.Com) et santé (UniversiaHealth). Diplômes reconnus par l'État.",
  intakePeriods: ['Septembre'],
  isPartner: true,
} as const;

export interface UniversiapolisProgram {
  /** Suffixe stable ; l'identifiant complet est `partner-p-<sha256(...)>`. */
  key: string;
  nameFr: string;
  fieldId: string;
  levelFr: 'Bac+2' | 'Bachelor' | 'Master';
  durationFr: string;
  /**
   * TOTAL ANNUEL du CSV — inscription, scolarité, documentation et assurance
   * comprises — et non la seule scolarité que compare la première page du PDF
   * tarifaire. C'est ce que l'étudiant paie réellement, donc le bon plancher
   * pour un classement par budget. Quand un cursus couvre plusieurs années au
   * tarif différent, on retient la MOINS chère : c'est un plancher.
   */
  tuitionFr: string;
  /** Page de l'université qui établit le diplôme. */
  sourceUrl: string;
  /** Années d'entrée que cette fiche regroupe — trace du regroupement. */
  mergedYears: string[];
}

export const UNIVERSIAPOLIS_PROGRAMS: readonly UniversiapolisProgram[] = [
  {
    key: 'epp-tronc-commun',
    nameFr: 'École Polytechnique — Cycle préparatoire intégré',
    fieldId: 'd03',
    // Le cycle préparatoire ne délivre pas de diplôme d'ingénieur : il ouvre
    // sur le cycle ingénieur. `Bac+2` décrit honnêtement où l'étudiant se
    // trouve à sa sortie.
    levelFr: 'Bac+2',
    durationFr: '2 ans',
    tuitionFr: '57 900 DH/an',
    sourceUrl: 'https://e-polytechnique.ma/formations/',
    mergedYears: ['1re année', '2e année'],
  },
  {
    key: 'epp-ingenierie',
    nameFr: "École Polytechnique — Diplôme d'ingénieur",
    fieldId: 'd03',
    // Formation Bac+5, reconnue équivalente au diplôme d'ingénieur d'État.
    levelFr: 'Master',
    durationFr: '3 ans après le cycle préparatoire (Bac+5)',
    tuitionFr: '58 800 DH/an',
    sourceUrl: 'https://e-polytechnique.ma/formations/cycle-ingenieur/',
    mergedYears: ['3e année', '4e année'],
  },
  {
    key: 'isiam-management',
    nameFr: 'ISIAM Business School — Management et commerce',
    fieldId: 'd02',
    // ISIAM délivre Licence (Bac+3) ET Master (Bac+5). Le CSV ne dit pas
    // quelles années relèvent du Master : on retient le diplôme d'entrée, la
    // Licence, et l'enrichissement se fera depuis la page Catalogue.
    levelFr: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    tuitionFr: '49 900 DH/an',
    sourceUrl: 'https://universiapolis.ma/formation/programmes/business-school/',
    mergedYears: ['1re année', '2e année', '3e année', '4e année'],
  },
  {
    key: 'suphdroit-droit-prive',
    // Rectifié : le CSV attribuait ce cursus à Sup'H.Com.
    nameFr: "Sup'H.Droit — Droit privé",
    fieldId: 'd07',
    levelFr: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    tuitionFr: '46 200 DH/an',
    sourceUrl:
      'https://universiapolis.ma/etablissements/ecole-de-droit-des-sciences-politiques-et-humaines/',
    mergedYears: ['2e année', '3e année', '4e année'],
  },
  {
    key: 'suphcom-tourisme',
    nameFr: "Sup'H.Com — Tourisme et Communication",
    fieldId: 'd10',
    levelFr: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    tuitionFr: '43 700 DH/an',
    sourceUrl: 'https://suphcom.ma/',
    mergedYears: ['2e année', '3e année', '4e année'],
  },
  {
    key: 'universiahealth-infirmier',
    nameFr: 'UniversiaHealth — Infirmier polyvalent',
    fieldId: 'd04',
    levelFr: 'Bachelor',
    durationFr: '3 ans (Bac+3)',
    tuitionFr: '43 400 DH/an',
    sourceUrl: 'https://universiapolis.ma/programmes/infirmier-polyvalent/',
    mergedYears: ['1re année'],
  },
];
