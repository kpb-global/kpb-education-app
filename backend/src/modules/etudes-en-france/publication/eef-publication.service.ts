import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';
import type { Prisma, PrismaClient } from '@prisma/client';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';
import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  planEefPublication,
  planEefUnpublication,
  type PublicationInstitution,
  type PublicationPlan,
  type PublicationProgram,
  type UnpublicationPlan,
} from './eef-publication.plan';

type Db = Pick<PrismaClient, 'institution' | 'program' | 'savedItem'>;

const CHUNK = 2_000;
const TRANSACTION = { timeout: 5 * 60_000, maxWait: 30_000 } as const;

function chunks<T>(values: readonly T[], size = CHUNK): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < values.length; i += size) {
    out.push(values.slice(i, i + size));
  }
  return out;
}

export interface PublicationOptions {
  readonly apply: boolean;
  readonly programIds?: readonly string[];
  /** Le nombre que le plan annonce ; exigé pour écrire. */
  readonly expectedPrograms?: number;
  readonly verifier: AdminSessionUser;
}

export type PublishResult =
  | { readonly mode: 'dry-run'; readonly plan: PublicationPlan }
  | {
      readonly mode: 'applied';
      readonly plan: PublicationPlan;
      readonly institutionActivated: boolean;
      readonly programsPublished: number;
      readonly verifiedBy: { readonly id: string; readonly name: string };
      readonly verifiedAt: string;
    };

export type UnpublishResult =
  | { readonly mode: 'dry-run'; readonly plan: UnpublicationPlan }
  | {
      readonly mode: 'applied';
      readonly plan: UnpublicationPlan;
      readonly institutionDeactivated: boolean;
      readonly programsDeactivated: number;
    };

/**
 * Publier, ou retirer, un établissement de l'import « Études en France » et ses
 * formations — l'acte qui rend l'import visible à un étudiant.
 *
 * ## Pourquoi un service dédié, alors que `PATCH …/programs/:id` existe
 *
 * Ce `PATCH` publie UNE ligne, sans tampon de vérification, sans contrôle de sa
 * source ni de sa procédure, et sans que quiconque sache que l'établissement qui
 * l'accompagne est publié ou non. Pour 84 établissements et 10 502 formations, il
 * n'y a pas de « publier tout » par cette voie : il y a 10 586 appels, dont chacun
 * peut oublier quelque chose. Ici :
 *
 *   • **par établissement** — l'unité qu'un relecteur peut réellement regarder ;
 *   • **simulation par défaut**, et un chiffre saisi pour écrire ;
 *   • **le plan est recalculé DANS la transaction** : on publie ce que la base
 *     contient à l'instant de l'écriture, jamais ce que la simulation a montré ;
 *   • **le relecteur est l'administrateur connecté** — jamais un identifiant
 *     fabriqué. Le badge « Vérifié » dit qui a regardé, et cette personne est celle
 *     qui a appuyé ;
 *   • **tout ou rien** : une formation qui n'est plus publiable au moment de
 *     l'écriture annule l'ensemble.
 *
 * Le retrait est l'exact inverse, et annonce combien d'étudiants perdent la
 * formation de leur liste.
 *
 * Ce qu'il ne fait PAS : décider que la procédure Études en France / DAP est
 * exacte, ni que la source est une fiche plutôt qu'une page d'accueil. Ces deux
 * jugements sont ceux du relecteur, et la documentation (`docs/eef-catalog-pipeline.md`)
 * les nomme comme préalables à la première publication.
 */
@Injectable()
export class EefPublicationService {
  private readonly logger = new Logger(EefPublicationService.name);

  constructor(private readonly prismaService: PrismaService) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  /** Les établissements de l'import, avec ce qui reste à relire. */
  async overview() {
    this.assertDb();
    const result = await this.prismaService.execute(async (db) => {
      const [institutions, counts] = await Promise.all([
        db.institution.findMany({
          where: { id: { startsWith: EEF_INSTITUTION_ID_PREFIX } },
          select: {
            id: true,
            nameFr: true,
            isActive: true,
            sourceUrl: true,
            logoUrl: true,
            lastVerifiedAt: true,
            verifiedByName: true,
          },
          orderBy: { nameFr: 'asc' },
        }),
        db.program.groupBy({
          by: ['institutionId', 'isActive'],
          where: { id: { startsWith: EEF_PROGRAM_ID_PREFIX } },
          _count: { _all: true },
        }),
      ]);
      return { institutions, counts };
    });
    if (!result) return { institutions: [], totals: emptyTotals() };

    const pending = new Map<string, number>();
    const published = new Map<string, number>();
    for (const row of result.counts) {
      const target = row.isActive ? published : pending;
      target.set(row.institutionId, row._count._all);
    }
    const institutions = result.institutions.map((institution) => ({
      id: institution.id,
      name: institution.nameFr,
      isActive: institution.isActive,
      sourceUrl: institution.sourceUrl,
      hasLogo: institution.logoUrl !== null && institution.logoUrl !== '',
      lastVerifiedAt: institution.lastVerifiedAt,
      verifiedByName: institution.verifiedByName,
      programsPending: pending.get(institution.id) ?? 0,
      programsPublished: published.get(institution.id) ?? 0,
    }));
    return {
      institutions,
      totals: {
        institutions: institutions.length,
        institutionsPublished: institutions.filter((i) => i.isActive).length,
        programsPending: institutions.reduce((n, i) => n + i.programsPending, 0),
        programsPublished: institutions.reduce(
          (n, i) => n + i.programsPublished,
          0,
        ),
      },
    };
  }

