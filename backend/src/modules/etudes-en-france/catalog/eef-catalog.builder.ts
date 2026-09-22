// ─────────────────────────────────────────────────────────────────────────────
// Catalogue « Études en France » — la conversion données ouvertes → catalogue.
//
// Pure, et c'est le point : le script de collecte (`scripts/fetch-eef-catalog.ts`)
// ne fait que parler au réseau et écrire des fichiers. Tout ce qui DÉCIDE —
// quelle ligne entre au catalogue, dans quel domaine, sous quelle procédure —
// est ici, donc testable sans réseau et sans base.
//
// Chaque fonction rend aussi ce qu'elle a REFUSÉ, avec le motif. Un pipeline
// qui n'annonce que ses succès ne se relit pas.
// ─────────────────────────────────────────────────────────────────────────────
import {
  normalizeCityName,
  normalizeLabel,
  resolveFieldId,
  refineParcoursupShape,
  resolveParcoursupShape,
  restoreAccentedLabel,
  stableEefId,
} from './eef-catalog.normalize';
import type {
  EefInstitutionRecord,
  EefProgramRecord,
} from './eef-catalog.types';

export const INSTITUTION_ID_PREFIX = 'eef-univ-';
export const PROGRAM_ID_PREFIX = 'eef-prog-';

/// Une ligne écartée, et pourquoi. Le générateur les compte par motif et les
/// recopie dans le manifeste : c'est le seul moyen de voir un jeu de données
/// dériver avant qu'il ne vide le catalogue en silence.
export interface RejectedRow {
  readonly reason:
    | 'famille-inconnue'
    | 'domaine-introuvable'
    | 'etablissement-inconnu'
    | 'intitule-vide'
    | 'source-manquante';
  readonly label: string;
}

/// Une université du référentiel MESR, telle que l'API la renvoie. Seuls les
/// champs lus sont déclarés — le jeu en compte une centaine.
export interface RawInstitution {
  readonly uai?: string | null;
  readonly uo_lib?: string | null;
  readonly uo_lib_en?: string | null;
  readonly sigle?: string | null;
  readonly com_nom?: string | null;
  readonly dep_nom?: string | null;
  readonly reg_nom?: string | null;
  readonly url?: string | null;
  readonly typologie_d_universites_et_assimiles?: string | null;
  readonly etablissement_id_paysage?: string | null;
  readonly [key: string]: unknown;
}

/// La page du référentiel qui atteste des faits d'un établissement.
export const MESR_INSTITUTION_SOURCE =
  'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/'
  + 'fr-esr-principaux-etablissements-enseignement-superieur/information/';

/// Dernière rentrée dont le référentiel publie les effectifs, et les années
/// antérieures en repli. Une université créée en 2025 n'a pas d'effectif 2024 :
/// on redescend plutôt que de servir zéro, et on ne sert rien si rien n'existe.
const ENROLMENT_YEARS = [2024, 2023, 2022, 2021, 2020] as const;

function firstEnrolment(
  raw: RawInstitution,
): { count: number; year: number } | null {
  for (const year of ENROLMENT_YEARS) {
    const value = raw[`inscrits_${year}`];
    const count =
      typeof value === 'number'
        ? value
        : typeof value === 'string'
          ? Number.parseFloat(value)
          : Number.NaN;
    if (Number.isFinite(count) && count > 0) {
      return { count: Math.round(count), year };
    }
  }
  return null;
}

/// L'UAI peut en contenir PLUSIEURS, séparés par `;` — Université Paris 8 en
/// déclare deux. Le premier fait l'identifiant, tous servent à la jointure :
/// choisir au hasard perdrait la moitié des formations de l'établissement.
export function institutionUaiCodes(raw: RawInstitution): string[] {
  return (raw.uai ?? '')
    .split(';')
    .map((code) => code.trim())
    .filter((code) => code !== '');
}

