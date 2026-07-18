import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import {
  databaseUnavailable,
  featureDisabled,
} from '../competition-readiness/common/competition-readiness.errors';
import { PrismaService } from '../prisma/prisma.service';

const MIN_PUBLIC_CELL_SIZE = 20;
const PUBLIC_SNAPSHOT_METRICS = {
  participants: 'pilot_participants',
  submissions: 'verified_submissions',
  admissions: 'verified_admissions',
  fundingAwards: 'verified_funding_awards',
} as const;

export interface ImpactStats {
  /** Participants from the latest frozen, public-safe impact snapshot. */
  studentsGuided: number;
  /** Verified admissions from the same immutable impact snapshot. */
  admissionsSecured: number;
  /** Verified submissions from the same immutable impact snapshot. */
  verifiedApplicationsSubmitted: number;
  /** Verified full or partial funding awards from the same snapshot. */
  scholarshipsSecured: number;
  /** Legacy public field; currently the verified-admissions snapshot metric. */
  knownDecisions: number;
  /** Active, approved scholarships in the catalogue. */
  scholarshipsTracked: number;
  orientationSessions: number;
  countriesCovered: number;
  /** Distinct partners covered by a current, signed, active agreement. */
  partnerInstitutions: number;
  /** 0-100, derived only from published reviews with active consent. */
  satisfactionRate: number | null;
  reviewsCount: number;
  generatedAt: string;
}

/** A consent-gated published counsellor review. */
export interface PublishedReview {
  id: string;
  counsellorId: string;
  reviewerName: string;
  rating: number;
  body: string;
  createdAt: string;
}

export interface PublishedReviews {
  reviews: PublishedReview[];
  count: number;
}