  async publish(
    institutionId: string,
    options: PublicationOptions,
  ): Promise<PublishResult> {
    this.assertDb();
    const requested = options.programIds;
    const plan = await this.readOnly(async (db) =>
      this.planPublish(db, institutionId, requested),
    );
    if (!options.apply) return { mode: 'dry-run', plan };

    this.assertConfirmed(options.expectedPrograms, plan.programs.toPublish.length);
    this.assertPublishable(plan);

    const now = new Date();
    const stamp = {
      lastVerifiedAt: now,
      verifiedById: options.verifier.id,
      verifiedByName: verifierName(options.verifier),
    } as const;

    const applied = await this.prismaService.execute((db) =>
      db.$transaction(async (tx) => {
        // Le plan est RECALCULÉ ici : entre la simulation et l'écriture, une
        // formation a pu perdre sa source, ou être publiée par quelqu'un d'autre.
        const fresh = await this.planPublish(tx, institutionId, requested);
        this.assertConfirmed(options.expectedPrograms, fresh.programs.toPublish.length);
        this.assertPublishable(fresh);

        let published = 0;
        for (const part of chunks(fresh.programs.toPublish)) {
          const result = await tx.program.updateMany({
            where: { id: { in: part }, institutionId, isActive: false },
            data: { isActive: true, ...stamp },
          });
          published += result.count;
        }
        if (published !== fresh.programs.toPublish.length) {
          throw new ConflictException(
            'Une formation a changé pendant la publication : rien n’a été écrit. '
              + 'Relancez la simulation.',
          );
        }

        // L'établissement ne prend le tampon que lorsqu'il devient visible ou
        // n'en avait pas : le relecteur d'hier ne s'efface pas parce qu'on ajoute
        // des formations aujourd'hui.
        const institution = await tx.institution.findUnique({
          where: { id: institutionId },
          select: { isActive: true, lastVerifiedAt: true },
        });
        const activates = fresh.institution.willActivate;
        const needsStamp = activates || institution?.lastVerifiedAt == null;
        if (activates || needsStamp) {
          await tx.institution.updateMany({
            where: { id: institutionId },
            data: {
              ...(activates ? { isActive: true } : {}),
              ...(needsStamp ? stamp : {}),
            },
          });
        }
        return { plan: fresh, published, activates };
      }, TRANSACTION),
    );
    if (!applied) throw new ServiceUnavailableException('Database unavailable.');

    this.logger.log(
      `EEF publication ${institutionId} : ${applied.published} formation(s), `
        + `établissement ${applied.activates ? 'publié' : 'déjà publié'}, `
        + `relecteur ${options.verifier.id}.`,
    );
    return {
      mode: 'applied',
      plan: applied.plan,
      institutionActivated: applied.activates,
      programsPublished: applied.published,
      verifiedBy: { id: stamp.verifiedById, name: stamp.verifiedByName },
      verifiedAt: now.toISOString(),
    };
  }

  async unpublish(
    institutionId: string,
    options: PublicationOptions,
  ): Promise<UnpublishResult> {
    this.assertDb();
    const requested = options.programIds;
    const plan = await this.readOnly(async (db) =>
      this.planUnpublish(db, institutionId, requested),
    );
    if (!options.apply) return { mode: 'dry-run', plan };

    this.assertConfirmed(options.expectedPrograms, plan.toDeactivate.length);
    this.assertRemovable(plan);

    const applied = await this.prismaService.execute((db) =>
      db.$transaction(async (tx) => {
        const fresh = await this.planUnpublish(tx, institutionId, requested);
        this.assertConfirmed(options.expectedPrograms, fresh.toDeactivate.length);
        this.assertRemovable(fresh);

        let deactivated = 0;
        for (const part of chunks(fresh.toDeactivate)) {
          const result = await tx.program.updateMany({
            where: { id: { in: part }, institutionId, isActive: true },
            data: { isActive: false },
          });
          deactivated += result.count;
        }
        if (deactivated !== fresh.toDeactivate.length) {
          throw new ConflictException(
            'Une formation a changé pendant le retrait : rien n’a été écrit. '
              + 'Relancez la simulation.',
          );
        }
        // Les tampons restent : « vérifié par X le jour Y » est l'historique de ce
        // qui a été publié, il ne s'efface pas avec la visibilité.
        if (fresh.deactivateInstitution) {
          await tx.institution.updateMany({
            where: { id: institutionId, isActive: true },
            data: { isActive: false },
          });
        }
        return { plan: fresh, deactivated };
      }, TRANSACTION),
    );
    if (!applied) throw new ServiceUnavailableException('Database unavailable.');

    this.logger.log(
      `EEF retrait ${institutionId} : ${applied.deactivated} formation(s), `
        + `établissement ${applied.plan.deactivateInstitution ? 'retiré' : 'conservé'}, `
        + `par ${options.verifier.id}.`,
    );
    return {
      mode: 'applied',
      plan: applied.plan,
      institutionDeactivated: applied.plan.deactivateInstitution,
      programsDeactivated: applied.deactivated,
    };
  }

