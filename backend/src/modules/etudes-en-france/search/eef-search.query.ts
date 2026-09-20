// ─────────────────────────────────────────────────────────────────────────────
// Recherche « Études en France » — la moitié pure.
//
// POURQUOI CE FICHIER EXISTE SÉPARÉMENT DU SERVICE
//
// Tout ce qui DÉCIDE — quels paramètres sont acceptés, ce qu'un curseur veut
// dire, quelle clause `where` en découle — est ici, sans Prisma et sans Nest.
// Le service n'est qu'un poseur de requêtes. C'est ce qui rend testable la
// partie où les bugs vivent : un filtre qui s'oublie, un curseur qui saute une
// ligne, une liste `IN` qu'on laisse grandir sans borne.
//
// POURQUOI UN CURSEUR ET PAS UN OFFSET
//
// `/catalog/programs` pagine par `offset`, et c'est tenable à 133 formations.
// À 10 247, l'offset a deux défauts qui ne se voient qu'en charge :
//
//   1. Postgres doit MATÉRIALISER puis jeter les `offset` premières lignes. La
//      page 1 coûte 20 lignes, la page 400 en coûte 8 020. La lenteur arrive
//      donc le jour où quelqu'un fait défiler, c'est-à-dire le jour de la
//      campagne.
//   2. Il n'est pas stable. Si un administrateur publie une fiche pendant
//      qu'un étudiant fait défiler, tout glisse d'un rang : il revoit une
//      formation, ou il en saute une sans jamais le savoir.
//
// Le curseur porte la POSITION (le dernier couple trié vu), pas un rang. Une
// insertion ailleurs dans la liste ne décale rien, et chaque page coûte le
// même prix parce que l'index la trouve directement.
// ─────────────────────────────────────────────────────────────────────────────
import {
  EEF_CYCLES,
  EEF_PROCEDURE_TYPES,
} from '../catalog/eef-catalog.types';

export const EEF_SEARCH_DEFAULT_LIMIT = 20;
export const EEF_SEARCH_MAX_LIMIT = 50;

/// Plafond du nombre de valeurs acceptées par facette dans une même requête.
/// Ce n'est pas de la prudence abstraite : `procedureType in (…)` avec dix
/// mille valeurs est une requête que n'importe qui peut fabriquer avec une
/// URL, et Postgres la planifiera consciencieusement.
export const EEF_SEARCH_MAX_FILTER_VALUES = 20;

/// Nombre maximal de mots retenus dans la recherche libre. Chaque mot ajoute
/// une disjonction `ILIKE` : les borner évite qu'une phrase collée dans la
/// barre de recherche devienne une requête à cinquante branches.
export const EEF_SEARCH_MAX_TERMS = 6;

const KNOWN_FIELD_IDS = new Set([
  'd01', 'd02', 'd03', 'd04', 'd05', 'd06',
  'd07', 'd08', 'd09', 'd10', 'd11', 'd12',
]);
const KNOWN_SELECTIVITY = new Set(['selective', 'non_selective']);
const KNOWN_PROCEDURES = new Set<string>(EEF_PROCEDURE_TYPES);
const KNOWN_CYCLES = new Set<string>(EEF_CYCLES);

/// Une valeur refusée, avec de quoi la corriger. Le message nomme le paramètre
/// ET les valeurs admises : un client qui reçoit « invalide » sans savoir quoi
/// envoyer réessaiera la même chose.
export class EefSearchParamError extends Error {
  constructor(
    readonly parameter: string,
    readonly value: string,
    readonly allowed: readonly string[],
  ) {
    super(
      `Paramètre « ${parameter} » : valeur « ${value} » inconnue. `
      + `Valeurs admises : ${allowed.join(', ')}.`,
    );
  }
}

export class EefSearchCursorError extends Error {
  constructor() {
    super('Curseur illisible. Relancer la recherche sans curseur.');
  }
}

export interface EefSearchInput {
  readonly q?: string;
  readonly procedureType?: string;
  readonly cycle?: string;
  readonly fieldId?: string;
  readonly institutionId?: string;
  readonly campusCity?: string;
  readonly selectivity?: string;
  readonly cursor?: string;
  readonly limit?: string | number;
}

export interface EefSearchCursor {
  readonly nameFr: string;
  readonly id: string;
}

export interface EefSearchParams {
  readonly terms: string[];
  readonly procedureTypes: string[];
  readonly cycles: string[];
  readonly fieldIds: string[];
  readonly institutionIds: string[];
  readonly campusCities: string[];
  readonly selectivities: string[];
  readonly cursor: EefSearchCursor | null;
  readonly limit: number;
}

/// Découpe une liste séparée par des virgules, en retirant les doublons et les
/// vides, et en refusant au-delà du plafond plutôt qu'en tronquant : tronquer
/// silencieusement rendrait un résultat qui ne correspond pas à la demande.
function parseList(
  parameter: string,
  raw: string | undefined,
  allowed: ReadonlySet<string> | null,
): string[] {
  if (!raw) return [];
  const seen = new Set<string>();
  for (const part of raw.split(',')) {
    const value = part.trim();
    if (value === '') continue;
    if (allowed && !allowed.has(value)) {
      throw new EefSearchParamError(parameter, value, [...allowed].sort());
    }
    seen.add(value);
    if (seen.size > EEF_SEARCH_MAX_FILTER_VALUES) {
      throw new EefSearchParamError(
        parameter,
        `${seen.size} valeurs`,
        [`au plus ${EEF_SEARCH_MAX_FILTER_VALUES} valeurs`],
      );
    }
  }
  return [...seen];
}

export function encodeEefCursor(cursor: EefSearchCursor): string {
  return Buffer.from(`${cursor.nameFr}\u0000${cursor.id}`, 'utf8').toString(
    'base64url',
  );
}

