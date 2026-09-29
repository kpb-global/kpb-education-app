import type { ExecutionContext, INestApplication } from '@nestjs/common';
import { ValidationPipe } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { Test } from '@nestjs/testing';

import { ROLES_KEY } from '../../../common/decorators/roles.decorator';
import { InternalRole } from '../../../common/enums/internal-role.enum';
import { AdminAuthGuard } from '../../../common/guards/admin-auth.guard';
import { RolesGuard } from '../../../common/guards/roles.guard';
import { EefPublicationController } from './eef-publication.controller';
import { EefPublicationService } from './eef-publication.service';

/**
 * Publier l'import, c'est rendre visibles à un étudiant SANS compte des fiches que
 * personne n'avait relues. Le périmètre est donc une décision de responsabilité :
 * `ContentManager` édite le catalogue, il ne signe pas sa publication.
 *
 * Les rôles sont résolus route par route, comme `RolesGuard` le fait (le handler
 * l'emporte sur la classe), et les routes sont lues sur le prototype : une route
 * ajoutée sans décision de périmètre fait rougir ce fichier.
 */
describe('EefPublicationController — périmètre', () => {
  const reflector = new Reflector();
  const guards: unknown[] =
    Reflect.getMetadata('__guards__', EefPublicationController) ?? [];
  const handlers = Object.getOwnPropertyNames(
    EefPublicationController.prototype,
  ).filter((name) => name !== 'constructor' && name !== 'verifier');

  const rolesFor = (name: string): InternalRole[] =>
    reflector.getAllAndOverride<InternalRole[]>(ROLES_KEY, [
      (EefPublicationController.prototype as unknown as Record<string, () => unknown>)[name],
      EefPublicationController,
    ]) ?? [];

  const SIGNERS = [InternalRole.Admin, InternalRole.SuperAdmin];

  it('exige l’authentification admin ET la garde de rôles', () => {
    expect(guards).toContain(AdminAuthGuard);
    expect(guards).toContain(RolesGuard);
  });

  it('n’expose que les trois routes prévues', () => {
    expect(handlers.sort()).toEqual(['overview', 'publish', 'unpublish']);
  });

  it.each(['overview', 'publish', 'unpublish'])(
    'la route %s est réservée à Admin et SuperAdmin',
    (name) => {
      expect(rolesFor(name).slice().sort()).toEqual(SIGNERS.slice().sort());
    },
  );

  it.each(['overview', 'publish', 'unpublish'])(
    'la route %s exclut content_manager, moderator, commercial et counselor',
    (name) => {
      const roles = rolesFor(name);
      for (const excluded of [
        InternalRole.ContentManager,
        InternalRole.Moderator,
        InternalRole.Commercial,
        InternalRole.Counselor,
      ]) {
        expect(roles).not.toContain(excluded);
      }
    },
  );
});

describe('EefPublicationController — HTTP', () => {
  let app: INestApplication;
  let base: string;
  const service = {
    overview: jest.fn(),
    publish: jest.fn(),
    unpublish: jest.fn(),
  };
  let session: { id: string; fullName: string; email: string } | undefined;

  beforeAll(async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [EefPublicationController],
      providers: [{ provide: EefPublicationService, useValue: service }],
    })
      .overrideGuard(AdminAuthGuard)
      .useValue({
        canActivate: (context: ExecutionContext) => {
          context.switchToHttp().getRequest().adminUser = session;
          return true;
        },
      })
      .overrideGuard(RolesGuard)
      .useValue({ canActivate: () => true })
      .compile();
    app = moduleRef.createNestApplication();
    // La même validation que `main.ts` : un champ inconnu est refusé.
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }),
    );
    await app.listen(0, '127.0.0.1');
    base = `http://127.0.0.1:${(app.getHttpServer().address() as { port: number }).port}`;
  });

  afterAll(() => app.close());
  beforeEach(() => {
    jest.clearAllMocks();
    session = { id: 'admin-1', fullName: 'Aïcha Relectrice', email: 'aicha@kpb.test' };
    service.publish.mockResolvedValue({ mode: 'dry-run' });
    service.unpublish.mockResolvedValue({ mode: 'dry-run' });
  });

  const post = (path: string, body: unknown) =>
    fetch(`${base}/admin/etudes-en-france/publication/${path}`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    });

  it('simule par défaut : `apply` absent vaut faux', async () => {
    const response = await post('institutions/eef-univ-1/publish', {});

    expect(response.status).toBe(201);
    expect(service.publish).toHaveBeenCalledWith(
      'eef-univ-1',
      expect.objectContaining({ apply: false }),
    );
  });

  it('n’écrit que pour `apply: true` — jamais pour une chaîne ou un nombre', async () => {
    for (const apply of ['true', 1, 'yes']) {
      const response = await post('institutions/eef-univ-1/publish', { apply });
      expect(response.status).toBe(400);
    }
    expect(service.publish).not.toHaveBeenCalled();

    await post('institutions/eef-univ-1/publish', { apply: true, expectedPrograms: 3 });
    expect(service.publish).toHaveBeenCalledWith(
      'eef-univ-1',
      expect.objectContaining({ apply: true, expectedPrograms: 3 }),
    );
  });

  it('inscrit comme relecteur l’administrateur de la SESSION', async () => {
    await post('institutions/eef-univ-1/publish', { apply: true, expectedPrograms: 1 });

    expect(service.publish.mock.calls[0][1].verifier).toEqual(
      expect.objectContaining({ id: 'admin-1', fullName: 'Aïcha Relectrice' }),
    );
  });

  it('refuse sans session au lieu de signer « Unknown admin »', async () => {
    session = undefined;

    const publish = await post('institutions/eef-univ-1/publish', { apply: true, expectedPrograms: 1 });
    const unpublish = await post('institutions/eef-univ-1/unpublish', {});

    expect(publish.status).toBe(401);
    expect(unpublish.status).toBe(401);
    expect(service.publish).not.toHaveBeenCalled();
    expect(service.unpublish).not.toHaveBeenCalled();
  });

  it.each([
    ['une liste vide', { programIds: [] }],
    ['un identifiant répété', { programIds: ['a', 'a'] }],
    ['un identifiant non textuel', { programIds: [1] }],
    ['un nombre négatif', { expectedPrograms: -1 }],
    ['un nombre décimal', { expectedPrograms: 1.5 }],
    ['un champ inconnu', { overwrite: true }],
  ])('refuse %s', async (_label, body) => {
    const response = await post('institutions/eef-univ-1/publish', body);

    expect(response.status).toBe(400);
    expect(service.publish).not.toHaveBeenCalled();
  });

  it('transmet la liste de formations telle quelle', async () => {
    await post('institutions/eef-univ-1/unpublish', {
      programIds: ['eef-prog-1', 'eef-prog-2'],
    });

    expect(service.unpublish).toHaveBeenCalledWith(
      'eef-univ-1',
      expect.objectContaining({ programIds: ['eef-prog-1', 'eef-prog-2'] }),
    );
  });

  it('sert la vue d’ensemble', async () => {
    service.overview.mockResolvedValue({ institutions: [], totals: {} });

    const response = await fetch(`${base}/admin/etudes-en-france/publication/institutions`);

    expect(response.status).toBe(200);
    expect(service.overview).toHaveBeenCalledTimes(1);
  });
});