  // ── lectures ──────────────────────────────────────────────────────────────

  private async readOnly<T>(read: (db: PrismaClient) => Promise<T>): Promise<T> {
    const result = await this.prismaService.execute(read);
    if (result === null) throw new ServiceUnavailableException('Database unavailable.');
    return result;
  }

  private async loadInstitution(
    db: Db,
    institutionId: string,
  ): Promise<PublicationInstitution> {
    const row = await db.institution.findUnique({
      where: { id: institutionId },
      select: { id: true, nameFr: true, isActive: true, sourceUrl: true },
    });
    if (!row) throw new NotFoundException(`Établissement inconnu : ${institutionId}.`);
    return row;
  }

  private async loadPrograms(
    db: Db,
    institutionId: string,
    programIds: readonly string[] | undefined,
  ): Promise<PublicationProgram[]> {
    const select = {
      id: true,
      institutionId: true,
      nameFr: true,
      isActive: true,
      sourceUrl: true,
      procedureType: true,
      fieldId: true,
    } satisfies Prisma.ProgramSelect;
    if (programIds === undefined) {
      return db.program.findMany({
        where: { institutionId, id: { startsWith: EEF_PROGRAM_ID_PREFIX } },
        select,
      });
    }
    const out: PublicationProgram[] = [];
    for (const part of chunks(programIds)) {
      out.push(
        ...(await db.program.findMany({ where: { id: { in: part } }, select })),
      );
    }
    return out;
  }

  private async planPublish(
    db: Db,
    institutionId: string,
    programIds: readonly string[] | undefined,
  ): Promise<PublicationPlan> {
    const institution = await this.loadInstitution(db, institutionId);
    const programs = await this.loadPrograms(db, institutionId, programIds);
    return planEefPublication({ institution, programs, programIds });
  }

  private async planUnpublish(
    db: Db,
    institutionId: string,
    programIds: readonly string[] | undefined,
  ): Promise<UnpublicationPlan> {
    const institution = await this.loadInstitution(db, institutionId);
    const programs = await this.loadPrograms(db, institutionId, programIds);
    const draft = planEefUnpublication({
      institution,
      programs,
      programIds,
      savedByStudents: 0,
    });
    // Les étudiants qui perdent une formation : lus une fois le plan connu, sur
    // les seules formations qu'il retirerait.
    const saved = new Set<string>();
    for (const part of chunks(draft.toDeactivate)) {
      const rows = await db.savedItem.findMany({
        where: { itemId: { in: part } },
        select: { userId: true },
      });
      for (const row of rows) saved.add(row.userId);
    }
    return { ...draft, savedByStudents: saved.size };
  }

  // ── gardes ────────────────────────────────────────────────────────────────

  private assertConfirmed(expected: number | undefined, actual: number) {
    if (expected === undefined) {
      throw new BadRequestException(
        'Pour écrire, indiquez `expectedPrograms` : le nombre de formations '
          + 'annoncé par la simulation.',
      );
    }
    if (expected !== actual) {
      throw new ConflictException(
        `La simulation annonçait ${expected} formation(s), la base en donne `
          + `${actual} : rien n’a été écrit. Relancez la simulation.`,
      );
    }
  }

  private assertPublishable(plan: PublicationPlan) {
    if (!plan.publishable) {
      throw new UnprocessableEntityException({
        message: 'Rien n’est publiable pour cet établissement.',
        plan,
      });
    }
  }

  private assertRemovable(plan: UnpublicationPlan) {
    if (plan.refusals.length > 0 || plan.nothingToDo) {
      throw new UnprocessableEntityException({
        message: 'Rien n’est à retirer pour cet établissement.',
        plan,
      });
    }
  }
}

function verifierName(verifier: AdminSessionUser): string {
  return verifier.fullName.trim() || verifier.email;
}

function emptyTotals() {
  return {
    institutions: 0,
    institutionsPublished: 0,
    programsPending: 0,
    programsPublished: 0,
  };
}
