import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

/**
 * Alumni mentor layer (Phase 3).
 *
 * Students who got into a university through (or independently of) KPB can
 * become verified mentors. Verification flow:
 *   1. Student calls `apply()` with university + programme + graduation year
 *      and an `alumniProofUrl` (admission letter or diploma scan).
 *   2. `alumniStatus` goes to `pending`.
 *   3. Admin reviews and calls `decide()` to `approved` or `rejected`.
 *   4. Only `approved` alumni show up in `listPublic()` and render with a
 *      badge in the community UI.
 *
 * Word-of-mouth is our best acquisition channel — the badge is as much a
 * trust signal for new students as it is recognition for the alum.
 */
@Injectable()
export class AlumniService {
  constructor(private readonly prismaService: PrismaService) {}

  /** Student → submit their application. Idempotent on re-submission. */
  async apply(
    userId: string,
    input: {
      alumniUniversity: string;
      alumniProgramme: string;
      alumniGraduationYear: number;
      alumniCountryCode?: string;
      alumniBioFr?: string;
      alumniBioEn?: string;
      alumniProofUrl: string;
    },
  ) {
    if (!input.alumniUniversity?.trim()) {
      throw new BadRequestException('alumniUniversity is required.');
    }
    if (!input.alumniProofUrl?.trim()) {
      throw new BadRequestException(
        'alumniProofUrl is required — upload the admission letter first.',
      );
    }
    const thisYear = new Date().getUTCFullYear();
    if (
      input.alumniGraduationYear < 1980 ||
      input.alumniGraduationYear > thisYear + 10
    ) {
      throw new BadRequestException('alumniGraduationYear out of range.');
    }

    return this.prismaService.execute((prisma) =>
      prisma.userProfile.update({
        where: { id: userId },
        data: {
          alumniStatus: 'pending',
          alumniUniversity: input.alumniUniversity,
          alumniProgramme: input.alumniProgramme,
          alumniGraduationYear: input.alumniGraduationYear,
          alumniCountryCode: input.alumniCountryCode?.toUpperCase(),
          alumniBioFr: input.alumniBioFr,
          alumniBioEn: input.alumniBioEn,
          alumniProofUrl: input.alumniProofUrl,
          // Reset verification audit trail on re-submission.
          alumniVerifiedAt: null,
          alumniVerifiedById: null,
        },
        select: {
          id: true,
          alumniStatus: true,
          alumniUniversity: true,
          alumniProgramme: true,
          alumniGraduationYear: true,
          alumniCountryCode: true,
        },
      }),
    );
  }

  /** Student → toggle whether their badge is visible in public listings. */
  async setBadgeVisible(userId: string, visible: boolean) {
    return this.prismaService.execute((prisma) =>
      prisma.userProfile.update({
        where: { id: userId },
        data: { alumniBadgeVisible: visible },
        select: { id: true, alumniBadgeVisible: true },
      }),
    );
  }

  /** Student → my own alumni status (so the mobile app can render the right CTA). */
  async getMyStatus(userId: string) {
    const u = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findUnique({
        where: { id: userId },
        select: {
          id: true,
          alumniStatus: true,
          alumniUniversity: true,
          alumniProgramme: true,
          alumniGraduationYear: true,
          alumniCountryCode: true,
          alumniBioFr: true,
          alumniBioEn: true,
          alumniBadgeVisible: true,
          alumniVerifiedAt: true,
        },
      }),
    );
    if (!u) {
      throw new NotFoundException('User not found.');
    }
    return u;
  }

  /** Public mentor directory — only `approved` + `alumniBadgeVisible=true`. */
  async listPublic(params: {
    countryCode?: string;
    university?: string;
    limit?: number;
  } = {}) {
    const limit = Math.min(Math.max(params.limit ?? 50, 1), 100);
    const items = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findMany({
        where: {
          alumniStatus: 'approved',
          alumniBadgeVisible: true,
          ...(params.countryCode
            ? { alumniCountryCode: params.countryCode.toUpperCase() }
            : {}),
          ...(params.university
            ? {
                alumniUniversity: {
                  contains: params.university,
                  mode: 'insensitive',
                },
              }
            : {}),
        },
        orderBy: { alumniVerifiedAt: 'desc' },
        take: limit,
        select: {
          id: true,
          fullName: true,
          alumniUniversity: true,
          alumniProgramme: true,
          alumniGraduationYear: true,
          alumniCountryCode: true,
          alumniBioFr: true,
          alumniBioEn: true,
          alumniVerifiedAt: true,
          // Intentionally omits alumniProofUrl — admin-only.
        },
      }),
    );
    return { items: items ?? [] };
  }

  // ── Admin ────────────────────────────────────────────────────────────────

  async listAdmin(status?: 'none' | 'pending' | 'approved' | 'rejected') {
    const items = await this.prismaService.execute((prisma) =>
      prisma.userProfile.findMany({
        where: {
          alumniStatus: status ?? { not: 'none' },
        },
        orderBy: { updatedAt: 'desc' },
        select: {
          id: true,
          fullName: true,
          email: true,
          alumniStatus: true,
          alumniUniversity: true,
          alumniProgramme: true,
          alumniGraduationYear: true,
          alumniCountryCode: true,
          alumniProofUrl: true,
          alumniVerifiedAt: true,
          alumniVerifiedById: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async decide(
    userId: string,
    adminUserId: string,
    decision: 'approved' | 'rejected',
  ) {
    if (decision !== 'approved' && decision !== 'rejected') {
      throw new BadRequestException(`Invalid decision: ${decision}`);
    }
    return this.prismaService.execute((prisma) =>
      prisma.userProfile.update({
        where: { id: userId },
        data: {
          alumniStatus: decision,
          alumniVerifiedAt: new Date(),
          alumniVerifiedById: adminUserId,
        },
        select: {
          id: true,
          alumniStatus: true,
          alumniVerifiedAt: true,
          alumniVerifiedById: true,
        },
      }),
    );
  }
}