export function decodeEefCursor(raw: string): EefSearchCursor {
  let decoded: string;
  try {
    decoded = Buffer.from(raw, 'base64url').toString('utf8');
  } catch {
    throw new EefSearchCursorError();
  }
  const separator = decoded.indexOf('\u0000');
  if (separator <= 0 || separator === decoded.length - 1) {
    throw new EefSearchCursorError();
  }
  return {
    nameFr: decoded.slice(0, separator),
    id: decoded.slice(separator + 1),
  };
}

export function parseEefSearchInput(input: EefSearchInput): EefSearchParams {
  const rawLimit =
    typeof input.limit === 'string' ? Number.parseInt(input.limit, 10) : input.limit;
  const limit =
    Number.isFinite(rawLimit) && (rawLimit as number) > 0
      ? Math.min(rawLimit as number, EEF_SEARCH_MAX_LIMIT)
      : EEF_SEARCH_DEFAULT_LIMIT;

  const terms = (input.q ?? '')
    .split(/\s+/)
    .map((term) => term.trim())
    .filter((term) => term !== '')
    .slice(0, EEF_SEARCH_MAX_TERMS);

  return {
    terms,
    procedureTypes: parseList('procedureType', input.procedureType, KNOWN_PROCEDURES),
    cycles: parseList('cycle', input.cycle, KNOWN_CYCLES),
    fieldIds: parseList('fieldId', input.fieldId, KNOWN_FIELD_IDS),
    // Pas de vocabulaire fermé : les identifiants d'établissement et les villes
    // viennent du catalogue lui-même. Un identifiant inconnu rend zéro
    // résultat, ce qui est la bonne réponse — pas une erreur.
    institutionIds: parseList('institutionId', input.institutionId, null),
    campusCities: parseList('campusCity', input.campusCity, null),
    selectivities: parseList('selectivity', input.selectivity, KNOWN_SELECTIVITY),
    cursor: input.cursor ? decodeEefCursor(input.cursor) : null,
    limit,
  };
}

/// Les facettes qu'on sait compter. Le nom est celui de la colonne : la
/// facette et le filtre parlent du même mot, sinon l'un des deux dérive.
export const EEF_SEARCH_FACETS = [
  'procedureType',
  'cycle',
  'fieldId',
  'selectivity',
  'campusCity',
  'institutionId',
] as const;

export type EefSearchFacet = (typeof EEF_SEARCH_FACETS)[number];

export interface BuildWhereOptions {
  /// La facette dont on compte les valeurs. Son propre filtre est alors
  /// EXCLU : sans cela, choisir « master » ferait tomber à zéro le compte de
  /// toutes les autres valeurs de la même facette, et l'étudiant ne pourrait
  /// plus voir combien de licences existent sans défaire son filtre.
  readonly excludeFacet?: EefSearchFacet;
  /// Le curseur ne s'applique qu'à la page. Un total ou une facette qui en
  /// tiendrait compte décrirait « ce qui reste », pas « ce qu'il y a ».
  readonly withCursor?: boolean;
}

/**
 * La clause `where` Prisma, construite à partir des paramètres.
 *
 * `isActive: true` et `countryId` ne sont jamais optionnels : le premier est la
 * frontière entre ce qui est relu et ce qui ne l'est pas, le second empêche
 * la recherche d'un catalogue français de rendre une école marocaine.
 */
export function buildEefSearchWhere(
  params: EefSearchParams,
  countryId: string,
  options: BuildWhereOptions = {},
): Record<string, unknown> {
  const where: Record<string, unknown> = {
    isActive: true,
    countryId,
    // Une ligne sans procédure n'appartient pas à ce catalogue : ce sont les
    // formations des écoles privées partenaires, qui ont leur propre espace.
    procedureType: { not: null },
  };
  const and: Record<string, unknown>[] = [];

  const apply = (facet: EefSearchFacet, values: string[]) => {
    if (options.excludeFacet === facet || values.length === 0) return;
    where[facet] = { in: values };
  };
  apply('procedureType', params.procedureTypes);
  apply('cycle', params.cycles);
  apply('fieldId', params.fieldIds);
  apply('selectivity', params.selectivities);
  apply('campusCity', params.campusCities);
  apply('institutionId', params.institutionIds);

  // Chaque mot doit être présent, mais peut l'être dans l'intitulé OU dans la
  // ville. « droit rennes » trouve donc la licence de droit à Rennes, alors
  // qu'un `contains` sur la phrase entière ne trouverait rien.
  for (const term of params.terms) {
    and.push({
      OR: [
        { nameFr: { contains: term, mode: 'insensitive' } },
        { campusCity: { contains: term, mode: 'insensitive' } },
      ],
    });
  }

  if (options.withCursor && params.cursor) {
    // Keyset sur (nameFr, id) : « strictement après le dernier vu ». L'égalité
    // sur `nameFr` est traitée à part parce que des homonymes existent en
    // nombre — « L1 - Droit » est servi par quarante universités.
    and.push({
      OR: [
        { nameFr: { gt: params.cursor.nameFr } },
        {
          AND: [
            { nameFr: params.cursor.nameFr },
            { id: { gt: params.cursor.id } },
          ],
        },
      ],
    });
  }

  if (and.length > 0) where.AND = and;
  return where;
}

/// L'ordre, écrit une fois. Il doit être TOTAL — `nameFr` seul ne l'est pas —
/// sinon deux lignes homonymes peuvent s'échanger entre deux pages et le
/// curseur en saute une.
export const EEF_SEARCH_ORDER_BY = [
  { nameFr: 'asc' as const },
  { id: 'asc' as const },
];
