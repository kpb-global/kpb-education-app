// ─────────────────────────────────────────────────────────────────────────────
// Collecte du catalogue « Études en France » depuis les données ouvertes de
// l'État. C'est la SEULE partie du pipeline qui parle au réseau ; elle ne
// décide de rien (voir `eef-catalog.builder.ts`) et ne touche pas la base.
//
// POURQUOI DES DONNÉES OUVERTES ET PAS UNE RECHERCHE IA
//
// Le plan (§ 5.2) exige une source HTTPS officielle par affirmation publiée.
// À 7 000 formations, une recherche IA produirait 7 000 affirmations qu'aucun
// humain ne pourra vérifier avant la campagne — c'est exactement la faute qui
// a mis « Bourse McCall MacBain » sur un appareil de production. Les jeux du
// ministère, eux, SONT la source : chaque ligne porte le lien de la fiche
// officielle, et la collecte est rejouable à l'identique.
//
// LICENCES — à ne pas perdre de vue, c'est une contrainte juridique
//
// Les trois jeux utilisés sont en Licence Ouverte v2.0 (Etalab) : réutilisation
// commerciale autorisée, avec mention de la source. Les jeux de l'Onisep, eux,
// sont en ODbL — partage à l'identique — et sont VOLONTAIREMENT écartés : les
// mélanger contaminerait tout le catalogue KPB.
//
//   npx ts-node scripts/fetch-eef-catalog.ts          # écrit les fichiers
//   npx ts-node scripts/fetch-eef-catalog.ts --check  # compare sans écrire
// ─────────────────────────────────────────────────────────────────────────────
import { mkdirSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  DIPLOMAS_DATASET_ID,
  buildInstitution,
  buildLabelIndex,
  buildLicenceContinuationPrograms,
  buildMasterPrograms,
  buildParcoursupPrograms,
  countRejections,
  type RawInstitution,
  type RawLicenceYearRow,
  type RawMasterMention,
  type RawMasterTrack,
  type RawParcoursupRow,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.builder';
import type {
  EefCatalogManifest,
  EefCatalogSource,
  EefInstitutionRecord,
  EefProgramRecord,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.types';

const PORTAL = 'https://data.enseignementsup-recherche.gouv.fr';
const API = `${PORTAL}/api/explore/v2.1/catalog/datasets`;
const LICENCE = 'Licence Ouverte v2.0 (Etalab)';

const DATA_DIR = join(
  __dirname,
  '..',
  'src',
  'modules',
  'etudes-en-france',
  'catalog',
  'data',
);
const UNIVERSITIES_DIR = join(DATA_DIR, 'universites');

/// Millésime des formations de premier cycle. Il se met à jour chaque automne :
/// une constante nommée vaut mieux qu'un `2026` semé dans trois requêtes.
const PARCOURSUP_YEAR = 2026;
/// Dernier millésime publié en données ouvertes par le portail Trouver Mon
/// Master. Il est ANCIEN, et c'est su : le portail a cessé d'exporter après la
/// campagne 2021. On en tire la STRUCTURE de l'offre (quelles mentions, dans
/// quelle université, avec quelles licences conseillées) et jamais un chiffre
/// daté — ni capacité d'accueil, ni date de recrutement. Le manifeste le
/// déclare, le validateur en avertit, et les lignes arrivent inactives.
const MASTER_YEAR = 2021;
/// Dernière rentrée publiée par le jeu des diplômes réellement préparés, d'où
/// viennent les 2e et 3e années de licence. Elle avance d'un an chaque automne.
const DIPLOMAS_YEAR = 2024;

async function fetchJson(url: string): Promise<any> {
  let lastError: unknown;
  for (let attempt = 0; attempt < 4; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { accept: 'application/json' },
      });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      return await response.json();
    } catch (error) {
      lastError = error;
      // Repli exponentiel : le portail limite le débit, et abandonner à la
      // première 429 rendrait la collecte non reproductible.
      await new Promise((resolve) => setTimeout(resolve, 1500 * (attempt + 1)));
    }
  }
  throw new Error(`Collecte impossible (${url}) : ${String(lastError)}`);
}