export function buildInstitution(
  raw: RawInstitution,
): EefInstitutionRecord | null {
  const codes = institutionUaiCodes(raw);
  const nameFr = (raw.uo_lib ?? '').trim();
  const website = (raw.url ?? '').trim();
  if (codes.length === 0 || nameFr === '' || !website.startsWith('https://')) {
    return null;
  }
  return {
    id: `${INSTITUTION_ID_PREFIX}${codes[0].toLowerCase()}`,
    uai: codes.join(';'),
    nameFr,
    // Le MESR publie un nom anglais officiel pour une partie des
    // établissements. Quand il n'en publie pas, on garde le nom français :
    // une raison sociale n'est pas une phrase à traduire.
    nameEn: (raw.uo_lib_en ?? '').trim() || nameFr,
    acronym: (raw.sigle ?? '').trim() || null,
    city: (raw.com_nom ?? '').trim(),
    department: (raw.dep_nom ?? '').trim(),
    region: (raw.reg_nom ?? '').trim(),
    websiteUrl: website,
    typology: (raw.typologie_d_universites_et_assimiles ?? '').trim() || null,
    enrolment: firstEnrolment(raw),
    sourceUrl: MESR_INSTITUTION_SOURCE,
  };
}

/// Une ligne de la cartographie des formations Parcoursup.
export interface RawParcoursupRow {
  readonly etablissement_id_paysage?: string | null;
  readonly etab_uai?: string | null;
  readonly etab_nom?: string | null;
  readonly tf?: readonly string[] | null;
  readonly nm?: readonly string[] | null;
  readonly fl?: readonly string[] | null;
  readonly commune?: string | null;
  readonly fiche?: string | null;
  readonly gta?: number | string | null;
}

export interface BuildResult<T> {
  readonly records: T[];
  readonly rejected: RejectedRow[];
}

/**
 * Formations de premier cycle, à partir de la cartographie Parcoursup.
 *
 * `institutionByPaysage` relie la ligne à l'université COURANTE : les
 * composantes (IUT, UFR, instituts) portent leur propre UAI mais le même
 * identifiant Paysage que leur université de rattachement. Se fier à l'UAI
 * perdrait les 800 formations de BUT.
 */
export function buildParcoursupPrograms(
  rows: readonly RawParcoursupRow[],
  institutionByPaysage: ReadonlyMap<string, EefInstitutionRecord>,
): BuildResult<EefProgramRecord> {
  const records: EefProgramRecord[] = [];
  const rejected: RejectedRow[] = [];
  const seen = new Set<string>();

  for (const row of rows) {
    const institution = institutionByPaysage.get(
      (row.etablissement_id_paysage ?? '').trim(),
    );
    if (!institution) {
      rejected.push({
        reason: 'etablissement-inconnu',
        label: (row.etab_nom ?? '').trim() || '(sans nom)',
      });
      continue;
    }
    const families = row.tf ?? [];
    const resolved = resolveParcoursupShape(families);
    if (!resolved) {
      rejected.push({ reason: 'famille-inconnue', label: families.join(' + ') });
      continue;
    }
    // `fl` porte la filière normalisée (« L1 - Droit »), `nm` le libellé
    // commercial de l'établissement. La filière classe mieux et varie moins.
    const label = (row.fl?.[0] ?? row.nm?.[0] ?? '').trim();
    if (label === '') {
      rejected.push({ reason: 'intitule-vide', label: (row.etab_nom ?? '').trim() });
      continue;
    }
    const shape = refineParcoursupShape(resolved, label);
    const source = (row.fiche ?? '').trim();
    if (!source.startsWith('https://')) {
      rejected.push({ reason: 'source-manquante', label });
      continue;
    }
    const field = resolveFieldId(label);
    if (!field) {
      rejected.push({ reason: 'domaine-introuvable', label });
      continue;
    }
    const code = String(row.gta ?? '').trim();
    const id = stableEefId(
      PROGRAM_ID_PREFIX,
      `parcoursup:${institution.id}:${code || normalizeLabel(label)}`,
    );
    // La cartographie répète une formation par bac d'origine ; le code de
    // formation, lui, est unique. Dédupliquer ici évite 4 000 doublons.
    if (seen.has(id)) continue;
    seen.add(id);
    records.push({
      id,
      institutionId: institution.id,
      nameFr: label,
      level: shape.level,
      cycle: shape.cycle,
      fieldId: field.fieldId,
      fieldIsFallback: field.isFallback,
      durationYears: shape.durationYears,
      campusCity: normalizeCityName(row.commune ?? '') || institution.city,
      procedureType: shape.procedureType,
      selectivity: shape.selectivity,
      formationCode: code,
      tracks: [],
      recommendedBachelors: [],
      admissionModes: [],
      dataset: 'parcoursup',
      sourceUrl: source,
    });
  }
  return { records, rejected };
}

