// ─────────────────────────────────────────────────────────────────────────────
// Recherche paginée du catalogue « Études en France ».
//
// CE QUE CE SERVICE RÈGLE, ET QUI N'EST PAS UN DÉTAIL DE PERFORMANCE
//
// Le client tient aujourd'hui la totalité du catalogue en mémoire et filtre
// côté app. À 133 formations c'était invisible ; à 10 247 c'est une app qui
// rame le jour de la campagne, sur les appareils les moins chers — ceux du
// public visé. Le plan (§ 5.1) le nomme comme le point d'architecture à ne pas
// repousser.
//
// Ce service ne fait QUE poser des requêtes : ce qu'elles disent est décidé
// dans `eef-search.query.ts`, sans Prisma ni Nest.
//
// PAS DE REPLI SUR LES JEUX DE DÉMONSTRATION
//
// `/catalog/*` sait dégrader vers `mock-catalog` hors production. Ici, non :
// il n'existe aucun échantillon « Études en France », et en fabriquer un
// servirait des formations qui n'existent pas — le scénario exact que tout ce
// pipeline refuse. Base indisponible ⇒ 503, partout.
// ─────────────────────────────────────────────────────────────────────────────
import { BadRequestException, Injectable } from '@nestjs/common';
import type { PrismaClient, Program } from '@prisma/client';

import { catalogUnavailable } from '../../catalog/catalog-degraded-mode';
import { resolveFranceCountryId } from '../catalog/eef-country';
import {
  loadPublishedInstitutions,
  publishedInstitutionIds,
  type PublishedInstitution,
} from '../catalog/eef-published-institutions';
import { mapEefProgram } from '../catalog/eef-program-view';
import { PrismaService } from '../../prisma/prisma.service';
import {
  EEF_SEARCH_FACETS,
  EEF_SEARCH_ORDER_BY,
  EefSearchCursorError,
  EefSearchParamError,
  buildEefSearchWhere,
  encodeEefCursor,
  isRestricted,
  parseEefSearchInput,
  type EefSearchFacet,
  type EefSearchInput,
  type EefSearchParams,
} from './eef-search.query';
import { buildSearchTerms, resolveTermInstitutions } from './eef-search.terms';

/// Les facettes à valeurs ouvertes : ville et établissement en comptent des
/// dizaines. On rend les plus fournies et on DIT qu'il en reste, plutôt que
/// d'en servir soixante-dix dont l'écran ne montrera jamais la moitié.
const OPEN_FACET_LIMIT = 20;
const OPEN_FACETS: ReadonlySet<EefSearchFacet> = new Set([
  'campusCity',
  'institutionId',
]);

export interface EefFacetValue {
  readonly value: string;
  readonly count: number;
}

export interface EefSearchResult {
  readonly items: unknown[];
  readonly total: number;
  readonly page: {
    readonly limit: number;
    readonly nextCursor: string | null;
    readonly hasMore: boolean;
  };
  readonly facets: Record<string, EefFacetValue[]>;
  readonly facetsTruncated: string[];
  /// Vrai si le catalogue publié contient au moins une formation, QUEL QUE SOIT
  /// le filtre. Faux ⇒ rien n'est encore publié : l'écran dit « le catalogue
  /// arrive » et non « ta recherche est trop étroite », ce qui serait faux et
  /// enverrait l'étudiant retirer des filtres sur une base vide.
  readonly catalogPublished: boolean;
  readonly source: 'database';
}

@Injectable()
export class EefSearchService {
  constructor(private readonly prismaService: PrismaService) {}

