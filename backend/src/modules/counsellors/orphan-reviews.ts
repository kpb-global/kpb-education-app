import type { PrismaClient } from '@prisma/client';

/**
 * Les avis conseillers ORPHELINS : sans auteur, et dont le dossier a disparu.
 *
 * ## D'où ils viennent
 *
 * `POST /counsellors/:id/reviews` prenait l'auteur dans le corps de la requête,
 * que l'app n'envoyait jamais : tout avis enregistré avant le correctif a
 * `reviewerUserId = NULL`. La suppression de compte (`deleteMany WHERE
 * reviewerUserId = …`) ne les trouvait donc pas, et le nom civil de l'étudiant
 * (`reviewerName`) a survécu à l'effacement de son compte.
 *
 * Le correctif retrouve ces avis PAR LE DOSSIER tant que le dossier existe
 * (`reviewsOfUser`, `profiles.service.ts`). Restent ceux dont le dossier a été
 * supprimé avec le compte, ou n'a jamais été renseigné : plus rien ne les
 * rattache à quelqu'un.
 *
 * ## Ce que fait l'outil — et pourquoi il SUPPRIME
 *
 * `deleteMe` SUPPRIME les avis d'un utilisateur qui efface son compte. Un avis
 * orphelin est, par construction, celui d'un utilisateur dont le compte (donc le
 * dossier) n'existe plus : lui appliquer autre chose que ce que `deleteMe` aurait
 * fait à l'époque reviendrait à conserver, sous un autre nom, ce que l'utilisateur
 * a demandé d'effacer. L'anonymiser (`reviewerName` seul) laisserait le texte,
 * qui peut nommer quelqu'un.
 *
 * Il ne touche JAMAIS un avis qui a un auteur, ni un avis sans auteur dont le
 * dossier existe encore (sa suppression est l'affaire de son propriétaire, que
 * `deleteMe` sait retrouver). Les compteurs du conseiller sont recalculés sur les
 * avis restants, avec la même formule que `CounsellorsService`.
 *
 * Il n'imprime que des décomptes : ni nom, ni texte, ni identifiant d'utilisateur.
 */
export interface OrphanReviewSummary {
  /** Avis sans auteur examinés. */
  unauthored: number;
  /** Parmi eux : dossier disparu ou jamais renseigné. */
  orphans: number;
  /** … dont publiés (ils comptent dans les compteurs du conseiller). */
  orphansPublished: number;
  /** Sans auteur mais dont le dossier existe encore — laissés en place. */
  keptBecauseCaseExists: number;
  counsellorsAffected: number;
  deleted: number;
}

export async function purgeOrphanReviews(
  client: PrismaClient,
  options: {
    apply: boolean;
    /**
     * Restreint l'examen à ces conseillers. Le CLI ne l'expose pas : c'est ce qui
     * permet à un test sur base réelle de ne toucher QUE ses propres lignes.
     */
    counsellorIds?: readonly string[];
  },
): Promise<OrphanReviewSummary> {
  const unauthored = await client.counsellorReview.findMany({
    where: {
      reviewerUserId: null,
      ...(options.counsellorIds
        ? { counsellorId: { in: [...options.counsellorIds] } }
        : {}),
    },
    select: { id: true, counsellorId: true, caseId: true, isPublished: true },
  });

  const caseIds = Array.from(
    new Set(unauthored.flatMap((r) => (r.caseId ? [r.caseId] : []))),
  );
  const existingCases =
    caseIds.length === 0
      ? []
      : await client.case.findMany({
          where: { id: { in: caseIds } },
          select: { id: true },
        });
  const existing = new Set(existingCases.map((c) => c.id));

  // Orphelin : aucun dossier renseigné, ou un dossier qui n'existe plus.
  const orphans = unauthored.filter((r) => !r.caseId || !existing.has(r.caseId));
  const counsellorIds = Array.from(new Set(orphans.map((r) => r.counsellorId)));

  const summary: OrphanReviewSummary = {
    unauthored: unauthored.length,
    orphans: orphans.length,
    orphansPublished: orphans.filter((r) => r.isPublished).length,
    keptBecauseCaseExists: unauthored.length - orphans.length,
    counsellorsAffected: counsellorIds.length,
    deleted: 0,
  };
  if (!options.apply || orphans.length === 0) return summary;

  // Suppression ET recalcul des compteurs dans UNE transaction : une coupure
  // entre les deux laisserait des compteurs périmés, que le rejeu ne corrigerait
  // pas (il ne trouverait plus d'orphelin, donc plus de conseiller à recalculer).
  summary.deleted = await client.$transaction(async (tx) => {
    // `reviewerUserId: null` est répété dans le WHERE : entre la lecture et
    // l'écriture, un avis a pu recevoir un auteur (la reprise de la migration
    // rejouée), et il ne doit alors pas être supprimé.
    const result = await tx.counsellorReview.deleteMany({
      where: { id: { in: orphans.map((r) => r.id) }, reviewerUserId: null },
    });

    for (const counsellorId of counsellorIds) {
      const published = await tx.counsellorReview.findMany({
        where: { counsellorId, isPublished: true },
        select: { rating: true },
      });
      const count = published.length;
      const avg =
        count === 0
          ? 0
          : published.reduce((sum, r) => sum + r.rating, 0) / count;
      // `updateMany` : pas d'exception si le conseiller a disparu entre-temps.
      await tx.counsellor.updateMany({
        where: { id: counsellorId },
        data: { avgRating: avg, reviewCount: count },
      });
    }
    return result.count;
  });
  return summary;
}
