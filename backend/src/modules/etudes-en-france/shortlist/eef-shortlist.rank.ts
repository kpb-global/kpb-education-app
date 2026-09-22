// ─────────────────────────────────────────────────────────────────────────────
// Le classement de la shortlist, et les clauses qui le posent en base.
//
// Pur : ni Prisma, ni Nest. Les clauses `where` sont des objets ordinaires, et
// c'est ce qui permet de tester « quelle question a été posée » sans base — le
// même partage que la recherche paginée.
//
// LA RÈGLE QUI GOUVERNE TOUT CE FICHIER
//
// Un étage se fonde sur un fait PUBLIÉ, ou n'existe pas. On ne mélange jamais
// deux axes dans un même classement : l'étage dit le RISQUE d'admission, les
// motifs disent l'ADÉQUATION. Confondre les deux produirait exactement le
// nombre opaque que cette fonctionnalité refuse — « 72 % » dont personne ne
// sait s'il parle du dossier ou de la filière.
// ─────────────────────────────────────────────────────────────────────────────
import {
  ANY_BACHELOR_LABEL,
  acceptsAnyBachelor,
} from '../catalog/eef-admission-signals';
import {
  EEF_PATH_BASIS,
  EEF_PATH_CYCLES,
  type EefEntryPath,
  type EefShortlistReason,
  type EefShortlistTier,
} from './eef-shortlist.types';

/// Combien de formations par étage. Une shortlist est courte par définition :
/// au-delà d'une poignée par étage, ce n'est plus une sélection, c'est le
/// catalogue — et le catalogue a déjà son écran de recherche.
export const EEF_SHORTLIST_DEFAULT_LIMIT = 5;
export const EEF_SHORTLIST_MAX_LIMIT = 10;

/**
 * Les modalités de candidature que la source publie, et l'effort qu'elles
 * demandent. Table FERMÉE, et c'est le point : une modalité inconnue ne reçoit
 * pas un poids « moyen », elle envoie la ligne dans `unranked`. Pondérer au
 * jugé un mot qu'on n'a jamais vu reviendrait à classer une formation sur une
 * lecture inventée de sa procédure.
 *
 * Les quatre valeurs observées sur les 2 914 masters qui publient une
 * modalité : Dossier (2 899), Entretien (1 628), Examen (203), Concours (83).
 */
export const ADMISSION_MODE_EFFORT: Readonly<
  Record<string, 'file' | 'interview' | 'exam'>
> = {
  Dossier: 'file',
  Entretien: 'interview',
  Examen: 'exam',
  Concours: 'exam',
};

export interface EefCandidateRow {
  readonly id: string;
  readonly fieldId: string;
  readonly cycle: string | null;
  readonly selectivity: string | null;
  readonly recommendedBachelors: readonly string[];
  readonly recommendedFieldIds: readonly string[];
  readonly admissionModes: readonly string[];
}

/**
 * L'étage d'une formation, pour un chemin donné.
 *
 * Trois lectures distinctes, parce que les trois chemins ne disposent pas des
 * mêmes faits — et prétendre le contraire aurait été la facilité qui rend la
 * liste fausse.
 */
