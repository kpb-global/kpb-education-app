import { BadRequestException, HttpException } from '@nestjs/common';

import { eefProgramWhere } from '../../../common/eef-provenance';
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

/// Un établissement publié tel que la base le rend : assez pour être nommé sur
/// une carte et retrouvé par son nom ou son sigle.
function institutionRow(id: string, over: Record<string, unknown> = {}) {
  return {
    id,
    nameFr: `Université ${id}`,
    nameEn: `University ${id}`,
    acronym: null,
    locationFr: 'Rennes, Bretagne',
    locationEn: 'Rennes, Brittany',
    institutionType: 'universite_publique',
    websiteUrl: 'https://www.exemple.fr',
    logoUrl: null,
    logoSourceUrl: null,
    logoLicence: null,
    ...over,
  };
}

/// L'établissement par défaut des lignes de test : publié, sauf demande contraire.
const PUBLISHED_INSTITUTION = 'eef-univ-0353074b';

/**
 * Vrai si la clause porte `institutionId IN ()` — c'est-à-dire qu'aucune ligne
 * ne peut la satisfaire.
 *
 * La doublure l'honore : sans cela, elle rendrait les mêmes lignes à chaque
 * requête, et « sans établissement publié, rien ne sort » ne serait testé par
 * rien — le test passerait aussi bien si la clause avait disparu.
 */
function noInstitutionAllowed(where: unknown): boolean {
  const and = ((where as Record<string, unknown>)?.AND ?? []) as Record<
    string,
    { in?: unknown[] }
  >[];
  return and.some(
    (clause) =>
      Array.isArray(clause.institutionId?.in) && clause.institutionId.in.length === 0,
  );
}

