import { Injectable, NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

type CounsellorInput = {
  fullName?: string;
  email?: string;
  phone?: string;
  whatsApp?: string;
  countryOfResidence?: string;
  specialties?: string[];
  languagesSpoken?: string[];
  bioFr?: string;
  bioEn?: string;
  yearsExperience?: number;
  hourlyRateXOF?: number;
  commissionBps?: number;
  kycStatus?:
    | 'pending'
    | 'under_review'
    | 'approved'
    | 'rejected'
    | 'suspended';
  kycNotes?: string | null;
  isActive?: boolean;
};

/**
 * Counsellor marketplace (Track B). Independent counsellors across francophone
 * West Africa can be onboarded, KYC-verified by admins, and assigned to cases.
 * KPB takes a commission (default 15%) on each paid consultation via
 * PaymentIntent.
 */
@Injectable()
export class CounsellorsService {
  constructor(private readonly prismaService: PrismaService) {}

  /** Public list — only active, KYC-approved counsellors. Used by mobile. */
  async listPublic(params: {
    countryOfResidence?: string;
    specialty?: string;
  }) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findMany({
        where: {
          isActive: true,
          kycStatus: 'approved',
          ...(params.countryOfResidence
            ? { countryOfResidence: params.countryOfResidence }
            : {}),
          ...(params.specialty
            ? { specialties: { has: params.specialty } }
            : {}),
        },
        orderBy: [{ avgRating: 'desc' }, { reviewCount: 'desc' }],
        select: {
          id: true,
          fullName: true,
          countryOfResidence: true,
          specialties: true,
          languagesSpoken: true,
          bioFr: true,
          bioEn: true,
          yearsExperience: true,
          hourlyRateXOF: true,
          avgRating: true,
          reviewCount: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async getPublic(id: string) {
    const counsellor = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findFirst({
        where: { id, isActive: true, kycStatus: 'approved' },
        // Explicit select: the public detail view must never leak the
        // counsellor's personal contact details (email/phone/whatsApp) or
        // internal KYC/commission fields.
        select: {
          id: true,
          fullName: true,
          countryOfResidence: true,
          specialties: true,
          languagesSpoken: true,
          bioFr: true,
          bioEn: true,
          yearsExperience: true,
          hourlyRateXOF: true,
          avgRating: true,
          reviewCount: true,
          reviews: {
            where: { isPublished: true },
            orderBy: { createdAt: 'desc' },
            take: 20,
          },
        },
      }),
    );
    if (!counsellor) {
      throw new NotFoundException(`Counsellor ${id} not available.`);
    }
    return counsellor;
  }

  /** Admin list — includes pending/rejected for the KYC queue. */
  async listAdmin(params: { kycStatus?: string }) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findMany({
        where: {
          ...(params.kycStatus
            ? { kycStatus: params.kycStatus as never }
            : {}),
        },
        orderBy: { createdAt: 'desc' },
      }),
    );
    return { items: items ?? [] };
  }

  async create(input: CounsellorInput) {
    const required = [
      'fullName',
      'email',
      'phone',
      'countryOfResidence',
      'bioFr',
      'bioEn',
    ] as const;
    for (const key of required) {
      if (!input[key]) {
        throw new NotFoundException(`Missing required field: ${key}`);
      }
    }

    const created = await this.prismaService.execute((prisma) =>
      prisma.counsellor.create({
        data: {
          fullName: input.fullName!,
          email: input.email!.toLowerCase(),
          phone: input.phone!,
          whatsApp: input.whatsApp,
          countryOfResidence: input.countryOfResidence!,
          specialties: input.specialties ?? [],
          languagesSpoken: input.languagesSpoken ?? ['fr'],
          bioFr: input.bioFr!,
          bioEn: input.bioEn!,
          yearsExperience: input.yearsExperience ?? 0,
          hourlyRateXOF: input.hourlyRateXOF ?? 0,
          commissionBps: input.commissionBps ?? 1500,
        },
      }),
    );
    return created;
  }

  async update(id: string, input: CounsellorInput) {
    const updated = await this.prismaService.execute((prisma) =>
      prisma.counsellor.update({
        where: { id },
        data: {
          ...(input.fullName !== undefined
            ? { fullName: input.fullName }
            : {}),
          ...(input.phone !== undefined ? { phone: input.phone } : {}),
          ...(input.whatsApp !== undefined
            ? { whatsApp: input.whatsApp }
            : {}),
          ...(input.countryOfResidence !== undefined
            ? { countryOfResidence: input.countryOfResidence }
            : {}),
          ...(input.specialties !== undefined
            ? { specialties: input.specialties }
            : {}),
          ...(input.languagesSpoken !== undefined
            ? { languagesSpoken: input.languagesSpoken }
            : {}),
          ...(input.bioFr !== undefined ? { bioFr: input.bioFr } : {}),
          ...(input.bioEn !== undefined ? { bioEn: input.bioEn } : {}),
          ...(input.yearsExperience !== undefined
            ? { yearsExperience: input.yearsExperience }
            : {}),
          ...(input.hourlyRateXOF !== undefined
            ? { hourlyRateXOF: input.hourlyRateXOF }
            : {}),
          ...(input.commissionBps !== undefined
            ? { commissionBps: input.commissionBps }
            : {}),
          ...(input.isActive !== undefined
            ? { isActive: input.isActive }
            : {}),
        },
      }),
    );
    return updated;
  }

  /** Admin-only: approve/reject KYC. Flipping to `approved` auto-activates. */
  async updateKyc(
    id: string,
    input: { kycStatus: CounsellorInput['kycStatus']; kycNotes?: string | null },
  ) {
    if (!input.kycStatus) {
      throw new NotFoundException('kycStatus is required.');
    }
    const now = input.kycStatus === 'approved' ? new Date() : null;
    const updated = await this.prismaService.execute((prisma) =>
      prisma.counsellor.update({
        where: { id },
        data: {
          kycStatus: input.kycStatus,
          kycNotes: input.kycNotes ?? null,
          kycVerifiedAt: now ?? undefined,
          // Approving auto-activates; any non-approved status deactivates.
          isActive: input.kycStatus === 'approved',
        },
      }),
    );
    return updated;
  }

  async createReview(
    counsellorId: string,
    input: {
      rating: number;
      body: string;
      reviewerName: string;
      reviewerUserId?: string;
      caseId?: string;
    },
  ) {
    if (input.rating < 1 || input.rating > 5) {
      throw new NotFoundException('Rating must be between 1 and 5.');
    }
    const review = await this.prismaService.execute(async (prisma) => {
      const created = await prisma.counsellorReview.create({
        data: {
          counsellorId,
          reviewerName: input.reviewerName,
          reviewerUserId: input.reviewerUserId,
          caseId: input.caseId,
          rating: input.rating,
          body: input.body,
          // Reviews are unpublished by default — moderators approve them. Cuts
          // down on fake/abusive reviews during beta.
          isPublished: false,
        },
      });
      // Refresh denormalized counters using only published reviews.
      const published = await prisma.counsellorReview.findMany({
        where: { counsellorId, isPublished: true },
        select: { rating: true },
      });
      const count = published.length;
      const avg =
        count === 0
          ? 0
          : published.reduce((sum, r) => sum + r.rating, 0) / count;
      await prisma.counsellor.update({
        where: { id: counsellorId },
        data: { avgRating: avg, reviewCount: count },
      });
      return created;
    });
    return review;
  }

  /** Admin-only: publish or unpublish a review. */
  async setReviewPublished(reviewId: string, isPublished: boolean) {
    return this.prismaService.execute(async (prisma) => {
      const updated = await prisma.counsellorReview.update({
        where: { id: reviewId },
        data: { isPublished },
      });
      const published = await prisma.counsellorReview.findMany({
        where: { counsellorId: updated.counsellorId, isPublished: true },
        select: { rating: true },
      });
      const count = published.length;
      const avg =
        count === 0
          ? 0
          : published.reduce((sum, r) => sum + r.rating, 0) / count;
      await prisma.counsellor.update({
        where: { id: updated.counsellorId },
        data: { avgRating: avg, reviewCount: count },
      });
      return updated;
    });
  }
}