export function tierOf(
  row: EefCandidateRow,
  path: EefEntryPath,
): EefShortlistTier {
  const basis = EEF_PATH_BASIS[path];

  if (basis === 'selectivity') {
    // Deux valeurs publiées, donc deux étages. Pas de « cible » : il n'existe
    // aucune troisième valeur à lui donner pour socle.
    if (row.selectivity === 'non_selective') return 'securite';
    if (row.selectivity === 'selective') return 'ambition';
    return 'unranked';
  }

  if (basis === 'admission_effort') {
    // On garde l'épreuve la PLUS exigeante parmi celles qu'on sait lire. Une
    // modalité hors table ne déclasse pas la ligne et ne la fait pas
    // disparaître non plus : elle est simplement ignorée pour l'effort. Une
    // ligne dont AUCUNE modalité n'est reconnue — y compris la ligne sans
    // modalité publiée — tombe dans `unranked`, qui est exactement l'aveu
    // qu'il faut.
    //
    // Cette énumération DOIT dire la même chose que `tierWhere` : toute
    // divergence rangerait une fiche dans une case où la requête ne va pas la
    // chercher, ou l'y ferait apparaître deux fois. Un test compare les deux
    // sur chaque combinaison de modalités.
    const efforts = row.admissionModes
      .map((mode) => ADMISSION_MODE_EFFORT[mode.trim()])
      .filter((effort): effort is 'file' | 'interview' | 'exam' =>
        effort !== undefined,
      );
    if (efforts.includes('exam')) return 'ambition';
    if (efforts.includes('interview')) return 'cible';
    if (efforts.includes('file')) return 'securite';
    return 'unranked';
  }

  // `basis === null` — le chemin ne porte aucune donnée de classement.
  return 'unranked';
}

/**
 * Pourquoi cette formation est là, en codes fermés et valeurs attestées.
 *
 * Les motifs de sélectivité ne sont émis que là où la sélectivité DISTINGUE
 * (le chemin post-bac). Sur un master, elle vaut `selective` pour les 3 112
 * lignes — la loi du 23 décembre 2016 en fait une règle, pas une
 * caractéristique de l'établissement. L'émettre partout aurait ajouté à chaque
 * fiche une justification qui ne justifie rien ; le fait, lui, reste écrit
 * dans les exigences d'admission de la formation.
 */
export function reasonsFor(
  row: EefCandidateRow,
  declaredFieldIds: readonly string[],
  path: EefEntryPath,
): EefShortlistReason[] {
  const declared = new Set(declaredFieldIds);
  const reasons: EefShortlistReason[] = [];

  if (declared.has(row.fieldId)) {
    reasons.push({ code: 'field_declared', value: row.fieldId });
  }
  // Trié pour que deux exécutions rendent la même liste : un ordre instable
  // ferait clignoter la justification d'une formation d'un appel à l'autre.
  for (const fieldId of [...row.recommendedFieldIds].sort()) {
    if (declared.has(fieldId)) {
      reasons.push({ code: 'bachelor_domain_recommended', value: fieldId });
    }
  }
  if (acceptsAnyBachelor(row.recommendedBachelors)) {
    reasons.push({ code: 'bachelor_any_accepted', value: ANY_BACHELOR_LABEL });
  }

  const basis = EEF_PATH_BASIS[path];

  if (basis === 'admission_effort') {
    for (const mode of row.admissionModes) {
      const effort = ADMISSION_MODE_EFFORT[mode.trim()];
      if (effort === 'file') {
        reasons.push({ code: 'admission_file_only', value: mode });
      } else if (effort === 'interview') {
        reasons.push({ code: 'admission_interview', value: mode });
      } else if (effort === 'exam') {
        reasons.push({ code: 'admission_exam', value: mode });
      }
      // Une modalité hors table n'est PAS servie comme motif : la ligne est
      // déjà dans `unranked`, et inventer un libellé pour un mot qu'on ne sait
      // pas lire donnerait à l'écran une phrase qu'il ne sait pas traduire.
    }
  }

  if (basis === 'selectivity') {
    if (row.selectivity === 'non_selective') {
      reasons.push({ code: 'selectivity_open', value: row.selectivity });
    } else if (row.selectivity === 'selective') {
      reasons.push({ code: 'selectivity_arbitrated', value: row.selectivity });
    }
  }

  return reasons;
}