  async search(input: EefSearchInput): Promise<EefSearchResult> {
    let params: EefSearchParams;
    try {
      params = parseEefSearchInput(input);
    } catch (error) {
      if (
        error instanceof EefSearchParamError
        || error instanceof EefSearchCursorError
      ) {
        // 400 et non 500 : c'est la requête qui est fautive, et le message
        // nomme le paramètre ET les valeurs admises pour que le client
        // corrige au lieu de réessayer à l'identique.
        throw new BadRequestException({
          code: 'EEF_SEARCH_BAD_PARAM',
          message: error.message,
        });
      }
      throw error;
    }

    if (!this.prismaService.isEnabled) throw catalogUnavailable('eef-search');

    const countryId = await this.resolveCountryId();
    const result = await this.run(async (prisma) => {
      // Lus UNE fois, avant la transaction, puis passés à TOUTES les clauses de
      // cette réponse : la page, le total et les six facettes décrivent ainsi le
      // même ensemble d'établissements, même si l'un d'eux est publié pendant
      // que la transaction s'exécute. Sans cette liste, une formation dont
      // l'établissement n'a jamais été relu était servie.
      const institutions = await loadPublishedInstitutions(prisma, countryId);
      const publishedIds = publishedInstitutionIds(institutions);
      // Les mots qui désignent un établissement (par son nom ou son sigle),
      // résolus UNE fois ici : page, total et facettes voient les mêmes.
      const termInstitutionIds = resolveTermInstitutions(
        buildSearchTerms(params.terms),
        institutions,
      );
      const pageWhere = buildEefSearchWhere(params, countryId, publishedIds, {
        withCursor: true,
        termInstitutionIds,
      });
      const totalWhere = buildEefSearchWhere(params, countryId, publishedIds, {
        termInstitutionIds,
      });

      // « Le catalogue est-il vide, ou est-ce ma recherche ? » Sans restriction,
      // `total` répond. Avec, il faut une sonde : une seule formation publiée,
      // sans aucun des filtres de la requête. Elle est posée DANS la transaction
      // ci-dessous : lue après, une publication survenue entre les deux ferait
      // coexister un résultat vide d'un instant et un `catalogPublished` d'un
      // autre — et l'écran dirait « ta recherche est trop étroite » sur un
      // catalogue qui vient de se vider, ou l'inverse.
      const needsProbe = isRestricted(params) && publishedIds.length > 0;

      // Une seule transaction : le total, la page, les six facettes et la sonde
      // doivent décrire le MÊME instant. Servis séparément, un import concurrent
      // rendrait « 1 240 résultats » au-dessus d'une liste qui en montre
      // d'autres.
      const fetched = await prisma.$transaction([
        prisma.program.findMany({
          where: pageWhere,
          orderBy: EEF_SEARCH_ORDER_BY,
          // Une ligne de plus que demandé : c'est elle qui dit s'il y a une
          // suite, sans payer un second `count`.
          take: params.limit + 1,
        }),
        prisma.program.count({ where: totalWhere }),
        ...EEF_SEARCH_FACETS.map((facet) =>
          prisma.program.groupBy({
            by: [facet],
            where: buildEefSearchWhere(params, countryId, publishedIds, {
              excludeFacet: facet,
              termInstitutionIds,
            }),
            _count: { _all: true },
            orderBy: { _count: { [facet]: 'desc' } },
            take: OPEN_FACETS.has(facet) ? OPEN_FACET_LIMIT + 1 : undefined,
          } as never),
        ),
        ...(needsProbe
          ? [
              prisma.program.findFirst({
                where: buildEefSearchWhere(
                  parseEefSearchInput({}),
                  countryId,
                  publishedIds,
                ),
                select: { id: true },
              }) as never,
            ]
          : []),
      ], {
        // `READ COMMITTED`, l'isolation par défaut de Postgres, donne à CHAQUE
        // instruction son propre instantané : une publication survenue entre
        // le total et les facettes rendrait une réponse qui se contredit.
        // `RepeatableRead` fait tenir la promesse que la transaction affiche.
        isolationLevel: 'RepeatableRead',
      });

      const [rows, total, ...rest] = fetched;
      const facetRows = rest.slice(0, EEF_SEARCH_FACETS.length);
      const probe = needsProbe ? rest[EEF_SEARCH_FACETS.length] : null;
      const catalogPublished = (total as number) > 0 || probe != null;
      return {
        rows: rows as Program[],
        total: total as number,
        facetRows,
        institutions,
        catalogPublished,
      };
    });

    const hasMore = result.rows.length > params.limit;
    const page = hasMore ? result.rows.slice(0, params.limit) : result.rows;
    const last = page[page.length - 1];

    const facets: Record<string, EefFacetValue[]> = {};
    const facetsTruncated: string[] = [];
    EEF_SEARCH_FACETS.forEach((facet, index) => {
      const raw = (result.facetRows[index] ?? []) as Record<string, unknown>[];
      const values = raw
        .map((row) => ({
          value: String(row[facet] ?? ''),
          count: Number((row._count as { _all: number } | undefined)?._all ?? 0),
        }))
        // Une valeur nulle en base n'est pas une facette : c'est l'absence de
        // réponse, et l'afficher comme un choix inviterait à filtrer dessus.
        .filter((entry) => entry.value !== '');
      if (OPEN_FACETS.has(facet) && values.length > OPEN_FACET_LIMIT) {
        facetsTruncated.push(facet);
        facets[facet] = values.slice(0, OPEN_FACET_LIMIT);
      } else {
        facets[facet] = values;
      }
    });

    const institutionsById = new Map<string, PublishedInstitution>(
      result.institutions.map((institution) => [institution.id, institution]),
    );

    return {
      items: page.map((row) => mapEefProgram(row, institutionsById)),
      total: result.total,
      page: {
        limit: params.limit,
        hasMore,
        nextCursor:
          hasMore && last
            ? encodeEefCursor({ nameFr: last.nameFr, id: last.id })
            : null,
      },
      facets,
      facetsTruncated,
      catalogPublished: result.catalogPublished,
      source: 'database',
    };
  }

  /**
   * Le pays, résolu par son CODE et non écrit en dur — et par la règle
   * PARTAGÉE avec l'import (`eef-country.ts`), qui accepte alpha-2 comme
   * alpha-3. La règle vivait ici en double de l'import, et c'est pour cela que
   * l'erreur — ne chercher que « FR » alors que le référentiel écrit « FRA » —
   * existait en double.
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
      // Le catalogue n'a nulle part où se rattacher : c'est une indisponibilité
      // de service, pas une requête fautive.
      throw catalogUnavailable('eef-search-country');
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
      throw catalogUnavailable('eef-search');
    }
    if (result === null) throw catalogUnavailable('eef-search');
    return result;
  }
}
