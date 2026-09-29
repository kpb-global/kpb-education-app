import type { PrismaClient } from '@prisma/client';

/**
 * La porte du consentement « témoignage public » — une seule, pour toute
 * surface qui publie le nom civil ou le texte d'un avis.
 *
 * Un avis n'est publiable que si son AUTEUR a un reçu `public_testimonial`
 * actif : notice en vigueur au moment de l'accord, non révoqué, et — pour un
 * mineur — une autorisation parentale vérifiée, non révoquée, non expirée.
 * `isPublished` (la modération) est nécessaire ; il n'est pas suffisant.
 *
 * Ce code vivait dans `ImpactService`, qui sert `/impact/reviews` et le taux de
 * satisfaction. `GET /counsellors/:id` servait pourtant lui aussi le nom civil
 * (`reviewerName`) dès que `isPublished` valait `true`, sans regarder aucun
 * reçu : deux portes, une seule gardée. Il est désormais ici, importé par les
 * deux, pour que le prochain écran qui publie un avis n'en réécrive pas une
 * troisième version.
 */
export type PublicTestimonialReceipt = {
  userId: string;
  purpose: string;
  grantedAt: Date;
  revokedAt: Date | null;
  user: { birthDate: Date | null };
  notice: {
    purpose: string;
    effectiveAt: Date;
    retiredAt: Date | null;
  };
  guardianAuthorization: {
    minorUserId: string;
    status: string;
    verifiedAt: Date | null;
    expiresAt: Date | null;
    revokedAt: Date | null;
  } | null;
};

const PUBLIC_TESTIMONIAL_RECEIPT_SELECT = {
  userId: true,
  purpose: true,
  grantedAt: true,
  revokedAt: true,
  user: { select: { birthDate: true } },
  notice: {
    select: {
      purpose: true,
      effectiveAt: true,
      retiredAt: true,
    },
  },
  guardianAuthorization: {
    select: {
      minorUserId: true,
      status: true,
      verifiedAt: true,
      expiresAt: true,
      revokedAt: true,
    },
  },
} as const;

/**
 * Les reçus `public_testimonial` non révoqués et en vigueur — éventuellement
 * restreints à `userIds` (la fiche d'un conseiller n'a besoin que des auteurs de
 * SES avis, pas de tous les reçus de la base). Une liste vide ne charge rien :
 * jamais « tout ».
 */
export function loadPublicTestimonialReceipts(
  db: Pick<PrismaClient, 'consentReceipt'>,
  now: Date,
  userIds?: readonly string[],
): Promise<PublicTestimonialReceipt[]> {
  if (userIds && userIds.length === 0) return Promise.resolve([]);
  return db.consentReceipt.findMany({
    where: {
      purpose: 'public_testimonial',
      revokedAt: null,
      grantedAt: { lte: now },
      ...(userIds ? { userId: { in: [...userIds] } } : {}),
      user: { birthDate: { not: null } },
      notice: {
        purpose: 'public_testimonial',
        effectiveAt: { lte: now },
        OR: [{ retiredAt: null }, { retiredAt: { gt: now } }],
      },
    },
    select: PUBLIC_TESTIMONIAL_RECEIPT_SELECT,
  });
}

export function eligiblePublicTestimonialUserIds(
  receipts: PublicTestimonialReceipt[],
  now: Date,
): string[] {
  const eligible = receipts
    .filter((receipt) => isActivePublicTestimonialReceipt(receipt, now))
    .map((receipt) => receipt.userId);
  return Array.from(new Set(eligible));
}

function isActivePublicTestimonialReceipt(
  receipt: PublicTestimonialReceipt,
  now: Date,
): boolean {
  if (
    receipt.purpose !== 'public_testimonial' ||
    receipt.notice.purpose !== 'public_testimonial' ||
    receipt.revokedAt !== null ||
    receipt.grantedAt > now ||
    receipt.notice.effectiveAt > receipt.grantedAt ||
    (receipt.notice.retiredAt !== null && receipt.notice.retiredAt <= now) ||
    receipt.user.birthDate === null
  ) {
    return false;
  }

  const requiredGuardian =
    isMinorAt(receipt.user.birthDate, receipt.grantedAt) ||
    isMinorAt(receipt.user.birthDate, now);
  if (!requiredGuardian) return true;

  const guardian = receipt.guardianAuthorization;
  return Boolean(
    guardian &&
      guardian.minorUserId === receipt.userId &&
      guardian.status === 'verified' &&
      guardian.verifiedAt !== null &&
      guardian.verifiedAt <= receipt.grantedAt &&
      guardian.verifiedAt <= now &&
      guardian.revokedAt === null &&
      (guardian.expiresAt === null || guardian.expiresAt > now),
  );
}

function isMinorAt(birthDate: Date, at: Date): boolean {
  const adultThreshold = new Date(at);
  adultThreshold.setUTCFullYear(adultThreshold.getUTCFullYear() - 18);
  return birthDate > adultThreshold;
}
