// ─────────────────────────────────────────────────────────────────────────────
// Les mots de la recherche libre — la moitié pure.
//
// CE QUE LA RECHERCHE COMPARAIT AVANT, ET POURQUOI C'ÉTAIT INSUFFISANT
//
// Chaque mot tapé devait figurer, à l'identique, dans l'intitulé de la formation
// ou dans sa ville. Trois façons de chercher normalement ne donnaient rien :
//
//   • sans accents : « genie » ne trouvait qu'1 formation sur 508 ;
//   • par université : « Sorbonne », « Paris-Saclay », « UPEC » — le nom de
//     l'établissement n'est pas dans l'intitulé de la formation ;
//   • par niveau : « licence droit » ne trouvait que les 27 intitulés (sur
//     5 646 licences) qui portent le mot « licence » ; les autres s'écrivent
//     « L1 - Droit ».
//
// Un mot est désormais satisfait s'il figure dans le texte normalisé de la
// formation (intitulé + ville), OU s'il désigne l'établissement, OU s'il désigne
// un niveau. Tous les mots doivent l'être : ajouter un mot resserre toujours.
// ─────────────────────────────────────────────────────────────────────────────
import type { PublishedInstitution } from '../catalog/eef-published-institutions';
import { normalizeSearchText } from '../catalog/eef-search-text';

export interface SearchTerm {
  /// Le mot tel que l'étudiant l'a tapé (accents compris) quand il tient en un
  /// seul mot ; sinon le mot normalisé. Sert à la comparaison brute de repli,
  /// pour les lignes dont le texte normalisé n'est pas encore rattrapé.
  readonly raw: string;
  /// Le mot normalisé : ce qui se compare au texte de la ligne.
  readonly norm: string;
  /// Les cycles que ce mot désigne (« licence » → L1, L2, L3, licence pro).
  /// Vide pour un mot qui ne désigne pas un niveau.
  readonly cycles: readonly string[];
  /// Vrai si le mot désigne une 1re année d'accès santé — PASS ou L.AS
  /// (`isHealthAccessYear`).
  readonly healthAccess: boolean;
  /// Faux pour un mot qui ne vaut QUE par ce qu'il désigne : il n'est cherché
  /// ni dans le texte de la formation, ni dans le nom des établissements.
  readonly matchesText: boolean;
}

/// Les mots qui ne discriminent rien. « licence de droit » et « licence droit »
/// doivent dire la même chose ; laissés, « de » serait satisfait par presque
/// tout et « la » par tout établissement dont le nom en contient un.
export const EEF_SEARCH_STOPWORDS: ReadonlySet<string> = new Set([
  'a', 'au', 'aux', 'd', 'de', 'des', 'du', 'en', 'et', 'l', 'la', 'le', 'les',
  'pour', 'sur', 'un', 'une', 'and', 'for', 'in', 'of', 'the',
]);

/// Plafond du nombre de mots une fois les composés découpés (« paris-saclay »
/// en vaut deux). Chaque mot ajoute une disjonction : les borner empêche une
/// phrase collée dans la barre de recherche de devenir une requête géante.
export const EEF_SEARCH_MAX_EXPANDED_TERMS = 10;

const LICENCE = ['licence1', 'licence2', 'licence3', 'licence_pro'] as const;

/// Les mots de niveau que les étudiants tapent, et les cycles qu'ils désignent.
/// Table FERMÉE, sur les clés normalisées : un mot absent n'est pas un niveau.
/// Les cycles sont ceux de `EEF_CYCLES` — le validateur de la recherche et la
/// shortlist parlent du même vocabulaire.
export const EEF_LEVEL_SYNONYMS: Readonly<Record<string, readonly string[]>> = {
  licence: LICENCE,
  licences: LICENCE,
  bachelor: [...LICENCE, 'but1'],
  l1: ['licence1'],
  l2: ['licence2'],
  l3: ['licence3'],
  lp: ['licence_pro'],
  master: ['master'],
  masters: ['master'],
  m1: ['master'],
  m2: ['master'],
  but: ['but1'],
  but1: ['but1'],
  deust: ['deust'],
  ingenieur: ['ingenieur'],
  ingenieurs: ['ingenieur'],
  // « Santé » désigne toute la famille « Études de santé » : les PASS et L.AS
  // comme les diplômes paramédicaux (orthophoniste, ergothérapeute…).
  sante: ['sante'],
  health: ['sante'],
};

/// Les mots des études médicales — médecine, maïeutique, odontologie, pharmacie,
/// kinésithérapie (MMOPK). Ils désignent une 1re année d'accès santé, PASS ou
/// L.AS, et ELLE SEULE (`eef-health-access.ts`).
///
/// Aucun intitulé du catalogue ne contient « médecine », « pharmacie » ni
/// « kiné » : on y entre par un PASS ou une L.AS, qui s'intitule « L1 - Droit »
/// ou « L1 - Chimie ». Mesuré en production le 01/10/2026 : `q=medecine` rendait
/// 0 résultat. Mené ensuite au cycle `sante` entier, il rendait les 61 diplômes
/// paramédicaux EN TÊTE (tri par intitulé), avant toute PASS ou L.AS.
///
/// Pas de « pass » : le mot est dans l'intitulé des 205 PASS (« Parcours d'Accès
/// Spécifique Santé (PASS) »), le texte suffit, et l'étudiant qui le tape veut
/// un PASS, pas une L.AS. Pas de « sage » ni de « femme » seuls (sage-femme se
/// découpe en deux mots) : « femme » viserait aussi « Études sur le genre ». Pas
/// de « medical » : aucun intitulé ne le porte, et le mot évoque autant
/// l'imagerie que le soin.
export const EEF_HEALTH_ACCESS_WORDS: ReadonlySet<string> = new Set([
  'medecine', 'medecin', 'medicine', 'las', 'paces', 'mmopk', 'pharmacie',
  'pharmacy', 'odontologie', 'dentaire', 'dentiste', 'maieutique', 'kine',
  'kinesitherapie',
]);

