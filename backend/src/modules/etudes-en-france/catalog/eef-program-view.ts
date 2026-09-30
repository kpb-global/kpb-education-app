// ─────────────────────────────────────────────────────────────────────────────
// La formation telle que l'espace « Études en France » la sert.
//
// `mapProgram` est celui du catalogue général : il ne porte ni la procédure, ni
// le cycle, ni l'établissement, parce que le catalogue général n'en a pas l'usage.
// Ici, si : « L1 - Droit » est proposée par quarante universités, et une carte qui
// n'en nomme aucune est inutilisable pour choisir.
//
// Les champs ajoutés sont des AJOUTS : le corps de `mapProgram` est repris tel
// quel, donc un client qui ne connaît que lui continue de tout lire.
// ─────────────────────────────────────────────────────────────────────────────
import type { Program } from '@prisma/client';

import { mapProgram } from '../../catalog/catalog.mapper';
import { commonsRasterDisplayUrl } from './eef-catalog.admission';
import type { PublishedInstitution } from './eef-published-institutions';

type Localized = { fr: string; en: string };

function localized(fr?: string | null, en?: string | null): Localized {
  return { fr: fr ?? '', en: en ?? fr ?? '' };
}

/// L'établissement, en résumé : ce qu'il faut pour le nommer sur une carte, le
/// situer et afficher son logo AVEC sa licence. La présentation et l'effectif
/// restent sur la fiche de l'établissement.
export function mapEefInstitutionSummary(institution: PublishedInstitution) {
  return {
    id: institution.id,
    name: localized(institution.nameFr, institution.nameEn),
    acronym: institution.acronym,
    location: localized(institution.locationFr, institution.locationEn),
    institutionType: institution.institutionType,
    websiteUrl: institution.websiteUrl,
    logoUrl: institution.logoUrl
      ? commonsRasterDisplayUrl(institution.logoUrl)
      : null,
    logoSourceUrl: institution.logoSourceUrl,
    logoLicence: institution.logoLicence,
  };
}

export function mapEefProgram(
  row: Program,
  institutions: ReadonlyMap<string, PublishedInstitution>,
) {
  const institution = institutions.get(row.institutionId);
  return {
    ...mapProgram(row),
    procedureType: row.procedureType,
    cycle: row.cycle,
    selectivity: row.selectivity,
    campusCity: row.campusCity,
    formationCode: row.formationCode,
    recommendedBachelors: row.recommendedBachelors,
    admissionModes: row.admissionModes,
    // Null seulement si l'établissement n'est plus dans la liste lue — ce que la
    // clause `institutionId IN (…)` de la requête exclut déjà. Servi en clair
    // plutôt que supposé impossible : le client ne plante pas sur un null.
    institution: institution ? mapEefInstitutionSummary(institution) : null,
  };
}
