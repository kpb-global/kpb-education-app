import { ServiceUnavailableException } from '@nestjs/common';

import { DeclareEefInterestDto } from './dto/declare-eef-interest.dto';
import { EtudesEnFranceService } from './etudes-en-france.service';

type UpsertArgs = {
  where: { userId: string };
  create: Record<string, unknown>;
  update: Record<string, unknown>;
};

/**
 * Un faux PrismaService qui reproduit les DEUX comportements qui comptent :
 * `isEnabled` à false quand aucune base n'est configurée, et `execute` qui rend
 * `null` dans ce cas plutôt que de lever. C'est ce `null` silencieux qui a
 * produit les défauts que ce service est écrit pour ne pas rejouer.
 */
function fakePrisma(options: {
  enabled?: boolean;
  executeResult?: unknown;
  onUpsert?: (args: UpsertArgs) => void;
  deleteResult?: unknown;
}) {
  const {
    enabled = true,
    executeResult = null,
    onUpsert = () => {},
    // `{ count: 0 }` par défaut, et c'est le cas intéressant : retirer une
    // déclaration qui n'existe pas doit réussir, pas lever.
    deleteResult = { count: 0 },
  } = options;

  return {
    isEnabled: enabled,
    execute: async (op: (client: unknown) => Promise<unknown>) => {
      if (!enabled) return null;
      const client = {
        eefInterest: {
          upsert: async (args: UpsertArgs) => {
            onUpsert(args);
            return executeResult;
          },
          findUnique: async () => executeResult,
          deleteMany: async () => deleteResult,
        },
      };
      return op(client);
    },
  };
}

/**
 * Un DTO valide, consentement compris.
 *
 * `consent` et `consentVersion` sont désormais OBLIGATOIRES : sans eux,
 * `consentedAt` n'était qu'un `now()` déplacé de Postgres vers Node, et un corps
 * vide fabriquait une preuve de consentement. Le compilateur a d'ailleurs
 * désigné les sept appels de ce fichier à l'instant où le champ est devenu
 * requis — c'est la propriété qu'on veut : le contrat ne peut plus être élargi
 * en silence.
 */
const dto = (over: Partial<DeclareEefInterestDto> = {}): DeclareEefInterestDto =>
  ({ consent: true, consentVersion: 'eef-consent-v1', ...over }) as
    DeclareEefInterestDto;

const ROW = {
  currentLevel: 'terminale',
  targetLevel: 'licence',
  fieldIds: ['info'],
  wantsPremium: true,
  consentVersion: 'eef-consent-v1',
  consentedAt: new Date('2026-08-21T10:00:00Z'),
};

