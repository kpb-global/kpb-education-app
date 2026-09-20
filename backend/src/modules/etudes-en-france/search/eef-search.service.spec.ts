import { BadRequestException, HttpException } from '@nestjs/common';

import { EefSearchService } from './eef-search.service';
import { PrismaService } from '../../prisma/prisma.service';
import { decodeEefCursor, encodeEefCursor } from './eef-search.query';

function programRow(over: Record<string, unknown> = {}) {
  return {
    id: 'p-1',
    institutionId: 'eef-univ-0353074b',
    countryId: 'france',
    fieldId: 'd07',
    nameFr: 'L1 - Droit',
    nameEn: 'L1 - Droit',
    levelFr: 'Bac+3 — Licence, 1re année',
    levelEn: 'Bac+3 — Bachelor, first year',
    durationFr: '3 ans',
    durationEn: '3 years',
    tuitionFr: 'x',
    tuitionEn: 'x',
    languageFr: 'Français',
    languageEn: 'French',
    requirementsFr: ['x'],
    requirementsEn: ['x'],
    campusOfferings: null,
    minGpaRequired: null,
    tuitionMinEur: null,
    applicationDeadline: null,
    teachingLanguages: ['fr'],
    lastVerifiedAt: null,
    sourceUrl: 'https://exemple.gouv.fr/x',
    verifiedById: null,
    verifiedByName: null,
    ...over,
  };
}

type Captured = { calls: Record<string, unknown>[] };

function serviceWith(opts: {
  rows?: Record<string, unknown>[];
  total?: number;
  facets?: Record<string, { value: string | null; count: number }[]>;
  countries?: { id: string; code: string }[];
  isEnabled?: boolean;
  throws?: boolean;
}) {
  const captured: Captured = { calls: [] };
  const facets = opts.facets ?? {};
  const client: Record<string, unknown> = {
    country: {
      findMany: async () =>
        opts.countries ?? [{ id: 'france', code: 'FR' }],
    },
    program: {
      findMany: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'findMany', ...args });
        return opts.rows ?? [];
      },
      count: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'count', ...args });
        return opts.total ?? (opts.rows ?? []).length;
      },
      groupBy: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'groupBy', ...args });
        const facet = (args.by as string[])[0];
        return (facets[facet] ?? []).map((entry) => ({
          [facet]: entry.value,
          _count: { _all: entry.count },
        }));
      },
    },
    $transaction: async (ps: Promise<unknown>[]) => Promise.all(ps),
  };
  const prisma = {
    isEnabled: opts.isEnabled ?? true,
    execute: async (op: (c: unknown) => Promise<unknown>) => {
      if (opts.throws) throw new Error('ECONNREFUSED');
      return op(client);
    },
  } as unknown as PrismaService;
  return { service: new EefSearchService(prisma), captured };
}

