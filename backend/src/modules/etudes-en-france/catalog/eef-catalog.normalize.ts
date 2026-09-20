// ─────────────────────────────────────────────────────────────────────────────
// Catalogue « Études en France » — les classements, et ce qu'ils avouent.
//
// Deux jeux de données publics décrivent l'offre des universités françaises
// avec DEUX vocabulaires qui ne se recoupent pas : Parcoursup parle de
// « filières » (« L1 - Droit », « BUT - Informatique »), Trouver Mon Master
// parle de « mentions » (« Droit des affaires »). Le catalogue KPB, lui, parle
// de douze domaines (d01..d12) et de quatre niveaux. Il faut donc traduire, et
// une traduction se trompe.
//
// CE QUI EST DÉLIBÉRÉ ICI
//
// 1. Les familles Parcoursup sont une table FERMÉE. Une famille inconnue
//    n'est pas devinée : la ligne est REJETÉE, avec son libellé, et le
//    générateur le compte. Un jeu de données qui change de vocabulaire doit
//    faire du bruit, pas produire 4 000 licences classées au hasard.
//
// 2. Le domaine, lui, ne peut pas être une table fermée : 600 intitulés
//    distincts, renouvelés chaque année. C'est donc une liste ORDONNÉE de
//    mots-clés, premier gagnant, avec un repli par grand domaine. Mais chaque
//    ligne sait si elle a été classée par mot-clé ou par repli
//    (`fieldIsFallback`), et le validateur plafonne le taux de repli. Un
//    classement qu'on ne peut pas critiquer est un classement qu'on croit
//    sur parole.
//
// 3. Une ligne qu'aucune règle ne classe est REJETÉE, pas rangée dans un
//    domaine « divers ». « DU - Diplôme d'Université » ne dit pas ce qu'on y
//    étudie ; le ranger quelque part serait inventer l'information que la
//    source refuse de donner.
// ─────────────────────────────────────────────────────────────────────────────
import { createHash } from 'node:crypto';

import type {
  EefCycle,
  EefLevel,
  EefProcedureType,
  EefSelectivity,
} from './eef-catalog.types';