describe('EtudesEnFranceService', () => {
  // LE test de ce fichier. Un service qui rendrait un objet d'apparence normale
  // sans base derrière ferait afficher « c'est noté » pour une ligne qui
  // n'existe nulle part — le défaut exact que le masquage
  // documentUploadEnabled documente côté mobile.
  it('refuses to report success when no database is configured', async () => {
    const service = new EtudesEnFranceService(
      fakePrisma({ enabled: false }) as never,
    );

    await expect(
      service.declareInterest('user-1', dto({ wantsPremium: true })),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('refuses to report success when the write returns nothing', async () => {
    const service = new EtudesEnFranceService(
      fakePrisma({ enabled: true, executeResult: null }) as never,
    );

    await expect(
      service.declareInterest('user-1', dto()),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('stamps the consent server-side on both create and update', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    const before = Date.now();
    await service.declareInterest('user-1', dto({ wantsPremium: true }));
    const after = Date.now();

    expect(seen).toHaveLength(1);
    const createStamp = seen[0].create.consentedAt as Date;
    const updateStamp = seen[0].update.consentedAt as Date;

    // La preuve de consentement est datée par le serveur, donc non antidatable
    // par un client, et rafraîchie à chaque redéclaration.
    for (const stamp of [createStamp, updateStamp]) {
      expect(stamp).toBeInstanceOf(Date);
      expect(stamp.getTime()).toBeGreaterThanOrEqual(before);
      expect(stamp.getTime()).toBeLessThanOrEqual(after);
    }
  });

  it('upserts on the user id so a double tap does not create a duplicate', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    await service.declareInterest('user-1', dto());
    await service.declareInterest('user-1', dto());

    expect(seen).toHaveLength(2);
    expect(seen[0].where).toEqual({ userId: 'user-1' });
    expect(seen[1].where).toEqual({ userId: 'user-1' });
  });

  it('dedupes and drops blank field ids before they reach the CSV export', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    await service.declareInterest(
      'user-1',
      dto({ fieldIds: ['info', ' info ', '', '   ', 'sante'] }),
    );

    expect(seen[0].create.fieldIds).toEqual(['info', 'sante']);
  });

  // ── Le consentement, devenu un acte et non un horodatage ─────────────────

  it('records the consent version so the accepted TEXT can be produced', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    await service.declareInterest(
      'user-1',
      dto({ consentVersion: '  eef-consent-v2  ' }),
    );

    // Rognée : une version avec des espaces autour serait une valeur distincte
    // dans un export, et l'on comparerait deux fois le même texte.
    expect(seen[0].create.consentVersion).toBe('eef-consent-v2');
    expect(seen[0].update.consentVersion).toBe('eef-consent-v2');
  });

  it('stamps consentedAt server-side and never takes it from the payload', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    // Une charge qui TENTE d'antidater. `forbidNonWhitelisted` la rejetterait en
    // amont ; ce test verrouille la deuxième ceinture, côté service.
    await service.declareInterest('user-1', {
      ...dto(),
      consentedAt: new Date('2020-01-01T00:00:00Z'),
    } as never);

    const stamped = seen[0].create.consentedAt as Date;
    expect(stamped.getUTCFullYear()).toBeGreaterThan(2024);
  });

  // ── Le retrait — le pendant du consentement ──────────────────────────────

  it('withdraw is idempotent: removing nothing succeeds', async () => {
    // Le cas réel : double tap sur un réseau lent, ou un retrait déjà effectué
    // depuis un autre appareil. Un 404 obligerait l'écran à distinguer « rien à
    // retirer » de « échec » pour aboutir au même affichage.
    const service = new EtudesEnFranceService(
      fakePrisma({ deleteResult: { count: 0 } }) as never,
    );

    await expect(service.withdraw('user-1')).resolves.toEqual(
      expect.objectContaining({ declared: false, consentedAt: null }),
    );
  });

  it('withdraw refuses to claim success when no database is configured', async () => {
    const service = new EtudesEnFranceService(
      fakePrisma({ enabled: false }) as never,
    );

    // Sans ce refus, l'écran afficherait « tu es retiré » sur une ligne toujours
    // en base — le mensonge exact que ce module existe pour ne pas dire.
    await expect(service.withdraw('user-1')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('normalizes blank level strings to null rather than empty cells', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    await service.declareInterest(
      'user-1',
      dto({ currentLevel: '   ', targetLevel: ' licence ' }),
    );

    expect(seen[0].create.currentLevel).toBeNull();
    expect(seen[0].create.targetLevel).toBe('licence');
  });

  // L'absence de ligne est un FAIT, pas une panne : la vitrine s'en sert pour
  // ne pas reposer la question à chaque ouverture.
  it('reports "not declared" rather than failing when there is no row', async () => {
    const service = new EtudesEnFranceService(
      fakePrisma({ executeResult: null }) as never,
    );

    await expect(service.getMyInterest('user-1')).resolves.toEqual({
      declared: false,
      currentLevel: null,
      targetLevel: null,
      fieldIds: [],
      wantsPremium: false,
      consentedAt: null,
    });
  });

  it('serves an existing declaration with an ISO consent timestamp', async () => {
    const service = new EtudesEnFranceService(
      fakePrisma({ executeResult: ROW }) as never,
    );

    await expect(service.getMyInterest('user-1')).resolves.toEqual({
      declared: true,
      currentLevel: 'terminale',
      targetLevel: 'licence',
      fieldIds: ['info'],
      wantsPremium: true,
      consentedAt: '2026-08-21T10:00:00.000Z',
    });
  });
});