/**
 * Les deux strates de candidature, dans l'ordre où on les sert.
 *
 * `linked` — la formation est reliée à un domaine DÉCLARÉ, dans un sens ou
 * dans l'autre : ou bien c'est son propre domaine, ou bien l'une des licences
 * qu'elle conseille en relève. La seconde branche est ce que cette
 * fonctionnalité apporte de neuf — pour un étudiant de « droit, économie »,
 * 594 masters conseillent son domaine sans être classés dedans, et aucun
 * filtre par domaine du diplôme ne les montrerait jamais.
 *
 * `open` — l'établissement publie « Toutes licences ». C'est une information
 * réelle, mais qui ne dit rien de l'étudiant : elle ne sert donc qu'à COMPLÉTER
 * un étage que la première strate n'a pas rempli. La servir au même rang
 * mettrait au sommet de la liste les formations qui n'ont rien à voir avec la
 * filière déclarée.
 *
 * `any` n'est pas une troisième strate : c'est leur RÉUNION, et elle ne sert
 * qu'à COMPTER. Compter sur `linked` seule rendait des étages où le nombre
 * servi dépasse le total annoncé — « 5 formations sur 3 » — dès qu'une ligne
 * « Toutes licences » venait compléter un étage clairsemé.
 */
export type EefCandidateStratum = 'linked' | 'open' | 'any';

/// Les strates SERVIES, dans l'ordre. `any` n'y figure pas : elle compte, elle
/// ne se sert pas.
export const EEF_CANDIDATE_STRATA: readonly EefCandidateStratum[] = [
  'linked',
  'open',
];

export interface BuildShortlistWhereOptions {
  readonly path: EefEntryPath;
  readonly countryId: string;
  readonly declaredFieldIds: readonly string[];
  readonly tier: EefShortlistTier;
  readonly stratum: EefCandidateStratum;
}

/**
 * La clause `where` d'un (étage, strate).
 *
 * `isActive: true` n'est jamais optionnel : c'est la frontière entre ce qu'un
 * vérificateur a relu et ce que le pipeline a déposé. Une shortlist —
 * c'est-à-dire une recommandation nominative — construite sur des lignes non
 * relues serait la pire surface possible pour cette barrière.
 */
export function buildShortlistWhere(
  options: BuildShortlistWhereOptions,
): Record<string, unknown> {
  const { path, countryId, declaredFieldIds, tier, stratum } = options;

  const linkedBranches = [
    { fieldId: { in: [...declaredFieldIds] } },
    { recommendedFieldIds: { hasSome: [...declaredFieldIds] } },
  ];

  const stratumClause: Record<string, unknown> = {};
  if (stratum === 'linked') {
    // Aucun domaine déclaré : la strate ne resserre rien, et la réponse le
    // DIT (`no_field_declared`). Poser `fieldId: { in: [] }` aurait rendu zéro
    // résultat, donc une liste vide indiscernable d'un catalogue vide.
    if (declaredFieldIds.length > 0) stratumClause.OR = linkedBranches;
  } else if (stratum === 'open') {
    stratumClause.recommendedBachelors = { has: ANY_BACHELOR_LABEL };
    // Ce que la première strate a déjà servi ne doit pas revenir ici : sans
    // cette exclusion, un master « Toutes licences » du bon domaine
    // occuperait deux places de l'étage avec la même fiche.
    if (declaredFieldIds.length > 0) stratumClause.NOT = { OR: linkedBranches };
  } else if (declaredFieldIds.length > 0) {
    // `any` : tout ce que l'une OU l'autre strate peut servir. Sans domaine
    // déclaré, `linked` ne resserre déjà rien, donc la réunion non plus.
    stratumClause.OR = [
      ...linkedBranches,
      { recommendedBachelors: { has: ANY_BACHELOR_LABEL } },
    ];
  }

  // L'ÉTAGE et la STRATE vont dans `AND`, jamais fusionnés à plat.
  //
  // Les deux emploient `OR` et `NOT` : à plat, le second écrasait le premier
  // sans un mot. Concrètement, la strate « ouverte » effaçait l'exclusion de
  // l'étage « sécurité », et des masters à entretien étaient servis comme
  // « dossier seul » — c'est-à-dire que la liste se trompait précisément sur
  // ce qu'elle promet d'expliquer. `AND` rend la collision impossible plutôt
  // que de compter sur la vigilance à chaque ajout de clause.
  return {
    isActive: true,
    countryId,
    cycle: { in: [...EEF_PATH_CYCLES[path]] },
    AND: [tierWhere(tier, path), stratumClause],
  };
}

