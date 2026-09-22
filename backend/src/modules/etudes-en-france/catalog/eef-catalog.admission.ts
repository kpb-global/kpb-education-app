// Lecture des faits d'admission et des logos. Aucune phrase ici : la prose
// vit dans `eef-catalog.copy.ts`. Une ligne qui ne somme pas, ou un logo
// dont la licence n'autorise pas la réutilisation commerciale, est écartée.
import type { EefAdmissionCohort, EefLogo } from './eef-catalog.types';

export const ADMISSION_SESSION = '2025';
export const ADMISSION_SOURCE_URL =
  'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/';

function integer(value: unknown): number | null {
  if (typeof value === 'number' && Number.isInteger(value)) return value;
  if (typeof value === 'string' && /^-?\d+$/.test(value.trim())) {
    return Number.parseInt(value, 10);
  }
  return null;
}

function rate(value: unknown): number | null {
  if (value == null || value === '') return null;
  const parsed = typeof value === 'number' ? value : Number.parseFloat(String(value));
  if (!Number.isFinite(parsed) || parsed < 0 || parsed > 100) return null;
  return Math.round(parsed);
}

/**
 * Une ligne du jeu `fr-esr-parcoursup`. Retourne null si les mentions ne
 * retombent pas sur le nombre d'admis : on ne sert pas un profil bancal.
 */
export function cohortFromParcoursupRow(
  row: Record<string, unknown>,
): EefAdmissionCohort | null {
  const code = String(row.cod_aff_form ?? '').trim();
  if (code === '') return null;
  const admitted = integer(row.acc_neobac);
  const sansMention = integer(row.acc_sansmention);
  const assezBien = integer(row.acc_ab);
  const bien = integer(row.acc_b);
  const tresBien = integer(row.acc_tb);
  const tresBienFelicitations = integer(row.acc_tbf);
  if (
    admitted == null
    || sansMention == null
    || assezBien == null
    || bien == null
    || tresBien == null
    || tresBienFelicitations == null
  ) {
    return null;
  }
  if (
    sansMention + assezBien + bien + tresBien + tresBienFelicitations
    !== admitted
  ) {
    return null;
  }
  const rank = integer(row.ran_grp1);
  return {
    session: ADMISSION_SESSION,
    sourceUrl: ADMISSION_SOURCE_URL,
    admittedNeobac: admitted,
    sansMention,
    assezBien,
    bien,
    tresBien,
    tresBienFelicitations,
    accessRatePct: rate(row.taux_acces_ens),
    lastCalledRank: rank != null && rank > 0 ? rank : null,
  };
}

export function formationCodeOfRow(row: Record<string, unknown>): string {
  return String(row.cod_aff_form ?? '').trim();
}

/**
 * Licences Commons qui autorisent la réutilisation commerciale.
 *
 * `CC BY-NC` commence par `CC BY` : un préfixe ou `\bcc[ -]?by\b` l'accepte
 * alors que l'usage commercial est interdit. On refuse donc NC (et les
 * formulations « noncommercial ») AVANT d'accepter BY / BY-SA / CC0 / PD.
 */
export function logoLicenceAllowsCommercialReuse(licence: string): boolean {
  const normalized = licence.trim().toLowerCase().replace(/_/g, ' ');
  if (
    /\bnc\b/.test(normalized)
    || normalized.includes('noncommercial')
    || normalized.includes('non-commercial')
    || normalized.includes('non commercial')
  ) {
    return false;
  }
  if (normalized.includes('public domain') || /\bcc0\b/.test(normalized)) {
    return true;
  }
  return /\bcc[ -]?by(?:[ -]?sa)?\b/.test(normalized);
}

/**
 * Flutter et le codec raster d'`Image.network` ne décodent pas le SVG.
 * Commons publie un PNG miniature pour chaque SVG : on s'en sert à l'affichage,
 * le fichier source (et sa page) restent la référence de licence.
 */
export function commonsRasterDisplayUrl(
  fileUrl: string,
  width = 320,
): string {
  const cleaned = fileUrl.split('?')[0] ?? fileUrl;
  if (!/\.svg$/i.test(cleaned)) return fileUrl;
  const match = cleaned.match(
    /^https:\/\/upload\.wikimedia\.org\/wikipedia\/([^/]+)\/([0-9a-f])\/([0-9a-f]{2})\/([^/?#]+)$/i,
  );
  if (!match) return fileUrl;
  const [, project, hash1, hash2, filename] = match;
  return (
    `https://upload.wikimedia.org/wikipedia/${project}/thumb/`
    + `${hash1}/${hash2}/${filename}/${width}px-${filename}.png`
  );
}

/**
 * Métadonnées Commons (`extmetadata`). Null si la licence n'est pas
 * réutilisable commercialement, ou si l'URL du fichier n'est pas Wikimedia.
 */
export function logoFromCommons(input: {
  readonly wikidataId: string;
  readonly fileUrl: string;
  readonly filePage: string;
  readonly licence: string;
  readonly restrictions: string;
}): EefLogo | null {
  if (!logoLicenceAllowsCommercialReuse(input.licence)) return null;
  if (!input.fileUrl.startsWith('https://') || !input.fileUrl.includes('wikimedia.org')) {
    return null;
  }
  if (!input.filePage.startsWith('https://') || !/^Q\d+$/.test(input.wikidataId)) {
    return null;
  }
  return {
    url: input.fileUrl,
    sourceUrl: input.filePage,
    licence: input.licence.trim(),
    wikidataId: input.wikidataId,
    trademarked: /trademark/i.test(input.restrictions),
  };
}