/// Les mots qui ne valent QUE par ce qu'ils désignent. « las » cherché dans le
/// texte trouve « Arts plastiques » (32 formations publiées) : il n'y est donc
/// pas cherché.
export const EEF_DESIGNATION_ONLY_WORDS: ReadonlySet<string> = new Set(['las']);

/**
 * Les mots de recherche exploitables, à partir de ce qu'a tapé l'étudiant.
 *
 * Un mot composé (« paris-saclay », « l'économie ») est découpé en ses mots :
 * la ponctuation n'est pas un caractère de la ligne, elle a été remplacée par un
 * espace à l'import. Les mots vides sont retirés — SAUF s'il n'y a rien d'autre :
 * « de » tout seul est une requête maladroite, pas une requête vide.
 */
export function buildSearchTerms(rawTerms: readonly string[]): SearchTerm[] {
  const expanded: SearchTerm[] = [];
  const seen = new Set<string>();
  // « L AS » tapé avec une espace arrive en deux mots : on les recolle aussi.
  const tokens: string[] = [];
  for (const token of rawTerms) {
    const previous = tokens[tokens.length - 1];
    if (
      previous !== undefined
      && normalizeSearchText(previous) === 'l'
      && normalizeSearchText(token) === 'as'
    ) {
      tokens[tokens.length - 1] = `${previous}.${token}`;
    } else {
      tokens.push(token);
    }
  }
  for (const token of tokens) {
    // « L.AS » s'écrit avec un point que la normalisation change en espace : sans
    // ce recollage, il deviendrait « l » (mot vide) et « as », et ne désignerait
    // plus l'accès santé.
    const words = normalizeSearchText(token)
      .replace(/\bl as\b/g, 'las')
      .split(' ')
      .filter((w) => w !== '');
    for (const word of words) {
      if (seen.has(word)) continue;
      seen.add(word);
      expanded.push({
        raw: words.length === 1 ? token : word,
        norm: word,
        cycles: EEF_LEVEL_SYNONYMS[word] ?? [],
        healthAccess: EEF_HEALTH_ACCESS_WORDS.has(word),
        matchesText: !EEF_DESIGNATION_ONLY_WORDS.has(word),
      });
    }
  }
  const meaningful = expanded.filter((term) => !EEF_SEARCH_STOPWORDS.has(term.norm));
  const kept = meaningful.length > 0 ? meaningful : expanded;
  return kept.slice(0, EEF_SEARCH_MAX_EXPANDED_TERMS);
}

/// Les établissements qu'un mot désigne : par un mot de leur nom qui COMMENCE par
/// ce mot (« saclay » → Paris-Saclay), ou par leur sigle. Jamais par un morceau
/// au milieu d'un mot : « ens » n'est pas « enseignement ». Sous trois lettres,
/// seul le sigle entier compte — « ai » ou « ul » désigneraient n'importe quoi.
export function institutionsMatchingTerm(
  term: SearchTerm,
  institutions: readonly Pick<
    PublishedInstitution,
    'id' | 'nameFr' | 'nameEn' | 'acronym'
  >[],
): string[] {
  const matched: string[] = [];
  for (const institution of institutions) {
    const acronym = normalizeSearchText(institution.acronym);
    const acronymHit =
      acronym !== ''
      && (acronym === term.norm
        || (term.norm.length >= 3 && acronym.startsWith(term.norm)));
    let nameHit = false;
    if (!acronymHit && term.norm.length >= 3) {
      for (const name of [institution.nameFr, institution.nameEn]) {
        if (
          normalizeSearchText(name)
            .split(' ')
            .some((word) => word.startsWith(term.norm))
        ) {
          nameHit = true;
          break;
        }
      }
    }
    if (acronymHit || nameHit) matched.push(institution.id);
  }
  return matched;
}

/// Pour chaque mot (clé : le mot normalisé), les identifiants d'établissements
/// qu'il désigne. Un mot qui n'en désigne aucun n'a pas d'entrée.
export function resolveTermInstitutions(
  terms: readonly SearchTerm[],
  institutions: readonly Pick<
    PublishedInstitution,
    'id' | 'nameFr' | 'nameEn' | 'acronym'
  >[],
): Map<string, string[]> {
  const result = new Map<string, string[]>();
  for (const term of terms) {
    const ids = institutionsMatchingTerm(term, institutions);
    if (ids.length > 0) result.set(term.norm, ids);
  }
  return result;
}
