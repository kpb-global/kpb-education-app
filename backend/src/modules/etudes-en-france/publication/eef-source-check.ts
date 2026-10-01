import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import type { EefCatalog } from '../catalog/eef-catalog.types';
import { classifyProgramSource } from './eef-publication.plan';

/**
 * Le contrôle des pages-sources des formations de l'import « Études en France ».
 *
 * ## Pourquoi ce contrôle existe
 *
 * Le plan de publication (`eef-publication.plan.ts`) exige une source HTTPS : il
 * ne sait PAS si la page répond. Or le badge « Vérifié » promet qu'on a regardé une
 * page, et une fiche dont le lien renvoie 404 ne tient pas cette promesse — elle
 * dit à un candidat « voici la source » et le laisse devant une page d'erreur.
 *
 * Mesuré le 01/10/2026 sur les 2 150 formations dont la source est une page de
 * l'établissement (les autres pointent Parcoursup, Mon Master ou le jeu de données
 * du ministère, des portails) : plus d'une adresse sur cinq est morte. Elles
 * viennent toutes des masters du jeu « Trouver mon master » de 2021.
 *
 * ## Ce que le contrôle dit, et ce qu'il ne dit pas
 *
 * Il constate qu'une adresse répond ou non. Il ne lit pas la page : une page qui
 * répond 200 en disant « formation introuvable » passe. Et il ne conclut « morte »
 * qu'après DEUX constats concordants à des moments différents — un 403, un 5xx, un
 * délai dépassé ou un certificat mal servi ne prouvent pas qu'une page a disparu,
 * ils la rangent en « incertaine », qui n'écarte rien.
 */
export type SourceVerdict = 'ok' | 'dead' | 'uncertain';

/** Un passage sur une adresse : le statut HTTP final, ou 0 sans réponse HTTP. */
export interface SourceObservation {
  readonly status: number;
  /**
   * L'adresse a redirigé vers la RACINE du site (ou d'une langue) alors qu'elle
   * demandait une page profonde : l'ancienne fiche est retirée et le site renvoie
   * l'accueil avec un 200. Le statut seul le prendrait pour une page vivante.
   */
  readonly redirectedToHome: boolean;
}

function isGone(observation: SourceObservation): boolean {
  return (
    observation.status === 404
    || observation.status === 410
    || (observation.status >= 200
      && observation.status < 300
      && observation.redirectedToHome)
  );
}

/**
 * - `ok` : au moins un passage a trouvé une vraie page (un site qui répond une fois
 *   existe ; l'autre passage était une panne).
 * - `dead` : au moins deux passages, tous « disparue » (404, 410, ou redirigée vers
 *   l'accueil).
 * - `uncertain` : tout le reste, y compris un seul passage.
 */
export function sourceVerdict(
  observations: readonly SourceObservation[],
): SourceVerdict {
  if (
    observations.some(
      (o) => o.status >= 200 && o.status < 300 && !o.redirectedToHome,
    )
  ) {
    return 'ok';
  }
  if (observations.length >= 2 && observations.every(isGone)) return 'dead';
  return 'uncertain';
}

/**
 * Une « racine » de site : rien, une langue (`/fr`, `/en-gb`), un nom d'accueil
 * (`/index.html`, `/accueil/`, `/home`), ou les deux (`/fr/home/`).
 */
const SITE_ROOT = /^(?:\/[a-z]{2}(?:-[a-z]{2})?)?(?:\/(?:index|accueil|home)(?:\.(?:html?|php))?)?\/?$/i;
/** Une requête qui ne fait que choisir la langue ne change pas la page. */
const LANGUAGE_ONLY_QUERY = /^(?:\?(?:lang|language|locale|l)=[a-z-]{2,5})?$/i;

/** `www.univ-x.fr` et `formations.univ-x.fr` : le même site pour ce contrôle. */
function registrableDomain(hostname: string): string {
  return hostname.toLowerCase().split('.').slice(-2).join('.');
}

function isSiteRoot(url: URL): boolean {
  return SITE_ROOT.test(url.pathname) && LANGUAGE_ONLY_QUERY.test(url.search);
}

