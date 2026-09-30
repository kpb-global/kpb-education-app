// ─────────────────────────────────────────────────────────────────────────────
// La file admin, le SLA de 07 h et le compteur du tableau de bord lisent LA MÊME
// définition de « à revérifier ».
//
// Ce que ce fichier garde que `verification-due.spec.ts` ne peut pas garder
//
// Les prédicats sont bons dans `verification-due.ts` ; encore faut-il que les
// DEUX consommateurs les appellent, avec la cadence de LA catégorie. Tant que la
// règle était recopiée, une copie qui perdait `isActive`, ou qui lisait 30 jours
// au lieu de 180, faisait diverger le compteur de la file sans qu'aucun test ne
// le voie : chacun comparait sa clause à un littéral, ou à `expect.any(Date)`.
//
// Ici les deux services tournent sur une horloge figée, contre une base simulée
// qui ENREGISTRE la clause reçue par chaque catégorie, et on exige qu'elles
// soient identiques — et égales à ce que la définition produit.
// ─────────────────────────────────────────────────────────────────────────────
import type { PrismaService } from '../prisma/prisma.service';
import { ReportsService } from '../reports/reports.service';
import {
  AdminCatalogService,
  VERIFICATION_POLICIES,
} from './admin-catalog.service';
import {
  countryVerificationDueWhere,
  institutionVerificationDueWhere,
  programVerificationDueWhere,
  scholarshipVerificationDueWhere,
} from './verification-due';

const NOW = new Date('2026-09-29T12:00:00.000Z');
const ENTITIES = ['country', 'institution', 'program', 'scholarship'] as const;
type Entity = (typeof ENTITIES)[number];

/** Seule `Date` est figée : les promesses et les minuteries restent réelles. */
const EVERYTHING_BUT_DATE = [
  'hrtime',
  'nextTick',
  'performance',
  'queueMicrotask',
  'requestAnimationFrame',
  'cancelAnimationFrame',
  'requestIdleCallback',
  'cancelIdleCallback',
  'setImmediate',
  'clearImmediate',
  'setInterval',
  'clearInterval',
  'setTimeout',
  'clearTimeout',
] as const;

describe('la file, le SLA et le compteur lisent la même définition', () => {
  beforeAll(() => {
    jest.useFakeTimers({ now: NOW, doNotFake: [...EVERYTHING_BUT_DATE] });
  });
  afterAll(() => {
    jest.useRealTimers();
  });

  /** Les clauses que la FILE envoie à la base, par catégorie. */
  async function queueWheres(): Promise<Record<Entity, unknown>> {
    const wheres = {} as Record<Entity, unknown>;
    const findMany = (entity: Entity) => async (args: { where: unknown }) => {
      wheres[entity] = args.where;
      return [];
    };
    const client = {
      country: { findMany: findMany('country') },
      institution: { findMany: findMany('institution') },
      program: { findMany: findMany('program') },
      scholarship: { findMany: findMany('scholarship') },
      $transaction: async (queries: Promise<unknown>[]) => Promise.all(queries),
    };
    const prisma = {
      isEnabled: true,
      execute: async (operation: (c: typeof client) => unknown) =>
        operation(client),
    } as unknown as PrismaService;
    await new AdminCatalogService(prisma).listVerificationDue();
    return wheres;
  }

  /** Les clauses que le COMPTEUR envoie à la base, par catégorie. */
  async function counterWheres(): Promise<Record<Entity, unknown>> {
    const wheres = {} as Record<Entity, unknown>;
    const count = (entity: Entity) => async (args: { where: unknown }) => {
      wheres[entity] = args.where;
      return 0;
    };
    const client = {
      case: {
        findMany: async () => [],
        count: async () => 0,
      },
      country: { count: count('country') },
      institution: { count: count('institution') },
      program: { count: count('program') },
      scholarship: { count: count('scholarship') },
      forumModerationAction: { count: async () => 0 },
    };
    const prisma = {
      isEnabled: true,
      execute: async (operation: (c: typeof client) => unknown) =>
        operation(client),
    } as unknown as PrismaService;
    await new ReportsService(prisma).getDashboardActivation();
    return wheres;
  }

  it('envoient à la base la MÊME clause, catégorie par catégorie', async () => {
    const queue = await queueWheres();
    const counter = await counterWheres();

    for (const entity of ENTITIES) {
      expect({ entity, where: counter[entity] }).toEqual({
        entity,
        where: queue[entity],
      });
    }
  });

  it('… et cette clause est celle de la définition, à la cadence de CHAQUE catégorie', async () => {
    const queue = await queueWheres();

    expect(queue.country).toEqual(
      countryVerificationDueWhere(VERIFICATION_POLICIES.countryVisa.cadenceDays, NOW),
    );
    expect(queue.institution).toEqual(
      institutionVerificationDueWhere(
        VERIFICATION_POLICIES.institutionScolarite.cadenceDays,
        NOW,
      ),
    );
    expect(queue.program).toEqual(
      programVerificationDueWhere(
        VERIFICATION_POLICIES.programScolarite.cadenceDays,
        NOW,
      ),
    );
    expect(queue.scholarship).toEqual(
      scholarshipVerificationDueWhere(
        VERIFICATION_POLICIES.scholarshipDeadline.cadenceDays,
        NOW,
      ),
    );
  });

  it('les cadences elles-mêmes sont celles du protocole de vérification', () => {
    // Pays et bourses périment vite (visas, échéances) ; établissements et
    // formations, lentement. Les changer est une décision d'exploitation
    // (`docs/catalog-verification-sop.md`), pas un effet de bord.
    expect({
      country: VERIFICATION_POLICIES.countryVisa.cadenceDays,
      institution: VERIFICATION_POLICIES.institutionScolarite.cadenceDays,
      program: VERIFICATION_POLICIES.programScolarite.cadenceDays,
      scholarship: VERIFICATION_POLICIES.scholarshipDeadline.cadenceDays,
    }).toEqual({ country: 30, institution: 180, program: 180, scholarship: 30 });
  });
});