/// Une mention de master du portail Trouver Mon Master.
export interface RawMasterMention {
  readonly etablissement_id_paysage?: string | null;
  readonly etab_nom?: string | null;
  readonly etab_ville?: string | null;
  readonly for_inm?: string | null;
  readonly for_intitule?: string | null;
  readonly for_dom?: string | null;
  readonly for_ouverte?: number | string | null;
}

/// Le détail d'un parcours de master : c'est lui qui porte les licences
/// conseillées, la modalité de candidature et le lien vers la fiche.
export interface RawMasterTrack {
  readonly for_inm?: string | null;
  readonly parc_intitule?: string | null;
  readonly parc_lic_conseille?: readonly string[] | null;
  readonly for_lic_conseille?: readonly string[] | null;
  readonly for_candidature?: readonly string[] | null;
  readonly for_lien_fiche?: string | null;
}

/// Repli quand aucun parcours ne publie de lien : la recherche officielle du
/// portail, qui reste une page de l'opérateur et non un agrégateur.
export const MASTER_PORTAL_SEARCH = 'https://www.monmaster.gouv.fr/';

/// Le séparateur que le portail des masters emploie DANS une valeur.
///
/// `for_lic_conseille` arrive tantôt en tableau de mentions propres, tantôt en
/// une seule chaîne jointe par des barres verticales — les deux formes dans le
/// même jeu, parfois dans la même fiche. Sans découpage, 501 entrées du
/// catalogue portaient une « mention » du genre
/// « Droit|Economie|Gestion|Toutes licences » : un libellé que personne ne
/// publie, qu'aucun appariement ne peut reconnaître, et qui range donc quatre
/// licences conseillées dans une case introuvable.
///
/// Une barre verticale n'apparaît dans aucun intitulé de mention français. Le
/// découpage est donc sans perte, et le validateur refuse désormais qu'une
/// valeur en contienne encore.
const SOURCE_VALUE_SEPARATOR = '|';

function splitPipedStrings(values: readonly string[]): string[] {
  return values.flatMap((value) =>
    (value ?? '').split(SOURCE_VALUE_SEPARATOR),
  );
}

function uniqueStrings(values: readonly string[]): string[] {
  const seen = new Set<string>();
  const out: string[] = [];
  for (const value of values) {
    const trimmed = (value ?? '').trim();
    if (trimmed === '' || seen.has(trimmed)) continue;
    seen.add(trimmed);
    out.push(trimmed);
  }
  return out;
}

/**
 * Mentions de master.
 *
 * `paysageToCurrent` traduit l'identifiant d'établissement du millésime des
 * données vers celui d'aujourd'hui. Sans lui, les fusions de 2022-2025 —
 * Rennes-I et Rennes-II devenues Université de Rennes, Bourgogne devenue
 * Bourgogne Europe — rendraient 430 mentions orphelines : elles existent,
 * elles sont simplement rattachées à un établissement qui n'a plus ce nom.
 */