async function fetchAll(
  dataset: string,
  where: string,
  orderBy?: string,
): Promise<any[]> {
  const rows: any[] = [];
  const pageSize = 100;
  for (let offset = 0; ; offset += pageSize) {
    const params = new URLSearchParams({
      limit: String(pageSize),
      offset: String(offset),
      where,
    });
    if (orderBy) params.set('order_by', orderBy);
    const page = await fetchJson(`${API}/${dataset}/records?${params}`);
    rows.push(...page.results);
    if (rows.length >= page.total_count || page.results.length === 0) break;
  }
  return rows;
}

/// Le portail refuse les clauses `where` trop longues : 70 identifiants en
/// disjonction dépassent la limite. On découpe, et on additionne.
async function fetchAllChunked(
  dataset: string,
  prefix: string,
  field: string,
  values: readonly string[],
  chunkSize = 15,
): Promise<any[]> {
  const rows: any[] = [];
  for (let index = 0; index < values.length; index += chunkSize) {
    const chunk = values.slice(index, index + chunkSize);
    const clause = chunk.map((value) => `${field}="${value}"`).join(' or ');
    rows.push(...(await fetchAll(dataset, `${prefix} and (${clause})`)));
  }
  return rows;
}

function slugify(value: string): string {
  return value
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 60);
}

