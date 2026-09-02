import { ForbiddenException, ServiceUnavailableException } from '@nestjs/common';
import { validate } from 'class-validator';
import { plainToInstance } from 'class-transformer';

import { JoinPremiumWaitlistDto } from './dto/join-premium-waitlist.dto';
import { PremiumWaitlistController } from './premium-waitlist.controller';
import { PremiumWaitlistService } from './premium-waitlist.service';

type UpsertArgs = {
  where: { userId: string };
  create: Record<string, unknown>;
  update: Record<string, unknown>;
};

/**
 * Un faux PrismaService reproduisant les deux comportements qui comptent :
 * `isEnabled` faux quand aucune base n'est configurée, et `execute` qui rend
 * `null` dans ce cas au lieu de lever. C'est ce `null` silencieux qui produit
 * les « c'est noté » sur des lignes jamais écrites.
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
    deleteResult = { count: 0 },
  } = options;

  return {
    isEnabled: enabled,
    execute: async (op: (client: unknown) => Promise<unknown>) => {
      if (!enabled) return null;
      const client = {
        premiumWaitlistEntry: {
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

const validDto: JoinPremiumWaitlistDto = {
  consent: true,
  consentVersion: 'premium-waitlist-v1',
};

const row = { consentedAt: new Date('2026-09-03T10:00:00.000Z') };

describe('PremiumWaitlistService', () => {
  it("horodate le consentement CÔTÉ SERVEUR, sans jamais le lire du client", async () => {
    let seen: UpsertArgs | null = null;
    const service = new PremiumWaitlistService(
      fakePrisma({ executeResult: row, onUpsert: (a) => (seen = a) }) as never,
    );

    const before = Date.now();
    await service.join('user-1', validDto);
    const after = Date.now();

    const args = seen as unknown as UpsertArgs;
    const stamped = args.create.consentedAt as Date;
    expect(stamped.getTime()).toBeGreaterThanOrEqual(before);
    expect(stamped.getTime()).toBeLessThanOrEqual(after);
    // La version voyage telle quelle : c'est elle qui dit CE QUI a été lu.
    expect(args.create.consentVersion).toBe('premium-waitlist-v1');
  });

  it('rafraîchit la preuve à la réinscription plutôt que de garder la première', async () => {
    let seen: UpsertArgs | null = null;
    const service = new PremiumWaitlistService(
      fakePrisma({ executeResult: row, onUpsert: (a) => (seen = a) }) as never,
    );

    await service.join('user-1', validDto);

    const args = seen as unknown as UpsertArgs;
    // Le consentement qui compte est le DERNIER donné : garder la première date
    // ferait produire une preuve périmée, désignant peut-être un texte que
    // l'étudiant n'a jamais vu.
    expect(args.update.consentedAt).toBeInstanceOf(Date);
    expect(args.update.consentVersion).toBe('premium-waitlist-v1');
  });

  it("n'invente JAMAIS un succès quand la base est absente", async () => {
    const service = new PremiumWaitlistService(
      fakePrisma({ enabled: false }) as never,
    );
    await expect(service.join('user-1', validDto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it("échoue fermé quand l'écriture ne rend rien", async () => {
    // Base configurée, mais l'écriture rend `null`. Sans ce contrôle, l'écran
    // afficherait « tu es inscrit » pour une ligne qui n'existe nulle part.
    const service = new PremiumWaitlistService(
      fakePrisma({ executeResult: null }) as never,
    );
    await expect(service.join('user-1', validDto)).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });

  it('rend « pas inscrit » quand aucune ligne n\'existe, sans lever', async () => {
    const service = new PremiumWaitlistService(
      fakePrisma({ executeResult: null }) as never,
    );
    await expect(service.getMine('user-1')).resolves.toEqual({
      registered: false,
      registeredAt: null,
    });
  });

  it('retire de façon idempotente — zéro ligne supprimée reste un succès', async () => {
    const service = new PremiumWaitlistService(
      fakePrisma({ deleteResult: { count: 0 } }) as never,
    );
    await expect(service.leave('user-1')).resolves.toEqual({
      registered: false,
      registeredAt: null,
    });
  });

  it("ne prétend pas avoir retiré quand la suppression ne rend rien", async () => {
    const service = new PremiumWaitlistService(
      fakePrisma({ deleteResult: null }) as never,
    );
    await expect(service.leave('user-1')).rejects.toBeInstanceOf(
      ServiceUnavailableException,
    );
  });
});

describe('JoinPremiumWaitlistDto', () => {
  const check = async (payload: Record<string, unknown>) =>
    validate(plainToInstance(JoinPremiumWaitlistDto, payload));

  it('refuse un corps vide — sinon un rejeu fabriquerait un consentement', async () => {
    expect(await check({})).not.toHaveLength(0);
  });

  it('refuse un consentement explicitement faux', async () => {
    expect(
      await check({ consent: false, consentVersion: 'premium-waitlist-v1' }),
    ).not.toHaveLength(0);
  });

  it('refuse une inscription sans version de texte', async () => {
    // Une date prouve le moment, pas ce qui a été lu.
    expect(await check({ consent: true })).not.toHaveLength(0);
    expect(await check({ consent: true, consentVersion: '  ' })).not.toHaveLength(0);
  });

  it('accepte le seul corps qui a du sens', async () => {
    expect(
      await check({ consent: true, consentVersion: 'premium-waitlist-v1' }),
    ).toHaveLength(0);
  });
});

describe('PremiumWaitlistController', () => {
  const service = {
    join: jest.fn(async () => ({ registered: true, registeredAt: null })),
    getMine: jest.fn(async () => ({ registered: false, registeredAt: null })),
    leave: jest.fn(async () => ({ registered: false, registeredAt: null })),
  };
  const controller = new PremiumWaitlistController(service as never);
  const req = (accountType?: string) =>
    ({ studentUser: { id: 'u1', accountType } }) as never;

  beforeEach(() => jest.clearAllMocks());

  it("refuse l'inscription aux comptes parent et partenaire", () => {
    // Un parent y ferait entrer SES coordonnées dans une liste que le
    // back-office présente comme une liste d'étudiants à prévenir.
    for (const type of ['parent', 'partner']) {
      expect(() => controller.join(req(type), { consent: true, consentVersion: 'v1' }))
        .toThrow(ForbiddenException);
    }
    expect(service.join).not.toHaveBeenCalled();
  });

  it('refuse aussi le RETRAIT aux mêmes comptes', () => {
    // Laisser la porte ouverte inviterait à croire que la règle ne vaut que
    // pour la création.
    expect(() => controller.leave(req('parent'))).toThrow(ForbiddenException);
    expect(service.leave).not.toHaveBeenCalled();
  });

  it('laisse la LECTURE ouverte à tous les comptes authentifiés', async () => {
    // Elle rend « pas inscrit » pour un parent, ce qui est vrai et sans effet.
    // La fermer produirait un 403 que le client avale, donc une erreur
    // invisible pour un non-problème.
    await expect(controller.getMine(req('parent'))).resolves.toEqual({
      registered: false,
      registeredAt: null,
    });
    expect(service.getMine).toHaveBeenCalledWith('u1');
  });

  it("accepte l'inscription d'un compte étudiant", () => {
    controller.join(req('student'), { consent: true, consentVersion: 'v1' });
    expect(service.join).toHaveBeenCalledWith('u1', {
      consent: true,
      consentVersion: 'v1',
    });
  });
});
