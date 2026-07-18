import { Injectable } from '@nestjs/common';
import type { Prisma } from '@prisma/client';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { AdminSessionUser } from '../../auth/auth.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
} from '../common/competition-readiness.errors';

export const ADMIN_IMPACT_CAPABILITIES = {
  managePartnerAgreements: 'manage_partner_agreements',
  recruitPilotParticipants: 'recruit_pilot_participants',
  viewPilotAggregates: 'view_pilot_aggregates',
  managePilots: 'manage_pilots',
  freezeImpactSnapshots: 'freeze_impact_snapshots',
} as const;

type ImpactCapability =
  (typeof ADMIN_IMPACT_CAPABILITIES)[keyof typeof ADMIN_IMPACT_CAPABILITIES];

type Grant = {
  countryCodes: string[];
  cohortIds: string[];
  resourceScope: Prisma.JsonValue | null;
};

type ResourceScope = {
  partnerIds?: string[];
  agreementIds?: string[];
  pilotIds?: string[];
  cohortIds?: string[];
};

export type AdminImpactResolvedScope = {
  grants:
    | Array<{ countryCodes: string[] | null; resource: ResourceScope }>
    | null;
  countryCodes: string[] | null;
  resources: ResourceScope[] | null;
};

@Injectable()
export class AdminImpactAccessService {
  constructor(private readonly prismaService: PrismaService) {}

  async listScope(
    actor: AdminSessionUser,
    capability: ImpactCapability,
  ): Promise<AdminImpactResolvedScope> {
    this.assertRole(actor, capability);
    const grants = await this.activeGrants(actor, capability);
    if (grants === null) {
      return { grants: null, countryCodes: null, resources: null };
    }

    const countryCodes = Array.from(
      new Set(grants.flatMap((grant) => normalizeCountries(grant.countryCodes))),
    );
    const resolvedGrants = grants
      .map((grant) => {
        const resource = this.parseResourceScope(grant.resourceScope);
        if (!resource) return null;
        return {
          countryCodes:
            grant.countryCodes.length === 0
              ? null
              : normalizeCountries(grant.countryCodes),
          resource: {
            ...resource,
            ...(grant.cohortIds.length > 0
              ? {
                  cohortIds: Array.from(
                    new Set([
                      ...(resource.cohortIds ?? []),
                      ...grant.cohortIds,
                    ]),
                  ),
                }
              : {}),
          },
        };
      })
      .filter(
        (
          grant,
        ): grant is { countryCodes: string[] | null; resource: ResourceScope } =>
          grant !== null,
      );
    if (resolvedGrants.length === 0) throw this.forbidden();
    const resources = resolvedGrants.map((grant) => grant.resource);
    return {
      grants: resolvedGrants,
      countryCodes: grants.some((grant) => grant.countryCodes.length === 0)
        ? null
        : countryCodes,
      resources,
    };
  }

  async assertAgreement(
    actor: AdminSessionUser,
    capability: ImpactCapability,
    agreement: { id: string; partnerId: string; countryCodes: string[] },
  ): Promise<void> {
    const scope = await this.listScope(actor, capability);
    if (this.agreementCovered(scope, agreement)) return;
    throw this.forbidden();
  }

  async assertPilot(
    actor: AdminSessionUser,
    capability: ImpactCapability,
    pilot: { id: string; countryCodes: string[] },
    cohortId?: string,
  ): Promise<void> {
    const scope = await this.listScope(actor, capability);
    if (this.pilotCovered(scope, pilot, cohortId)) return;
    throw this.forbidden();
  }

  agreementCovered(
    scope: AdminImpactResolvedScope,
    agreement: { id: string; partnerId: string; countryCodes: string[] },
  ): boolean {
    if (scope.grants === null) return true;
    return scope.grants.some(({ countryCodes, resource }) => {
      if (
        countryCodes &&
        (agreement.countryCodes.length === 0 ||
          !agreement.countryCodes.every((code) =>
            countryCodes.includes(code.toUpperCase()),
          ))
      ) {
        return false;
      }
      return (
        (!resource.partnerIds ||
          resource.partnerIds.includes(agreement.partnerId)) &&
        (!resource.agreementIds || resource.agreementIds.includes(agreement.id)) &&
        !resource.pilotIds &&
        !resource.cohortIds
      );
    });
  }

  pilotCovered(
    scope: AdminImpactResolvedScope,
    pilot: { id: string; countryCodes: string[]; cohortIds?: string[] },
    cohortId?: string,
  ): boolean {
    if (scope.grants === null) return true;
    return scope.grants.some(({ countryCodes, resource }) => {
      if (
        countryCodes &&
        (pilot.countryCodes.length === 0 ||
          !pilot.countryCodes.every((code) =>
            countryCodes.includes(code.toUpperCase()),
          ))
      ) {
        return false;
      }
      const candidateCohorts = cohortId
        ? [cohortId]
        : (pilot.cohortIds ?? []);
      return (
        !resource.partnerIds &&
        !resource.agreementIds &&
        (!resource.pilotIds || resource.pilotIds.includes(pilot.id)) &&
        (!resource.cohortIds ||
          candidateCohorts.some((id) => resource.cohortIds?.includes(id)))
      );
    });
  }

  private assertRole(actor: AdminSessionUser, capability: ImpactCapability) {
    const roles: Record<ImpactCapability, readonly string[]> = {
      [ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements]: [
        InternalRole.Commercial,
        InternalRole.Admin,
        InternalRole.SuperAdmin,
      ],
      [ADMIN_IMPACT_CAPABILITIES.recruitPilotParticipants]: [
        InternalRole.Commercial,
        InternalRole.Admin,
        InternalRole.SuperAdmin,
      ],
      [ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates]: [
        InternalRole.Moderator,
        InternalRole.Admin,
        InternalRole.SuperAdmin,
      ],
      [ADMIN_IMPACT_CAPABILITIES.managePilots]: [
        InternalRole.Admin,
        InternalRole.SuperAdmin,
      ],
      [ADMIN_IMPACT_CAPABILITIES.freezeImpactSnapshots]: [
        InternalRole.Admin,
        InternalRole.SuperAdmin,
      ],
    };
    if (!roles[capability].includes(actor.role)) throw this.forbidden();
  }

  private async activeGrants(
    actor: AdminSessionUser,
    capability: ImpactCapability,
  ): Promise<Grant[] | null> {
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

  private parseResourceScope(value: Prisma.JsonValue | null): ResourceScope | null {
    if (value === null) return {};
    if (Array.isArray(value) || typeof value !== 'object') return null;
    const allowed = new Set([
      'partnerIds',
      'agreementIds',
      'pilotIds',
      'cohortIds',
    ]);
    if (Object.keys(value).some((key) => !allowed.has(key))) return null;
    const result: ResourceScope = {};
    for (const key of allowed) {
      const entry = value[key];
      if (entry === undefined) continue;
      if (!Array.isArray(entry) || entry.some((item) => typeof item !== 'string')) {
        return null;
      }
      result[key as keyof ResourceScope] = entry as string[];
    }
    return result;
  }

  private forbidden() {
    return new CompetitionReadinessHttpException(
      'FORBIDDEN_SCOPE',
      403,
      'This operator is not authorized for this impact resource.',
    );
  }
}

function normalizeCountries(values: string[]): string[] {
  return Array.from(new Set(values.map((value) => value.trim().toUpperCase()))).filter(
    (value) => /^[A-Z]{2}$/.test(value),
  );
}