export function buildMasterPrograms(
  mentions: readonly RawMasterMention[],
  tracks: readonly RawMasterTrack[],
  institutionByPaysage: ReadonlyMap<string, EefInstitutionRecord>,
  paysageToCurrent: ReadonlyMap<string, string>,
): BuildResult<EefProgramRecord> {
  const tracksByMention = new Map<string, RawMasterTrack[]>();
  for (const track of tracks) {
    const key = (track.for_inm ?? '').trim();
    if (key === '') continue;
    const bucket = tracksByMention.get(key);
    if (bucket) bucket.push(track);
    else tracksByMention.set(key, [track]);
  }

  const records: EefProgramRecord[] = [];
  const rejected: RejectedRow[] = [];
  const seen = new Set<string>();

  for (const mention of mentions) {
    const sourcePaysage = (mention.etablissement_id_paysage ?? '').trim();
    const currentPaysage = paysageToCurrent.get(sourcePaysage) ?? sourcePaysage;
    const institution = institutionByPaysage.get(currentPaysage);
    if (!institution) {
      rejected.push({
        reason: 'etablissement-inconnu',
        label: (mention.etab_nom ?? '').trim() || '(sans nom)',
      });
      continue;
    }
    const label = (mention.for_intitule ?? '').trim();
    if (label === '') {
      rejected.push({ reason: 'intitule-vide', label: (mention.etab_nom ?? '').trim() });
      continue;
    }
    const field = resolveFieldId(label, mention.for_dom);
    if (!field) {
      rejected.push({ reason: 'domaine-introuvable', label });
      continue;
    }
    const code = (mention.for_inm ?? '').trim();
    const id = stableEefId(
      PROGRAM_ID_PREFIX,
      `master:${institution.id}:${code || normalizeLabel(label)}`,
    );
    if (seen.has(id)) continue;
    seen.add(id);

    const related = tracksByMention.get(code) ?? [];
    const sourceUrl =
      related
        .map((track) => (track.for_lien_fiche ?? '').trim())
        .find((url) => url.startsWith('https://')) ?? MASTER_PORTAL_SEARCH;

    records.push({
      id,
      institutionId: institution.id,
      nameFr: label,
      level: 'Master',
      cycle: 'master',
      fieldId: field.fieldId,
      fieldIsFallback: field.isFallback,
      durationYears: 2,
      campusCity: normalizeCityName(mention.etab_ville ?? '') || institution.city,
      procedureType: 'eef',
      // L'admission en master est sélective de droit depuis la loi du
      // 23 décembre 2016 : ce n'est pas une estimation, c'est la règle.
      selectivity: 'selective',
      formationCode: code,
      tracks: uniqueStrings(
        splitPipedStrings(related.map((track) => track.parc_intitule ?? '')),
      ),
      recommendedBachelors: uniqueStrings(
        splitPipedStrings([
          ...related.flatMap((track) => track.for_lic_conseille ?? []),
          ...related.flatMap((track) => track.parc_lic_conseille ?? []),
        ]),
      ),
      admissionModes: uniqueStrings(
        splitPipedStrings(
          related.flatMap((track) => track.for_candidature ?? []),
        ),
      ),
      dataset: 'trouver-mon-master',
      sourceUrl,
    });
  }
  return { records, rejected };
}

export function countRejections(
  rejected: readonly RejectedRow[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const row of rejected) out[row.reason] = (out[row.reason] ?? 0) + 1;
  return out;
}

