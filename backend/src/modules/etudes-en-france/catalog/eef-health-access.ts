// ─────────────────────────────────────────────────────────────────────────────
// Une 1re année d'accès santé — un PASS ou une L.AS. Une seule définition, pour
// la recherche (« médecine » y mène) comme pour la carte (le badge « Accès
// santé » la nomme).
//
// POURQUOI PAS SIMPLEMENT LE CYCLE `sante`
//
// Le cycle `sante` reprend la famille « Études de santé » de Parcoursup. Elle
// compte, mesuré le 01/10/2026 sur le catalogue publié, 650 formations :
//
//   • 589 premières années — 205 PASS et 384 L.AS (« L1 - Droit », « L1 -
//     Chimie »…). C'est par elles qu'on entre en médecine, maïeutique,
//     odontologie, pharmacie ou kinésithérapie ;
//   • 61 diplômes paramédicaux — orthophoniste, orthoptiste, audioprothésiste,
//     psychomotricien, ergothérapeute, BTS opticien-lunetier, deux C.M.I…
//
// Mener « médecine » aux 650, triées par intitulé, mettait les 61 paramédicales
// EN TÊTE : aucune PASS ni L.AS dans les 50 premiers résultats. Et le badge
// « Accès santé » s'affichait sur un certificat d'orthophoniste, qui n'en est pas
// un. Ces diplômes se trouvent par leurs propres mots ; « santé » mène toujours à
// toute la famille.
//
// Le signe distinctif est l'intitulé : Parcoursup préfixe la filière (« L1 - »)
// et toutes les premières années de la famille, et elles seules, le portent.
// ─────────────────────────────────────────────────────────────────────────────

/// Le cycle de la famille « Études de santé ».
export const EEF_HEALTH_CYCLE = 'sante';

/// Le préfixe que Parcoursup donne aux premières années de licence, PASS et L.AS
/// comprises.
export const EEF_FIRST_YEAR_PREFIX = 'L1 - ';

/// Vrai pour un PASS ou une L.AS.
export function isHealthAccessYear(row: {
  readonly cycle: string | null;
  readonly nameFr: string;
}): boolean {
  return (
    row.cycle === EEF_HEALTH_CYCLE
    && row.nameFr.startsWith(EEF_FIRST_YEAR_PREFIX)
  );
}

/// La même définition, en clause Prisma. Sensible à la casse comme
/// `startsWith` : c'est l'intitulé tel que l'import l'écrit.
export function healthAccessYearWhere(): Record<string, unknown> {
  return {
    cycle: EEF_HEALTH_CYCLE,
    nameFr: { startsWith: EEF_FIRST_YEAR_PREFIX },
  };
}
