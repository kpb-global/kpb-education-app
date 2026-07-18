import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
  featureDisabled,
} from '../common/competition-readiness.errors';

export type AdminReviewActor = Pick<
  AdminSessionUser,
  'id' | 'email' | 'fullName' | 'role'
>;

export type ReviewProjection = 'metadata' | 'assigned' | 'full';

export const ADMIN_REVIEW_CAPABILITIES = {
  viewMetadata: 'view_review_request_metadata',
  viewAssigned: 'view_assigned_review_requests',
  viewEvidence: 'view_shared_review_documents',
  triage: 'triage_review_requests',
  assign: 'assign_review_requests',
  convert: 'convert_review_to_case',
  viewAiOperations: 'view_ai_operations',
  manageOwnAvailability: 'manage_own_availability',
  manageCounsellorAvailability: 'manage_counsellor_availability',
  offerSlots: 'offer_review_slots',
} as const;

type ActiveGrant = {
  countryCodes: string[];
  cohortIds: string[];
  resourceScope: Prisma.JsonValue | null;
};

type ScopedReview = {
  id: string;
  status?: string;
  assignedCounsellorId: string | null;
  workspace: {
    scholarshipId?: string;
    scholarship: { id: string; countryId: string };
  };
};

const COMMERCIAL_VISIBLE_STATUSES = [
  'triaged',
  'more_information_needed',
  'call_offered',
  'scheduled',
  'converted_to_case',
  'autonomy_recommended',
  'declined',
  'closed',
] as const;

@Injectable()
export class AdminReviewAccessService {
  constructor(private readonly prismaService: PrismaService) {}

  assertReviewFeatureEnabled() {
    if (
      process.env.KPB_STUDY_REVIEW_ENABLED?.trim().toLowerCase() !== 'true'
    ) {
      throw featureDisabled('study_review');
    }
  }

  isPlatformAdmin(actor: AdminReviewActor): boolean {
    return (
      actor.role === InternalRole.Admin ||
      actor.role === InternalRole.SuperAdmin
    );
  }

  isCommercial(actor: AdminReviewActor): boolean {
    return actor.role === InternalRole.Commercial;
  }

  isCounselor(actor: AdminReviewActor): boolean {
    return actor.role === InternalRole.Counselor;
  }