// ─────────────────────────────────────────────────────────────────────────────
// Les 2e et 3e années de licence.
//
// POURQUOI ELLES NE VIENNENT PAS DE PARCOURSUP
//
// La cartographie Parcoursup ne décrit que l'ENTRÉE EN PREMIÈRE ANNÉE. Or un
// candidat qui passe par la procédure Études en France vise très souvent une
// L2 ou une L3 — c'est même le cas le plus courant pour qui a déjà commencé
// des études chez lui. Ces années existent, elles ne sont simplement dans
// aucun portail de candidature nationale : on entre en L2 ou en L3 sur dossier,
// auprès de l'université.
//
// POURQUOI ON NE LES DÉDUIT PAS DES L1
//
// « Une licence dure trois ans, donc toute L1 implique une L2 et une L3 » est
// vrai en général et faux en particulier : PASS n'a pas de L2 du même nom, les
// portails pluridisciplinaires se scindent, des mentions ferment une année
// sans fermer l'autre, et certaines L3 n'existent que sur un campus
// secondaire. Déduire produirait des fiches plausibles et non vérifiables —
// exactement ce que ce pipeline refuse.
//
// D'OÙ ELLES VIENNENT
//
// Du jeu des diplômes réellement préparés : le ministère y publie, par
// établissement et par année d'étude, les diplômes où des étudiants étaient
// INSCRITS à la rentrée. Une L3 y figure parce que quelqu'un l'a suivie. C'est
// une preuve d'existence, pas une déduction — et elle porte l'implantation
// exacte, donc le bon campus.
// ─────────────────────────────────────────────────────────────────────────────

/// Une ligne du jeu des diplômes préparés, agrégée par établissement courant,
/// diplôme, année d'étude et implantation.
export interface RawLicenceYearRow {
  readonly etablissement_id_paysage_actuel?: string | null;
  readonly etablissement_actuel_lib?: string | null;
  readonly libelle_intitule_1?: string | null;
  /// « 02 » ou « 03 » : l'année dans le cursus.
  readonly niveau?: string | null;
  readonly implantation_commune?: string | null;
  readonly diplom?: string | null;
}

export const DIPLOMAS_DATASET_ID =
  'fr-esr-principaux-diplomes-et-formations-prepares-etablissements-publics';

/**
 * Le lien qui atteste UNE ligne, et pas seulement le jeu de données.
 *
 * Un `sourceUrl` partagé par 3 000 fiches ne se vérifie pas : le vérificateur
 * retomberait sur 530 000 lignes et refermerait l'onglet. Le portail accepte
 * des filtres dans l'URL, donc chaque fiche pointe sur SA ligne — le diplôme,
 * l'établissement et la rentrée. C'est ce qui rend la file de vérification
 * exécutable à cette échelle.
 */
export function diplomaSourceUrl(
  paysageId: string,
  diplomaCode: string,
  rentree: number,
): string {
  const refines = [
    `rentree%3A${rentree}`,
    `diplom%3A${encodeURIComponent(diplomaCode)}`,
    `etablissement_id_paysage_actuel%3A${encodeURIComponent(paysageId)}`,
  ];
  return (
    'https://data.enseignementsup-recherche.gouv.fr/explore/assets/'
    + `${DIPLOMAS_DATASET_ID}/view/?refine=${refines.join('&refine=')}`
  );
}

/// Intitulés déjà connus du catalogue, AVEC leurs accents, indexés sur leur
/// forme normalisée. Le préfixe de filière (« L1 - », « BUT - », « Master — »)
/// est retiré : c'est la mention qui se retrouve d'un jeu à l'autre.
export function buildLabelIndex(
  programs: readonly EefProgramRecord[],
): Map<string, string> {
  const index = new Map<string, string>();
  for (const program of programs) {
    const withoutPrefix = program.nameFr.replace(/^[^-—]{1,12}[-—]\s*/, '').trim();
    for (const candidate of [withoutPrefix, program.nameFr]) {
      const key = normalizeLabel(candidate);
      if (key !== '' && !index.has(key)) index.set(key, candidate);
    }
  }
  return index;
}

/// Ce qu'une « année d'étude » du jeu source vaut au catalogue.
const LICENCE_YEARS: Readonly<
  Record<string, { cycle: 'licence2' | 'licence3'; remainingYears: number }>
