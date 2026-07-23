// ─────────────────────────────────────────────────────────────────────────────
// Approximate UTC offset (whole hours) by country of residence.
//
// Used only to gate time-of-day-sensitive pushes (quiet hours). `countryOfResidence`
// is a free-form string captured at onboarding and is NOT normalized, so we match
// case/accent-insensitively against ISO-3166 alpha-2, alpha-3, and common FR/EN
// names.
//
// Offsets deliberately ignore DST and half-hour zones: quiet hours is a soft guard
// (don't ping someone at 3am), not a scheduler, so ±1h at the margins is fine.
// Unknown or empty values fall back to UTC+0 (GMT) — the modal offset for
// francophone West Africa (Senegal, Mali, Côte d'Ivoire, Burkina Faso, Guinea…).
// ─────────────────────────────────────────────────────────────────────────────

export const DEFAULT_UTC_OFFSET_HOURS = 0;

/** Normalize a free-form country string: lowercase, strip accents, collapse
 *  every run of non-alphanumeric characters to a single space, trim. */
function normalize(value: string): string {
  return value
    .normalize('NFD')
    .replace(/\p{Diacritic}/gu, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

// Human-readable aliases per offset. Kept compact and focused on the KPB market
// (francophone Africa) plus the app's study destinations, since a parent may
// reside abroad. Normalized at module load into `OFFSET_BY_KEY`.
const OFFSET_ALIASES: Array<{ offset: number; aliases: string[] }> = [
  {
    offset: 0,
    aliases: [
      'SN', 'SEN', 'Senegal', 'Sénégal',
      'ML', 'MLI', 'Mali',
      'CI', 'CIV', "Côte d'Ivoire", 'Cote d Ivoire', 'Ivory Coast',
      'BF', 'BFA', 'Burkina Faso',
      'GN', 'GIN', 'Guinea', 'Guinée',
      'TG', 'TGO', 'Togo',
      'MR', 'MRT', 'Mauritania', 'Mauritanie',
      'GM', 'GMB', 'Gambia',
      'GH', 'GHA', 'Ghana',
      'GB', 'GBR', 'United Kingdom', 'Royaume-Uni', 'UK',
      'PT', 'PRT', 'Portugal',
    ],
  },
  {
    offset: 1,
    aliases: [
      'NE', 'NER', 'Niger',
      'NG', 'NGA', 'Nigeria',
      'BJ', 'BEN', 'Benin', 'Bénin',
      'CM', 'CMR', 'Cameroon', 'Cameroun',
      'TD', 'TCD', 'Chad', 'Tchad',
      'GA', 'GAB', 'Gabon',
      'CG', 'COG', 'Congo', 'Republic of the Congo',
      'CD', 'COD', 'DR Congo', 'RDC', 'République Démocratique du Congo',
      'CF', 'CAF', 'Central African Republic', 'Centrafrique',
      'DZ', 'DZA', 'Algeria', 'Algérie',
      'TN', 'TUN', 'Tunisia', 'Tunisie',
      'MA', 'MAR', 'Morocco', 'Maroc',
      'FR', 'FRA', 'France',
      'BE', 'BEL', 'Belgium', 'Belgique',
      'DE', 'DEU', 'Germany', 'Allemagne',
      'ES', 'ESP', 'Spain', 'Espagne',
      'IT', 'ITA', 'Italy', 'Italie',
      'CH', 'CHE', 'Switzerland', 'Suisse',
    ],
  },
  {
    offset: 2,
    aliases: [
      'EG', 'EGY', 'Egypt', 'Égypte',
      'ZA', 'ZAF', 'South Africa', 'Afrique du Sud',
      'RW', 'RWA', 'Rwanda',
      'BI', 'BDI', 'Burundi',
    ],
  },
  {
    offset: 3,
    aliases: [
      'TR', 'TUR', 'Turkey', 'Turquie', 'Türkiye',
      'MG', 'MDG', 'Madagascar',
      'KE', 'KEN', 'Kenya',
      'SA', 'SAU', 'Saudi Arabia', 'Arabie Saoudite',
      'QA', 'QAT', 'Qatar',
    ],
  },
  {
    offset: 4,
    aliases: [
      'AE', 'ARE', 'United Arab Emirates', 'Émirats Arabes Unis', 'Emirats', 'UAE',
      'MU', 'MUS', 'Mauritius', 'Maurice',
    ],
  },
  {
    offset: 8,
    aliases: ['CN', 'CHN', 'China', 'Chine'],
  },
  {
    // Canada spans several zones; default to Eastern (Québec/Montréal), where
    // most KPB Canada-bound students settle. US default also Eastern.
    offset: -5,
    aliases: [
      'CA', 'CAN', 'Canada',
      'US', 'USA', 'United States', 'États-Unis', 'Etats Unis',
    ],
  },
];

const OFFSET_BY_KEY: Map<string, number> = (() => {
  const map = new Map<string, number>();
  for (const { offset, aliases } of OFFSET_ALIASES) {
    for (const alias of aliases) {
      map.set(normalize(alias), offset);
    }
  }
  return map;
})();

/** Whole-hour UTC offset for a residence string, or UTC+0 when unknown. */
export function utcOffsetHoursForCountry(country?: string | null): number {
  if (!country) return DEFAULT_UTC_OFFSET_HOURS;
  const key = normalize(country);
  if (!key) return DEFAULT_UTC_OFFSET_HOURS;
  return OFFSET_BY_KEY.get(key) ?? DEFAULT_UTC_OFFSET_HOURS;
}

/** Local hour (0–23) at `utcDate` for the given whole-hour offset. */
export function localHourFor(utcDate: Date, offsetHours: number): number {
  return (((utcDate.getUTCHours() + offsetHours) % 24) + 24) % 24;
}

/**
 * True when the local hour falls in the quiet window [startHour, endHour).
 * The window wraps midnight when startHour > endHour (e.g. 21 → 8 covers
 * 21,22,23,0,1,…,7). A degenerate start === end window is treated as "never
 * quiet" so a misconfiguration can never silence every push.
 */
export function isWithinQuietHours(
  utcDate: Date,
  offsetHours: number,
  startHour: number,
  endHour: number,
): boolean {
  if (startHour === endHour) return false;
  const hour = localHourFor(utcDate, offsetHours);
  return startHour > endHour
    ? hour >= startHour || hour < endHour
    : hour >= startHour && hour < endHour;
}
