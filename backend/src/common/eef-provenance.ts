import type { Prisma } from '@prisma/client';

/**
 * D'où vient une ligne du catalogue : de l'import « Études en France », ou non.
 *
 * ## Le défaut que ce fichier ferme
 *
 * Le catalogue général (`/catalog/*`, Explore, les recommandations) ne filtrait
 * que sur `isActive`. Dès qu'une seule université était publiée, ses lignes
 * entraient dans l'instantané de 1 000 formations que CHAQUE build installée
 * charge au démarrage — trié par nom, plafonné, sans en-tête de version pour
 * distinguer les clients. Le débordement commence à 367 lignes EEF actives
 * (1 000 − les 634 formations partenaires servies aujourd'hui), alors qu'une
 * seule université en compte jusqu'à 414. Mesuré : avec les 10 502 lignes
 * actives, il ne reste que 121 des 634 formations partenaires (OMNES, ICN,
 * Mundiapolis) dans l'instantané. Personne n'aurait vu d'erreur : des fiches
 * disparaissent, c'est tout.
 *
 * ## Pourquoi la PROVENANCE, et pas la procédure
 *
 * Le code connaît déjà trois façons de dire « ceci est une ligne EEF » :
 * la recherche filtre sur `procedureType IS NOT NULL`, la shortlist sur
 * `cycle IN (…)`, et l'import écrit un identifiant préfixé. Trois définitions,
 * c'est la garantie qu'une porte finisse par n'en vérifier aucune.
 *
 * Le préfixe est la seule des trois qui ne dépend d'aucune décision future.
 * `procedureType` porte le sens « procédure de candidature » : le schéma prévoit
 * déjà la valeur `hors_eef`, et qualifier un jour les 133 formations partenaires
 * (aujourd'hui NULL) est une évolution plausible. Un filtre `procedureType IS
 * NULL` les ferait alors disparaître d'Explore sans un mot. `uaiCode` a le même
 * défaut : un établissement privé partenaire a lui aussi un code UAI.
 *
 * Le seed OMNES délimite déjà ses lignes de la même manière (`omnes-`,
 * `omnes-p-`). Ici les deux préfixes sont dits UNE fois, importés par le
 * constructeur de l'import qui les écrit, et par chaque surface qui les exclut :
 * `eef-provenance.spec.ts` échoue si l'import se met à produire un identifiant
 * que ces clauses ne reconnaissent pas.
 *
 * ## Ce que ça n'interdit pas
 *
 * Que les universités publiques apparaissent un jour dans Explore, le
 * comparateur ou le « moment aha ». C'est une décision produit ouverte. Elle se
 * prendra ICI, en un seul endroit, et non en retirant une clause de quatre
 * fichiers dont un serait oublié.
 */
export const EEF_INSTITUTION_ID_PREFIX = 'eef-univ-';
export const EEF_PROGRAM_ID_PREFIX = 'eef-prog-';

export function isEefProgramId(id: string): boolean {
  return id.startsWith(EEF_PROGRAM_ID_PREFIX);
}

export function isEefInstitutionId(id: string): boolean {
  return id.startsWith(EEF_INSTITUTION_ID_PREFIX);
}

/**
 * La formation appartient à l'import EEF : son identifiant porte le préfixe de
 * l'import, OU son établissement le porte.
 *
 * Le second critère ferme le cas d'une formation créée À LA MAIN sous une
 * université de l'import : elle reçoit un identifiant généré (`cuid`), et
 * `isActive` vaut `true` par défaut. Avec le seul préfixe d'identifiant, elle
 * serait servie par le catalogue général — sur une carte sans établissement,
 * puisque l'établissement, lui, en est exclu — et recommandée par le moteur avec
 * un nom d'école vide. Une formation qui a pour parent une université de l'import
 * est de l'import, quelle que soit la façon dont elle est arrivée.
 *
 * Réservé à l'ADMIN en pratique (`createProgram` / `updateProgram` acceptent un
 * `institutionId` quelconque) ; la liste déroulante de l'interface ne propose
 * plus ces universités, donc il faut un appel direct à l'API. Rare, mais la
 * garde coûte une ligne.
 */
export function eefProgramWhere(): Prisma.ProgramWhereInput {
  return {
    OR: [
      { id: { startsWith: EEF_PROGRAM_ID_PREFIX } },
      { institutionId: { startsWith: EEF_INSTITUTION_ID_PREFIX } },
    ],
  };
}

/**
 * La formation n'appartient PAS à l'import EEF (voir [eefProgramWhere]).
 *
 * À poser sur toute lecture du catalogue GÉNÉRAL. Ce n'est jamais un filtre
 * optionnel : il ne dépend d'aucun paramètre de requête, pour qu'aucun appel
 * — `?institutionId=eef-univ-…` compris — ne puisse le contourner.
 *
 * Fonction et non constante : Prisma ne modifie pas ses entrées, mais les
 * appelants complètent leurs clauses (`where.OR = …`), et un objet partagé
 * entre deux requêtes est le genre d'aliasing qu'on ne relit jamais.
 */
export function notEefProgram(): Prisma.ProgramWhereInput {
  return { NOT: eefProgramWhere() };
}

/** L'établissement n'a PAS été créé par l'import EEF. Voir [notEefProgram]. */
export function notEefInstitution(): Prisma.InstitutionWhereInput {
  return { NOT: { id: { startsWith: EEF_INSTITUTION_ID_PREFIX } } };
}

/**
 * La formation n'est PAS « importée par l'EEF et pas encore publiée ».
 *
 * Pour la file de revérification, le SLA quotidien et le compteur du tableau de
 * bord — qui sont des files de RE-vérification : des fiches publiées dont la
 * cadence est échue. Une ligne importée et inactive n'y a pas sa place : elle
 * n'a jamais été publiée, sa revue est le flux de PUBLICATION, qui demande un
 * outil dédié (À CONSTRUIRE : valider une ligne dans la file ne pose que le
 * tampon de vérification, jamais `isActive`).
 *
 * Sans cette clause, le premier import ajoutait 10 500 lignes « jamais
 * vérifiées » à la file (donc une page admin qui rend un champ par ligne), et
 * l'alerte de 07 h annonçait chaque matin « SLA breach : 10 5xx never
 * verified » — jusqu'à ne plus rien vouloir dire, bourses comprises.
 *
 * Une ligne EEF PUBLIÉE (`isActive: true`) reste dans la file : c'est
 * exactement le cas où elle doit être revérifiée. Et si quelqu'un publie sans
 * poser `lastVerifiedAt`, elle y apparaît « jamais vérifiée » — le signal voulu.
 * Les lignes inactives NON EEF gardent leur comportement d'avant.
 */
export function notPendingEefProgram(): Prisma.ProgramWhereInput {
  return {
    NOT: {
      AND: [{ id: { startsWith: EEF_PROGRAM_ID_PREFIX } }, { isActive: false }],
    },
  };
}

/** Voir [notPendingEefProgram]. */
export function notPendingEefInstitution(): Prisma.InstitutionWhereInput {
  return {
    NOT: {
      AND: [
        { id: { startsWith: EEF_INSTITUTION_ID_PREFIX } },
        { isActive: false },
      ],
    },
  };
}
