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
export const AUDIENCE_REQUIRED_FILTER: Readonly<
  Record<string, string | null>
> = Object.freeze({
  // Diffusions assumées : leur nom DIT qu'elles visent tout le monde.
  all_users: null,
  all_students: null,
  // Audiences ciblées : sans leur filtre, elles ne visent personne.
  country: 'countryId',
  country_of_residence: 'countryCode',
  case_status: 'status',
  account_type: 'accountType',
  study_level: 'levels',
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
