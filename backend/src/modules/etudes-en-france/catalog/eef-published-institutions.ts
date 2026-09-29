import type { PrismaClient } from '@prisma/client';

/**
 * Les identifiants des établissements PUBLIÉS du pays — ceux dont une formation
 * a le droit d'être servie.
 *
 * ## Le défaut que cette liste ferme
 *
 * `Program` n'a aucune relation Prisma vers `Institution` : `institutionId` est
 * un `String` nu. Ni la recherche ni la shortlist ne pouvaient donc demander « et
 * son établissement est-il publié ? » — chacune ne regardait que le drapeau de la
 * formation. Une formation publiée sous une université encore inactive
 * (publication partielle, `PATCH` isolé sur une fiche) était servie, et pire,
 * RECOMMANDÉE nominativement, avec pour établissement une fiche que personne
 * n'avait relue : le nom, la ville et le logo de cette université partiraient
 * chez l'étudiant sans que rien ne les ait vérifiés.
 *
 * ## Pourquoi une liste lue, et pas une jointure
 *
 * Sans relation, la seule façon de l'exprimer en Prisma est un `IN` sur les
 * identifiants. La liste est petite (une centaine d'établissements par pays au
 * plus), donc l'`IN` reste bon marché ; et elle est lue AVANT la requête des
 * formations, une seule fois par appel, puis passée à TOUTES les clauses de la
 * même réponse (page, total, facettes, étages). Les huit requêtes d'une
 * recherche décrivent ainsi le même ensemble d'établissements, même si l'un
 * d'eux est publié pendant que la transaction s'exécute.
 *
 * ## Pourquoi tous les établissements actifs du pays, et pas ceux préfixés `eef-`
 *
 * L'exigence est « le parent de la formation est publié », pas « le parent vient
 * de l'import ». Le jour où des formations d'un établissement partenaire
 * apparaîtront dans cet espace, elles ne disparaîtront pas pour une raison
 * d'identifiant.
 *
 * Liste vide (aucun établissement publié) ⇒ `institutionId IN ()` ⇒ aucun
 * résultat. C'est l'état d'aujourd'hui en production, et c'est le bon.
 */
export async function loadPublishedInstitutionIds(
  prisma: Pick<PrismaClient, 'institution'>,
  countryId: string,
): Promise<string[]> {
  const rows = await prisma.institution.findMany({
    where: { isActive: true, countryId },
    select: { id: true },
    orderBy: { id: 'asc' },
  });
  return rows.map((row) => row.id);
}