/// Comparaison insensible aux accents, à la casse, aux apostrophes et aux
/// traits d'union. L'apostrophe compte : sans elle, « Réalisation
/// d'applications » ne rencontre jamais la règle « realisation d applications »
/// — c'est 23 formations d'informatique silencieusement non classées.
export function normalizeLabel(raw: string): string {
  const stripped = (raw ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/['’-]/g, ' ');
  return stripped.replace(/\s+/g, ' ').trim();
}

/**
 * Nom de ville lisible.
 *
 * L'adresse postale d'un établissement arrive en capitales et suffixée du
 * bureau distributeur : « RENNES CEDEX 7 », « PARIS CEDEX 05 ». Servi tel
 * quel, ce n'est pas une ville, c'est une ligne d'enveloppe — et l'étudiant
 * qui filtre sur « Rennes » ne la trouve pas.
 *
 * Les particules restent en minuscules (« Saint-Martin-d'Hères », « Le Havre »
 * garde sa majuscule en tête) : on retitre chaque segment séparé par un espace
 * ou un trait d'union, en laissant « de », « du », « des », « la », « le »,
 * « les », « sur », « sous », « en », « et », « lez », « lès » tels quels sauf
 * en tête.
 */
const CITY_PARTICLES = new Set([
  'de', 'du', 'des', 'la', 'le', 'les', 'sur', 'sous', 'en', 'et', 'lez',
  'les', 'aux', 'au', 'd', 'l',
]);

export function normalizeCityName(raw: string): string {
  const withoutCedex = (raw ?? '')
    .replace(/\bCEDEX\b.*$/i, '')
    .replace(/\s+/g, ' ')
    .trim();
  if (withoutCedex === '') return '';
  // Une chaîne déjà correctement capitalisée n'est pas retouchée : le
  // référentiel des établissements publie « Saint-Martin-d'Hères » proprement,
  // et lui appliquer notre propre casse ne ferait que créer des variantes.
  if (withoutCedex !== withoutCedex.toUpperCase()) return withoutCedex;
  let first = true;
  return withoutCedex
    .toLowerCase()
    .split(/([ -])/)
    .map((token) => {
      if (token === ' ' || token === '-') return token;
      const capitalized = token.charAt(0).toUpperCase() + token.slice(1);
      if (first) {
        first = false;
        return capitalized;
      }
      return CITY_PARTICLES.has(token) ? token : capitalized;
    })
    .join('');
}

/// Domaines du catalogue KPB, dans l'ordre d'évaluation. L'ordre est le
/// classement : « informatique médicale » doit tomber en santé avant de tomber
/// en informatique, donc d04 passe avant d01.
export const FIELD_KEYWORD_RULES: readonly {
  readonly fieldId: string;
  readonly keywords: readonly string[];
}[] = [
  {
    fieldId: 'd04', // Santé & Sciences Médicales
    keywords: [
      'pass', 'parcours d acces specifique sante', 'acces sante', 'medecine',
      'maieutique', 'sage femme', 'odontolog', 'pharmac', 'kinesitherap',
      'infirmi', 'sante publique', 'sciences pour la sante', 'biologie sante',
      'nutrition', 'audioprothes', 'opticien', 'orthopt', 'orthophon',
      'psychomotric', 'ergotherap', 'pedicure', 'podolog', 'soins',
      'medical', 'biomedical', 'sante et societe', 'cancerolog', 'neurosciences',
      'imagerie medicale', 'ethique medicale', 'vieillissement', 'handicap',
    ],
  },
  {
    fieldId: 'd01', // Informatique & IA
    keywords: [
      'informatique', 'intelligence artificielle', 'cybersecur',
      'reseaux et telecom', 'developpement web', 'genie logiciel',
      'science des donnees', 'data science', 'donnees massives', 'big data',
      'multimedia et de l internet', 'systemes d information', 'numerique',
      'miage', 'calcul haute performance', 'realite virtuelle', 'jeu video',
      'realisation d applications', 'deploiement d applications',
      'outils decisionnels', 'internet des objets', 'webmaster',
      'systemes communicants',
    ],
  },
  {
    fieldId: 'd03', // Finance, Banque & Comptabilité
    keywords: [
      'comptab', 'audit', 'finance', 'banque', 'assurance', 'actuar', 'fiscal',
      'controle de gestion', 'monnaie', 'expertise comptable', 'patrimoine',
    ],
  },
  {
    fieldId: 'd07', // Droit & Sciences Politiques
    keywords: [
      'droit', 'juridique', 'justice', 'notarial', 'science politique',
      'sciences politiques', 'relations internationales',
      'administration publique', 'carrieres juridiques', 'criminolog',
      'securite globale', 'gendarmerie', 'defense', 'etudes politiques',
    ],
  },
  {
    fieldId: 'd11', // Architecture, BTP & Urbanisme
    keywords: [
      'architecture', 'genie civil', 'btp', 'urbanis', 'travaux batiment',
      'batiment', 'construction', 'travaux publics', 'amenagement du territoire',
      'paysage', 'villes et territoires durables', 'genie urbain',
    ],
  },
  {
    fieldId: 'd08', // Énergie, Environnement & Développement durable
    keywords: [
      'environnement', 'ecolog', 'energie', 'developpement durable', 'climat',
      'biodiversite', 'geosciences', 'sciences de la terre', 'sciences marines',
      'sciences de la mer', 'oceanograph', 'hydrolog', 'risques et environnement',
      'eau', 'dechets', 'transition ecologique', 'maitrise de l energie',
      'genie de l environnement',
    ],
  },
  {
    fieldId: 'd10', // Agriculture & Agroalimentaire
    keywords: [
      'agronom', 'agricult', 'agroalimentaire', 'sciences de l aliment', 'agro',
      'viticult', 'vigne et du vin', 'horticult', 'forest', 'elevage',
      'veterinaire', 'aquacult',
    ],
  },
  {
    fieldId: 'd12', // Hôtellerie, Tourisme & Luxe
    keywords: [
      'tourisme', 'hotell', 'luxe', 'gastronom', 'oenolog', 'loisirs',
      'evenementiel',
    ],
  },
  {
    fieldId: 'd06', // Marketing, Communication & Arts
    keywords: [
      'marketing', 'communication', 'publicite', 'journalis', 'arts', 'art',
      'design', 'cinema', 'audiovisuel', 'musicolog', 'musique', 'theatre',
      'theatral', 'spectacle', 'patrimoine culturel', 'mediation culturelle',
      'edition', 'creation numerique', 'mode', 'photograph', 'danse',
      'strategie de marque', 'vente', 'commercialisation', 'commerce',
    ],
  },
  {
    fieldId: 'd09', // Éducation, Sciences Humaines & Langues
    keywords: [
      'enseignement', 'meef', 'professorat', 'education', 'langues', 'lettres',
      'linguistique', 'sciences du langage', 'traduction', 'interpretariat',
      'histoire', 'geographie', 'philosophie', 'sociolog', 'anthropolog',
      'ethnolog', 'psycholog', 'archeolog', 'civilisations', 'documentation',
      'bibliotheque', 'sciences humaines', 'sciences sociales', 'demograph',
      'religion', 'theolog', 'francais langue etrangere', 'etudes europeennes',
      'etudes culturelles', 'sciences de l education', 'humanites',
      'carrieres sociales', 'animation sociale', 'assistance sociale',
      'travail social', 'sanitaires et sociales', 'intervention sociale',
      'mediations citoyennes', 'cognitiv',
    ],
  },
  {
    fieldId: 'd02', // Gestion, Business & Management
    keywords: [
      'management', 'gestion', 'administration economique', 'entrepreneur',
      'ressources humaines', 'logistique', 'transport', 'achat', 'qualite',
      'economie', 'econometrie', 'supply chain', 'strategie', 'innovation',
      'affaires internationales', 'international business', 'business',
      'entreprise et association', 'echanges internationaux',
    ],
  },
  {
    fieldId: 'd05', // Ingénierie & Sciences Appliquées
    keywords: [
      'ingenieur', 'ingenierie', 'mecanique', 'electroniq', 'electricite',
      'electrotechniq', 'automatiq', 'robotiq', 'materiaux', 'physique',
      'chimie', 'mathematiq', 'statistiq', 'mesures physiques', 'productique',
      'maintenance', 'industri', 'aeronaut', 'spatial', 'nucleaire',
      'plasturgie', 'metrolog', 'instrumentation', 'sciences pour l ingenieur',
      'genie des procedes', 'genie industriel', 'conception et production durables',
      'synthese', 'optique', 'photonique', 'acoustique', 'textile', 'emballage',
      'systemes embarques', 'systemes complexes', 'sciences de la vie', 'biolog',
      'biotechnolog', 'microbiolog', 'biochimie', 'genetique',
      'sciences et technologies', 'sport', 'activites physiques', 'staps',
      'metiers de la forme',
    ],
  },
];

/// Repli par grand domaine universitaire, tel que Trouver Mon Master le publie.
/// Il ne sert que lorsqu'aucun mot-clé ne tombe, et il est compté à part.
export const FIELD_FALLBACK_BY_DOMAIN: Readonly<Record<string, string>> = {
  'arts, lettres, langues': 'd09',
  'sciences humaines et sociales': 'd09',
  'droit, economie, gestion': 'd02',
  'droit, economie, gestion et science politique': 'd07',
  'sciences, technologies, sante': 'd05',
  'sciences et technologies': 'd05',
  'sciences de la sante': 'd04',
  'sciences et techniques des activites physiques et sportives': 'd05',
  'sciences politiques et sociales': 'd07',
  'culture et communication': 'd06',
  'sciences de la vie et de l environnement': 'd08',
  'sciences de la mer et du littoral': 'd08',
};

export interface FieldResolution {
  readonly fieldId: string;
  readonly isFallback: boolean;
}

/**
 * Classe un intitulé dans un domaine du catalogue, ou renvoie `null` quand
 * aucune règle ne s'applique. `null` veut dire « la source ne dit pas ce qu'on
 * y étudie » — la ligne est alors écartée par le générateur, pas rangée
 * ailleurs.
 *
 * `domain` est le grand domaine publié par la source (TMM), utilisé en repli.
 * Quand il en liste plusieurs, séparés par `|`, seul le premier est lu : un
 * repli est déjà une approximation, en cumuler deux n'améliore rien.
 */
export function resolveFieldId(
  label: string,
  domain?: string | null,
): FieldResolution | null {
  const normalized = normalizeLabel(label);
  if (normalized !== '') {
    for (const rule of FIELD_KEYWORD_RULES) {
      for (const keyword of rule.keywords) {
        if (normalized.includes(keyword)) {
          return { fieldId: rule.fieldId, isFallback: false };
        }
      }
    }
  }
  const primaryDomain = normalizeLabel((domain ?? '').split('|')[0] ?? '');
  const fallback = FIELD_FALLBACK_BY_DOMAIN[primaryDomain];
  return fallback ? { fieldId: fallback, isFallback: true } : null;
}

/**
 * Rétablissement des accents sur un intitulé de diplôme.
 *
 * POURQUOI C'EST NÉCESSAIRE
 *
 * Le jeu des diplômes réellement préparés — seule source ouverte qui atteste
 * une 2e et une 3e année de licence — publie ses intitulés SANS ACCENTS :
 * « Langues, litteratures et civilisations etrangeres et regionales ».
 * Servi tel quel, c'est une faute d'orthographe sur 3 000 fiches.
 *
 * POURQUOI ON NE DEVINE PAS
 *
 * Replacer des accents par règle est impossible en français (« cote », « côte »,
 * « coté », « côté »). On ne devine donc rien : on RECONNAÎT. Deux sources,
 * dans cet ordre :
 *
 * 1. Un intitulé déjà présent dans le catalogue avec ses accents — Parcoursup
 *    et Trouver Mon Master les publient correctement. C'est 78 intitulés sur
 *    96, et ça ne coûte aucune saisie humaine.
 * 2. Une table FERMÉE pour les 18 restants, essentiellement les mentions STAPS
 *    et quelques doubles licences, qu'aucun des deux autres jeux ne nomme.
 *
 * Ce qui ne tombe dans ni l'un ni l'autre garde son intitulé brut. C'est laid
 * et c'est voulu : une fiche sans accent se repère et se corrige, une fiche
 * accentuée au hasard ne se repère pas.
 */
export const LICENCE_LABEL_CORRECTIONS: Readonly<Record<string, string>> = {
  'staps : education et motricite': 'STAPS : éducation et motricité',
  'staps : entrainement sportif': 'STAPS : entraînement sportif',
  'staps : ergonomie du sport et performance motrice':
    'STAPS : ergonomie du sport et performance motrice',
  'staps : activite physique adaptee et sante':
    'STAPS : activité physique adaptée et santé',
  'staps : management du sport': 'STAPS : management du sport',
  'information communication': 'Information-communication',
  'sciences et societe': 'Sciences et société',
  'sciences de la terre et de l environnement':
    "Sciences de la Terre et de l'environnement",
  'histoire geographie': 'Histoire-géographie',
  'etudes politiques': 'Études politiques',
  'informatique et applications': 'Informatique et applications',
  'histoire allemand': 'Histoire-allemand',
  'histoire anglais': 'Histoire-anglais',
  'lettres anglais': 'Lettres-anglais',
  'lettres histoire': 'Lettres-histoire',
  'lettres sciences du langage': 'Lettres-sciences du langage',
  'acoustique et vibrations': 'Acoustique et vibrations',
  'licence integree franco allemande en droit':
    'Licence intégrée franco-allemande en droit',
  'terre, eau, environnement': 'Terre, eau, environnement',
  'droits francais droits etrangers': 'Droits français-droits étrangers',
  'sante et societe': 'Santé et société',
  'genie urbain': 'Génie urbain',
  'sciences cognitives': 'Sciences cognitives',
  'sciences de la vigne et du vin': 'Sciences de la vigne et du vin',
  'sciences des systemes communicants': 'Sciences des systèmes communicants',
};

export function restoreAccentedLabel(
  raw: string,
  knownLabels: ReadonlyMap<string, string>,
): string {
  const trimmed = (raw ?? '').trim();
  if (trimmed === '') return '';
  const key = normalizeLabel(trimmed);
  return knownLabels.get(key) ?? LICENCE_LABEL_CORRECTIONS[key] ?? trimmed;
}

/// Forme d'une formation Parcoursup : ce que sa famille implique.
export interface ParcoursupShape {
  readonly cycle: EefCycle;
  readonly level: EefLevel;
  readonly durationYears: number;
  readonly procedureType: EefProcedureType;
  readonly selectivity: EefSelectivity;
}

/**
 * Table FERMÉE des familles Parcoursup retenues au catalogue.
 *
 * Ce qui n'y figure pas est écarté volontairement, et le générateur le compte
 * par famille : CPGE, BTS, DCG, diplômes d'université, formations
 * préparatoires et formations du travail social ne sont pas des diplômes
 * universitaires au sens de la procédure — les servir sous « universités
 * publiques » tromperait sur ce qu'on peut y demander.
 *
 * `procedureType` suit une règle unique et publiée : la demande d'admission
 * préalable ne concerne QUE la 1re année de licence (dossier blanc) et la
 * 1re année en école d'architecture (dossier jaune). Tout le reste de l'offre
 * universitaire — BUT, DEUST, licence professionnelle, master — relève de la
 * procédure Études en France. Voir `EEF_PROCEDURE_SOURCE_URL`.
 */
export const PARCOURSUP_FAMILIES: Readonly<Record<string, ParcoursupShape>> = {
  Licence: {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'non_selective',
  },
  'Licence sélective': {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  'LPE - Licence Professorat des Ecoles': {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  'Formations aux métiers du sport': {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'non_selective',
  },
  "Formations d'art, de design et du spectacle vivant": {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  'C.M.I - Cursus Master en Ingénierie': {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  'I.A.E - Instituts d’administration des entreprises': {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  "I.A.E - Instituts d'administration des entreprises": {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  'Sciences Po - Instituts d’études politiques': {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  "Sciences Po - Instituts d'études politiques": {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_blanche', selectivity: 'selective',
  },
  BUT: {
    cycle: 'but1', level: 'Bachelor', durationYears: 3,
    procedureType: 'eef', selectivity: 'selective',
  },
  DEUST: {
    cycle: 'deust', level: 'Bac+2', durationYears: 2,
    procedureType: 'eef', selectivity: 'selective',
  },
  'Licence professionnelle': {
    cycle: 'licence_pro', level: 'Bachelor', durationYears: 1,
    procedureType: 'eef', selectivity: 'selective',
  },
  'Etudes de santé': {
    // PASS et L.AS sont des PREMIÈRES ANNÉES DE LICENCE : dossier blanc, même
    // échéance que n'importe quelle L1, et non une procédure santé à part.
    cycle: 'sante', level: 'Bachelor', durationYears: 1,
    procedureType: 'dap_blanche', selectivity: 'non_selective',
  },
  "Formations d'architecture, du paysage et du patrimoine": {
    cycle: 'licence1', level: 'Bachelor', durationYears: 3,
    procedureType: 'dap_jaune', selectivity: 'selective',
  },
  "Formations des écoles d'ingénieurs": {
    // Cycle en cinq ans après le bac. La sélection appartient à l'école (ou au
    // concours commun) : ce n'est pas la procédure Études en France.
    cycle: 'ingenieur', level: 'Master', durationYears: 5,
    procedureType: 'hors_eef', selectivity: 'selective',
  },
};

/// La page qui fait foi sur le partage DAP / procédure Études en France.
/// Elle est recopiée dans `sourceUrl` de rien du tout : elle justifie une
/// RÈGLE, pas une ligne. Elle vit donc ici et dans le README des données.
export const EEF_PROCEDURE_SOURCE_URL =
  'https://www.campusfrance.org/fr/dap-demande-admission-prealable-france';

/**
 * Forme d'une ligne Parcoursup à partir de ses familles (`tf`).
 *
 * Une ligne porte souvent DEUX familles — « Licence sélective » et
 * « Licence ». La plus spécifique gagne, et c'est pour cela qu'on ne se
 * contente pas de la première : prendre « Licence » au hasard effacerait la
 * sélectivité, c'est-à-dire la seule information qui distingue les deux.
 */
export function resolveParcoursupShape(
  families: readonly string[],
): ParcoursupShape | null {
  const known = families
    .map((family) => PARCOURSUP_FAMILIES[family])
    .filter((shape): shape is ParcoursupShape => shape !== undefined);
  if (known.length === 0) return null;
  const selective = known.find((shape) => shape.selectivity === 'selective');
  const base = known.find((shape) => shape.cycle !== 'licence1') ?? known[0];
  return selective && base.cycle === 'licence1'
    ? { ...base, selectivity: 'selective' }
    : base;
}

/// Identifiant stable, dérivé d'une clé métier et non d'un rang de ligne.
/// Une université qui change de nom, un jeu de données qui change d'ordre :
/// l'id ne bouge pas, donc l'import reste idempotent.
export function stableEefId(prefix: string, key: string): string {
  return `${prefix}${createHash('sha256').update(key).digest('hex').slice(0, 16)}`;
}
