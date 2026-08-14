import type { Prisma } from '@prisma/client';

/**
 * La clause que TOUTE lecture publique de bourse doit porter.
 *
 * Elle vit ici, en un seul endroit, parce que les deux chemins de lecture
 * (`/catalog/scholarships` et `/scholarships`) avaient déjà divergé : le premier
 * portait un commentaire « hide pending-scraped and expired » alors qu'aucun
 * filtre de date n'existait dans son `where`. Une règle dupliquée à trois
 * endroits est une règle qui finira par ne s'appliquer qu'à deux.
 *
 * Chacune des trois conditions ferme un incident réel :
 *
 * `isActive` + `moderationStatus` — la porte historique, celle que les 11 fiches
 * de démonstration franchissaient grâce aux défauts du schéma.
 *
 * `lastVerifiedAt: { not: null }` — les 11 fiches servies en production jusqu'au
 * 14/08/2026 n'avaient AUCUNE date de vérification. Cette clause rend cet état
 * impubliable, quoi que fasse un futur chemin d'écriture ou une réapprobation
 * manuelle. Sa contrepartie obligatoire vit dans `setModeration` : approuver EST
 * un acte de vérification humaine, donc l'approbation horodate. Sans cette
 * contrepartie, une saisie admin manuelle deviendrait impubliable.
 *
 * `deadlineAt` dans le futur ou nul — trois bourses étaient affichées comme
 * disponibles avec une date limite dépassée de 13, 44 et 90 jours. Un `null` est
 * accepté : beaucoup de programmes-cadres n'ont pas de date unique, et les
 * masquer serait une perte d'information, pas une protection.
 */
export function publicScholarshipWhere(
  now: Date = new Date(),
): Prisma.ScholarshipWhereInput {
  return {
    isActive: true,
    moderationStatus: 'approved',
    lastVerifiedAt: { not: null },
    OR: [{ deadlineAt: null }, { deadlineAt: { gte: now } }],
  };
}

/**
 * Le statut de cycle tel qu'il doit être SERVI, dérivé de l'horloge et non du
 * littéral en base.
 *
 * Aucun chemin d'écriture ne pose jamais `closed` : seuls `saveForecast` et
 * `activate` écrivent un statut, et ni l'un ni l'autre ne ferme un cycle. Un
 * cycle annoncé « ouvert » le reste donc pour toujours, même sa clôture passée —
 * y compris après correction dans le dépôt, puisque l'import ne met pas à jour
 * les lignes existantes. On cesse de faire confiance au littéral.
 */
export function servedCycleStatus(
  status: string,
  closesAt: Date | null,
  estimatedCloseAt: Date | null,
  now: Date = new Date(),
): string {
  if (status !== 'open') return status;
  const close = closesAt ?? estimatedCloseAt;
  if (close && close.getTime() <= now.getTime()) return 'closed';
  return status;
}