describe('EefSearchService', () => {
  it('ne rend que du relu, sur le bon pays', async () => {
    const { service, captured } = serviceWith({ rows: [programRow()] });
    await service.search({});
    const findMany = captured.calls.find((c) => c.kind === 'findMany')!;
    const where = findMany.where as Record<string, unknown>;
    expect(where.isActive).toBe(true);
    expect(where.countryId).toBe('france');
  });

  it('résout le pays par son CODE, pas par un identifiant écrit en dur', async () => {
    // Deux identifiants de la France coexistent en base selon le semeur : en
    // coder un rendrait zéro résultat sur un catalogue plein.
    const { service, captured } = serviceWith({
      rows: [programRow()],
      countries: [{ id: 'fra', code: 'FR' }, { id: 'mar', code: 'MA' }],
    });
    await service.search({});
    const findMany = captured.calls.find((c) => c.kind === 'findMany')!;
    expect((findMany.where as Record<string, unknown>).countryId).toBe('fra');
  });

  it('refuse d’avancer si la France est ambiguë ou absente', async () => {
    for (const countries of [[], [{ id: 'a', code: 'FR' }, { id: 'b', code: 'fr' }]]) {
      const { service } = serviceWith({ countries });
      await expect(service.search({})).rejects.toBeInstanceOf(HttpException);
    }
  });

  it('demande une ligne de plus que la page, et en fait le curseur', async () => {
    const rows = Array.from({ length: 4 }, (_, i) =>
      programRow({ id: `p-${i}`, nameFr: `L1 - ${i}` }),
    );
    const { service, captured } = serviceWith({ rows, total: 42 });

    const result = await service.search({ limit: '3' });

    const findMany = captured.calls.find((c) => c.kind === 'findMany')!;
    expect(findMany.take).toBe(4);
    expect(result.items).toHaveLength(3);
    expect(result.total).toBe(42);
    expect(result.page.hasMore).toBe(true);
    expect(decodeEefCursor(result.page.nextCursor!)).toEqual({
      nameFr: 'L1 - 2',
      id: 'p-2',
    });
  });

  it('ne rend pas de curseur sur la dernière page', async () => {
    const { service } = serviceWith({ rows: [programRow()] });
    const result = await service.search({ limit: '3' });
    expect(result.page.hasMore).toBe(false);
    expect(result.page.nextCursor).toBeNull();
  });

  it('compte tout, page comprise, dans la même transaction', async () => {
    // Servis séparément, le total et la page pourraient décrire deux instants
    // différents : « 1 240 résultats » au-dessus d'une liste qui en montre
    // d'autres.
    const { service, captured } = serviceWith({ rows: [programRow()] });
    await service.search({});
    expect(captured.calls.filter((c) => c.kind === 'groupBy')).toHaveLength(6);
    expect(captured.calls.filter((c) => c.kind === 'count')).toHaveLength(1);
  });

  it('compte une facette sans son propre filtre', async () => {
    const { service, captured } = serviceWith({ rows: [programRow()] });
    await service.search({ cycle: 'master', fieldId: 'd07' });
    const cycleFacet = captured.calls.find(
      (c) => c.kind === 'groupBy' && (c.by as string[])[0] === 'cycle',
    )!;
    const where = cycleFacet.where as Record<string, unknown>;
    expect(where.cycle).toBeUndefined();
    expect(where.fieldId).toEqual({ in: ['d07'] });
  });

  it('n’applique jamais le curseur au total ni aux facettes', async () => {
    // Ils décrivent « ce qu'il y a », pas « ce qui reste ».
    const { service, captured } = serviceWith({ rows: [programRow()] });
    await service.search({
      cursor: encodeEefCursor({ nameFr: 'L1 - Droit', id: 'p-1' }),
    });
    for (const call of captured.calls.filter((c) => c.kind !== 'findMany')) {
      expect((call.where as Record<string, unknown>).AND).toBeUndefined();
    }
    const findMany = captured.calls.find((c) => c.kind === 'findMany')!;
    expect((findMany.where as Record<string, unknown>).AND).toBeDefined();
  });

  it('écarte la valeur nulle d’une facette', async () => {
    // L'absence de réponse n'est pas un choix : l'afficher inviterait à
    // filtrer sur « rien ».
    const { service } = serviceWith({
      rows: [programRow()],
      facets: {
        cycle: [
          { value: 'master', count: 3112 },
          { value: null, count: 7 },
        ],
      },
    });
    const result = await service.search({});
    expect(result.facets.cycle).toEqual([{ value: 'master', count: 3112 }]);
  });

  it('tronque les facettes ouvertes et le DIT', async () => {
    const cities = Array.from({ length: 25 }, (_, i) => ({
      value: `Ville ${i}`,
      count: 25 - i,
    }));
    const { service } = serviceWith({ rows: [programRow()], facets: { campusCity: cities } });
    const result = await service.search({});
    expect(result.facets.campusCity).toHaveLength(20);
    expect(result.facetsTruncated).toContain('campusCity');
    expect(result.facetsTruncated).not.toContain('cycle');
  });

  it('répond 400 sur un paramètre fautif, en nommant les valeurs admises', async () => {
    const { service } = serviceWith({});
    await expect(service.search({ cycle: 'doctorat' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
    await expect(service.search({ cursor: 'pas-un-curseur' })).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('répond 503 plutôt que de servir un échantillon', async () => {
    // Il n'existe aucun jeu de démonstration « Études en France » : en
    // fabriquer un servirait des formations qui n'existent pas.
    const down = serviceWith({ isEnabled: false });
    await expect(down.service.search({})).rejects.toBeInstanceOf(HttpException);

    const broken = serviceWith({ throws: true });
    await expect(broken.service.search({})).rejects.toBeInstanceOf(HttpException);
  });
});
