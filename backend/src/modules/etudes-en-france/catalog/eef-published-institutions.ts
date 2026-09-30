import type { PrismaClient } from '@prisma/client';

/// Ce qu'une réponse de l'espace a le droit de dire d'un établissement PUBLIÉ :
/// de quoi l'afficher sur une carte (nom, ville, logo et sa licence) et le
/// retrouver par son nom ou son sigle. Ni la présentation ni l'effectif daté :
/// c'est la fiche, pas la carte.
export interface PublishedInstitution {
  readonly id: string;
  readonly nameFr: string;
  readonly nameEn: string;
  readonly acronym: string | null;
  readonly locationFr: string;
  readonly locationEn: string;
  readonly institutionType: string | null;
  readonly websiteUrl: string | null;
  readonly logoUrl: string | null;
  readonly logoSourceUrl: string | null;
  readonly logoLicence: string | null;
}

const PUBLISHED_INSTITUTION_SELECT = {
  id: true,
  nameFr: true,
  nameEn: true,
  acronym: true,
  locationFr: true,
  locationEn: true,
  institutionType: true,
  websiteUrl: true,
  logoUrl: true,
  logoSourceUrl: true,
  logoLicence: true,
} as const;

/**
 * Les établissements PUBLIÉS du pays — ceux dont une formation a le droit d'être
 * servie — avec de quoi les nommer sur une carte.
 *
 * Les clauses `IN` n'en consomment que les identifiants (`publishedInstitutionIds`) ;
 * le reste sert à DIRE, dans chaque item, de quelle université il s'agit. Une
 * seule lecture pour les deux usages : deux lectures pourraient décrire deux
 * ensembles différents d'établissements dans la même réponse.
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
 * Conséquence à connaître : la liste contient AUSSI les établissements
 * partenaires actifs du pays (ESSEC, OMNES…). Ce qui garde aujourd'hui leurs
 * formations hors de l'espace, ce n'est donc pas cette liste mais les autres
 * clauses — `procedureType IS NOT NULL` pour la recherche, `cycle IN (…)` pour la
 * shortlist — que ces formations (procédure « non qualifiée ») ne remplissent
 * pas. Si l'exploitation qualifie un jour une formation partenaire, elle entrera
 * dans l'espace ET restera dans le catalogue général : c'est une décision de
 * produit à prendre en connaissance de cause (voir `common/eef-provenance.ts`).
 *
 * Liste vide (aucun établissement publié) ⇒ `institutionId IN ()` ⇒ aucun
 * résultat, jamais « tout ». Elle l'est sur une base neuve ; elle ne l'est PAS
 * sur la base de production, où les partenaires sont actifs. La branche vide est
 * donc prouvée directement (`eef-provenance.postgres.spec.ts`), pas déduite de
 * l'état d'une base.
 */
export async function loadPublishedInstitutions(
  prisma: Pick<PrismaClient, 'institution'>,
  countryId: string,
): Promise<PublishedInstitution[]> {
  return prisma.institution.findMany({
    where: { isActive: true, countryId },
    select: PUBLISHED_INSTITUTION_SELECT,
    orderBy: { id: 'asc' },
  });
}

/// Les identifiants seuls : ce que les clauses `IN` des requêtes consomment.
export function publishedInstitutionIds(
  institutions: readonly PublishedInstitution[],
): string[] {
  return institutions.map((institution) => institution.id);
}