async function main(): Promise<void> {
  const fetchedAt = new Date().toISOString();
  const sources: EefCatalogSource[] = [];

  // ── 1. Les universités publiques ──────────────────────────────────────────
  // `typologie_d_universites_et_assimiles is not null` est le critère qui
  // compte, et il vaut mieux que `type="Université"` : quatre universités —
  // Grenoble Alpes, Côte d'Azur, Lorraine, PSL — sont classées « grand
  // établissement » depuis leur passage en établissement expérimental. Les
  // exclure retirerait quatre des plus grosses universités de France.
  const institutionWhere =
    'secteur_d_etablissement="public" and typologie_d_universites_et_assimiles is not null';
  const rawInstitutions = (await fetchAll(
    'fr-esr-principaux-etablissements-enseignement-superieur',
    institutionWhere,
    'uo_lib',
  )) as RawInstitution[];
  sources.push({
    dataset: 'parcoursup',
    datasetId: 'fr-esr-principaux-etablissements-enseignement-superieur',
    portal: PORTAL,
    licence: LICENCE,
    query: institutionWhere,
    vintage: '2025',
    fetchedAt,
    rowCount: rawInstitutions.length,
  });

  const institutions: EefInstitutionRecord[] = [];
  const byPaysage = new Map<string, EefInstitutionRecord>();
  const skippedInstitutions: string[] = [];
  for (const raw of rawInstitutions) {
    const record = buildInstitution(raw);
    if (!record) {
      skippedInstitutions.push((raw.uo_lib ?? '(sans nom)').trim());
      continue;
    }
    institutions.push(record);
    const paysage = (raw.etablissement_id_paysage ?? '').trim();
    if (paysage !== '') byPaysage.set(paysage, record);
  }
  console.log(
    `Universités publiques : ${institutions.length} retenues, ${skippedInstitutions.length} écartées`,
  );
  if (skippedInstitutions.length > 0) {
    console.log(`  écartées : ${skippedInstitutions.join(', ')}`);
  }

  const paysageIds = [...byPaysage.keys()].sort();

  // ── 2. Premier cycle : la cartographie des formations Parcoursup ─────────
  const parcoursupWhere = `annee=${PARCOURSUP_YEAR}`;
  const rawParcoursup = (await fetchAllChunked(
    'fr-esr-cartographie_formations_parcoursup',
    parcoursupWhere,
    'etablissement_id_paysage',
    paysageIds,
  )) as RawParcoursupRow[];
  sources.push({
    dataset: 'parcoursup',
    datasetId: 'fr-esr-cartographie_formations_parcoursup',
    portal: PORTAL,
    licence: LICENCE,
    query: `${parcoursupWhere} and etablissement_id_paysage in (${paysageIds.length} universités)`,
    vintage: String(PARCOURSUP_YEAR),
    fetchedAt,
    rowCount: rawParcoursup.length,
  });

  const firstCycle = buildParcoursupPrograms(rawParcoursup, byPaysage);
  console.log(
    `Premier cycle : ${firstCycle.records.length} formations, `
    + `${firstCycle.rejected.length} lignes écartées `
    + `${JSON.stringify(countRejections(firstCycle.rejected))}`,
  );

  // ── 3. Masters : Trouver Mon Master, recalé sur les fusions ──────────────
  const masterWhere = `annee=${MASTER_YEAR}`;
  const rawMentions = (await fetchAll(
    'fr-esr-tmm-donnees-du-portail-dinformation-trouver-mon-master-mentions-de-master',
    masterWhere,
  )) as RawMasterMention[];
  const rawTracks = (await fetchAll(
    'fr-esr-tmm-donnees-du-portail-dinformation-trouver-mon-master-parcours-de-format',
    masterWhere,
  )) as RawMasterTrack[];
  sources.push(
    {
      dataset: 'trouver-mon-master',
      datasetId:
        'fr-esr-tmm-donnees-du-portail-dinformation-trouver-mon-master-mentions-de-master',
      portal: PORTAL,
      licence: LICENCE,
      query: masterWhere,
      vintage: String(MASTER_YEAR),
      fetchedAt,
      rowCount: rawMentions.length,
    },
    {
      dataset: 'trouver-mon-master',
      datasetId:
        'fr-esr-tmm-donnees-du-portail-dinformation-trouver-mon-master-parcours-de-format',
      portal: PORTAL,
      licence: LICENCE,
      query: masterWhere,
      vintage: String(MASTER_YEAR),
      fetchedAt,
      rowCount: rawTracks.length,
    },
  );

  // La table de correspondance des fusions. Elle vient du jeu des diplômes
  // préparés, seul endroit où le ministère publie, pour chaque établissement
  // historique, l'établissement qui lui a succédé.
  const mergeMapDataset =
    'fr-esr-principaux-diplomes-et-formations-prepares-etablissements-publics';
  const mergeRows: any[] = [];
  for (let offset = 0; ; offset += 100) {
    const params = new URLSearchParams({
      limit: '100',
      offset: String(offset),
      select:
        'etablissement_id_paysage_source,etablissement_id_paysage_actuel',
      group_by:
        'etablissement_id_paysage_source,etablissement_id_paysage_actuel',
    });
    const page = await fetchJson(`${API}/${mergeMapDataset}/records?${params}`);
    mergeRows.push(...page.results);
    if (page.results.length < 100) break;
  }
  const paysageToCurrent = new Map<string, string>();
  for (const row of mergeRows) {
    const from = (row.etablissement_id_paysage_source ?? '').trim();
    const to = (row.etablissement_id_paysage_actuel ?? '').trim();
    if (from !== '' && to !== '') paysageToCurrent.set(from, to);
  }
  sources.push({
    dataset: 'trouver-mon-master',
    datasetId: mergeMapDataset,
    portal: PORTAL,
    licence: LICENCE,
    query: 'group_by(etablissement_id_paysage_source, etablissement_id_paysage_actuel)',
    vintage: '2024',
    fetchedAt,
    rowCount: mergeRows.length,
  });

  const masters = buildMasterPrograms(
    rawMentions,
    rawTracks,
    byPaysage,
    paysageToCurrent,
  );
  console.log(
    `Masters : ${masters.records.length} mentions, `
    + `${masters.rejected.length} lignes écartées `
    + `${JSON.stringify(countRejections(masters.rejected))}`,
  );

  // ── 4. Les 2e et 3e années de licence ────────────────────────────────────
  // Parcoursup ne décrit que l'entrée en 1re année ; un candidat qui a déjà
  // commencé des études chez lui vise une L2 ou une L3. Ces années ne vivent
  // dans aucun portail de candidature : on les prend là où le ministère atteste
  // qu'elles ont eu des inscrits.
  //
  // `group_by` sur les cinq colonnes utiles : le jeu compte 530 000 lignes
  // d'effectifs, on n'en veut que la liste distincte des diplômes préparés.
  const licenceYearSelect = [
    'etablissement_id_paysage_actuel',
    'etablissement_actuel_lib',
    'libelle_intitule_1',
    'niveau',
    'implantation_commune',
    'diplom',
  ].join(',');
  const licenceYearWhere =
    `rentree=${DIPLOMAS_YEAR} and diplome_rgp="Licence" and (niveau="02" or niveau="03")`;
  const rawLicenceYears: RawLicenceYearRow[] = [];
  for (let offset = 0; ; offset += 100) {
    const params = new URLSearchParams({
      limit: '100',
      offset: String(offset),
      where: licenceYearWhere,
      select: licenceYearSelect,
      group_by: licenceYearSelect,
    });
    const page = await fetchJson(`${API}/${DIPLOMAS_DATASET_ID}/records?${params}`);
    rawLicenceYears.push(...(page.results as RawLicenceYearRow[]));
    if (page.results.length < 100) break;
  }
  sources.push({
    dataset: 'diplomes-prepares',
    datasetId: DIPLOMAS_DATASET_ID,
    portal: PORTAL,
    licence: LICENCE,
    query: licenceYearWhere,
    vintage: String(DIPLOMAS_YEAR),
    fetchedAt,
    rowCount: rawLicenceYears.length,
  });

  // Les intitulés de ce jeu sont publiés SANS ACCENTS. On les reconnaît sur
  // ceux que Parcoursup et Trouver Mon Master écrivent correctement, plutôt
  // que de replacer des accents par règle — ce qui est impossible en français.
  const labelIndex = buildLabelIndex([
    ...firstCycle.records,
    ...masters.records,
  ]);
  const licenceYears = buildLicenceContinuationPrograms(
    rawLicenceYears,
    byPaysage,
    labelIndex,
    DIPLOMAS_YEAR,
  );
  console.log(
    `2e et 3e années : ${licenceYears.records.length} formations, `
    + `${licenceYears.rejected.length} lignes écartées `
    + `${JSON.stringify(countRejections(licenceYears.rejected))}`,
  );

  // ── 5. Écriture, un fichier par université ───────────────────────────────
  const programsByInstitution = new Map<string, EefProgramRecord[]>();
  for (const program of [
    ...firstCycle.records,
    ...licenceYears.records,
    ...masters.records,
  ]) {
    const bucket = programsByInstitution.get(program.institutionId);
    if (bucket) bucket.push(program);
    else programsByInstitution.set(program.institutionId, [program]);
  }

  if (process.argv.includes('--check')) {
    console.log(
      `\n--check : ${institutions.length} universités, `
      + `${firstCycle.records.length + licenceYears.records.length + masters.records.length} formations. Rien écrit.`,
    );
    return;
  }

  mkdirSync(UNIVERSITIES_DIR, { recursive: true });
  // On repart d'un dossier vide : une université disparue du référentiel doit
  // disparaître du dépôt, sinon le catalogue accumule des fantômes qu'aucune
  // collecte ne retire.
  for (const name of readdirSync(UNIVERSITIES_DIR)) {
    if (name.endsWith('.json')) rmSync(join(UNIVERSITIES_DIR, name));
  }

  let programCount = 0;
  for (const institution of institutions) {
    const programs = (programsByInstitution.get(institution.id) ?? []).sort(
      (a, b) => a.id.localeCompare(b.id),
    );
    programCount += programs.length;
    const file = `${slugify(institution.nameFr)}-${institution.uai.split(';')[0].toLowerCase()}.json`;
    writeFileSync(
      join(UNIVERSITIES_DIR, file),
      `${JSON.stringify({ institution, programs }, null, 2)}\n`,
      'utf8',
    );
  }

  const manifest: EefCatalogManifest = {
    catalogVersion: '1.1.0',
    generatedAt: fetchedAt,
    countryId: 'france',
    institutionCount: institutions.length,
    programCount,
    sources,
  };
  writeFileSync(
    join(DATA_DIR, 'manifest.json'),
    `${JSON.stringify(manifest, null, 2)}\n`,
    'utf8',
  );
  console.log(
    `\nÉcrit : ${institutions.length} fichiers, ${programCount} formations.`,
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
