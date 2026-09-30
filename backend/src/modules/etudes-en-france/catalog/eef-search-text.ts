// ─────────────────────────────────────────────────────────────────────────────
// Le texte cherchable — UNE définition, pour l'import, le rattrapage et la
// requête.
//
// POURQUOI UN TEXTE NORMALISÉ, ET PAS UN `ILIKE`
//
// `ILIKE` ignore la casse et RIEN d'autre. Les intitulés du catalogue mêlent les
// deux graphies (313 « economie », 47 « économie » ; 507 « génie », 1 « genie »)
// et la plupart des claviers de téléphone n'ont pas d'accents à portée de doigt :
// taper « genie » ne trouvait qu'1 formation sur 508, sans que l'étudiant puisse
// le deviner. La comparaison se fait donc entre deux chaînes PASSÉES PAR LA MÊME
// FONCTION — celle de la ligne, écrite une fois à l'import, et celle du mot tapé.
//
// Si l'une des deux moitiés change de règle sans l'autre, la recherche ne plante
// pas : elle cesse de trouver, en silence. C'est pourquoi la règle vit ici et
// nulle part ailleurs.
//
// DIFFÉRENT DE `normalizeLabel` À DESSEIN
//
// `normalizeLabel` classe les formations par domaine (mots-clés) : ses résultats
// sont figés par des tests de données, et en changer la règle déplacerait des
// milliers de lignes d'un domaine à l'autre. Celle-ci n'a aucune incidence sur un
// classement ; elle ne sert qu'à faire se rencontrer deux chaînes.
// ─────────────────────────────────────────────────────────────────────────────

/// Minuscules, sans accents, toute ponctuation en espace. « Génie civil » et
/// « GENIE-CIVIL » donnent la même chose : « genie civil ».
///
/// Les ligatures (œ, æ) et « ß » ne se décomposent pas en NFD : elles sont
/// réécrites à la main, sinon « cœur » ne rencontrerait jamais « coeur ».
export function normalizeSearchText(raw: string | null | undefined): string {
  return (raw ?? '')
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/œ/g, 'oe')
    .replace(/æ/g, 'ae')
    .replace(/ß/g, 'ss')
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

/// Ce qu'on écrit dans `Program.searchText` : l'intitulé ET la ville, pour que
/// « besancon » trouve Besançon comme « droit » trouve le droit.
export function programSearchText(
  nameFr: string,
  campusCity: string | null | undefined,
): string {
  return normalizeSearchText(`${nameFr} ${campusCity ?? ''}`);
}