> = {
  '02': { cycle: 'licence2', remainingYears: 2 },
  '03': { cycle: 'licence3', remainingYears: 1 },
};

/// Intitulés qui ne désignent pas une mention de licence : un « portail » est
/// une entrée pluridisciplinaire de première année, qui se scinde ensuite.
/// L'annoncer comme une L2 ou une L3 à part entière tromperait.
function isNotAMention(label: string): boolean {
  const normalized = normalizeLabel(label);
  return (
    normalized.startsWith('portail') || normalized.startsWith('pluridisciplinaire')
  );
}

export function buildLicenceContinuationPrograms(
  rows: readonly RawLicenceYearRow[],
  institutionByPaysage: ReadonlyMap<string, EefInstitutionRecord>,
  knownLabels: ReadonlyMap<string, string>,
  rentree: number,
): BuildResult<EefProgramRecord> {
  const records: EefProgramRecord[] = [];
  const rejected: RejectedRow[] = [];
  const seen = new Set<string>();

  for (const row of rows) {
    const paysage = (row.etablissement_id_paysage_actuel ?? '').trim();
    const institution = institutionByPaysage.get(paysage);
    if (!institution) {
      rejected.push({
        reason: 'etablissement-inconnu',
        label: (row.etablissement_actuel_lib ?? '').trim() || '(sans nom)',
      });
      continue;
    }
    const year = LICENCE_YEARS[(row.niveau ?? '').trim()];
    if (!year) {
      rejected.push({ reason: 'famille-inconnue', label: `niveau ${row.niveau}` });
      continue;
    }
    const rawLabel = (row.libelle_intitule_1 ?? '').trim();
    if (rawLabel === '' || isNotAMention(rawLabel)) {
      rejected.push({
        reason: rawLabel === '' ? 'intitule-vide' : 'domaine-introuvable',
        label: rawLabel || (row.etablissement_actuel_lib ?? '').trim(),
      });
      continue;
    }
    const field = resolveFieldId(rawLabel);
    if (!field) {
      rejected.push({ reason: 'domaine-introuvable', label: rawLabel });
      continue;
    }
    const code = (row.diplom ?? '').trim();
    if (code === '') {
      rejected.push({ reason: 'source-manquante', label: rawLabel });
      continue;
    }
    const campus = normalizeCityName(row.implantation_commune ?? '') || institution.city;
    // Le campus entre dans la clé : une même licence servie à Poitiers et à
    // Niort est DEUX offres pour un étudiant, qui ne déménagera pas deux fois.
    const id = stableEefId(
      PROGRAM_ID_PREFIX,
      `licence-year:${institution.id}:${code}:${year.cycle}:${normalizeLabel(campus)}`,
    );
    if (seen.has(id)) continue;
    seen.add(id);

    const label = restoreAccentedLabel(rawLabel, knownLabels);
    records.push({
      id,
      institutionId: institution.id,
      nameFr: `${year.cycle === 'licence2' ? 'L2' : 'L3'} - ${label}`,
      level: 'Bachelor',
      cycle: year.cycle,
      fieldId: field.fieldId,
      fieldIsFallback: field.isFallback,
      durationYears: year.remainingYears,
      campusCity: campus,
      // La DAP ne concerne que la PREMIÈRE année. Une L2 ou une L3 se demande
      // par la procédure Études en France, sur un autre calendrier.
      procedureType: 'eef',
      // L'entrée en cours de cursus passe par une commission de validation
      // d'études : l'université arbitre, quelle que soit la capacité.
      selectivity: 'selective',
      formationCode: code,
      tracks: [],
      recommendedBachelors: [],
      admissionModes: [],
      dataset: 'diplomes-prepares',
      sourceUrl: diplomaSourceUrl(paysage, code, rentree),
    });
  }
  return { records, rejected };
}