/** `requested` est une page profonde, `final` la racine du même site. */
export function redirectedToHome(requested: string, final: string): boolean {
  try {
    const from = new URL(requested);
    const to = new URL(final);
    if (registrableDomain(from.hostname) !== registrableDomain(to.hostname)) {
      return false;
    }
    return !isSiteRoot(from) && isSiteRoot(to);
  } catch {
    return false;
  }
}

export interface SourceCheckEntry {
  readonly programId: string;
  readonly institutionId: string;
  readonly url: string;
  /** Le dernier statut observé (0 : aucune réponse) et le nombre de passages. */
  readonly status: number;
  readonly passes: number;
  readonly redirectedToHome: boolean;
}

export interface SourceCheckReport {
  readonly checkedAt: string;
  readonly method: string;
  /**
   * `full` : toutes les pages d'établissement du catalogue. `partial` : un essai
   * (`--limit`) — un rapport partiel ne peut JAMAIS servir à publier.
   */
  readonly scope: 'full' | 'partial';
  /**
   * L'empreinte de ce qui devait être contrôlé (voir [scopeDigest]). Si le
   * catalogue est régénéré — une formation ajoutée, une adresse changée — elle ne
   * correspond plus, et le rapport est périmé même si chaque entrée citée existe.
   */
  readonly scopeDigest: string;
  readonly totals: {
    readonly programsChecked: number;
    readonly urlsChecked: number;
    readonly ok: number;
    readonly dead: number;
    readonly uncertain: number;
  };
  /** Écartées de la publication : la page a disparu, constat double. */
  readonly dead: readonly SourceCheckEntry[];
  /** Pas de preuve de disparition : publiées, à revoir. */
  readonly uncertain: readonly SourceCheckEntry[];
}

export const EEF_SOURCE_CHECK_FILE = join(__dirname, 'data', 'source-check.json');

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function parseEntries(value: unknown, where: string): SourceCheckEntry[] {
  if (!Array.isArray(value)) throw new Error(`${where} : une liste est attendue.`);
  return value.map((raw, index) => {
    if (
      !isRecord(raw)
      || typeof raw.programId !== 'string'
      || typeof raw.institutionId !== 'string'
      || typeof raw.url !== 'string'
      || typeof raw.status !== 'number'
      || typeof raw.passes !== 'number'
      || typeof raw.redirectedToHome !== 'boolean'
    ) {
      throw new Error(`${where}[${index}] : entrée illisible.`);
    }
    return {
      programId: raw.programId,
      institutionId: raw.institutionId,
      url: raw.url,
      status: raw.status,
      passes: raw.passes,
      redirectedToHome: raw.redirectedToHome,
    };
  });
}

/**
 * Les entrées d'une liste (`dead`, `uncertain`) doivent correspondre à son total.
 *
 * Le total compte des ADRESSES ; la liste compte des FORMATIONS, dont plusieurs
 * peuvent partager une adresse. Les adresses distinctes de la liste doivent donc être
 * exactement `total`. Sans cela, un fichier amputé de quelques entrées (une fusion de
 * git mal résolue, un éditeur qui tronque) resterait « non vide » et serait lu comme
 * complet : `deadProgramIds()` oublierait les formations perdues et la publication les
 * activerait malgré leur page morte. Des doublons de formation sont refusés pour la
 * même raison : ils cachent un manque derrière un compte juste.
 */
function assertEntriesMatchTotals(
  name: 'dead' | 'uncertain',
  entries: readonly SourceCheckEntry[],
  total: number,
): void {
  const urls = new Set(entries.map((entry) => entry.url));
  if (urls.size !== total) {
    throw new Error(
      `Rapport de contrôle incohérent : « ${name} » annonce ${total} adresse(s), la liste en porte ${urls.size}.`,
    );
  }
  if (new Set(entries.map((entry) => entry.programId)).size !== entries.length) {
    throw new Error(`Rapport de contrôle incohérent : « ${name} » contient une formation en double.`);
  }
}

