/**
 * La règle « quel cycle décrit l'état actuel de cette bourse » : un cycle
 * OUVERT, sinon une PRÉVISION, sinon le premier.
 *
 * ## Pourquoi elle est extraite ici alors qu'elle tient en trois lignes
 *
 * Elle était dupliquée sciemment dans `scholarships-index.service.ts` et
 * `catalog.mapper.ts`, avec un commentaire disant que trois lignes ne valaient
 * pas une dépendance partagée. L'argument tenait tant que les deux copies
 * étaient identiques.
 *
 * Il a cessé de tenir à la troisième lecture. Les notifications, en ajoutant
 * leur propre sélection, ont pris « l'année lexicographiquement la plus
 * récente » (`orderBy: academicYear desc, take: 1`) — une quatrième règle, qui
 * *ressemble* aux autres et n'en est pas une. Le cas où elles divergent est
 * réel et fréquent : une bourse dont la campagne 2026-2027 est OUVERTE et
 * CONFIRMÉE, et pour laquelle l'exploitation a déjà saisi une prévision
 * 2027-2028. `deadlineAt` appartient alors au cycle ouvert, mais la sélection
 * par année rendait la prévision — donc « estimée » — et les rappels J-30,
 * J-14, J-7, J-3 et J-1 d'une échéance parfaitement confirmée étaient
 * supprimés. Silencieusement, et précisément pour les bourses les plus suivies.
 *
 * Une règle de sélection qui décide si l'on prévient un étudiant d'une échéance
 * ne doit exister qu'à un seul endroit.
 */

/** La forme minimale dont la règle a besoin. */
export interface CycleSelectable {
  status: string;
}

/**
 * Rend le cycle courant, ou `undefined` si la liste est vide.
 *
 * L'ordre des candidats est celui de `scholarships-index.service.ts` et de
 * `catalog.mapper.ts`, à l'octet près — c'est le point.
 */
export function selectCurrentCycle<T extends CycleSelectable>(
  cycles: readonly T[] | undefined | null,
): T | undefined {
  if (!cycles?.length) return undefined;
  return (
    cycles.find((cycle) => cycle.status === 'open') ??
    cycles.find((cycle) => cycle.status === 'forecast') ??
    cycles[0]
  );
}

/**
 * La date d'échéance de cette bourse est-elle une PROJECTION ?
 *
 * « Pas de cycle » vaut CONFIRMÉ, comme partout ailleurs dans le dépôt
 * (`catalog.mapper.ts`, `ScholarshipModel.deadlineIsEstimated`) : les fiches
 * héritées n'ont pas de cycle et leur date est vraie. Le sens de ce défaut est
 * choisi : se taire à tort prive un étudiant d'un rappel utile, ce qui est pire
 * que le risque inverse pour une fiche héritée dont la date a été saisie à la
 * main.
 */
export function hasEstimatedDeadline(
  cycles:
    | readonly { status: string; dateConfidence: string }[]
    | undefined
    | null,
): boolean {
  return selectCurrentCycle(cycles)?.dateConfidence === 'estimated';
}
