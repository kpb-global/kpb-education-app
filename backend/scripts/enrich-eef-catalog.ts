// Complète le catalogue déjà versionné, sans le reconstruire.
//
// Une collecte complète (`eef:fetch`) réécrit les 70 fichiers. Ici on ajoute
// seulement ce qui manquait : les établissements hors typologie, le profil
// d'admission Parcoursup 2025 sur les formations qui ont un code, et le logo
// quand Wikimedia en publie un sous une licence réutilisable.
//
//   npx ts-node scripts/enrich-eef-catalog.ts
import { readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  ADDITIONAL_DEGREE_GRANTING,
  institutionKindForUai,
} from '../src/modules/etudes-en-france/catalog/eef-additional-institutions';
import {
  ADMISSION_SESSION,
  ADMISSION_SOURCE_URL,
  cohortFromParcoursupRow,
  formationCodeOfRow,
  logoFromCommons,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.admission';
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
import {
  EEF_CATALOG_DATA_DIR,
  EEF_CATALOG_UNIVERSITIES_DIR,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';
import type {
  EefAdmissionCohort,
  EefCatalogManifest,
  EefCatalogSource,
  EefInstitutionRecord,
  EefLogo,
  EefProgramRecord,
  EefUniversityFile,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.types';

const PORTAL = 'https://data.enseignementsup-recherche.gouv.fr';
const API = `${PORTAL}/api/explore/v2.1/catalog/datasets`;
const LICENCE = 'Licence Ouverte v2.0 (Etalab)';
const USER_AGENT = 'KPBEducationEefCatalog/1.2 (educational catalog enrichment)';
const PARCOURSUP_YEAR = 2026;
const MASTER_YEAR = 2021;
const DIPLOMAS_YEAR = 2024;

async function fetchJson(url: string, headers: Record<string, string> = {}): Promise<any> {
  let lastError: unknown;
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      const response = await fetch(url, {
        headers: { accept: 'application/json', 'user-agent': USER_AGENT, ...headers },
      });
      if (response.status === 429 || response.status >= 500) {
        throw new Error(`HTTP ${response.status}`);
      }
      if (!response.ok) throw new Error(`HTTP ${response.status} ${url}`);
      return await response.json();
    } catch (error) {
      lastError = error;
      await new Promise((resolve) => setTimeout(resolve, 1200 * (attempt + 1)));
    }
  }
  throw new Error(`Collecte impossible (${url}) : ${String(lastError)}`);
}

async function fetchAll(dataset: string, where: string): Promise<any[]> {
  const rows: any[] = [];
  for (let offset = 0; ; offset += 100) {
    const params = new URLSearchParams({
      limit: '100',
      offset: String(offset),
      where,
    });
    const page = await fetchJson(`${API}/${dataset}/records?${params}`);
    rows.push(...page.results);
    if (rows.length >= page.total_count || page.results.length === 0) break;
  }
  return rows;
}

async function fetchAllChunked(
  dataset: string,
  prefix: string,
  field: string,
  values: readonly string[],
): Promise<any[]> {
  const rows: any[] = [];
  for (let index = 0; index < values.length; index += 12) {
    const chunk = values.slice(index, index + 12);
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

function readUniversities(): { file: string; data: EefUniversityFile }[] {
  return readdirSync(EEF_CATALOG_UNIVERSITIES_DIR)
    .filter((name) => name.endsWith('.json'))
    .sort()
    .map((file) => ({
      file,
      data: JSON.parse(
        readFileSync(join(EEF_CATALOG_UNIVERSITIES_DIR, file), 'utf8'),
      ) as EefUniversityFile,
    }));
}

function writeUniversity(file: string, data: EefUniversityFile): void {
  writeFileSync(
    join(EEF_CATALOG_UNIVERSITIES_DIR, file),
    `${JSON.stringify(data, null, 2)}\n`,
    'utf8',
  );
}

function knownUais(rows: { data: EefUniversityFile }[]): Set<string> {
  const out = new Set<string>();
  for (const row of rows) {
    for (const code of row.data.institution.uai.split(';')) {
      const trimmed = code.trim().toUpperCase();
      if (trimmed) out.add(trimmed);
    }
  }
  return out;
}

async function fetchMergeMap(): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  for (let offset = 0; ; offset += 100) {
    const params = new URLSearchParams({
      limit: '100',
      offset: String(offset),
      select: 'etablissement_id_paysage_source,etablissement_id_paysage_actuel',
      group_by: 'etablissement_id_paysage_source,etablissement_id_paysage_actuel',
    });
    const page = await fetchJson(`${API}/${DIPLOMAS_DATASET_ID}/records?${params}`);
    for (const row of page.results) {
      const from = (row.etablissement_id_paysage_source ?? '').trim();
      const to = (row.etablissement_id_paysage_actuel ?? '').trim();
      if (from && to) map.set(from, to);
    }
    if (page.results.length < 100) break;
  }
  return map;
}

async function addMissingInstitutions(
  existing: { data: EefUniversityFile }[],
): Promise<number> {
  const present = knownUais(existing);
  const wanted = ADDITIONAL_DEGREE_GRANTING.map((row) => row.uai).filter(
    (uai) => !present.has(uai.toUpperCase()),
  );
  if (wanted.length === 0) {
    console.log('Établissements hors typologie : déjà tous présents.');
    return 0;
  }
  const raws = (await fetchAllChunked(
    'fr-esr-principaux-etablissements-enseignement-superieur',
    'secteur_d_etablissement="public"',
    'uai',
    wanted,
  )) as RawInstitution[];
  const institutions: EefInstitutionRecord[] = [];
  const byPaysage = new Map<string, EefInstitutionRecord>();
  for (const raw of raws) {
    const built = buildInstitution(raw);
    if (!built) {
      console.log(`  écarté (fiche incomplète) : ${(raw.uo_lib ?? '').trim()}`);
      continue;
    }
    const kind = institutionKindForUai(built.uai);
    if (!kind) continue;
    const codes = built.uai.split(';').map((code) => code.trim().toUpperCase());
    if (codes.some((code) => present.has(code))) continue;
    for (const code of codes) present.add(code);
    const institution: EefInstitutionRecord = { ...built, institutionKind: kind };
    institutions.push(institution);
    const paysage = (raw.etablissement_id_paysage ?? '').trim();
    if (paysage) byPaysage.set(paysage, institution);
  }

  const paysageIds = [...byPaysage.keys()];
  console.log(
    `Établissements à ajouter : ${institutions.length} (${paysageIds.length} identifiants paysage)`,
  );
  if (paysageIds.length === 0) return 0;

  const parcoursup = buildParcoursupPrograms(
    (await fetchAllChunked(
      'fr-esr-cartographie_formations_parcoursup',
      `annee=${PARCOURSUP_YEAR}`,
      'etablissement_id_paysage',
      paysageIds,
    )) as RawParcoursupRow[],
    byPaysage,
  );
  console.log(
    `  premier cycle : ${parcoursup.records.length} `
    + JSON.stringify(countRejections(parcoursup.rejected)),
  );

  const mentions = (await fetchAll(
    'fr-esr-tmm-donnees-du-portail-dinformation-trouver-mon-master-mentions-de-master',
    `annee=${MASTER_YEAR}`,
  )) as RawMasterMention[];
  const tracks = (await fetchAll(
    'fr-esr-tmm-donnees-du-portail-dinformation-trouver-mon-master-parcours-de-format',
    `annee=${MASTER_YEAR}`,
  )) as RawMasterTrack[];
  const masters = buildMasterPrograms(
    mentions,
    tracks,
    byPaysage,
    await fetchMergeMap(),
  );
  console.log(
    `  masters : ${masters.records.length} `
    + JSON.stringify(countRejections(masters.rejected)),
  );

  const knownLabels = buildLabelIndex([
    ...existing.flatMap((row) => row.data.programs),
    ...parcoursup.records,
    ...masters.records,
  ]);
  const licenceSelect = [
    'etablissement_id_paysage_actuel',
    'etablissement_actuel_lib',
    'libelle_intitule_1',
    'niveau',
    'implantation_commune',
    'diplom',
  ].join(',');
  const licenceWhere =
    `rentree=${DIPLOMAS_YEAR} and diplome_rgp="Licence" and (niveau="02" or niveau="03")`;
  const licenceRows: RawLicenceYearRow[] = [];
  for (let offset = 0; ; offset += 100) {
    const params = new URLSearchParams({
      limit: '100',
      offset: String(offset),
      where: licenceWhere,
      select: licenceSelect,
      group_by: licenceSelect,
    });
    const page = await fetchJson(`${API}/${DIPLOMAS_DATASET_ID}/records?${params}`);
    licenceRows.push(...(page.results as RawLicenceYearRow[]));
    if (page.results.length < 100) break;
  }
  const licenceYears = buildLicenceContinuationPrograms(
    licenceRows,
    byPaysage,
    knownLabels,
    DIPLOMAS_YEAR,
  );
  console.log(
    `  L2/L3 : ${licenceYears.records.length} `
    + JSON.stringify(countRejections(licenceYears.rejected)),
  );

  const byId = new Map<string, EefProgramRecord[]>();
  for (const program of [
    ...parcoursup.records,
    ...masters.records,
    ...licenceYears.records,
  ]) {
    const bucket = byId.get(program.institutionId) ?? [];
    bucket.push(program);
    byId.set(program.institutionId, bucket);
  }

  let written = 0;
  for (const institution of institutions) {
    const programs = (byId.get(institution.id) ?? []).sort((a, b) =>
      a.id.localeCompare(b.id),
    );
    if (programs.length === 0) {
      console.log(`  sans formation joinable : ${institution.nameFr}`);
      continue;
    }
    const file = `${slugify(institution.nameFr)}-${institution.uai.split(';')[0].toLowerCase()}.json`;
    writeUniversity(file, { institution, programs });
    written += 1;
    console.log(`  + ${institution.nameFr} (${programs.length})`);
  }
  return written;
}

async function fetchCohorts(
  codes: readonly string[],
): Promise<Map<string, EefAdmissionCohort>> {
  const out = new Map<string, EefAdmissionCohort>();
  const unique = [...new Set(codes.filter((code) => /^\d+$/.test(code)))];
  for (let index = 0; index < unique.length; index += 15) {
    const chunk = unique.slice(index, index + 15);
    const clause = chunk.map((code) => `cod_aff_form="${code}"`).join(' or ');
    const params = new URLSearchParams({
      limit: '100',
      where: `session="${ADMISSION_SESSION}" and (${clause})`,
      select: [
        'cod_aff_form',
        'acc_neobac',
        'acc_sansmention',
        'acc_ab',
        'acc_b',
        'acc_tb',
        'acc_tbf',
        'taux_acces_ens',
        'ran_grp1',
      ].join(','),
    });
    const page = await fetchJson(
      `${API}/fr-esr-parcoursup/records?${params}`,
    );
    for (const row of page.results as Record<string, unknown>[]) {
      const cohort = cohortFromParcoursupRow(row);
      const code = formationCodeOfRow(row);
      if (cohort && code) out.set(code, cohort);
    }
    if (index % 150 === 0) {
      console.log(`  profils d'admission : ${out.size} / ${unique.length} codes demandés`);
    }
  }
  return out;
}

function fileTitle(value: string): string | null {
  try {
    const url = new URL(value);
    const path = decodeURIComponent(url.pathname);
    const special = path.indexOf('/Special:FilePath/');
    if (special >= 0) {
      const name = path.slice(special + '/Special:FilePath/'.length).split('/')[0];
      return name ? `File:${name}` : null;
    }
    const wiki = path.indexOf('/wiki/File:');
    if (wiki >= 0) return `File:${path.slice(wiki + '/wiki/File:'.length)}`;
    return null;
  } catch {
    return null;
  }
}

async function fetchLogos(uais: readonly string[]): Promise<Map<string, EefLogo>> {
  const wanted = new Set(uais.map((uai) => uai.toUpperCase()));
  const values = [...wanted].map((uai) => `"${uai}"`).join(' ');
  const query = `
    SELECT ?uai ?item ?logo WHERE {
      VALUES ?uai { ${values} }
      ?item wdt:P3202 ?uai .
      ?item wdt:P154 ?logo .
    }`;
  const sparql = await fetchJson(
    `https://query.wikidata.org/sparql?format=json&query=${encodeURIComponent(query)}`,
    { accept: 'application/sparql-results+json' },
  );
  const candidates: { uai: string; wikidataId: string; title: string }[] = [];
  for (const row of sparql.results?.bindings ?? []) {
    const uai = String(row.uai?.value ?? '').toUpperCase();
    if (!wanted.has(uai)) continue;
    const item = String(row.item?.value ?? '');
    const wikidataId = item.split('/').pop() ?? '';
    const title = fileTitle(String(row.logo?.value ?? ''));
    if (!title || !/^Q\d+$/.test(wikidataId)) continue;
    candidates.push({ uai, wikidataId, title });
  }

  const byTitle = new Map<string, { url: string; page: string; licence: string; restrictions: string }>();
  for (let index = 0; index < candidates.length; index += 40) {
    const chunk = candidates.slice(index, index + 40);
    const params = new URLSearchParams({
      action: 'query',
      format: 'json',
      prop: 'imageinfo',
      iiprop: 'url|extmetadata',
      titles: chunk.map((row) => row.title).join('|'),
    });
    const page = await fetchJson(`https://commons.wikimedia.org/w/api.php?${params}`);
    for (const info of Object.values(page.query?.pages ?? {}) as any[]) {
      const image = info.imageinfo?.[0];
      if (!image?.url || !image.descriptionurl) continue;
      const meta = image.extmetadata ?? {};
      byTitle.set(info.title, {
        url: image.url,
        page: image.descriptionurl,
        licence: meta.LicenseShortName?.value ?? '',
        restrictions: meta.Restrictions?.value ?? '',
      });
    }
  }

  const out = new Map<string, EefLogo>();
  for (const candidate of candidates) {
    if (out.has(candidate.uai)) continue;
    const meta = byTitle.get(candidate.title);
    if (!meta) continue;
    const logo = logoFromCommons({
      wikidataId: candidate.wikidataId,
      fileUrl: meta.url.split('?')[0],
      filePage: meta.page.startsWith('http://')
        ? `https://${meta.page.slice('http://'.length)}`
        : meta.page,
      licence: meta.licence.replace(/<[^>]+>/g, ''),
      restrictions: meta.restrictions.replace(/<[^>]+>/g, ''),
    });
    if (logo) out.set(candidate.uai, logo);
  }
  return out;
}

function logoForInstitution(
  institution: EefInstitutionRecord,
  logos: ReadonlyMap<string, EefLogo>,
): EefLogo | null {
  for (const code of institution.uai.split(';')) {
    const logo = logos.get(code.trim().toUpperCase());
    if (logo) return logo;
  }
  return null;
}

async function main(): Promise<void> {
  const before = readUniversities();
  const added = await addMissingInstitutions(before);
  const rows = readUniversities();

  const codes = rows.flatMap((row) =>
    row.data.programs
      .filter((program) => program.dataset === 'parcoursup')
      .map((program) => program.formationCode),
  );
  console.log(`Jointure Parcoursup ${ADMISSION_SESSION} : ${new Set(codes).size} codes`);
  const cohorts = await fetchCohorts(codes);
  console.log(`Profils retenus : ${cohorts.size}`);

  const uais = rows.flatMap((row) =>
    row.data.institution.uai.split(';').map((code) => code.trim()),
  );
  const logos = await fetchLogos(uais);
  console.log(`Logos réutilisables : ${logos.size}`);

  let cohortAttached = 0;
  let logosAttached = 0;
  for (const row of rows) {
    const logo = logoForInstitution(row.data.institution, logos);
    if (logo) logosAttached += 1;
    const { logo: _previousLogo, ...institution } = row.data.institution;
    const programs = row.data.programs.map((program) => {
      const { admissionCohort: _previous, ...rest } = program;
      const cohort =
        program.dataset === 'parcoursup'
          ? cohorts.get(program.formationCode)
          : undefined;
      if (!cohort) return rest;
      cohortAttached += 1;
      return { ...rest, admissionCohort: cohort };
    });
    writeUniversity(row.file, {
      institution: logo ? { ...institution, logo } : institution,
      programs,
    });
  }

  const manifest = JSON.parse(
    readFileSync(join(EEF_CATALOG_DATA_DIR, 'manifest.json'), 'utf8'),
  ) as EefCatalogManifest;
  const programCount = rows.reduce((sum, row) => sum + row.data.programs.length, 0);
  const admissionSource: EefCatalogSource = {
    dataset: 'parcoursup',
    datasetId: 'fr-esr-parcoursup',
    portal: PORTAL,
    licence: LICENCE,
    query: `session=${ADMISSION_SESSION} and cod_aff_form in (formations Parcoursup du catalogue)`,
    vintage: ADMISSION_SESSION,
    fetchedAt: new Date().toISOString(),
    rowCount: cohorts.size,
  };
  const sources = [
    ...manifest.sources.filter((source) => source.datasetId !== admissionSource.datasetId),
    admissionSource,
  ];
  const next: EefCatalogManifest = {
    ...manifest,
    catalogVersion: '1.2.0',
    institutionCount: rows.length,
    programCount,
    sources,
  };
  writeFileSync(
    join(EEF_CATALOG_DATA_DIR, 'manifest.json'),
    `${JSON.stringify(next, null, 2)}\n`,
    'utf8',
  );
  console.log(
    JSON.stringify(
      {
        addedInstitutions: added,
        institutions: rows.length,
        programs: programCount,
        cohortAttached,
        logosAttached,
        source: ADMISSION_SOURCE_URL,
      },
      null,
      2,
    ),
  );
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
