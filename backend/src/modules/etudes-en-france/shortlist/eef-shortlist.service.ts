// ─────────────────────────────────────────────────────────────────────────────
// La shortlist « Études en France » — la moitié qui parle à la base.
//
// Tout ce qui DÉCIDE — le chemin d'entrée, l'étage, les motifs, les clauses —
// vit dans `eef-shortlist.path.ts` et `eef-shortlist.rank.ts`, sans Prisma ni
// Nest. Ici on pose les questions et on assemble la réponse.
//
// PAS DE REPLI SUR LES JEUX DE DÉMONSTRATION, ENCORE MOINS QU'AILLEURS
//
// La recherche refuse déjà de dégrader vers `mock-catalog`. Une shortlist est
// pire : ce n'est pas une liste que l'étudiant a demandée par mots-clés, c'est
// une RECOMMANDATION NOMINATIVE. Servir des formations d'échantillon
// reviendrait à recommander des établissements qui n'existent pas. Base
// indisponible ⇒ 503.
//
// POURQUOI `isActive: true` COMPTE DOUBLE ICI
//
// C'est la frontière entre ce qu'un vérificateur a relu et ce que le pipeline
// a déposé. Elle vaut pour la recherche ; elle vaut davantage pour une liste
// qui dit « celles-ci sont pour toi ».
// ─────────────────────────────────────────────────────────────────────────────
import { Injectable } from '@nestjs/common';
import type { PrismaClient } from '@prisma/client';

import { catalogUnavailable } from '../../catalog/catalog-degraded-mode';
import { mapProgram } from '../../catalog/catalog.mapper';
import { PrismaService } from '../../prisma/prisma.service';
import { resolveFranceCountryId } from '../catalog/eef-country';
import { resolveEefPath, type EefDeclaration } from './eef-shortlist.path';
import {
  EEF_CANDIDATE_STRATA,
  EEF_SHORTLIST_ORDER_BY,
  buildShortlistWhere,
  clampShortlistLimit,
  reasonsFor,
  type EefCandidateRow,
} from './eef-shortlist.rank';
import {
  EEF_PATH_BASIS,
  EEF_SHORTLIST_TIERS,
  type EefShortlistBasis,
  type EefShortlistBlocked,
  type EefShortlistDisclosure,
  type EefShortlistReason,
  type EefShortlistTier,
} from './eef-shortlist.types';

/// Vraies pour chaque ligne du catalogue, donc dites UNE fois en tête de
/// réponse. Les répéter par formation serait du bruit ; les taire ferait
/// passer le silence pour une absence de frais, d'exigence ou d'échéance.
const CONSTANT_DISCLOSURES: readonly EefShortlistDisclosure[] = [
  'tuition_not_published',
  'french_level_not_published',
  'campaign_dates_served_separately',
];

export interface EefShortlistItem {
  readonly program: unknown;
  readonly reasons: EefShortlistReason[];
}

export interface EefShortlistTierResult {
  readonly tier: EefShortlistTier;
  /// Le nombre TOTAL de formations de cet étage, pas le nombre servi. « 5 sur
  /// 412 » et « 5 sur 5 » n'appellent pas le même geste, et seule la seconde
  /// autorise à dire qu'on a fait le tour.
  readonly total: number;
  readonly items: EefShortlistItem[];
}

export interface EefShortlistResult {
  readonly declaration: {
    readonly currentLevel: string | null;
    readonly targetLevel: string | null;
    readonly fieldIds: string[];
  } | null;
  readonly path: string | null;
  readonly blocked: EefShortlistBlocked | null;
  readonly ranking: { readonly basis: EefShortlistBasis };
  readonly tiers: EefShortlistTierResult[];
  readonly limit: number;
  readonly disclosures: EefShortlistDisclosure[];
  readonly source: 'database';
}

@Injectable()
export class EefShortlistService {
  constructor(private readonly prismaService: PrismaService) {}

