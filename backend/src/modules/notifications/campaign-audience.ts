/**
 * Les audiences de campagne, et le filtre que chacune EXIGE.
 *
 * Source unique : le DTO valide `audienceType` sur ces clés, l'exécuteur s'en
 * sert pour refuser de résoudre une audience dont le filtre manque, et un test
 * vérifie que l'exécuteur a bien une branche par clé.
 *
 * ── Pourquoi une valeur « exigée » ────────────────────────────────────────
 *
 * `resolveRecipients` construisait `where: filtre ? {…} : undefined` pour
 * `case_status`, `account_type` et `country_of_residence`. Or `where:
 * undefined` en Prisma ne veut pas dire « personne » : il veut dire « aucun
 * filtre », donc TOUS LES COMPTES. Un filtre oublié ou mal orthographié
 * transformait un envoi ciblé en diffusion à toute la base. `study_level`
 * retombait de même sur tous les étudiants.
 *
 * Le dépôt connaissait pourtant la règle — `country` porte depuis toujours le
 * commentaire « A missing filter must NOT fall through to "everyone" » et rend
 * un tableau vide, tout comme `single_user`. Elle n'était appliquée qu'à deux
 * audiences sur six.
 *
 * On échoue donc FERMÉ, partout : filtre absent ⇒ zéro destinataire. Envoyer à
 * personne est un incident qu'on constate et qu'on corrige ; envoyer à tout le
 * monde ne se rattrape pas.
 */
export const AUDIENCE_REQUIRED_FILTER: Readonly<Record<string, string | null>> =
  Object.freeze({
    // Diffusions assumées : leur nom DIT qu'elles visent tout le monde.
    all_users: null,
    all_students: null,
    // Les déclarants « Études en France » : l'ensemble est BORNÉ PAR LA TABLE
    // `EefInterest` (seuls ceux qui ont déclaré leur intérêt), pas par un filtre —
    // elle ne peut donc pas retomber sur « tout le monde ». `exceptCountries` est
    // OPTIONNEL : il retire les pays où la procédure est suspendue.
    eef_interest: null,
    // Audiences ciblées : sans leur filtre, elles ne visent personne.
    country: 'countryId',
    country_of_residence: 'countryCode',
    case_status: 'status',
    account_type: 'accountType',
    study_level: 'levels',
    // Tous les étudiants SAUF des pays donnés. Le filtre est exigé : une exclusion
    // vide serait « tous les étudiants », c'est-à-dire la diffusion que le nom de
    // cette audience prétend éviter.
    all_students_except_countries: 'exceptCountries',
    single_user: 'userId',
  });

export const AUDIENCE_TYPES = Object.keys(AUDIENCE_REQUIRED_FILTER);

/** Le filtre exigé par cette audience est-il présent et non vide ? */
export function audienceFilterMissing(
  audienceType: string,
  filters: Record<string, unknown>,
): boolean {
  const key = AUDIENCE_REQUIRED_FILTER[audienceType];
  if (!key) return false;
  const value = filters[key];
  if (value === undefined || value === null) return true;
  if (typeof value === 'string') return value.trim() === '';
  if (Array.isArray(value)) return value.length === 0;
  return false;
}

/**
 * Le jeton qui désigne « les pays où la procédure Études en France est
 * suspendue », lus dans `KPB_EEF_SUSPENDED_COUNTRIES` — la MÊME liste que celle
 * que `/config/app` sert à l'app.
 *
 * Écrire `["Niger","NE"]` à la main dans chaque campagne est ce qui fait oublier
 * un pays le jour où la liste change : une campagne « la campagne est ouverte »
 * partirait vers un pays dont l'État dit que les dossiers ne sont pas traités.
 * Avec ce jeton, la campagne suit la liste de l'exploitation.
 */
export const EEF_SUSPENDED_COUNTRIES_TOKEN = 'eef_suspended';

/**
 * Les pays à EXCLURE, depuis le filtre `exceptCountries` : une liste, une chaîne
 * séparée par des virgules, ou le jeton [EEF_SUSPENDED_COUNTRIES_TOKEN] (qui
 * peut aussi figurer DANS la liste, à côté d'autres pays).
 *
 * Dédoublonné et sans blancs. Vide quand rien n'est lisible : l'appelant décide
 * alors quoi en faire (`all_students_except_countries` échoue fermé, avant même
 * de venir ici ; `eef_interest` n'exclut simplement personne).
 */
export function resolveExcludedCountries(
  value: unknown,
  env: NodeJS.ProcessEnv = process.env,
): string[] {
  const raw: unknown[] = Array.isArray(value)
    ? value
    : typeof value === 'string'
      ? value.split(',')
      : [];

  const out = new Set<string>();
  for (const entry of raw) {
    if (typeof entry !== 'string') continue;
    const trimmed = entry.trim();
    if (!trimmed) continue;
    if (trimmed.toLowerCase() === EEF_SUSPENDED_COUNTRIES_TOKEN) {
      for (const country of (env.KPB_EEF_SUSPENDED_COUNTRIES ?? '').split(
        ',',
      )) {
        const name = country.trim();
        if (name) out.add(name);
      }
      continue;
    }
    out.add(trimmed);
  }
  return [...out];
}
