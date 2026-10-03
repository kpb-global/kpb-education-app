import type { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';

import { StudentAuthGuard } from '../../../common/guards/student-auth.guard';
import { PrismaService } from '../../prisma/prisma.service';
import { EtudesEnFranceController } from '../etudes-en-france.controller';
import { EtudesEnFranceService } from '../etudes-en-france.service';
import { EefShortlistController } from '../shortlist/eef-shortlist.controller';
import { EefShortlistService } from '../shortlist/eef-shortlist.service';
import { EefSearchController } from './eef-search.controller';
import { EefSearchService } from './eef-search.service';

/**
 * `GET /etudes-en-france/cities`, vue de l'extérieur : par HTTP, avec ses deux
 * voisins du même préfixe — le contrôleur de la déclaration d'intérêt et celui
 * de la shortlist, tous deux GARDÉS au niveau de la classe.
 *
 * Trois choses ne se prouvent qu'ainsi :
 *
 *   1. la route est PUBLIQUE. Posée par mégarde sous un contrôleur gardé, elle
 *      rendrait 403 à l'étudiant qui n'a pas encore de compte — celui pour qui
 *      le catalogue est gratuit ;
 *   2. aucune route voisine ne l'AVALE. Un `@Get(':id')` sous le même préfixe
 *      répondrait « cities » comme un identifiant ;
 *   3. ce qu'Express livre (un paramètre répété arrive en tableau) arrive tel
 *      quel au service, et `campusCity` n'y arrive PAS.
 */
describe('GET /etudes-en-france/cities — la route publique', () => {
  let app: INestApplication;
  let base: string;

  const searchService = {
    search: jest.fn(),
    cities: jest.fn(),
  };
  const interestService = { getMyInterest: jest.fn() };
  const shortlistService = { getShortlist: jest.fn() };
  // Un garde qui REFUSE tout : si la route est exposée par le contrôleur gardé,
  // elle répond 403 ; si elle est publique, il n'est jamais appelé.
  const guard = { canActivate: jest.fn(() => false) };

  const CITIES_BODY = {
    cities: [{ value: 'Paris', count: 727 }],
    total: 10_029,
    catalogPublished: true,
    source: 'database',
  };

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [
        EefSearchController,
        EtudesEnFranceController,
        EefShortlistController,
      ],
      providers: [
        { provide: EefSearchService, useValue: searchService },
        { provide: EtudesEnFranceService, useValue: interestService },
        { provide: EefShortlistService, useValue: shortlistService },
      ],
    })
      .overrideGuard(StudentAuthGuard)
      .useValue(guard)
      .compile();
    app = moduleRef.createNestApplication();
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());

  beforeEach(() => {
    jest.clearAllMocks();
    searchService.cities.mockResolvedValue(CITIES_BODY);
    searchService.search.mockResolvedValue({ items: [] });
  });

  it('répond 200 SANS identité, et n’appelle aucun garde', async () => {
    const response = await fetch(`${base}/etudes-en-france/cities`);

    expect(response.status).toBe(200);
    expect(await response.json()).toEqual(CITIES_BODY);
    expect(guard.canActivate).not.toHaveBeenCalled();
  });

  it('le garde est bien actif sur les voisins : la route publique n’est pas un faux positif', async () => {
    // Sans ce contrôle, un garde qui ne s'exécute jamais ferait passer le test
    // précédent aussi bien.
    for (const path of ['interest', 'shortlist']) {
      const response = await fetch(`${base}/etudes-en-france/${path}`);
      expect(response.status).toBe(403);
    }
    expect(guard.canActivate).toHaveBeenCalledTimes(2);
  });

  it('« cities » est résolu par SA route : ni la recherche ni un voisin ne l’avalent', async () => {
    await fetch(`${base}/etudes-en-france/cities`);

    expect(searchService.cities).toHaveBeenCalledTimes(1);
    expect(searchService.search).not.toHaveBeenCalled();
    expect(interestService.getMyInterest).not.toHaveBeenCalled();
    expect(shortlistService.getShortlist).not.toHaveBeenCalled();
  });

  it('laisse la recherche à sa place', async () => {
    const response = await fetch(`${base}/etudes-en-france/search?q=droit`);
    expect(response.status).toBe(200);
    expect(searchService.search).toHaveBeenCalledTimes(1);
    expect(searchService.cities).not.toHaveBeenCalled();
  });

  it('ne répond qu’à GET', async () => {
    for (const method of ['POST', 'PUT', 'PATCH', 'DELETE']) {
      const response = await fetch(`${base}/etudes-en-france/cities`, { method });
      expect(response.status).toBe(404);
    }
    expect(searchService.cities).not.toHaveBeenCalled();
  });

  it('transmet les six filtres, rien d’autre', async () => {
    await fetch(
      `${base}/etudes-en-france/cities?q=droit&procedureType=eef&cycle=master`
        + '&fieldId=d07&institutionId=eef-univ-a&selectivity=selective',
    );

    expect(searchService.cities).toHaveBeenCalledWith({
      q: 'droit',
      procedureType: 'eef',
      cycle: 'master',
      fieldId: 'd07',
      institutionId: 'eef-univ-a',
      selectivity: 'selective',
    });
  });

  it('livre un paramètre répété au service sous forme de TABLEAU', async () => {
    // C'est ce qu'Express rend pour `?cycle=master&cycle=licence1` — la forme que
    // produisent naturellement les clients HTTP, et celle qui a déjà fait rendre
    // 500 à la recherche.
    await fetch(
      `${base}/etudes-en-france/cities?cycle=master&cycle=licence1`
        + '&procedureType=eef,dap_blanche',
    );

    const [input] = searchService.cities.mock.calls[0];
    expect(input.cycle).toEqual(['master', 'licence1']);
    expect(input.procedureType).toBe('eef,dap_blanche');
  });

  it('ne transmet NI campusCity, NI curseur, NI taille de page', async () => {
    const response = await fetch(
      `${base}/etudes-en-france/cities?campusCity=Paris,Lyon&cursor=abc&limit=3`
        + '&cycle=master',
    );

    expect(response.status).toBe(200);
    const [input] = searchService.cities.mock.calls[0];
    expect(Object.keys(input).sort()).toEqual([
      'cycle',
      'fieldId',
      'institutionId',
      'procedureType',
      'q',
      'selectivity',
    ]);
    expect(input.cycle).toBe('master');
  });

  it('transmet les paramètres absents comme absents', async () => {
    await fetch(`${base}/etudes-en-france/cities`);
    const [input] = searchService.cities.mock.calls[0];
    expect(Object.values(input).every((value) => value === undefined)).toBe(true);
  });
});

