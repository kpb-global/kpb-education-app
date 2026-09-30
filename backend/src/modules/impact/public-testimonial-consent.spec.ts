import {
  eligiblePublicTestimonialUserIds,
  loadPublicTestimonialReceipts,
  type PublicTestimonialReceipt,
} from './public-testimonial-consent';

// La porte du consentement « témoignage public », testée seule : deux surfaces
// l'importent (`/impact/reviews` et la fiche d'un conseiller), donc une règle
// qui glisse ici glisse aux deux endroits à la fois.

const NOW = new Date('2026-09-29T12:00:00.000Z');
const ADULT = new Date('1990-01-01T00:00:00.000Z');
const MINOR = new Date('2012-03-03T00:00:00.000Z');

function receipt(
  userId: string,
  overrides: Partial<PublicTestimonialReceipt> = {},
): PublicTestimonialReceipt {
  return {
    userId,
    purpose: 'public_testimonial',
    grantedAt: new Date('2026-01-01T00:00:00.000Z'),
    revokedAt: null,
    user: { birthDate: ADULT },
    notice: {
      purpose: 'public_testimonial',
      effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
      retiredAt: null,
    },
    guardianAuthorization: null,
    ...overrides,
  };
}

const verifiedGuardian = (userId: string) => ({
  minorUserId: userId,
  status: 'verified',
  verifiedAt: new Date('2025-12-15T00:00:00.000Z'),
  expiresAt: null,
  revokedAt: null,
});

describe('eligiblePublicTestimonialUserIds', () => {
  const eligible = (...receipts: PublicTestimonialReceipt[]) =>
    eligiblePublicTestimonialUserIds(receipts, NOW);

  it('accepte un adulte au reçu actif', () => {
    expect(eligible(receipt('u1'))).toEqual(['u1']);
  });

  it('ne compte un auteur qu’une fois, même avec deux reçus', () => {
    expect(eligible(receipt('u1'), receipt('u1'))).toEqual(['u1']);
  });

  it.each([
    ['révoqué', { revokedAt: new Date('2026-02-01T00:00:00.000Z') }],
    ['accordé dans le futur', { grantedAt: new Date('2026-10-01T00:00:00.000Z') }],
    ['sans date de naissance', { user: { birthDate: null } }],
    [
      'd’une autre finalité',
      { purpose: 'marketing_contact' } as Partial<PublicTestimonialReceipt>,
    ],
    [
      'sur une notice d’une autre finalité',
      {
        notice: {
          purpose: 'marketing_contact',
          effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
          retiredAt: null,
        },
      },
    ],
    [
      'sur une notice entrée en vigueur APRÈS l’accord',
      {
        notice: {
          purpose: 'public_testimonial',
          effectiveAt: new Date('2026-02-01T00:00:00.000Z'),
          retiredAt: null,
        },
      },
    ],
    [
      'sur une notice retirée',
      {
        notice: {
          purpose: 'public_testimonial',
          effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
          retiredAt: new Date('2026-06-01T00:00:00.000Z'),
        },
      },
    ],
  ])('refuse un reçu %s', (_label, overrides) => {
    expect(eligible(receipt('u1', overrides as Partial<PublicTestimonialReceipt>))).toEqual([]);
  });

  it('exige une autorisation parentale vérifiée pour un mineur', () => {
    const minor = { birthDate: MINOR };
    expect(eligible(receipt('u1', { user: minor }))).toEqual([]);
    expect(
      eligible(receipt('u1', { user: minor, guardianAuthorization: verifiedGuardian('u1') })),
    ).toEqual(['u1']);
  });

  it.each([
    ['en attente', { status: 'pending' }],
    ['révoquée', { revokedAt: new Date('2026-03-01T00:00:00.000Z') }],
    ['expirée', { expiresAt: new Date('2026-06-01T00:00:00.000Z') }],
    ['vérifiée APRÈS l’accord', { verifiedAt: new Date('2026-02-01T00:00:00.000Z') }],
    ['posée pour un AUTRE mineur', { minorUserId: 'someone-else' }],
  ])('refuse un mineur dont l’autorisation parentale est %s', (_label, change) => {
    const guardian = { ...verifiedGuardian('u1'), ...change };
    expect(
      eligible(receipt('u1', { user: { birthDate: MINOR }, guardianAuthorization: guardian })),
    ).toEqual([]);
  });

  it('exige l’autorisation aussi pour qui était mineur À L’ACCORD, même devenu majeur', () => {
    // Né en 2008 : 17 ans le 01/01/2026 (accord), 18 ans depuis le 01/05/2026.
    const turnedAdult = { birthDate: new Date('2008-05-01T00:00:00.000Z') };
    expect(eligible(receipt('u1', { user: turnedAdult }))).toEqual([]);
    expect(
      eligible(
        receipt('u1', { user: turnedAdult, guardianAuthorization: verifiedGuardian('u1') }),
      ),
    ).toEqual(['u1']);
  });
});

describe('loadPublicTestimonialReceipts', () => {
  function reader() {
    const calls: Array<Record<string, any>> = [];
    return {
      calls,
      db: {
        consentReceipt: {
          findMany: async (args: Record<string, unknown>) => {
            calls.push(args);
            return [];
          },
        },
      },
    };
  }

  it('lit les reçus en vigueur, non révoqués, sur une notice non retirée', async () => {
    const { db, calls } = reader();
    await loadPublicTestimonialReceipts(db as never, NOW);

    expect(calls).toHaveLength(1);
    expect(calls[0].where).toEqual({
      purpose: 'public_testimonial',
      revokedAt: null,
      grantedAt: { lte: NOW },
      user: { birthDate: { not: null } },
      notice: {
        purpose: 'public_testimonial',
        effectiveAt: { lte: NOW },
        OR: [{ retiredAt: null }, { retiredAt: { gt: NOW } }],
      },
    });
  });

  it('se restreint aux auteurs donnés', async () => {
    const { db, calls } = reader();
    await loadPublicTestimonialReceipts(db as never, NOW, ['u1', 'u2']);

    expect(calls[0].where.userId).toEqual({ in: ['u1', 'u2'] });
  });

  it('ne lit RIEN pour une liste d’auteurs vide — jamais « tous les reçus »', async () => {
    const { db, calls } = reader();

    await expect(loadPublicTestimonialReceipts(db as never, NOW, [])).resolves.toEqual([]);
    expect(calls).toEqual([]);
  });
});