/**
 * Lit un rapport en REFUSANT ce qui n'a pas la forme attendue. Un fichier tronqué
 * qui se lirait « aucune page morte » publierait tout ce qu'il devait écarter.
 */
export function parseSourceCheckReport(raw: unknown): SourceCheckReport {
  if (!isRecord(raw)) throw new Error('Rapport de contrôle illisible.');
  if (typeof raw.checkedAt !== 'string' || Number.isNaN(Date.parse(raw.checkedAt))) {
    throw new Error('Rapport de contrôle : `checkedAt` absent ou illisible.');
  }
  if (typeof raw.method !== 'string') {
    throw new Error('Rapport de contrôle : `method` absent.');
  }
  if (raw.scope !== 'full' && raw.scope !== 'partial') {
    throw new Error('Rapport de contrôle : `scope` doit valoir « full » ou « partial ».');
  }
  if (typeof raw.scopeDigest !== 'string' || !/^[0-9a-f]{64}$/.test(raw.scopeDigest)) {
    throw new Error('Rapport de contrôle : `scopeDigest` absent ou illisible.');
  }
  const totals = raw.totals;
  if (
    !isRecord(totals)
    || ['programsChecked', 'urlsChecked', 'ok', 'dead', 'uncertain'].some(
      (key) => typeof totals[key] !== 'number',
    )
  ) {
    throw new Error('Rapport de contrôle : `totals` incomplet.');
  }
  const dead = parseEntries(raw.dead, 'dead');
  const uncertain = parseEntries(raw.uncertain, 'uncertain');
  const counted = {
    programsChecked: totals.programsChecked as number,
    urlsChecked: totals.urlsChecked as number,
    ok: totals.ok as number,
    dead: totals.dead as number,
    uncertain: totals.uncertain as number,
  };
  assertEntriesMatchTotals('dead', dead, counted.dead);
  assertEntriesMatchTotals('uncertain', uncertain, counted.uncertain);
  if (counted.ok + counted.dead + counted.uncertain !== counted.urlsChecked) {
    throw new Error(
      'Rapport de contrôle incohérent : valides + mortes + incertaines ne font pas le nombre d’adresses contrôlées.',
    );
  }
  const listed = new Set<string>();
  for (const entry of [...dead, ...uncertain]) {
    if (listed.has(entry.programId)) {
      throw new Error(
        `Rapport de contrôle incohérent : la formation ${entry.programId} figure deux fois.`,
      );
    }
    listed.add(entry.programId);
  }
  if (listed.size > counted.programsChecked) {
    throw new Error(
      'Rapport de contrôle incohérent : plus de formations listées que de formations contrôlées.',
    );
  }
  return {
    checkedAt: raw.checkedAt,
    method: raw.method,
    scope: raw.scope,
    scopeDigest: raw.scopeDigest,
    totals: {
      programsChecked: totals.programsChecked as number,
      urlsChecked: totals.urlsChecked as number,
      ok: totals.ok as number,
      dead: totals.dead as number,
      uncertain: totals.uncertain as number,
    },
    dead,
    uncertain,
  };
}

export function loadSourceCheckReport(
  file: string = EEF_SOURCE_CHECK_FILE,
): SourceCheckReport {
  return parseSourceCheckReport(JSON.parse(readFileSync(file, 'utf8')) as unknown);
}

/** Les formations que la publication déléguée laisse en attente. */
export function deadProgramIds(report: SourceCheckReport): Set<string> {
  return new Set(report.dead.map((entry) => entry.programId));
}

// ── ce qui est contrôlé, et si le rapport est digne de servir à publier ───────

export interface CheckedPage {
  readonly programId: string;
  readonly institutionId: string;
  readonly url: string;
}

/**
 * Les formations dont la source est une PAGE D'ÉTABLISSEMENT. Les fiches Parcoursup,
 * la racine de Mon Master et le jeu de données du ministère sont des portails qui
 * répondent toujours : leur contrôle ne dirait rien de l'existence de la formation.
 */
