// ─────────────────────────────────────────────────────────────────────────────
// ImpactService — aggregate social-impact metrics for the public impact board.
//
// Powers the in-app "Notre impact" dashboard and doubles as pitch ammunition
// for grant/competition applications. All queries degrade gracefully (tryExecute
// returns null without a DB) so the endpoint never throws.
// ─────────────────────────────────────────────────────────────────────────────

import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

export interface ImpactStats {
  studentsGuided: number;
  admissionsSecured: number;
  /// Count of active, approved scholarships in the catalogue (verifiable),
  /// replacing the former fabricated "value in EUR" (convertedCases × 4500).
  scholarshipsTracked: number;
  orientationSessions: number;
  countriesCovered: number;
  partnerInstitutions: number;
  /// 0–100, derived from published counsellor reviews. NULL until any review
  /// exists — we never fabricate a satisfaction figure.
  satisfactionRate: number | null;
  reviewsCount: number;
  generatedAt: string;
}

/// A single published counsellor review, reduced to public-safe fields only.
/// PII columns (reviewerUserId, caseId) are deliberately never exposed.
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

@Injectable()
export class ImpactService {
  constructor(private readonly prisma: PrismaService) {}

  async getStats(): Promise<ImpactStats> {
    const [
      studentsGuided,
      completedCases,
      orientationSessions,
      partnerInstitutions,
      countriesCovered,
      scholarshipsTracked,
      reviewAgg,
    ] = await Promise.all([
      this.prisma.tryExecute((db) =>
        db.userProfile.count({ where: { accountType: 'student' } }),
      ),
      this.prisma.tryExecute((db) =>
        db.case.count({ where: { status: 'completed' } }),
      ),
      this.prisma.tryExecute((db) => db.orientationSession.count()),
      this.prisma.tryExecute((db) =>
        db.institution.count({ where: { isPartner: true } }),
      ),
      // Real destination coverage from the catalogue (was hardcoded 9).
      this.prisma.tryExecute((db) =>
        db.country.count({ where: { isActive: true } }),
      ),
      // Real, verifiable scholarship coverage (was a fabricated EUR estimate).
      this.prisma.tryExecute((db) =>
        db.scholarship.count({
          where: { isActive: true, moderationStatus: 'approved' },
        }),
      ),
      // Satisfaction from published reviews only — no survey data ⇒ null.
      this.prisma.tryExecute((db) =>
        db.counsellorReview.aggregate({
          where: { isPublished: true },
          _avg: { rating: true },
          _count: { _all: true },
        }),
      ),
    ]);

    const reviewsCount = reviewAgg?._count?._all ?? 0;
    const avgRating = reviewAgg?._avg?.rating ?? null;
    // ratings are 1–5 → scale to 0–100; null when there are no reviews.
    const satisfactionRate =
      reviewsCount > 0 && avgRating != null
        ? Math.round(avgRating * 20)
        : null;

    return {
      studentsGuided: studentsGuided ?? 0,
      // Admissions = completed dossiers (a completed case == a placed student).
      admissionsSecured: completedCases ?? 0,
      scholarshipsTracked: scholarshipsTracked ?? 0,
      orientationSessions: orientationSessions ?? 0,
      countriesCovered: countriesCovered ?? 0,
      partnerInstitutions: partnerInstitutions ?? 0,
      satisfactionRate,
      reviewsCount,
      generatedAt: new Date().toISOString(),
    };
  }

  /// Top published counsellor reviews for the public social-proof carousel.
  ///
  /// Only `isPublished` reviews are returned, newest first, capped at [limit].
  /// The Prisma `select` enumerates public-safe fields only — reviewerUserId
  /// and caseId are never selected, so no PII can leak to the client. Degrades
  /// to an empty list (never fabricated reviews) when the DB is unavailable.
  async getPublishedReviews(limit = 10): Promise<PublishedReviews> {
    const rows = await this.prisma.tryExecute((db) =>
      db.counsellorReview.findMany({
        where: { isPublished: true },
        orderBy: { createdAt: 'desc' },
        take: limit,
        select: {
          id: true,
          counsellorId: true,
          reviewerName: true,
          rating: true,
          body: true,
          createdAt: true,
        },
      }),
    );

    const reviews: PublishedReview[] = (rows ?? []).map((r) => ({
      id: r.id,
      counsellorId: r.counsellorId,
      reviewerName: r.reviewerName,
      rating: r.rating,
      body: r.body,
      createdAt:
        r.createdAt instanceof Date
          ? r.createdAt.toISOString()
          : String(r.createdAt),
    }));

    return { reviews, count: reviews.length };
  }
}
