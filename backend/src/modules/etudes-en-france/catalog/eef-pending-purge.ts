import type { PrismaClient } from '@prisma/client';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';

/**
 * Supprime les lignes de l'import « Études en France » qui n'ont JAMAIS été
 * publiées ni vérifiées, pour qu'un nouvel import les recrée avec les règles
 * corrigées.
 *
 * ## Pourquoi
 *
 * `eef:import` est CRÉATION SEULE : une ligne dont l'identifiant existe déjà n'est
 * jamais mise à jour (un administrateur a pu la corriger). Et `eef:backfill` ne
 * comble que des colonnes vides. Résultat : une règle corrigée dans le dépôt —
 * le domaine (`fieldId`), une procédure, un intitulé — n'atteint pas une ligne
 * déjà importée. Tant qu'AUCUNE ligne n'est publiée, personne n'a pu relire,
 * enregistrer ni recommander ces lignes : les supprimer puis réimporter est le
 * réalignement le plus simple, et le seul qui ne demande pas d'écrire un
 * `eef:reconcile` champ par champ. Ce dernier ne deviendra nécessaire qu'après la
 * première vague de publication.
 *
 * ## Ce que l'outil refuse de toucher
 *
 * Une ligne n'est candidate que si elle porte le préfixe de l'import ET est
 * inactive ET n'a jamais été vérifiée (ni `lastVerifiedAt` ni `verifiedById`).
 * Parmi les candidates, sont PROTÉGÉES et comptées à part :
 *
 *   • une formation que quelqu'un a enregistrée (`SavedItem`) ;
 *   • un établissement qui garde une formation NON candidate (publiée, vérifiée
 *     ou enregistrée), qu'un accord de partenariat référence, ou qu'on a
 *     enregistré.
 *
 * Les correspondances (`Match`) d'une formation supprimée partent avec elle : ce
 * sont des lignes de cache de 24 h, toujours recalculables.
 *
 * Chaque suppression répète les conditions « inactive, jamais vérifiée » dans son
 * `WHERE` : entre la lecture et l'écriture, une ligne a pu être publiée, et elle
 * ne doit alors pas être supprimée.
 */
export interface PendingPurgeSummary {
  programsPending: number;
  programsProtected: { saved: number };
  programsDeleted: number;
  institutionsPending: number;
  institutionsProtected: {
    keepsNonPendingPrograms: number;
    partnerAgreement: number;
    saved: number;
  };
  institutionsDeleted: number;
  matchesDeleted: number;
}

const CHUNK = 2_000;

function chunks<T>(values: readonly T[], size = CHUNK): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < values.length; i += size) {
    out.push(values.slice(i, i + size));
  }
  return out;
}

export async function purgePendingEefRows(
  client: PrismaClient,
  options: {
    apply: boolean;
    /**
     * Restreint l'examen à ces établissements (et à leurs formations). Le CLI ne
     * l'expose pas : c'est ce qui permet à un test sur base réelle de ne toucher
     * QUE ses propres lignes.
     */
    onlyInstitutionIds?: readonly string[];
  },
): Promise<PendingPurgeSummary> {
  const only = options.onlyInstitutionIds;
  const neverPublished = {
    isActive: false,
    lastVerifiedAt: null,
    verifiedById: null,
  } as const;

  const programs = await client.program.findMany({
    where: {
      id: { startsWith: EEF_PROGRAM_ID_PREFIX },
      ...neverPublished,
      ...(only ? { institutionId: { in: [...only] } } : {}),
    },
    select: { id: true },
  });

  const saved = new Set<string>();
  for (const part of chunks(programs.map((p) => p.id))) {
    const rows = await client.savedItem.findMany({
      where: { itemId: { in: part } },
      select: { itemId: true },
    });
    for (const row of rows) saved.add(row.itemId);
  }
  const deletablePrograms = programs
    .map((p) => p.id)
    .filter((id) => !saved.has(id));
  const deletableSet = new Set(deletablePrograms);

  const institutions = await client.institution.findMany({
    where: {
      id: {
        startsWith: EEF_INSTITUTION_ID_PREFIX,
        ...(only ? { in: [...only] } : {}),
      },
      ...neverPublished,
    },
    select: { id: true },
  });
  const institutionIds = institutions.map((i) => i.id);

  // Tous les enfants de ces établissements, candidats ou non : un établissement
  // qui garde une formation qu'on ne supprime pas ne peut pas partir.
  const keeps = new Set<string>();
  const withAgreement = new Set<string>();
  const institutionSaved = new Set<string>();
  for (const part of chunks(institutionIds)) {
    const children = await client.program.findMany({
      where: { institutionId: { in: part } },
      select: { id: true, institutionId: true },
    });
    for (const child of children) {
      if (!deletableSet.has(child.id)) keeps.add(child.institutionId);
    }
    const agreements = await client.partnerAgreement.findMany({
      where: { institutionId: { in: part } },
      select: { institutionId: true },
    });
    for (const agreement of agreements) {
      if (agreement.institutionId) withAgreement.add(agreement.institutionId);
    }
    const savedRows = await client.savedItem.findMany({
      where: { itemId: { in: part } },
      select: { itemId: true },
    });
    for (const row of savedRows) institutionSaved.add(row.itemId);
  }
  const deletableInstitutions = institutionIds.filter(
    (id) => !keeps.has(id) && !withAgreement.has(id) && !institutionSaved.has(id),
  );

  const summary: PendingPurgeSummary = {
    programsPending: programs.length,
    programsProtected: { saved: saved.size },
    programsDeleted: 0,
    institutionsPending: institutions.length,
    institutionsProtected: {
      keepsNonPendingPrograms: institutionIds.filter((id) => keeps.has(id)).length,
      partnerAgreement: institutionIds.filter((id) => withAgreement.has(id)).length,
      saved: institutionIds.filter((id) => institutionSaved.has(id)).length,
    },
    institutionsDeleted: 0,
    matchesDeleted: 0,
  };
  if (!options.apply) return summary;

  await client.$transaction(
    async (tx) => {
      for (const part of chunks(deletablePrograms)) {
        const matches = await tx.match.deleteMany({
          where: { programId: { in: part } },
        });
        summary.matchesDeleted += matches.count;
        const removed = await tx.program.deleteMany({
          where: { id: { in: part }, ...neverPublished },
        });
        summary.programsDeleted += removed.count;
      }
      for (const part of chunks(deletableInstitutions)) {
        // Un établissement qui a gagné une formation entre-temps (ou dont une
        // formation a été publiée, donc non supprimée ci-dessus) est protégé par
        // la base : `count` refuse la suppression.
        for (const id of part) {
          const remaining = await tx.program.count({
            where: { institutionId: id },
          });
          if (remaining > 0) continue;
          const removed = await tx.institution.deleteMany({
            where: { id, ...neverPublished },
          });
          summary.institutionsDeleted += removed.count;
        }
      }
    },
    { timeout: 10 * 60_000, maxWait: 30_000 },
  );
  return summary;
}
