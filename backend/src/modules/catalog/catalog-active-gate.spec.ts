// ─────────────────────────────────────────────────────────────────────────────
// La barrière « relu / non relu » sur les surfaces PUBLIQUES.
//
// POURQUOI CE FICHIER EXISTE
//
// L'import du catalogue « Études en France » crée ses lignes `isActive: false`
// et la documentation promet que rien ne s'affiche tant que personne n'a relu.
// Cette promesse était FAUSSE : le drapeau était écrit, et aucune lecture ne le
// lisait. `CatalogService` et `MatchesService` construisaient leur filtre à
// partir des seuls paramètres de requête, donc 10 247 formations non relues
// devenaient publiques à la seconde où l'import se terminait.
//
// Ces tests tiennent la promesse à la place du commentaire. Ils regardent la
// clause `where` réellement envoyée à Prisma, pas le résultat : une régression
// se voit à l'endroit où elle se produit.
// ─────────────────────────────────────────────────────────────────────────────
import { Test } from '@nestjs/testing';
import type { PrismaClient } from '@prisma/client';

import { CatalogService } from './catalog.service';
import { PrismaService } from '../prisma/prisma.service';

type Captured = { institutions?: unknown; programs?: unknown; hidden?: unknown };

function fakePrisma(
  captured: Captured,
  rows: {
    institutions?: Record<string, unknown>[];
    programs?: Record<string, unknown>[];
    hidden?: { id: string }[];
  } = {},
) {
  const institutionRows = rows.institutions ?? [];
  const programRows = rows.programs ?? [];
  const hiddenRows = rows.hidden ?? [];
  const client: Record<string, unknown> = {
    institution: {
      findMany: jest.fn(async (args: { where: unknown }) => {
        captured.institutions = args.where;
        return institutionRows;
      }),
    },
    program: {
      findMany: jest.fn(async (args: { where: Record<string, unknown> }) => {
        // Les deux requêtes `program.findMany` du service se distinguent par
        // leur `isActive` : la publique demande les actives, celle qui nettoie
        // `programIds` demande les inactives.
        if (args.where?.isActive === false) {
          captured.hidden = args.where;
          return hiddenRows;
        }
        captured.programs = args.where;
        return programRows;
      }),
      count: jest.fn(async () => programRows.length),
    },
    $transaction: jest.fn(
      async (arg: unknown): Promise<unknown> =>
        typeof arg === 'function'
          ? await (arg as (tx: unknown) => Promise<unknown>)(client)
          : await Promise.all(arg as Promise<unknown>[]),
    ),
  };
  return client as unknown as PrismaClient;
}

function institutionRow(over: Record<string, unknown> = {}) {
  return {
    id: 'eef-univ-0353074b',
    nameFr: 'Université de Rennes',
    nameEn: 'University of Rennes',
    countryId: 'france',
    locationFr: 'Rennes, Bretagne',
    locationEn: 'Rennes, Bretagne',
    overviewFr: 'x',
    overviewEn: 'x',
    studyLevels: ['Bachelor'],
    tuitionLabelFr: 'x',
    tuitionLabelEn: 'x',
    languageRequirementsFr: 'x',
    languageRequirementsEn: 'x',
    intakePeriods: [],
    programIds: ['prog-relu', 'prog-en-attente'],
    isPartner: false,
    isActive: true,
    lastVerifiedAt: null,
    sourceUrl: null,
    ...over,
  };
}

describe('CatalogService — la barrière relu / non relu', () => {
  let service: CatalogService;
  const prismaService = {
    isEnabled: true,
    execute: jest.fn(),
  };

  beforeEach(async () => {
    jest.clearAllMocks();
    const moduleRef = await Test.createTestingModule({
      providers: [
        CatalogService,
        { provide: PrismaService, useValue: prismaService },
      ],
    }).compile();
    service = moduleRef.get(CatalogService);
  });

  it('ne sert que les formations relues, quels que soient les filtres', async () => {
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured)),
    );

    await service.getPrograms();
    expect(captured.programs).toEqual({ isActive: true });

    await service.getPrograms({ fieldId: 'd07', countryId: 'france', q: 'droit' });
    expect((captured.programs as Record<string, unknown>).isActive).toBe(true);
  });

  it('ne sert que les établissements relus', async () => {
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(fakePrisma(captured, { institutions: [institutionRow()] })),
    );

    await service.getInstitutions();
    expect(captured.institutions).toEqual({ isActive: true });

    await service.getInstitutions({ countryId: 'france', partnerOnly: true });
    expect((captured.institutions as Record<string, unknown>).isActive).toBe(true);
  });

  it('retire de programIds les formations non relues', async () => {
    // `programIds` est dénormalisé et contient TOUTES les formations, relues
    // ou non. L'app s'en sert pour compter, prévisualiser et naviguer : le
    // servir brut publierait des références vers des fiches non relues même
    // une fois la liste des formations filtrée.
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(
        fakePrisma(captured, {
          institutions: [institutionRow()],
          hidden: [{ id: 'prog-en-attente' }],
        }),
      ),
    );

    const result = await service.getInstitutions();

    expect(captured.hidden).toEqual({
      isActive: false,
      institutionId: { in: ['eef-univ-0353074b'] },
    });
    expect((result.items[0] as { programIds: string[] }).programIds).toEqual([
      'prog-relu',
    ]);
  });

  it('laisse intacte une référence orpheline', async () => {
    // Nettoyer un identifiant qui ne correspond à aucune formation serait un
    // changement de comportement sans rapport avec la relecture. On ne retire
    // que ce qu'on sait inactif.
    const captured: Captured = {};
    prismaService.execute.mockImplementation((op: (p: PrismaClient) => unknown) =>
      op(
        fakePrisma(captured, {
          institutions: [institutionRow({ programIds: ['prog-relu', 'prog-fantome'] })],
          hidden: [],
        }),
      ),
    );

    const result = await service.getInstitutions();

    expect((result.items[0] as { programIds: string[] }).programIds).toEqual([
      'prog-relu',
      'prog-fantome',
    ]);
  });
});
