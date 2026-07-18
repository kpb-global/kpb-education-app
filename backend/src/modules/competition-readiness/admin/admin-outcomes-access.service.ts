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
import type { OutcomeType } from '../outcomes/outcomes.service';

export const ADMIN_OUTCOME_CAPABILITY = 'verify_outcomes';

type ResourceScope = {
  outcomeIds?: string[];
  workspaceIds?: string[];
  scholarshipIds?: string[];
};

type ResolvedScope = ResourceScope & {
  countryIds: string[] | null;
};

type ScopedOutcome = {
  id: string;
  workspaceId: string;
};

@Injectable()
export class AdminOutcomesAccessService {
  constructor(private readonly prismaService: PrismaService) {}

  assertEnvironment() {
    const enabled =
      process.env.KPB_COMPETITION_READINESS_ENABLED?.trim().toLowerCase() ===
        'true' &&
      process.env.KPB_SUCCESS_LAB_ENABLED?.trim().toLowerCase() === 'true' &&
      process.env.KPB_OUTCOME_EVIDENCE_ENABLED?.trim().toLowerCase() === 'true';
    if (!enabled) throw featureDisabled('outcome_evidence');
  }

  async whereFor(
    actor: AdminSessionUser,
    _type: OutcomeType,
    requestedCountryCode?: string,
  ): Promise<Prisma.ApplicationSubmissionWhereInput> {
    this.assertEnvironment();
    const scopes = await this.resolveScopes(actor);
    const requestedCountries = requestedCountryCode
      ? await this.countryIds([requestedCountryCode])
      : null;
    if (requestedCountryCode && requestedCountries?.length === 0) {
      return { id: { in: [] } };
    }
    if (scopes === null) {
      return requestedCountries
        ? { workspace: { scholarship: { countryId: { in: requestedCountries } } } }
        : {};
    }

    const where = scopes.map((scope) => {
      const countryIds = this.intersection(
        scope.countryIds,
        requestedCountries,
      );
      if (countryIds !== null && countryIds.length === 0) {
        return { id: { in: [] } };
      }
      return {
        ...(scope.outcomeIds ? { id: { in: scope.outcomeIds } } : {}),
        workspace: {
          AND: [
            ...(scope.workspaceIds
              ? [{ id: { in: scope.workspaceIds } }]
              : []),
            ...(scope.scholarshipIds
              ? [{ scholarshipId: { in: scope.scholarshipIds } }]
              : []),
            ...(countryIds
              ? [{ scholarship: { countryId: { in: countryIds } } }]
              : []),
          ],
        },
      } satisfies Prisma.ApplicationSubmissionWhereInput;
    });
    return where.length > 0 ? { OR: where } : { id: { in: [] } };
  }

  async assertIndependentVerifier(
    actor: AdminSessionUser,
    outcome: ScopedOutcome,
  ) {
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    const conflict = await this.prismaService.execute(async (prisma) => {
      const counsellor = await prisma.counsellor.findFirst({
        where: {
          OR: [
            { adminUserId: actor.id },
            {
              adminUserId: null,
              email: { equals: actor.email, mode: 'insensitive' },
            },
          ],
        },
        select: { id: true },
      });
      if (!counsellor) return false;
      const assigned = await prisma.studyReviewRequest.findFirst({
        where: {
          workspaceId: outcome.workspaceId,
          assignedCounsellorId: counsellor.id,
        },
        select: { id: true },
      });
      return Boolean(assigned);
    });
    if (conflict === null) throw databaseUnavailable();
    if (conflict) {
      throw new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        403,
        'A counsellor cannot verify an outcome they supported.',
      );
    }
  }

  private async resolveScopes(
    actor: AdminSessionUser,
  ): Promise<ResolvedScope[] | null> {
    if (actor.role === InternalRole.SuperAdmin) return null;
    if (
      actor.role !== InternalRole.Moderator &&
      actor.role !== InternalRole.Admin
    ) {
      throw this.forbidden();
    }
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    const now = new Date();
    const grants = await this.prismaService.execute((prisma) =>
      prisma.adminScopeGrant.findMany({
        where: {
          adminUserId: actor.id,
          capability: ADMIN_OUTCOME_CAPABILITY,
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

    const resolved: ResolvedScope[] = [];
    for (const grant of grants) {
      // Outcome workspaces do not yet carry a cohort FK. A cohort-bound grant
      // therefore fails closed instead of silently widening access.
      if (grant.cohortIds.length > 0) continue;
      const resource = this.parseResourceScope(grant.resourceScope);
      if (!resource) continue;
      resolved.push({
        ...resource,
        countryIds: await this.countryIds(grant.countryCodes),
      });
    }
    if (resolved.length === 0) throw this.forbidden();
    return resolved;
  }

  private parseResourceScope(
    value: Prisma.JsonValue | null,
  ): ResourceScope | null {
    if (value === null) return {};
    if (Array.isArray(value) || typeof value !== 'object') return null;
    const allowed = new Set([
      'outcomeIds',
      'workspaceIds',
      'scholarshipIds',
    ]);
    if (Object.keys(value).some((key) => !allowed.has(key))) return null;
    const result: ResourceScope = {};
    for (const key of allowed) {
      const entry = value[key];
      if (entry === undefined) continue;
      if (
        !Array.isArray(entry) ||
        entry.some((item) => typeof item !== 'string')
      ) {
        return null;
      }
      result[key as keyof ResourceScope] = entry as string[];
    }
    return result;
  }

  private async countryIds(countryCodes: string[]): Promise<string[] | null> {
    if (countryCodes.length === 0) return null;
    const normalized = Array.from(
      new Set(
        countryCodes.flatMap((code) => [
          code.trim(),
          code.trim().toLowerCase(),
          code.trim().toUpperCase(),
        ]),
      ),
    ).filter(Boolean);
    const countries = await this.prismaService.execute((prisma) =>
      prisma.country.findMany({
        where: { code: { in: normalized } },
        select: { id: true, code: true },
      }),
    );
    if (countries === null) throw databaseUnavailable();
    return Array.from(
      new Set([
        ...normalized,
        ...countries.flatMap((country) => [country.id, country.code]),
      ]),
    );
  }

  private intersection(
    left: string[] | null,
    right: string[] | null,
  ): string[] | null {
    if (left === null) return right;
    if (right === null) return left;
    const allowed = new Set(right);
    return left.filter((value) => allowed.has(value));
  }

  private forbidden() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'This operator is not authorized for outcome verification.',
    );
  }
}