  async resolveCounsellor(actor: AdminReviewActor) {
    if (!this.isCounselor(actor)) throw this.forbidden();
    if (!this.prismaService.isEnabled) throw databaseUnavailable();

    const counsellor = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findFirst({
        where: {
          isActive: true,
          OR: [
            { adminUserId: actor.id },
            {
              adminUserId: null,
              email: { equals: actor.email, mode: 'insensitive' },
            },
          ],
        },
        select: { id: true, fullName: true, adminUserId: true },
      }),
    );
    if (!counsellor) throw this.forbidden();
    return counsellor;
  }

  async listScope(actor: AdminReviewActor): Promise<{
    where: Prisma.StudyReviewRequestWhereInput;
    projection: ReviewProjection;
    counsellorId: string | null;
  }> {
    const capability = this.isCommercial(actor)
      ? ADMIN_REVIEW_CAPABILITIES.viewMetadata
      : ADMIN_REVIEW_CAPABILITIES.viewAssigned;
    const grantWhere = await this.capabilityScopeWhere(actor, capability);
    if (this.isPlatformAdmin(actor)) {
      return { where: grantWhere, projection: 'full', counsellorId: null };
    }
    if (this.isCommercial(actor)) {
      return {
        where: {
          AND: [
            grantWhere,
            { status: { in: [...COMMERCIAL_VISIBLE_STATUSES] } },
          ],
        },
        projection: 'metadata',
        counsellorId: null,
      };
    }
    const counsellor = await this.resolveCounsellor(actor);
    return {
      where: {
        AND: [grantWhere, { assignedCounsellorId: counsellor.id }],
      },
      projection: 'assigned',
      counsellorId: counsellor.id,
    };
  }

  async assertCanReadDetail(
    actor: AdminReviewActor,
    review: ScopedReview,
  ): Promise<ReviewProjection> {
    if (this.isCommercial(actor)) {
      if (
        !review.status ||
        !COMMERCIAL_VISIBLE_STATUSES.includes(
          review.status as (typeof COMMERCIAL_VISIBLE_STATUSES)[number],
        )
      ) {
        throw this.forbidden();
      }
      await this.assertCapabilityForReview(
        actor,
        ADMIN_REVIEW_CAPABILITIES.viewMetadata,
        review,
      );
      return 'metadata';
    }
    await this.assertCapabilityForReview(
      actor,
      ADMIN_REVIEW_CAPABILITIES.viewAssigned,
      review,
    );
    if (this.isPlatformAdmin(actor)) return 'full';
    if (!this.isCounselor(actor)) throw this.forbidden();
    const counsellor = await this.resolveCounsellor(actor);
    if (review.assignedCounsellorId !== counsellor.id) throw this.forbidden();
    return 'assigned';
  }

  async assertCanTriage(
    actor: AdminReviewActor,
    review: ScopedReview,
  ) {
    await this.assertCapabilityForReview(
      actor,
      ADMIN_REVIEW_CAPABILITIES.triage,
      review,
    );
    if (this.isPlatformAdmin(actor)) return;
    if (!this.isCounselor(actor)) throw this.forbidden();
    const counsellor = await this.resolveCounsellor(actor);
    if (review.assignedCounsellorId !== counsellor.id) throw this.forbidden();
  }

  async assertCanConvert(
    actor: AdminReviewActor,
    review: ScopedReview,
  ) {
    if (!this.isPlatformAdmin(actor) && !this.isCommercial(actor)) {
      throw this.forbidden();
    }
    await this.assertCapabilityForReview(
      actor,
      ADMIN_REVIEW_CAPABILITIES.convert,
      review,
    );
  }

  async assertCanAssign(
    actor: AdminReviewActor,
    review: ScopedReview,
    targetCounsellorId: string | null,
  ) {
    if (!this.isPlatformAdmin(actor)) throw this.forbidden();
    await this.assertCapabilityForReview(
      actor,
      ADMIN_REVIEW_CAPABILITIES.assign,
      { ...review, assignedCounsellorId: targetCounsellorId },
    );
  }

  async assertCanOpenEvidence(actor: AdminReviewActor, review: ScopedReview) {
    if (!this.isPlatformAdmin(actor) && !this.isCounselor(actor)) {
      throw this.forbidden();
    }
    await this.assertCapabilityForReview(
      actor,
      ADMIN_REVIEW_CAPABILITIES.viewEvidence,
      review,
    );
    if (this.isPlatformAdmin(actor)) return;
    const counsellor = await this.resolveCounsellor(actor);
    if (review.assignedCounsellorId !== counsellor.id) throw this.forbidden();
  }

  async assertCanOfferSlots(actor: AdminReviewActor, review: ScopedReview) {
    await this.assertCapabilityForReview(
      actor,
      ADMIN_REVIEW_CAPABILITIES.offerSlots,
      review,
    );
    if (this.isPlatformAdmin(actor)) return;
    if (!this.isCounselor(actor)) throw this.forbidden();
    const counsellor = await this.resolveCounsellor(actor);
    if (review.assignedCounsellorId !== counsellor.id) throw this.forbidden();
  }

  async assertCanManageCounsellor(
    actor: AdminReviewActor,
    counsellorId: string,
  ) {
    const capability = this.isCounselor(actor)
      ? ADMIN_REVIEW_CAPABILITIES.manageOwnAvailability
      : ADMIN_REVIEW_CAPABILITIES.manageCounsellorAvailability;
    const grants = await this.activeGrants(actor, capability);
    if (this.isCounselor(actor)) {
      const counsellor = await this.resolveCounsellor(actor);
      if (counsellor.id !== counsellorId) throw this.forbidden();
    } else if (!this.isPlatformAdmin(actor)) {
      throw this.forbidden();
    }
    if (grants === null) return;
    const target = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findUnique({
        where: { id: counsellorId },
        select: { id: true, countryOfResidence: true },
      }),
    );
    if (!target) throw this.forbidden();
    for (const grant of grants) {
      if (grant.cohortIds.length > 0) continue;
      const resource = this.parseResourceScope(grant.resourceScope);
      if (
        !resource ||
        (resource.counsellorIds &&
          !resource.counsellorIds.includes(counsellorId))
      ) {
        continue;
      }
      if (grant.countryCodes.length > 0) {
        const candidates = await this.managedCountryCandidates(
          grant.countryCodes,
        );
        if (!candidates.includes(target.countryOfResidence)) continue;
      }
      return;
    }
    throw this.forbidden();
  }

  async manageableCounsellorScope(
    actor: AdminReviewActor,
  ): Promise<Prisma.CounsellorWhereInput> {
    if (this.isCounselor(actor)) {
      const counsellor = await this.resolveCounsellor(actor);
      await this.assertCanManageCounsellor(actor, counsellor.id);
      return { id: counsellor.id };
    }
    if (!this.isPlatformAdmin(actor)) throw this.forbidden();
    const grants = await this.activeGrants(
      actor,
      ADMIN_REVIEW_CAPABILITIES.manageCounsellorAvailability,
    );
    if (grants === null) return {};
    const scopes: Prisma.CounsellorWhereInput[] = [];
    for (const grant of grants) {
      if (grant.cohortIds.length > 0) continue;
      const resource = this.parseResourceScope(grant.resourceScope);
      if (!resource) continue;
      if (
        !resource.counsellorIds &&
        (resource.reviewRequestIds || resource.scholarshipIds)
      ) {
        continue;
      }
      const countryCandidates =
        grant.countryCodes.length > 0
          ? await this.managedCountryCandidates(grant.countryCodes)
          : null;
      if (countryCandidates && countryCandidates.length === 0) continue;
      scopes.push({
        AND: [
          ...(resource.counsellorIds
            ? [{ id: { in: resource.counsellorIds } }]
            : []),
          ...(countryCandidates
            ? [{ countryOfResidence: { in: countryCandidates } }]
            : []),
        ],
      });
    }
    return scopes.length > 0 ? { OR: scopes } : { id: { in: [] } };
  }

  async selectableCounsellorScope(
    actor: AdminReviewActor,
    reviewRequestId?: string,
  ): Promise<Prisma.CounsellorWhereInput> {
    if (!reviewRequestId) return this.manageableCounsellorScope(actor);
    if (!this.isPlatformAdmin(actor)) throw this.forbidden();
    const review = await this.prismaService.execute((prisma) =>
      prisma.studyReviewRequest.findUnique({
        where: { id: reviewRequestId },
        select: {
          id: true,
          assignedCounsellorId: true,
          workspace: {
            select: {
              scholarshipId: true,
              scholarship: { select: { id: true, countryId: true } },
            },
          },
        },
      }),
    );
    if (!review) throw this.forbidden();
    const grants = await this.activeGrants(
      actor,
      ADMIN_REVIEW_CAPABILITIES.assign,
    );
    if (grants === null) return {};
    const scopes: Prisma.CounsellorWhereInput[] = [];
    for (const grant of grants) {
      if (grant.cohortIds.length > 0) continue;
      const resource = this.parseResourceScope(grant.resourceScope);
      if (!resource) continue;
      if (grant.countryCodes.length > 0) {
        const countryCandidates = await this.countryIds(grant.countryCodes);
        if (
          !countryCandidates?.includes(review.workspace.scholarship.countryId)
        ) {
          continue;
        }
      }
      if (
        resource.reviewRequestIds &&
        !resource.reviewRequestIds.includes(review.id)
      ) {
        continue;
      }
      if (
        resource.scholarshipIds &&
        !resource.scholarshipIds.includes(review.workspace.scholarship.id)
      ) {
        continue;
      }
      scopes.push(
        resource.counsellorIds
          ? { id: { in: resource.counsellorIds } }
          : {},
      );
    }
    if (scopes.length === 0) throw this.forbidden();
    return { OR: scopes };
  }

  async assertCapability(
    actor: AdminReviewActor,
    capability: string,
  ): Promise<void> {
    await this.activeGrants(actor, capability);
  }

  private async capabilityScopeWhere(
    actor: AdminReviewActor,
    capability: string,
  ): Promise<Prisma.StudyReviewRequestWhereInput> {
    const grants = await this.activeGrants(actor, capability);
    if (grants === null) return {};
    const grantScopes = await Promise.all(
      grants.map((grant) => this.grantWhere(grant)),
    );
    const usable = grantScopes.filter(
      (scope): scope is Prisma.StudyReviewRequestWhereInput => scope !== null,
    );
    if (usable.length === 0) return { id: { in: [] } };
    return { OR: usable };
  }

  private async assertCapabilityForReview(
    actor: AdminReviewActor,
    capability: string,
    review: ScopedReview,
  ) {
    const grants = await this.activeGrants(actor, capability);
    if (grants === null) return;
    for (const grant of grants) {
      if (await this.grantCoversReview(grant, review)) return;
    }
    throw this.forbidden();
  }

  private async activeGrants(
    actor: AdminReviewActor,
    capability: string,
  ): Promise<ActiveGrant[] | null> {
    if (actor.role === InternalRole.SuperAdmin) return null;
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    const now = new Date();
    const grants = await this.prismaService.execute((prisma) =>
      prisma.adminScopeGrant.findMany({
        where: {
          adminUserId: actor.id,
          capability,
          startsAt: { lte: now },
          revokedAt: null,
          OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
        },
        select: {
          countryCodes: true,
          cohortIds: true,
          resourceScope: true,
        },
      }),
    );
    if (!grants?.length) throw this.forbidden();
    return grants;
  }

  private async grantWhere(
    grant: ActiveGrant,
  ): Promise<Prisma.StudyReviewRequestWhereInput | null> {
    if (grant.cohortIds.length > 0) return null;
    const resource = this.parseResourceScope(grant.resourceScope);
    if (resource === null) return null;
    const countryIds = await this.countryIds(grant.countryCodes);
    return {
      AND: [
        ...(countryIds
          ? [
              {
                workspace: {
                  scholarship: { countryId: { in: countryIds } },
                },
              } as Prisma.StudyReviewRequestWhereInput,
            ]
          : []),
        ...(resource.reviewRequestIds
          ? [{ id: { in: resource.reviewRequestIds } }]
          : []),
        ...(resource.scholarshipIds
          ? [
              {
                workspace: { scholarshipId: { in: resource.scholarshipIds } },
              },
            ]
          : []),
        ...(resource.counsellorIds
          ? [
              {
                assignedCounsellorId: { in: resource.counsellorIds },
              },
            ]
          : []),
      ],
    };
  }

  private async grantCoversReview(grant: ActiveGrant, review: ScopedReview) {
    if (grant.cohortIds.length > 0) return false;
    const resource = this.parseResourceScope(grant.resourceScope);
    if (resource === null) return false;
    if (grant.countryCodes.length > 0) {
      const candidates = await this.countryIds(grant.countryCodes);
      if (!candidates?.includes(review.workspace.scholarship.countryId)) {
        return false;
      }
    }
    if (
      resource.reviewRequestIds &&
      !resource.reviewRequestIds.includes(review.id)
    ) {
      return false;
    }
    if (
      resource.scholarshipIds &&
      !resource.scholarshipIds.includes(review.workspace.scholarship.id)
    ) {
      return false;
    }
    if (
      resource.counsellorIds &&
      (!review.assignedCounsellorId ||
        !resource.counsellorIds.includes(review.assignedCounsellorId))
    ) {
      return false;
    }
    return true;
  }

  private parseResourceScope(value: Prisma.JsonValue | null): {
    reviewRequestIds?: string[];
    scholarshipIds?: string[];
    counsellorIds?: string[];
  } | null {
    if (value === null) return {};
    if (Array.isArray(value) || typeof value !== 'object') return null;
    const allowed = new Set([
      'reviewRequestIds',
      'scholarshipIds',
      'counsellorIds',
    ]);
    if (Object.keys(value).some((key) => !allowed.has(key))) return null;
    const result: {
      reviewRequestIds?: string[];
      scholarshipIds?: string[];
      counsellorIds?: string[];
    } = {};
    for (const key of allowed) {
      const entry = value[key];
      if (entry === undefined) continue;
      if (
        !Array.isArray(entry) ||
        entry.some((item) => typeof item !== 'string')
      ) {
        return null;
      }
      result[key as keyof typeof result] = entry as string[];
    }
    return result;
  }

  private async countryIds(countryCodes: string[]): Promise<string[] | null> {
    if (countryCodes.length === 0) return null;
    const normalized = Array.from(
      new Set(
        countryCodes.flatMap((code) => [
          code,
          code.toLowerCase(),
          code.toUpperCase(),
        ]),
      ),
    );
    const countries = await this.prismaService.execute((prisma) =>
      prisma.country.findMany({
        where: { code: { in: normalized } },
        select: { id: true, code: true },
      }),
    );
    return Array.from(
      new Set([
        ...normalized,
        ...(countries ?? []).flatMap((country) => [country.id, country.code]),
      ]),
    );
  }

  private async managedCountryCandidates(
    countryCodes: string[],
  ): Promise<string[]> {
    const normalized = Array.from(
      new Set(
        countryCodes.flatMap((code) => [
          code,
          code.toLowerCase(),
          code.toUpperCase(),
        ]),
      ),
    );
    const countries = await this.prismaService.execute((prisma) =>
      prisma.country.findMany({
        where: { code: { in: normalized } },
        select: { id: true, code: true },
      }),
    );
    if (!countries?.length) return [];
    return Array.from(
      new Set(
        countries.flatMap((country) => [
          country.id,
          country.code,
          country.code.toLowerCase(),
          country.code.toUpperCase(),
        ]),
      ),
    );
  }

  private forbidden() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'This operator is not authorized for this review request.',
    );
  }

}