export function checkedScope(catalog: EefCatalog): CheckedPage[] {
  const pages: CheckedPage[] = [];
  for (const university of catalog.universities) {
    for (const program of university.programs) {
      if (classifyProgramSource(program.sourceUrl) !== 'formation_page') continue;
      if (new URL(program.sourceUrl).hostname === 'dossierappel.parcoursup.fr') continue;
      pages.push({
        programId: program.id,
        institutionId: program.institutionId,
        url: program.sourceUrl,
      });
    }
  }
  return pages;
}

export function scopeDigest(pages: readonly CheckedPage[]): string {
  const lines = pages
    .map((page) => `${page.programId}\t${page.institutionId}\t${page.url}`)
    .sort();
  return createHash('sha256').update(lines.join('\n')).digest('hex');
}

/** Sous ces seuils, c'est le CONTRÔLE qui est en panne, pas les pages. */
export const MIN_OK_SHARE = 0.4;
export const MAX_UNCERTAIN_SHARE = 0.35;

/**
 * Le rapport est-il digne de décider ce qu'on publie ?
 *
 * Un rapport « frais et bien formé » n'est pas un rapport juste : avec un réseau
 * coupé, le sondage sort `0 valides, 0 mortes, 12 incertaines`, un fichier tout à
 * fait valide qui ne met AUCUNE formation en attente — c'est-à-dire qui publie les
 * pages mortes qu'il devait écarter (relevé en relecture indépendante).
 *
 * Refus si : partiel ; périmé par rapport au catalogue ; trop peu de pages valides
 * ou trop d'incertaines (le sondage lui-même est en cause).
 */
export function assertSourceCheckUsable(
  report: SourceCheckReport,
  catalog: EefCatalog,
): void {
  if (report.scope !== 'full') {
    throw new Error('Le contrôle des pages est un essai partiel : il ne peut pas servir à publier.');
  }
  const pages = checkedScope(catalog);
  if (report.scopeDigest !== scopeDigest(pages)) {
    throw new Error(
      'Le catalogue a changé depuis le contrôle des pages (formation ajoutée, retirée ou adresse modifiée) : '
        + 'relancer « npm run eef:check-sources ».',
    );
  }
  if (report.totals.programsChecked !== pages.length) {
    throw new Error(
      `Le contrôle annonce ${report.totals.programsChecked} formation(s) contrôlée(s), le catalogue en compte ${pages.length}.`,
    );
  }
  // Chaque adresse du rapport désigne TOUTES les formations qui la portent : une adresse
  // morte dont une formation manque dans `dead` laisserait cette formation publiée.
  const programsByUrl = new Map<string, string[]>();
  for (const page of pages) {
    programsByUrl.set(page.url, [...(programsByUrl.get(page.url) ?? []), page.programId]);
  }
  if (report.totals.urlsChecked !== programsByUrl.size) {
    throw new Error(
      `Le contrôle annonce ${report.totals.urlsChecked} adresse(s) contrôlée(s), le catalogue en compte ${programsByUrl.size}.`,
    );
  }
  const deadIds = deadProgramIds(report);
  for (const entry of report.dead) {
    const missing = (programsByUrl.get(entry.url) ?? []).filter((id) => !deadIds.has(id));
    if (missing.length > 0) {
      throw new Error(
        `Rapport de contrôle incomplet : l'adresse morte de ${entry.programId} porte aussi ${missing.length} formation(s) absente(s) de « dead ».`,
      );
    }
  }
  const urls = report.totals.urlsChecked;
  if (urls === 0 || report.totals.ok / urls < MIN_OK_SHARE) {
    throw new Error(
      `Seulement ${report.totals.ok} page(s) valide(s) sur ${urls} : le sondage est probablement en panne `
        + `(réseau, blocage) plutôt que les pages. Seuil : ${MIN_OK_SHARE * 100} %.`,
    );
  }
  if (report.totals.uncertain / urls > MAX_UNCERTAIN_SHARE) {
    throw new Error(
      `${report.totals.uncertain} page(s) incertaine(s) sur ${urls} : le sondage est trop incomplet pour décider `
        + `ce qu'on publie. Seuil : ${MAX_UNCERTAIN_SHARE * 100} %.`,
    );
  }
}
