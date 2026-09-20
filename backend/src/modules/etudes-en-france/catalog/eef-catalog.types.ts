// ─────────────────────────────────────────────────────────────────────────────
// Catalogue « Études en France » — la forme des enregistrements versionnés.
//
// UN ENREGISTREMENT PORTE DES FAITS, PAS DE LA PROSE.
//
// Le pipeline des bourses versionne des fiches rédigées : 25 opportunités, un
// paragraphe chacune, écrites à la main. Ici on parle de ~7 000 formations dans
// 70 universités. Dupliquer la prose bilingue dans chaque ligne ferait
// 11 Mo de JSON dans un dépôt qui en pèse 15, et surtout rendrait toute
// correction de formulation illisible en revue — 7 000 lignes modifiées pour
// un mot.
//
// Donc : le fichier de données ne contient QUE ce qui varie d'une formation à
// l'autre et qui vient d'une source officielle (intitulé, niveau, ville, code
// de formation, lien vers la fiche). Les phrases — description, exigences
// d'admission, libellés bilingues de niveau et de durée — sont DÉRIVÉES par
// `eef-catalog.copy.ts`, une fois, testées une fois.
//
// Conséquence à connaître : on ne peut pas corriger la phrase d'une seule
// formation en éditant le JSON. C'est voulu. Une exception par formation est
// une affirmation non vérifiable à l'échelle ; elle se fait dans l'admin,
// ligne par ligne, avec un vérificateur nommé.
// ─────────────────────────────────────────────────────────────────────────────

/// Procédure d'admission applicable à un candidat résidant dans un pays
/// à procédure « Études en France ». Ce n'est PAS le type de formation :
/// une même licence se demande par DAP blanche en 1re année et par la
/// procédure EEF en 2e ou 3e année.
export type EefProcedureType =
  /// Demande d'admission préalable, dossier BLANC : 1re année de licence
  /// à l'université.
  | 'dap_blanche'
  /// Demande d'admission préalable, dossier JAUNE : 1re année en école
  /// nationale supérieure d'architecture. Même échéance, autre dossier.
  | 'dap_jaune'
  /// Procédure « Études en France » sur la plateforme Campus France :
  /// tout le reste de l'offre universitaire (BUT, L2, L3, master, doctorat).
  | 'eef'
  /// Parcoursup : le chemin des candidats résidant en France. Servi pour
  /// information — un candidat depuis Abidjan ne passe pas par là.
  | 'parcoursup'
  /// Hors du champ de la procédure (formation non ouverte aux candidatures
  /// internationales individuelles, ou procédure propre à l'établissement).
  | 'hors_eef';

export const EEF_PROCEDURE_TYPES: readonly EefProcedureType[] = [
  'dap_blanche',
  'dap_jaune',
  'eef',
  'parcoursup',
  'hors_eef',
];

/// Sélectivité déclarée par la source officielle. « selective » veut dire que
/// l'établissement arbitre entre les dossiers ; « non_selective » que la
/// capacité d'accueil est la seule limite. Aucune des deux ne dit « facile ».
export type EefSelectivity = 'selective' | 'non_selective';

/// Niveau du catalogue KPB. Volontairement identique au référentiel déjà servi
/// par `normalizeDegreeLevel` (admin-catalog), pas un second vocabulaire.
export type EefLevel = 'Bac+2' | 'Bachelor' | 'Master' | 'Doctorat';

/// Cycle d'entrée, plus fin que le niveau, parce que c'est lui qui décide de la
/// procédure et du calendrier.
export type EefCycle =
  | 'licence1'
  | 'licence2'
  | 'licence3'
  | 'licence_pro'
  | 'but1'
  | 'deust'
  | 'sante'
  | 'ingenieur'
  | 'master';

export const EEF_CYCLES: readonly EefCycle[] = [
  'licence1',
  'licence2',
  'licence3',
  'licence_pro',
  'but1',
  'deust',
  'sante',
  'ingenieur',
  'master',
];

/// Jeu de données d'origine. Sert au journal d'import et à la re-vérification :
/// savoir d'où vient une ligne, c'est savoir quoi re-interroger.
export type EefSourceDataset =
  | 'parcoursup'
  | 'trouver-mon-master'
  /// Diplômes réellement préparés dans les établissements publics (SISE).
  /// C'est la seule source ouverte qui atteste une 2e et une 3e année de
  /// licence : elle les liste parce que des étudiants y ÉTAIENT inscrits.
  | 'diplomes-prepares';