function serviceWith(opts: {
  rows?: Record<string, unknown>[];
  total?: number;
  facets?: Record<string, { value: string | null; count: number }[]>;
  countries?: { id: string; code: string }[];
  /// Les établissements publiés que la base répond. Par défaut, un seul. Une
  /// chaîne est un identifiant ; un objet, un établissement complet.
  publishedInstitutions?: (string | ReturnType<typeof institutionRow>)[];
  isEnabled?: boolean;
  throws?: boolean;
  /// Ce que répond « existe-t-il une formation publiée, sans aucun filtre ? ».
  anyPublished?: boolean;
}) {
  const captured: Captured = { calls: [] };
  const facets = opts.facets ?? {};
  const client: Record<string, unknown> = {
    country: {
      findMany: async () =>
        opts.countries ?? [{ id: 'france', code: 'FR' }],
    },
    institution: {
      findMany: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'institution', ...args });
        return (opts.publishedInstitutions ?? [PUBLISHED_INSTITUTION]).map(
          (entry) => (typeof entry === 'string' ? institutionRow(entry) : entry),
        );
      },
    },
    program: {
      findMany: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'findMany', ...args });
        return noInstitutionAllowed(args.where) ? [] : (opts.rows ?? []);
      },
      findFirst: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'findFirst', ...args });
        if (noInstitutionAllowed(args.where)) return null;
        return opts.anyPublished === false ? null : { id: 'p-any' };
      },
      count: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'count', ...args });
        return noInstitutionAllowed(args.where)
          ? 0
          : (opts.total ?? (opts.rows ?? []).length);
      },
      groupBy: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'groupBy', ...args });
        if (noInstitutionAllowed(args.where)) return [];
        const facet = (args.by as string[])[0];
        return (facets[facet] ?? []).map((entry) => ({
          [facet]: entry.value,
          _count: { _all: entry.count },
        }));
      },
    },
    $transaction: async (
      ps: Promise<unknown>[],
      options?: Record<string, unknown>,
    ) => {
      captured.calls.push({ kind: 'transaction', size: ps.length, ...options });
      return Promise.all(ps);
    },
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
    // Ils décrivent « ce qu'il y a », pas « ce qui reste ». Leur `AND` ne porte
    // donc QUE les clauses de PORTÉE — l'établissement publié et la provenance —,
    // aucun morceau de curseur.
    const { service, captured } = serviceWith({ rows: [programRow()] });
    await service.search({
      cursor: encodeEefCursor({ nameFr: 'L1 - Droit', id: 'p-1' }),
    });
    const reads = captured.calls.filter(
      (c) =>
        c.kind !== 'findMany' && c.kind !== 'institution' && c.where !== undefined,
    );
    expect(reads.length).toBeGreaterThan(0);
    for (const call of reads) {
      expect((call.where as Record<string, unknown>).AND).toEqual([
        { institutionId: { in: [PUBLISHED_INSTITUTION] } },
        eefProgramWhere(),
      ]);
    }
    const findMany = captured.calls.find((c) => c.kind === 'findMany')!;
    const pageAnd = (findMany.where as Record<string, unknown>).AND as unknown[];
    // Le curseur, puis la portée (publié + provenance).
    expect(pageAnd).toHaveLength(3);
    expect(JSON.stringify(pageAnd)).toContain('"gt"');
  });

  // ── Le parent doit être publié ────────────────────────────────────────────
  //
  // `Program` n'a pas de relation vers `Institution` : une formation publiée
  // sous une université que personne n'a relue était servie, avec pour parent
  // une fiche non vérifiée. Ces tests regardent la question posée à la base.
  describe('l’établissement doit être publié', () => {
    it('lit les établissements actifs du pays, et rien d’autre', async () => {
      const { service, captured } = serviceWith({ rows: [programRow()] });
      await service.search({});
      const asked = captured.calls.filter((c) => c.kind === 'institution');
      expect(asked).toHaveLength(1);
      expect(asked[0].where).toEqual({ isActive: true, countryId: 'france' });
    });

    it('passe la MÊME liste à la page, au total et à chaque facette', async () => {
      // Une liste lue une fois, huit clauses : elles décrivent le même ensemble
      // d'établissements même si l'un d'eux est publié pendant la transaction.
      const { service, captured } = serviceWith({
        rows: [programRow()],
        publishedInstitutions: ['eef-univ-a', 'eef-univ-b'],
      });
      await service.search({});

      const programReads = captured.calls.filter(
        (c) => c.kind !== 'institution' && c.where !== undefined,
      );
      // 1 page + 1 total + 6 facettes.
      expect(programReads).toHaveLength(8);
      for (const call of programReads) {
        expect((call.where as Record<string, unknown>).AND).toContainEqual({
          institutionId: { in: ['eef-univ-a', 'eef-univ-b'] },
        });
      }
    });

    it('lit les établissements AVANT la transaction, une seule fois', async () => {
      const { service, captured } = serviceWith({ rows: [programRow()] });
      await service.search({});
      const kinds = captured.calls.map((c) => c.kind);
      expect(kinds.filter((k) => k === 'institution')).toHaveLength(1);
      expect(kinds.indexOf('institution')).toBeLessThan(
        kinds.indexOf('transaction'),
      );
    });

    it('sans aucun établissement publié, ne sert rien — c’est l’état de la production', async () => {
      // La liste vide ne doit surtout pas DISPARAÎTRE de la clause : l'omettre
      // servirait tout le catalogue. La doublure honore `IN ()`, donc ce test
      // échoue si la clause est absente.
      const { service } = serviceWith({
        rows: [programRow()],
        total: 42,
        publishedInstitutions: [],
        facets: { cycle: [{ value: 'master', count: 42 }] },
      });
      const result = await service.search({});
      expect(result.items).toEqual([]);
      expect(result.total).toBe(0);
      expect(result.page.hasMore).toBe(false);
      expect(result.facets.cycle).toEqual([]);
    });

    it('ne sert pas non plus quand l’établissement demandé n’est pas publié', async () => {
      // Le client peut demander n'importe quel identifiant d'établissement :
      // demander un parent non publié ne doit pas le rendre servable.
      const { service, captured } = serviceWith({
        rows: [programRow()],
        publishedInstitutions: ['eef-univ-a'],
      });
      await service.search({ institutionId: 'eef-univ-non-publiee' });
      const findMany = captured.calls.find((c) => c.kind === 'findMany')!;
      const where = findMany.where as Record<string, unknown>;
      expect(where.institutionId).toEqual({ in: ['eef-univ-non-publiee'] });
      expect(where.AND).toContainEqual({ institutionId: { in: ['eef-univ-a'] } });
    });
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

  describe('ce que chaque item dit de la formation et de son établissement', () => {
    it('sert la procédure, le cycle et l’établissement nommé', async () => {
      const { service } = serviceWith({
        rows: [
          programRow({
            procedureType: 'dap_blanche',
            cycle: 'licence1',
            selectivity: 'non_selective',
            campusCity: 'Rennes',
            formationCode: '12345',
            admissionModes: [],
            recommendedBachelors: [],
          }),
        ],
        publishedInstitutions: [
          institutionRow(PUBLISHED_INSTITUTION, {
            nameFr: 'Université de Rennes',
            acronym: 'UR',
            logoUrl:
              'https://upload.wikimedia.org/wikipedia/commons/thumb/a/ab/L.svg/320px-L.svg.png',
            logoSourceUrl: 'https://commons.wikimedia.org/wiki/File:L.svg',
            logoLicence: 'CC0',
          }),
        ],
      });

      const { items } = await service.search({});

      expect(items[0]).toMatchObject({
        procedureType: 'dap_blanche',
        cycle: 'licence1',
        campusCity: 'Rennes',
        institution: {
          id: PUBLISHED_INSTITUTION,
          name: { fr: 'Université de Rennes' },
          acronym: 'UR',
          logoLicence: 'CC0',
        },
      });
    });

    it('ne met jamais un établissement non publié dans un item', async () => {
      const { service } = serviceWith({
        rows: [programRow({ institutionId: 'eef-univ-autre' })],
        publishedInstitutions: [PUBLISHED_INSTITUTION],
      });
      const { items } = await service.search({});
      expect((items[0] as { institution: unknown }).institution).toBeNull();
    });
  });

  describe('la recherche libre par université et par niveau', () => {
    it('résout le nom ou le sigle en établissements AVANT les requêtes', async () => {
      const { service, captured } = serviceWith({
        rows: [programRow()],
        publishedInstitutions: [
          institutionRow('eef-univ-sorbonne', { nameFr: 'Sorbonne Université' }),
          institutionRow('eef-univ-upec', {
            nameFr: 'Université Paris-Est Créteil',
            acronym: 'UPEC',
          }),
        ],
      });

      await service.search({ q: 'sorbonne' });
      await service.search({ q: 'upec' });

      const wheres = captured.calls
        .filter((c) => c.kind === 'findMany')
        .map((c) => JSON.stringify(c.where));
      expect(wheres[0]).toContain('"institutionId":{"in":["eef-univ-sorbonne"]}');
      expect(wheres[1]).toContain('"institutionId":{"in":["eef-univ-upec"]}');
    });

    it('applique la MÊME résolution à la page, au total et aux facettes', async () => {
      const { service, captured } = serviceWith({
        rows: [programRow()],
        publishedInstitutions: [
          institutionRow('eef-univ-sorbonne', { nameFr: 'Sorbonne Université' }),
        ],
      });
      await service.search({ q: 'sorbonne' });
      const queried = captured.calls.filter((c) =>
        ['findMany', 'count', 'groupBy'].includes(String(c.kind)),
      );
      expect(queried.length).toBeGreaterThan(2);
      for (const call of queried) {
        expect(JSON.stringify(call.where)).toContain(
          '"institutionId":{"in":["eef-univ-sorbonne"]}',
        );
      }
    });

    it('traduit « licence » en cycles, sans lire d’établissement de plus', async () => {
      const { service, captured } = serviceWith({ rows: [programRow()] });
      await service.search({ q: 'licence droit' });
      const where = JSON.stringify(
        captured.calls.find((c) => c.kind === 'findMany')!.where,
      );
      expect(where).toContain('"cycle":{"in":["licence1","licence2","licence3","licence_pro"]}');
      expect(captured.calls.filter((c) => c.kind === 'institution')).toHaveLength(1);
    });
  });

  describe('catalogPublished — le catalogue est-il vide, ou est-ce la recherche ?', () => {
    it('est vrai dès qu’une formation est servie', async () => {
      const { service } = serviceWith({ rows: [programRow()], total: 1 });
      const result = await service.search({ q: 'droit' });
      expect(result.catalogPublished).toBe(true);
    });

    // La sonde décrit le MÊME instant que la page, le total et les facettes : lue
    // après la transaction, une publication survenue entre les deux ferait
    // coexister un résultat vide d'un instant et un `catalogPublished` d'un autre.
    it('pose la sonde DANS la transaction isolée, pas après', async () => {
      const { service, captured } = serviceWith({ rows: [], total: 0, anyPublished: true });
      await service.search({ q: 'introuvable' });

      const probes = captured.calls.filter((c) => c.kind === 'findFirst');
      const transactions = captured.calls.filter((c) => c.kind === 'transaction');
      expect(probes).toHaveLength(1);
      expect(transactions).toHaveLength(1);
      // page + total + six facettes + la sonde.
      expect(transactions[0].size).toBe(2 + 6 + 1);
      expect(transactions[0].isolationLevel).toBe('RepeatableRead');
    });

    it('ne pose aucune sonde sans restriction : `total` répond déjà', async () => {
      const { service, captured } = serviceWith({ rows: [], total: 0 });
      await service.search({});
      expect(captured.calls.some((c) => c.kind === 'findFirst')).toBe(false);
      const [transaction] = captured.calls.filter((c) => c.kind === 'transaction');
      expect(transaction.size).toBe(2 + 6);
    });

    it('est faux quand rien n’est publié, sans aucun filtre', async () => {
      const { service, captured } = serviceWith({
        rows: [],
        total: 0,
        publishedInstitutions: [],
      });
      const result = await service.search({});
      expect(result.total).toBe(0);
      expect(result.catalogPublished).toBe(false);
      expect(captured.calls.some((c) => c.kind === 'findFirst')).toBe(false);
    });

    it('est faux sans restriction et sans résultat, même si des établissements sont publiés', async () => {
      const { service } = serviceWith({ rows: [], total: 0 });
      expect((await service.search({})).catalogPublished).toBe(false);
    });

    it('est VRAI quand la recherche est trop étroite sur un catalogue plein', async () => {
      // C'est la distinction que l'écran attend : zéro résultat ne veut pas dire
      // « catalogue vide ».
      const { service, captured } = serviceWith({ rows: [], total: 0, anyPublished: true });
      const result = await service.search({ q: 'introuvable' });
      expect(result.total).toBe(0);
      expect(result.catalogPublished).toBe(true);
      const probe = captured.calls.find((c) => c.kind === 'findFirst')!;
      // La sonde ne porte AUCUN filtre de la requête — seulement la portée.
      expect(JSON.stringify(probe.where)).not.toContain('introuvable');
      expect(JSON.stringify(probe.where)).toContain('"isActive":true');
    });

    it('est faux quand la recherche est étroite ET que le catalogue est vide', async () => {
      const { service } = serviceWith({ rows: [], total: 0, anyPublished: false });
      expect((await service.search({ cycle: 'master' })).catalogPublished).toBe(false);
    });

    it('n’interroge rien de plus quand aucun établissement n’est publié', async () => {
      const { service, captured } = serviceWith({
        rows: [],
        total: 0,
        publishedInstitutions: [],
      });
      const result = await service.search({ q: 'droit' });
      expect(result.catalogPublished).toBe(false);
      expect(captured.calls.some((c) => c.kind === 'findFirst')).toBe(false);
    });
  });

  // ── cities — la liste COMPLÈTE des villes de campus ───────────────────────
  //
  // La facette `campusCity` de `search` est plafonnée à 20 valeurs : les 20
  // premières villes ne couvrent que 4 201 formations sur 10 029. Un filtre
  // « Ville » avec recherche a besoin de toutes les villes, avec ce que
  // chacune donnerait SI ON LA CHOISISSAIT — les autres filtres restant ceux
  // de l'écran. Ces tests regardent la question posée à la base ; l'effet
  // réel est prouvé sur Postgres (`eef-search.postgres.spec.ts`).
  describe('cities — la liste complète des villes de campus', () => {
    const city = (value: string | null, count: number) => ({ value, count });

    const groupBys = (captured: Captured) =>
      captured.calls.filter((c) => c.kind === 'groupBy');

    it('rend TOUTES les villes : aucune troncature à 20, aucun drapeau', async () => {
      const cities = Array.from({ length: 276 }, (_, i) =>
        city(`Ville ${String(i).padStart(3, '0')}`, 1000 - i),
      );
      const { service } = serviceWith({ total: 10_029, facets: { campusCity: cities } });

      const result = await service.cities({});

      expect(result.cities).toHaveLength(276);
      expect(result.cities[0]).toEqual({ value: 'Ville 000', count: 1000 });
      expect(result.cities[275]).toEqual({ value: 'Ville 275', count: 725 });
      // Pas de `facetsTruncated` : il n'y a rien de tronqué à dire.
      expect(result).not.toHaveProperty('facetsTruncated');
    });

    it('ne pose AUCUN `take` sur le comptage des villes', async () => {
      const { service, captured } = serviceWith({
        total: 3,
        facets: { campusCity: [city('Paris', 3)] },
      });
      await service.cities({});
      const [groupBy] = groupBys(captured);
      expect(groupBy.by).toEqual(['campusCity']);
      expect(groupBy.take).toBeUndefined();
    });

    it('ne pose qu’UNE requête de comptage de villes — pas les six facettes', async () => {
      const { service, captured } = serviceWith({ total: 3 });
      await service.cities({});
      expect(groupBys(captured)).toHaveLength(1);
      expect(captured.calls.filter((c) => c.kind === 'findMany')).toHaveLength(0);
      expect(captured.calls.filter((c) => c.kind === 'count')).toHaveLength(1);
    });

    it('rend la forme annoncée, et rien d’autre', async () => {
      const { service } = serviceWith({
        total: 800,
        facets: { campusCity: [city('Paris', 727), city('Rennes', 73)] },
      });
      const result = await service.cities({});
      expect(result).toEqual({
        cities: [
          { value: 'Paris', count: 727 },
          { value: 'Rennes', count: 73 },
        ],
        total: 800,
        catalogPublished: true,
        source: 'database',
      });
    });

    describe('l’ordre', () => {
      it('trie par nombre décroissant, puis par nom', async () => {
        const { service } = serviceWith({
          total: 100,
          facets: {
            campusCity: [
              city('Rennes', 5),
              city('Paris', 50),
              city('Angers', 5),
              city('Lyon', 20),
            ],
          },
        });
        const { cities } = await service.cities({});
        expect(cities.map((entry) => entry.value)).toEqual([
          'Paris',
          'Lyon',
          'Angers',
          'Rennes',
        ]);
      });

      it('ordonne les noms SANS tenir compte des accents ni de la casse', async () => {
        // Un tri par point de code range « Épinal » après « Zola » : l'étudiant
        // qui cherche Épinal dans une liste alphabétique le chercherait au bout.
        const { service } = serviceWith({
          total: 100,
          facets: {
            campusCity: [
              city('Zola', 5),
              city('Épinal', 5),
              city('eu', 5),
              city('Évry', 5),
              city('Aix', 5),
            ],
          },
        });
        const { cities } = await service.cities({});
        expect(cities.map((entry) => entry.value)).toEqual([
          'Aix',
          'Épinal',
          'eu',
          'Évry',
          'Zola',
        ]);
      });

      it('départage deux graphies d’une même ville de façon STABLE', async () => {
        // « Créteil » et « Creteil » coexistent dans le catalogue (deux jeux
        // ouverts, deux orthographes). Ex æquo une fois les accents ôtés : l'ordre
        // ne doit pas dépendre de celui où la base les a rendues.
        const forward = serviceWith({
          total: 9,
          facets: { campusCity: [city('Créteil', 4), city('Creteil', 4)] },
        });
        const backward = serviceWith({
          total: 9,
          facets: { campusCity: [city('Creteil', 4), city('Créteil', 4)] },
        });
        const a = (await forward.service.cities({})).cities.map((e) => e.value);
        const b = (await backward.service.cities({})).cities.map((e) => e.value);
        expect(a).toEqual(b);
        expect(a).toEqual(['Creteil', 'Créteil']);
      });
    });

    describe('une formation sans ville', () => {
      it('n’apparaît dans aucune ville', async () => {
        const { service } = serviceWith({
          total: 10,
          facets: {
            campusCity: [
              city('Paris', 6),
              city(null, 3),
              city('', 1),
              city('   ', 1),
            ],
          },
        });
        const { cities } = await service.cities({});
        expect(cities).toEqual([{ value: 'Paris', count: 6 }]);
      });

      it('reste dans `total` : c’est le nombre de formations hors ville', async () => {
        // 10 formations correspondent aux filtres, 6 ont une ville : `total` dit
        // 10, pas la somme des villes. L'écran peut ainsi dire « 4 sans ville ».
        const { service } = serviceWith({
          total: 10,
          facets: { campusCity: [city('Paris', 6), city(null, 4)] },
        });
        const result = await service.cities({});
        expect(result.total).toBe(10);
        expect(result.cities.reduce((sum, entry) => sum + entry.count, 0)).toBe(6);
      });
    });

    describe('campusCity est IGNORÉ', () => {
      it('ne figure pas dans la clause, même si le client l’envoie', async () => {
        // Le compteur d'une ville répond à « combien si je choisissais CETTE
        // ville ? ». Avec la ville déjà choisie dans la clause, toutes les autres
        // tomberaient à zéro et l'étudiant ne pourrait plus en changer.
        const { service, captured } = serviceWith({ total: 3 });
        await service.cities({ campusCity: 'Paris,Lyon', cycle: 'master' } as never);
        const reads = captured.calls.filter(
          (c) => c.kind === 'groupBy' || c.kind === 'count',
        );
        expect(reads.length).toBe(2);
        for (const call of reads) {
          const where = call.where as Record<string, unknown>;
          expect(where.campusCity).toBeUndefined();
          expect(JSON.stringify(where)).not.toContain('Paris');
          // Le reste de la requête, lui, est bien appliqué.
          expect(where.cycle).toEqual({ in: ['master'] });
        }
      });

      it('ne le valide pas non plus : 21 villes n’y font pas rendre 400', async () => {
        const tooMany = Array.from({ length: 21 }, (_, i) => `Ville ${i}`).join(',');
        const { service } = serviceWith({ total: 3 });
        await expect(
          service.cities({ campusCity: tooMany } as never),
        ).resolves.toMatchObject({ source: 'database' });
      });

      it('ignore aussi le curseur et la taille de page, qui n’ont pas de sens ici', async () => {
        const { service } = serviceWith({ total: 3 });
        await expect(
          service.cities({ cursor: 'pas-un-curseur', limit: '3' } as never),
        ).resolves.toMatchObject({ source: 'database' });
      });
    });

    describe('les autres filtres sont ceux de la recherche', () => {
      const filterCases: [string, string | string[], string[]][] = [
        ['procedureType', 'dap_blanche,eef', ['dap_blanche', 'eef']],
        ['cycle', ['master', 'licence1'], ['master', 'licence1']],
        ['fieldId', 'd07', ['d07']],
        ['institutionId', 'eef-univ-a,eef-univ-b', ['eef-univ-a', 'eef-univ-b']],
        ['selectivity', 'selective', ['selective']],
      ];
      it.each(filterCases)(
        '%s est appliqué au comptage des villes ET au total (csv et répété)',
        async (name, input, expected) => {
          const { service, captured } = serviceWith({ total: 3 });
          await service.cities({ [name]: input } as never);
          const reads = captured.calls.filter(
            (c) => c.kind === 'groupBy' || c.kind === 'count',
          );
          expect(reads).toHaveLength(2);
          for (const call of reads) {
            expect((call.where as Record<string, unknown>)[name]).toEqual({
              in: expected,
            });
          }
        },
      );

      it('lit les mots de `q` comme la recherche : établissement résolu, niveau désigné', async () => {
        const { service, captured } = serviceWith({
          total: 3,
          publishedInstitutions: [
            institutionRow('eef-univ-sorbonne', { nameFr: 'Sorbonne Université' }),
          ],
        });
        await service.cities({ q: 'licence sorbonne' });
        const reads = captured.calls.filter(
          (c) => c.kind === 'groupBy' || c.kind === 'count',
        );
        expect(reads).toHaveLength(2);
        for (const call of reads) {
          const where = JSON.stringify(call.where);
          expect(where).toContain('"institutionId":{"in":["eef-univ-sorbonne"]}');
          expect(where).toContain('"cycle":{"in":["licence1","licence2","licence3","licence_pro"]}');
        }
      });

      it('ne pose que des clauses de PORTÉE en plus : établissement publié et provenance', async () => {
        const { service, captured } = serviceWith({ total: 3 });
        await service.cities({});
        for (const call of captured.calls.filter(
          (c) => c.kind === 'groupBy' || c.kind === 'count',
        )) {
          const where = call.where as Record<string, unknown>;
          expect(where.isActive).toBe(true);
          expect(where.countryId).toBe('france');
          expect(where.AND).toEqual([
            { institutionId: { in: [PUBLISHED_INSTITUTION] } },
            eefProgramWhere(),
          ]);
        }
      });

      it('répond 400 sur une valeur hors référentiel, comme la recherche', async () => {
        const { service } = serviceWith({});
        const failure = await service
          .cities({ cycle: 'doctorat' })
          .then(() => null, (error: unknown) => error);
        expect(failure).toBeInstanceOf(BadRequestException);
        expect((failure as BadRequestException).getResponse()).toMatchObject({
          code: 'EEF_SEARCH_BAD_PARAM',
        });
        await expect(
          service.cities({ selectivity: 'peut-être' }),
        ).rejects.toBeInstanceOf(BadRequestException);
        await expect(
          service.cities({ fieldId: ['d01', 'd99'] }),
        ).rejects.toBeInstanceOf(BadRequestException);
      });

      it('refuse une liste `IN` sans borne, comme la recherche', async () => {
        const tooMany = Array.from({ length: 21 }, (_, i) => `inst-${i}`).join(',');
        const { service } = serviceWith({});
        await expect(
          service.cities({ institutionId: tooMany }),
        ).rejects.toBeInstanceOf(BadRequestException);
      });
    });

    describe('l’établissement doit être publié', () => {
      it('lit les établissements UNE fois, avant la transaction', async () => {
        const { service, captured } = serviceWith({ total: 3 });
        await service.cities({});
        const kinds = captured.calls.map((c) => c.kind);
        expect(kinds.filter((k) => k === 'institution')).toHaveLength(1);
        expect(kinds.indexOf('institution')).toBeLessThan(kinds.indexOf('transaction'));
      });

      it('sans aucun établissement publié, ne rend aucune ville — jamais « toutes »', async () => {
        // La doublure honore `institutionId IN ()` : ce test échoue si la clause
        // disparaît de la requête.
        const { service } = serviceWith({
          total: 42,
          publishedInstitutions: [],
          facets: { campusCity: [city('Paris', 42)] },
        });
        const result = await service.cities({});
        expect(result.cities).toEqual([]);
        expect(result.total).toBe(0);
        expect(result.catalogPublished).toBe(false);
      });
    });

    describe('une seule transaction, comme la recherche', () => {
      it('lit villes et total au même instant, en RepeatableRead', async () => {
        const { service, captured } = serviceWith({ total: 3 });
        await service.cities({});
        const transactions = captured.calls.filter((c) => c.kind === 'transaction');
        expect(transactions).toHaveLength(1);
        // villes + total, sans restriction donc sans sonde.
        expect(transactions[0].size).toBe(2);
        expect(transactions[0].isolationLevel).toBe('RepeatableRead');
      });
    });

    describe('catalogPublished', () => {
      it('est vrai dès qu’une formation correspond', async () => {
        const { service } = serviceWith({ total: 1 });
        expect((await service.cities({ cycle: 'master' })).catalogPublished).toBe(true);
      });

      it('ne pose aucune sonde sans restriction : `total` répond déjà', async () => {
        const { service, captured } = serviceWith({ total: 0 });
        const result = await service.cities({});
        expect(result.catalogPublished).toBe(false);
        expect(captured.calls.some((c) => c.kind === 'findFirst')).toBe(false);
      });

      it('est VRAI quand les filtres sont trop étroits sur un catalogue publié', async () => {
        // Zéro ville ne veut pas dire « catalogue vide » : l'écran doit dire
        // « aucune ville pour ces filtres », pas « le catalogue arrive ».
        const { service, captured } = serviceWith({ total: 0, anyPublished: true });
        const result = await service.cities({ q: 'introuvable' });
        expect(result.cities).toEqual([]);
        expect(result.total).toBe(0);
        expect(result.catalogPublished).toBe(true);
        const probe = captured.calls.find((c) => c.kind === 'findFirst')!;
        expect(JSON.stringify(probe.where)).not.toContain('introuvable');
      });

      it('pose la sonde DANS la transaction isolée', async () => {
        const { service, captured } = serviceWith({ total: 0, anyPublished: true });
        await service.cities({ q: 'introuvable' });
        const [transaction] = captured.calls.filter((c) => c.kind === 'transaction');
        // villes + total + la sonde.
        expect(transaction.size).toBe(3);
        expect(transaction.isolationLevel).toBe('RepeatableRead');
      });

      it('est faux quand les filtres sont étroits ET que le catalogue est vide', async () => {
        const { service } = serviceWith({ total: 0, anyPublished: false });
        expect((await service.cities({ cycle: 'master' })).catalogPublished).toBe(false);
      });

      it('n’interroge rien de plus quand aucun établissement n’est publié', async () => {
        const { service, captured } = serviceWith({
          total: 0,
          publishedInstitutions: [],
        });
        const result = await service.cities({ q: 'droit' });
        expect(result.catalogPublished).toBe(false);
        expect(captured.calls.some((c) => c.kind === 'findFirst')).toBe(false);
      });
    });

    describe('pas de repli sur un échantillon', () => {
      it('répond 503 quand la base est désactivée ou en panne', async () => {
        // Il n'existe aucun jeu de démonstration « Études en France » : en
        // fabriquer un servirait des villes qui n'ont aucune formation. `source`
        // vaut donc toujours « database », et la panne se dit par un 503.
        const down = serviceWith({ isEnabled: false });
        const failure = await down.service
          .cities({})
          .then(() => null, (error: unknown) => error);
        expect(failure).toBeInstanceOf(HttpException);
        expect((failure as HttpException).getStatus()).toBe(503);
        expect((failure as HttpException).getResponse()).toMatchObject({
          code: 'CATALOG_UNAVAILABLE',
        });

        const broken = serviceWith({ throws: true });
        await expect(broken.service.cities({})).rejects.toMatchObject({
          status: 503,
        });
      });

      it('répond 503 quand la France est ambiguë ou absente', async () => {
        for (const countries of [[], [{ id: 'a', code: 'FR' }, { id: 'b', code: 'fr' }]]) {
          const { service } = serviceWith({ countries });
          await expect(service.cities({})).rejects.toBeInstanceOf(HttpException);
        }
      });

      it('valide les paramètres AVANT de toucher à la base : un 400 reste un 400 base éteinte', async () => {
        const { service } = serviceWith({ isEnabled: false });
        await expect(
          service.cities({ cycle: 'doctorat' }),
        ).rejects.toBeInstanceOf(BadRequestException);
      });
    });
  });
});