  async getShortlist(
    userId: string,
    rawLimit?: string,
  ): Promise<EefShortlistResult> {
    const limit = clampShortlistLimit(rawLimit);

    if (!this.prismaService.isEnabled) throw catalogUnavailable('eef-shortlist');

    // Le résultat est EMBALLÉ, et ce n'est pas une coquetterie.
    //
    // `run()` traite un `null` comme « base indisponible » — c'est la
    // convention de `PrismaService.execute`, qui rend `null` quand Prisma est
    // éteint. Or `findUnique` rend légitimement `null` ici : c'est le cas de
    // l'étudiant qui n'a jamais déclaré son intérêt, c'est-à-dire le PREMIER
    // écran. Sans emballage, il recevait un 503 — une panne affichée à la
    // place de la question à poser, exactement la confusion que cette
    // fonctionnalité existe pour éviter.
    const { row: interest } = await this.run(async (prisma) => ({
      row: await prisma.eefInterest.findUnique({
        where: { userId },
        select: { currentLevel: true, targetLevel: true, fieldIds: true },
      }),
    }));

    const declaration: EefDeclaration | null = interest
      ? {
          currentLevel: interest.currentLevel,
          targetLevel: interest.targetLevel,
          fieldIds: interest.fieldIds ?? [],
        }
      : null;

    const resolution = resolveEefPath(declaration);

    if (resolution.blocked !== null) {
      // 200, pas 4xx. La lecture a réussi ; ce qui manque, c'est une réponse
      // de l'étudiant. Un code d'erreur ferait afficher un écran de panne là
      // où il faut poser une question.
      return this.blockedResult(declaration, resolution.blocked, limit);
    }

    const path = resolution.path;
    const basis = EEF_PATH_BASIS[path];
    const declaredFieldIds = declaration?.fieldIds ?? [];
    const countryId = await this.resolveCountryId();

    // Une seule transaction pour les étages ET leurs totaux : servis
    // séparément, un import concurrent rendrait « 412 formations » au-dessus
    // d'un étage qui en montre cinq autres.
    const plan = EEF_SHORTLIST_TIERS.flatMap((tier) =>
      EEF_CANDIDATE_STRATA.map((stratum) => ({ tier, stratum })),
    );

    const fetched = await this.run(async (prisma) =>
      prisma.$transaction(
        [
          ...plan.map(({ tier, stratum }) =>
            prisma.program.findMany({
              where: buildShortlistWhere({
                path,
                countryId,
                declaredFieldIds,
                tier,
                stratum,
              }),
              // La ligne ENTIÈRE : `mapProgram` sert le même objet que la
              // recherche, et servir une fiche amputée obligerait le client à
              // deux lectures différentes de la même formation.
              orderBy: EEF_SHORTLIST_ORDER_BY,
              take: limit,
            }),
          ),
          ...EEF_SHORTLIST_TIERS.map((tier) =>
            prisma.program.count({
              where: buildShortlistWhere({
                path,
                countryId,
                declaredFieldIds,
                tier,
                // Le total compte l'ÉTAGE ENTIER, pas une strate : un étudiant
                // veut savoir combien de masters « dossier seul » le concernent,
                // pas comment on s'y est pris pour en choisir cinq. Compter sur
                // `linked` seule aurait pu annoncer un total inférieur au
                // nombre servi.
                stratum: 'any',
              }),
            }),
          ),
        ],
        // `READ COMMITTED` donne à chaque instruction son propre instantané :
        // une publication survenue entre deux étages ferait apparaître la même
        // formation dans deux colonnes, ou dans aucune.
        { isolationLevel: 'RepeatableRead' },
      ),
    );

    const pages = fetched.slice(0, plan.length) as Record<string, unknown>[][];
    const totals = fetched.slice(plan.length) as unknown as number[];

    const tiers: EefShortlistTierResult[] = EEF_SHORTLIST_TIERS.map(
      (tier, tierIndex) => {
        const seen = new Set<string>();
        const rows: Record<string, unknown>[] = [];
        // Strate `linked` d'abord, `open` seulement pour compléter : servies au
        // même rang, les formations « Toutes licences » occuperaient le haut de
        // la liste sans avoir aucun lien avec la filière déclarée.
        for (const stratum of EEF_CANDIDATE_STRATA) {
          const index = plan.findIndex(
            (entry) => entry.tier === tier && entry.stratum === stratum,
          );
          for (const row of pages[index] ?? []) {
            const id = String(row.id);
            if (rows.length >= limit || seen.has(id)) continue;
            seen.add(id);
            rows.push(row);
          }
        }
        return {
          tier,
          total: Number(totals[tierIndex] ?? 0),
          items: rows.map((row) => ({
            program: mapProgram(row as never),
            reasons: reasonsFor(
              row as unknown as EefCandidateRow,
              declaredFieldIds,
              path,
            ),
          })),
        };
      },
    )
      // Un étage vide n'est pas servi : une colonne vide se lit « rien pour
      // toi », ce qui est faux quand les autres étages sont pleins.
      .filter((entry) => entry.items.length > 0);

    return {
      declaration: this.publicDeclaration(declaration),
      path,
      blocked: null,
      ranking: { basis },
      tiers,
      limit,
      disclosures: [
        ...CONSTANT_DISCLOSURES,
        ...(declaredFieldIds.length === 0
          ? (['no_field_declared'] as const)
          : []),
        ...(basis === null ? (['no_ranking_data'] as const) : []),
      ],
      source: 'database',
    };
  }

  private blockedResult(
    declaration: EefDeclaration | null,
    blocked: EefShortlistBlocked,
    limit: number,
  ): EefShortlistResult {
    return {
      declaration: this.publicDeclaration(declaration),
      path: null,
      blocked,
      ranking: { basis: null },
      tiers: [],
      limit,
      disclosures: [...CONSTANT_DISCLOSURES],
      source: 'database',
    };
  }

  private publicDeclaration(declaration: EefDeclaration | null) {
    if (!declaration) return null;
    return {
      currentLevel: declaration.currentLevel,
      targetLevel: declaration.targetLevel,
      fieldIds: [...declaration.fieldIds],
    };
  }

  /**
   * Le pays, résolu par son CODE et par la règle PARTAGÉE avec l'import et la
   * recherche. Écrire `'fra'` en dur ici aurait recréé, une troisième fois,
   * l'erreur que `eef-country.ts` existe pour ne plus avoir en double.
   */
  private async resolveCountryId(): Promise<string> {
    const rows = await this.run((prisma) =>
      prisma.country.findMany({
        where: { isActive: true },
        select: { id: true, code: true },
      }),
    );
    try {
      return resolveFranceCountryId(rows);
    } catch {
      throw catalogUnavailable('eef-shortlist-country');
    }
  }

  private async run<T>(
    operation: (prisma: PrismaClient) => Promise<T>,
  ): Promise<T> {
    let result: T | null;
    try {
      result = await this.prismaService.execute(operation);
    } catch {
      // `PrismaService.execute()` a déjà journalisé le code d'erreur borné et
      // sans données personnelles avant de relancer.
      throw catalogUnavailable('eef-shortlist');
    }
    if (result === null) throw catalogUnavailable('eef-shortlist');
    return result;
  }
}