/// Une université publique (ou assimilée : les établissements expérimentaux
/// qui portent une typologie d'université au référentiel MESR).
export interface EefInstitutionRecord {
  /// Stable, dérivé de l'UAI. Un renommage d'université ne change pas l'id.
  readonly id: string;
  readonly uai: string;
  readonly nameFr: string;
  /// Le nom officiel anglais quand le MESR en publie un, sinon le nom français.
  /// Une université française est un nom propre : la traduire à la main serait
  /// inventer une raison sociale qui n'existe pas.
  readonly nameEn: string;
  readonly acronym: string | null;
  readonly city: string;
  readonly department: string;
  readonly region: string;
  readonly websiteUrl: string;
  /// Typologie MESR (« Université pluridisciplinaire avec santé »…). Null quand
  /// le référentiel ne la renseigne pas.
  readonly typology: string | null;
  /// Nombre d'étudiants inscrits, et l'année de ce comptage. Servir un effectif
  /// sans son année, c'est servir un chiffre qui vieillit sans le dire.
  readonly enrolment: { readonly count: number; readonly year: number } | null;
  /// La page officielle qui atteste des faits ci-dessus.
  readonly sourceUrl: string;
}

/// Une formation ouverte dans une de ces universités.
export interface EefProgramRecord {
  readonly id: string;
  readonly institutionId: string;
  readonly nameFr: string;
  readonly level: EefLevel;
  readonly cycle: EefCycle;
  /// Domaine du catalogue KPB (d01..d12).
  readonly fieldId: string;
  /// `true` quand le domaine vient du repli par famille et non d'un mot-clé de
  /// l'intitulé. Le compteur qui en découle est ce qui rend le classement
  /// critiquable au lieu d'être cru sur parole.
  readonly fieldIsFallback: boolean;
  readonly durationYears: number;
  readonly campusCity: string;
  readonly procedureType: EefProcedureType;
  readonly selectivity: EefSelectivity;
  /// Code de la formation chez l'opérateur (code Parcoursup `g_ta_cod`,
  /// identifiant national de mention TMM). C'est ce que l'étudiant retrouve
  /// sur le portail, et ce qui permet de re-vérifier la ligne.
  readonly formationCode: string;
  /// Parcours / mentions détaillées annoncés par la source, s'il y en a.
  readonly tracks: readonly string[];
  /// Master : licences conseillées à l'entrée, telles que publiées par
  /// l'établissement. C'est la seule exigence d'admission réellement
  /// nominative que les données ouvertes fournissent.
  readonly recommendedBachelors: readonly string[];
  /// Master : modalité de candidature publiée (« Dossier », « Entretien »…).
  readonly admissionModes: readonly string[];
  readonly dataset: EefSourceDataset;
  /// La fiche officielle de CETTE formation. Une ligne sans fiche ne passe pas
  /// le validateur.
  readonly sourceUrl: string;
}

/// Le fichier versionné d'une université : l'établissement et ses formations.
export interface EefUniversityFile {
  readonly institution: EefInstitutionRecord;
  readonly programs: readonly EefProgramRecord[];
}

/// Provenance d'un jeu de données, recopiée dans le manifeste. Sans licence
/// nommée, une donnée publique n'est pas réutilisable — c'est une affirmation
/// juridique, elle doit voyager avec la donnée.
export interface EefCatalogSource {
  readonly dataset: EefSourceDataset;
  readonly datasetId: string;
  readonly portal: string;
  readonly licence: string;
  readonly query: string;
  /// Millésime des données, tel que publié par le producteur.
  readonly vintage: string;
  /// Date de la collecte, ISO. Pas la date de vérification : personne n'a
  /// encore relu ces lignes quand elles arrivent.
  readonly fetchedAt: string;
  readonly rowCount: number;
}

export interface EefCatalogManifest {
  readonly catalogVersion: string;
  readonly generatedAt: string;
  readonly countryId: string;
  readonly institutionCount: number;
  readonly programCount: number;
  readonly sources: readonly EefCatalogSource[];
}

export interface EefCatalog {
  readonly manifest: EefCatalogManifest;
  readonly universities: readonly EefUniversityFile[];
}