type PublicTestimonialReceipt = {
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

@Injectable()
export class ImpactService {
  constructor(private readonly prisma: PrismaService) {}

  async getStats(): Promise<ImpactStats> {
    this.assertPublicImpactEnabled();
    const now = new Date();

    try {
      const result = await this.prisma.execute(async (db) => {
        const [
          snapshot,
          orientationSessions,
          partnerAgreements,
          countriesCovered,
          scholarshipsTracked,
          testimonialReceipts,
        ] = await Promise.all([
          // Frozen snapshots are the only public source for participant and
          // outcome counts. Never derive these claims from all user accounts,
          // mutable submission revisions, cases, or raw decision tables.
          db.impactSnapshot.findFirst({
            where: { isPublicSafe: true },
            orderBy: [
              { sourceWatermark: 'desc' },
              { generatedAt: 'desc' },
              { snapshotVersion: 'desc' },
            ],
            select: {
              metrics: true,
              generatedAt: true,
            },
          }),
          db.orientationSession.count(),
          // A catalogue boolean is not evidence of a current partnership.
          // Count each partner once and require a current, signed agreement
          // whose contractual window is active at read time.
          db.partnerAgreement.findMany({
            where: {
              isCurrent: true,
              status: 'active',
              signedAt: { not: null, lte: now },
              AND: [
                {
                  OR: [
                    { startsAt: null },
                    { startsAt: { lte: now } },
                  ],
                },
                {
                  OR: [{ endsAt: null }, { endsAt: { gt: now } }],
                },
              ],
            },
            distinct: ['partnerId'],
            select: { partnerId: true },
          }),
          db.country.count({ where: { isActive: true } }),
          db.scholarship.count({
            where: { isActive: true, moderationStatus: 'approved' },
          }),
          this.loadPublicTestimonialReceipts(db, now),
        ]);

        const eligibleReviewerIds = eligiblePublicTestimonialUserIds(
          testimonialReceipts,
          now,
        );
        const reviewAggregate =
          eligibleReviewerIds.length === 0
            ? null
            : await db.counsellorReview.aggregate({
                where: {
                  isPublished: true,
                  reviewerUserId: {
                    not: null,
                    in: eligibleReviewerIds,
                  },
                },
                _avg: { rating: true },
                _count: { _all: true },
              });

        return {
          snapshot,
          orientationSessions,
          partnerInstitutions: partnerAgreements.length,
          countriesCovered,
          scholarshipsTracked,
          reviewAggregate,
        };
      });

      if (!result) throw databaseUnavailable();

      const participants = publicSnapshotCount(
        result.snapshot?.metrics,
        PUBLIC_SNAPSHOT_METRICS.participants,
      );
      const submissions = publicSnapshotCount(
        result.snapshot?.metrics,
        PUBLIC_SNAPSHOT_METRICS.submissions,
      );
      const admissions = publicSnapshotCount(
        result.snapshot?.metrics,
        PUBLIC_SNAPSHOT_METRICS.admissions,
      );
      const fundingAwards = publicSnapshotCount(
        result.snapshot?.metrics,
        PUBLIC_SNAPSHOT_METRICS.fundingAwards,
      );
      const reviewsCount = result.reviewAggregate?._count._all ?? 0;
      const averageRating = result.reviewAggregate?._avg.rating ?? null;

      return {
        studentsGuided: participants,
        admissionsSecured: admissions,
        verifiedApplicationsSubmitted: submissions,
        scholarshipsSecured: fundingAwards,
        knownDecisions: admissions,
        scholarshipsTracked: result.scholarshipsTracked,
        orientationSessions: result.orientationSessions,
        countriesCovered: result.countriesCovered,
        partnerInstitutions: result.partnerInstitutions,
        satisfactionRate:
          reviewsCount > 0 && averageRating !== null
            ? Math.round(averageRating * 20)
            : null,
        reviewsCount,
        generatedAt: (result.snapshot?.generatedAt ?? now).toISOString(),
      };
    } catch (error) {
      if (isCompetitionReadinessException(error)) throw error;
      throw databaseUnavailable();
    }
  }

  async getPublishedReviews(limit = 10): Promise<PublishedReviews> {
    this.assertPublicImpactEnabled();
    const now = new Date();
    const safeLimit =
      Number.isSafeInteger(limit) && limit > 0 ? Math.min(limit, 50) : 10;

    try {
      const result = await this.prisma.execute(async (db) => {
        const receipts = await this.loadPublicTestimonialReceipts(db, now);
        const eligibleReviewerIds = eligiblePublicTestimonialUserIds(
          receipts,
          now,
        );
        if (eligibleReviewerIds.length === 0) return [];

        return db.counsellorReview.findMany({
          where: {
            isPublished: true,
            reviewerUserId: {
              not: null,
              in: eligibleReviewerIds,
            },
          },
          orderBy: { createdAt: 'desc' },
          take: safeLimit,
          // reviewerUserId and caseId are used neither in the response nor in
          // serialization. reviewerName/body are released only after the
          // separate, active public_testimonial receipt gate above succeeds.
          select: {
            id: true,
            counsellorId: true,
            reviewerName: true,
            rating: true,
            body: true,
            createdAt: true,
          },
        });
      });
      if (!result) throw databaseUnavailable();

      const reviews = result.map((row) => ({
        id: row.id,
        counsellorId: row.counsellorId,
        reviewerName: row.reviewerName,
        rating: row.rating,
        body: row.body,
        createdAt: row.createdAt.toISOString(),
      }));
      return { reviews, count: reviews.length };
    } catch (error) {
      if (isCompetitionReadinessException(error)) throw error;
      throw databaseUnavailable();
    }
  }

  private loadPublicTestimonialReceipts(
    db: Parameters<Parameters<PrismaService['execute']>[0]>[0],
    now: Date,
  ): Promise<PublicTestimonialReceipt[]> {
    return db.consentReceipt.findMany({
      where: {
        purpose: 'public_testimonial',
        revokedAt: null,
        grantedAt: { lte: now },
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

  private assertPublicImpactEnabled(): void {
    const enabled =
      process.env.KPB_COMPETITION_READINESS_ENABLED?.trim().toLowerCase() ===
        'true' &&
      process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED?.trim().toLowerCase() ===
        'true';
    if (!enabled) throw featureDisabled('public_impact_stats');
  }
}

function publicSnapshotCount(
  metrics: Prisma.JsonValue | undefined,
  metricKey: string,
): number {
  if (!Array.isArray(metrics)) return 0;
  const matches = metrics.filter(
    (entry): entry is Prisma.JsonObject =>
      entry !== null &&
      typeof entry === 'object' &&
      !Array.isArray(entry) &&
      entry.metricKey === metricKey,
  );
  if (matches.length !== 1) return 0;

  const metric = matches[0];
  const value = metric.value;
  const sampleSize = metric.sampleSize;
  if (
    metric.metricVersion !== 1 ||
    metric.caveat !== null ||
    !Number.isSafeInteger(value) ||
    (value as number) < 0 ||
    !Number.isSafeInteger(sampleSize) ||
    (sampleSize as number) < MIN_PUBLIC_CELL_SIZE
  ) {
    return 0;
  }
  return value as number;
}

function eligiblePublicTestimonialUserIds(
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

function isCompetitionReadinessException(
  error: unknown,
): error is ReturnType<typeof databaseUnavailable> {
  return Boolean(
    error &&
      typeof error === 'object' &&
      'getResponse' in error &&
      typeof (error as { getResponse?: unknown }).getResponse === 'function',
  );
}
