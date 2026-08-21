import { ServiceUnavailableException } from '@nestjs/common';

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
}) {
  const {
    enabled = true,
    executeResult = null,
    onUpsert = () => {},
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
        },
      };
      return op(client);
    },
  };
}

const ROW = {
  currentLevel: 'terminale',
  targetLevel: 'licence',
  fieldIds: ['info'],
  wantsPremium: true,
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
      service.declareInterest('user-1', { wantsPremium: true }),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('refuses to report success when the write returns nothing', async () => {
    const service = new EtudesEnFranceService(
      fakePrisma({ enabled: true, executeResult: null }) as never,
    );

    await expect(
      service.declareInterest('user-1', {}),
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
    await service.declareInterest('user-1', { wantsPremium: true });
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

    await service.declareInterest('user-1', {});
    await service.declareInterest('user-1', {});

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

    await service.declareInterest('user-1', {
      fieldIds: ['info', ' info ', '', '   ', 'sante'],
    });

    expect(seen[0].create.fieldIds).toEqual(['info', 'sante']);
  });

  it('normalizes blank level strings to null rather than empty cells', async () => {
    const seen: UpsertArgs[] = [];
    const service = new EtudesEnFranceService(
      fakePrisma({
        executeResult: ROW,
        onUpsert: (args) => seen.push(args),
      }) as never,
    );

    await service.declareInterest('user-1', {
      currentLevel: '   ',
      targetLevel: ' licence ',
    });

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