/**
 * Les statuts, avec le VRAI service (et une base absente) : le 400 d'un
 * paramètre fautif et le 503 d'une base indisponible doivent sortir tels quels
 * par HTTP, avec le `code` que l'app lit pour choisir son message.
 */
describe('GET /etudes-en-france/cities — les erreurs, par HTTP', () => {
  let app: INestApplication;
  let base: string;
  let isEnabled = false;

  beforeAll(async () => {
    const prisma = {
      get isEnabled() {
        return isEnabled;
      },
      execute: async () => null,
    } as unknown as PrismaService;
    const moduleRef = await Test.createTestingModule({
      controllers: [EefSearchController],
      providers: [
        { provide: PrismaService, useValue: prisma },
        EefSearchService,
      ],
    }).compile();
    app = moduleRef.createNestApplication();
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());

  it('400 EEF_SEARCH_BAD_PARAM sur une valeur hors référentiel, avec les valeurs admises', async () => {
    isEnabled = true;
    const response = await fetch(`${base}/etudes-en-france/cities?cycle=doctorat`);

    expect(response.status).toBe(400);
    const body = (await response.json()) as { code: string; message: string };
    expect(body.code).toBe('EEF_SEARCH_BAD_PARAM');
    expect(body.message).toContain('cycle');
    expect(body.message).toContain('master');
  });

  it('503 CATALOG_UNAVAILABLE quand la base est indisponible — jamais un échantillon', async () => {
    isEnabled = false;
    const response = await fetch(`${base}/etudes-en-france/cities`);

    expect(response.status).toBe(503);
    const body = (await response.json()) as { code: string };
    expect(body.code).toBe('CATALOG_UNAVAILABLE');
  });
});