/**
 * La partie de la clause qui sélectionne l'étage.
 *
 * Exportée pour être testée seule : c'est ici que se joue la correspondance
 * entre ce que `tierOf` décide en mémoire et ce que la base sait trouver. Les
 * deux DOIVENT dire la même chose — un étage `cible` que la requête ne sait
 * pas cibler rendrait des fiches rangées dans une case où elles ne sont pas.
 */
export function tierWhere(
  tier: EefShortlistTier,
  path: EefEntryPath,
): Record<string, unknown> {
  const basis = EEF_PATH_BASIS[path];
  const knownModes = Object.keys(ADMISSION_MODE_EFFORT);
  const examModes = knownModes.filter(
    (mode) => ADMISSION_MODE_EFFORT[mode] === 'exam',
  );
  const interviewModes = knownModes.filter(
    (mode) => ADMISSION_MODE_EFFORT[mode] === 'interview',
  );

  const fileModes = knownModes.filter(
    (mode) => ADMISSION_MODE_EFFORT[mode] === 'file',
  );

  if (basis === 'selectivity') {
    if (tier === 'securite') return { selectivity: 'non_selective' };
    if (tier === 'ambition') return { selectivity: 'selective' };
    if (tier === 'unranked') {
      // `NOT IN` seul laisserait échapper les `NULL` : en SQL, `NULL IN (…)`
      // vaut NULL, donc sa négation aussi, et la ligne ne serait rendue par
      // AUCUN étage. Une formation qui disparaît de la liste sans être classée
      // nulle part est précisément la panne qu'`unranked` existe pour éviter.
      return {
        OR: [
          { selectivity: null },
          { NOT: { selectivity: { in: ['non_selective', 'selective'] } } },
        ],
      };
    }
    // `cible` n'existe pas sur cet axe : aucune ligne ne doit y tomber, et
    // c'est la requête qui doit le garantir, pas la confiance dans l'appelant.
    return { id: { in: [] } };
  }

  if (basis === 'admission_effort') {
    // Les quatre branches partitionnent : l'épreuve la plus exigeante gagne,
    // et ce qui ne porte aucune modalité RECONNUE tombe dans `unranked`.
    // Toute ligne atterrit donc dans exactement un étage — ni doublon, ni
    // disparition, y compris si la source publie un jour un mot nouveau.
    if (tier === 'ambition') return { admissionModes: { hasSome: examModes } };
    if (tier === 'cible') {
      return {
        admissionModes: { hasSome: interviewModes },
        NOT: { admissionModes: { hasSome: examModes } },
      };
    }
    if (tier === 'securite') {
      return {
        admissionModes: { hasSome: fileModes },
        NOT: {
          OR: [
            { admissionModes: { hasSome: examModes } },
            { admissionModes: { hasSome: interviewModes } },
          ],
        },
      };
    }
    return { NOT: { admissionModes: { hasSome: knownModes } } };
  }

  // Aucun axe : tout est `unranked`, et rien d'autre.
  return tier === 'unranked' ? {} : { id: { in: [] } };
}

/// L'ordre à l'intérieur d'un étage. Total — `nameFr` seul ne l'est pas, « M1
/// Droit » étant servi par des dizaines d'universités — pour qu'un même profil
/// relise la même liste d'un appel à l'autre.
export const EEF_SHORTLIST_ORDER_BY = [
  { nameFr: 'asc' as const },
  { id: 'asc' as const },
];

/** Borne la taille demandée, sans jamais rendre zéro. */
export function clampShortlistLimit(raw: string | undefined): number {
  const parsed = Number.parseInt((raw ?? '').trim(), 10);
  if (!Number.isFinite(parsed) || parsed <= 0) {
    return EEF_SHORTLIST_DEFAULT_LIMIT;
  }
  return Math.min(parsed, EEF_SHORTLIST_MAX_LIMIT);
}
