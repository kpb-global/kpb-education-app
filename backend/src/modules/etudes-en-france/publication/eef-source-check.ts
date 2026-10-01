import { readFileSync } from 'node:fs';
import { join } from 'node:path';

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
 * du ministère, qui répondent) : environ un quart de ces adresses est morte. Elles
 * viennent surtout des masters du jeu « Trouver mon master » de 2021.
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

const LANGUAGE_ROOT = /^(?:\/[a-z]{2}(?:-[a-z]{2})?)?(?:\/(?:index|accueil)\.(?:html?|php))?\/?$/i;

/** `requested` est une page profonde, `final` la racine du même site. */
export function redirectedToHome(requested: string, final: string): boolean {
  try {
    const from = new URL(requested);
    const to = new URL(final);
    if (from.hostname.replace(/^www\./, '') !== to.hostname.replace(/^www\./, '')) {
      return false;
    }
    const fromIsRoot = LANGUAGE_ROOT.test(from.pathname) && from.search === '';
    return !fromIsRoot && LANGUAGE_ROOT.test(to.pathname) && to.search === '';
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
  if (dead.length === 0 && (totals.dead as number) > 0) {
    throw new Error(
      'Rapport de contrôle incohérent : des pages mortes sont annoncées, aucune n’est listée.',
    );
  }
  return {
    checkedAt: raw.checkedAt,
    method: raw.method,
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
