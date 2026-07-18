import { createHmac } from 'node:crypto';

import { Injectable, Logger } from '@nestjs/common';
import { ConsentPurpose } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';

export const COMPETITION_READINESS_FEATURES = [
  'competition_readiness',
  'success_lab',
  'ai_diagnostic',
  'outcome_evidence',
  'public_impact_stats',
] as const;

export type CompetitionReadinessFeature =
  (typeof COMPETITION_READINESS_FEATURES)[number];

export type FeatureAccessBlockReason =
  | 'feature_disabled'
  | 'kill_switch_enabled'
  | 'database_unavailable'
  | 'profile_not_found'
  | 'account_type_not_allowed'
  | 'rollout_not_configured'
  | 'country_not_eligible'
  | 'rollout_excluded'
  | 'consent_required'
  | 'birth_date_required'
  | 'age_below_minimum'
  | 'guardian_authorization_required';

export type FeatureAccessDecision =
  | { allowed: true; feature: CompetitionReadinessFeature }
  | {
      allowed: false;
      feature: CompetitionReadinessFeature;
      reason: FeatureAccessBlockReason;
    };

export interface FeatureAccessRequest {
  feature: CompetitionReadinessFeature;
  userId: string;
  /**
   * Canonical ISO alpha-2 code resolved from server-owned profile/catalog data.
   * Controllers must never copy this value directly from an untrusted body.
   */
  countryCode?: string | null;
  now?: Date;
}

interface FeaturePolicy {
  enabled: boolean;
  blockReason?: FeatureAccessBlockReason;
  studentOnly: boolean;
  rolloutRequired: boolean;
  consentPurpose?: ConsentPurpose;
  guardianCheckForMinor: boolean;
  minimumAge?: number;
}

const AI_AND_OUTCOME_CONSENTS = [
  ConsentPurpose.ai_third_party,
  ConsentPurpose.outcome_evidence,
] as const;

function envEnabled(value: string | undefined, defaultValue = false): boolean {
  if (value === undefined) return defaultValue;
  return value.trim().toLowerCase() === 'true';
}

function normalizedCountryCodes(value: string | undefined): string[] {
  return (value ?? '')
    .split(',')
    .map((entry) => entry.trim().toUpperCase())
    .filter((entry) => /^[A-Z]{2}$/.test(entry));
}

const LEGACY_COUNTRY_CODES: Readonly<Record<string, string>> = {
  NIGER: 'NE',
  SENEGAL: 'SN',
  'COTE D IVOIRE': 'CI',
};

function normalizedCountryCode(
  value: string | null | undefined,
): string | null {
  const normalized = value
    ?.normalize('NFD')
    .replace(/\p{Mark}/gu, '')
    .toUpperCase()
    .replace(/[^A-Z]+/g, ' ')
    .trim()
    .replace(/\s+/g, ' ');
  if (!normalized) return null;
  if (/^[A-Z]{2}$/.test(normalized)) return normalized;
  return LEGACY_COUNTRY_CODES[normalized] ?? null;
}

function isMinorAt(birthDate: Date, now: Date): boolean {
  const adultThreshold = new Date(now);
  adultThreshold.setUTCFullYear(adultThreshold.getUTCFullYear() - 18);
  return birthDate > adultThreshold;
}

function ageAt(birthDate: Date, now: Date): number {
  let age = now.getUTCFullYear() - birthDate.getUTCFullYear();
  const birthdayHasPassed =
    now.getUTCMonth() > birthDate.getUTCMonth() ||
    (now.getUTCMonth() === birthDate.getUTCMonth() &&
      now.getUTCDate() >= birthDate.getUTCDate());
  if (!birthdayHasPassed) age -= 1;
  return age;
}

function aiDiagnosticMinimumAge(): number {
  const configured = Number(process.env.KPB_AI_DIAGNOSTIC_MIN_AGE ?? '13');
  return Number.isInteger(configured) && configured >= 13 && configured <= 18
    ? configured
    : 13;
}

@Injectable()
export class FeatureAccessService {
  private readonly logger = new Logger(FeatureAccessService.name);

  constructor(private readonly prisma: PrismaService) {}

  async evaluate(input: FeatureAccessRequest): Promise<FeatureAccessDecision> {
    const policy = this.policyFor(input.feature);
    if (!policy.enabled) {
      return this.blocked(
        input.feature,
        policy.blockReason ?? 'feature_disabled',
      );
    }

    // Every authenticated feature decision is grounded in the canonical profile
    // and versioned receipts. Missing configuration or a failed DB read denies.
    if (!this.prisma.isEnabled) {
      return this.blocked(input.feature, 'database_unavailable');
    }

    const now = input.now ?? new Date();
    let profile: Awaited<ReturnType<typeof this.loadProfile>>;
    try {
      profile = await this.loadProfile(input.userId, now);
    } catch {
      this.logger.warn(
        'Feature access denied because the database is unavailable.',
      );
      return this.blocked(input.feature, 'database_unavailable');
    }

    if (!profile) {
      return this.blocked(input.feature, 'profile_not_found');
    }

    if (policy.studentOnly && profile.accountType !== 'student') {
      return this.blocked(input.feature, 'account_type_not_allowed');
    }

    if (policy.rolloutRequired) {
      const rolloutBlock = this.rolloutBlockReason({
        feature: input.feature,
        userId: input.userId,
        countryCode:
          normalizedCountryCode(input.countryCode) ??
          normalizedCountryCode(profile.countryOfResidence),
      });
      if (rolloutBlock) return this.blocked(input.feature, rolloutBlock);
    }

    if (policy.consentPurpose) {
      const consent = profile.consentReceipts.find(
        (receipt) => receipt.purpose === policy.consentPurpose,
      );
      if (!consent) return this.blocked(input.feature, 'consent_required');

      if (policy.guardianCheckForMinor) {
        if (!profile.birthDate) {
          return this.blocked(input.feature, 'birth_date_required');
        }
        if (
          policy.minimumAge !== undefined &&
          ageAt(profile.birthDate, now) < policy.minimumAge
        ) {
          return this.blocked(input.feature, 'age_below_minimum');
        }
        if (
          isMinorAt(profile.birthDate, now) &&
          !this.hasValidGuardianAuthorization(
            consent.guardianAuthorization,
            now,
          )
        ) {
          return this.blocked(input.feature, 'guardian_authorization_required');
        }
      }
    }

    return { allowed: true, feature: input.feature };
  }

  private async loadProfile(userId: string, now: Date) {
    return this.prisma.execute((db) =>
      db.userProfile.findUnique({
        where: { id: userId },
        select: {
          accountType: true,
          birthDate: true,
          countryOfResidence: true,
          consentReceipts: {
            where: {
              purpose: { in: [...AI_AND_OUTCOME_CONSENTS] },
              revokedAt: null,
              grantedAt: { lte: now },
              notice: {
                effectiveAt: { lte: now },
                retiredAt: null,
              },
            },
            orderBy: { grantedAt: 'desc' },
            select: {
              purpose: true,
              guardianAuthorization: {
                select: {
                  status: true,
                  verifiedAt: true,
                  expiresAt: true,
                  revokedAt: true,
                },
              },
            },
          },
        },
      }),
    );
  }

  private policyFor(feature: CompetitionReadinessFeature): FeaturePolicy {
    const competitionReadiness = envEnabled(
      process.env.KPB_COMPETITION_READINESS_ENABLED,
    );
    const successLab =
      competitionReadiness && envEnabled(process.env.KPB_SUCCESS_LAB_ENABLED);

    switch (feature) {
      case 'competition_readiness':
        return {
          enabled: competitionReadiness,
          studentOnly: false,
          rolloutRequired: false,
          guardianCheckForMinor: false,
        };
      case 'success_lab':
        return {
          enabled: successLab,
          studentOnly: true,
          rolloutRequired: true,
          guardianCheckForMinor: false,
        };
      case 'ai_diagnostic': {
        const killSwitch = envEnabled(
          process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH,
          true,
        );
        return {
          enabled:
            successLab &&
            envEnabled(process.env.KPB_AI_DIAGNOSTIC_ENABLED) &&
            !killSwitch,
          blockReason: killSwitch ? 'kill_switch_enabled' : 'feature_disabled',
          studentOnly: true,
          rolloutRequired: true,
          consentPurpose: ConsentPurpose.ai_third_party,
          guardianCheckForMinor: true,
          minimumAge: aiDiagnosticMinimumAge(),
        };
      }
      case 'outcome_evidence':
        return {
          enabled:
            successLab &&
            envEnabled(process.env.KPB_OUTCOME_EVIDENCE_ENABLED),
          studentOnly: true,
          rolloutRequired: false,
          consentPurpose: ConsentPurpose.outcome_evidence,
          guardianCheckForMinor: true,
        };
      case 'public_impact_stats':
        return {
          enabled:
            competitionReadiness &&
            envEnabled(process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED),
          studentOnly: false,
          rolloutRequired: false,
          guardianCheckForMinor: false,
        };
    }
  }

  private rolloutBlockReason(input: {
    feature: CompetitionReadinessFeature;
    userId: string;
    countryCode: string | null;
  }): FeatureAccessBlockReason | null {
    const countries = normalizedCountryCodes(
      process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES,
    );
    const rawPercent = process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT;
    const percent = Number(rawPercent ?? '0');

    if (
      countries.length === 0 ||
      !Number.isInteger(percent) ||
      percent < 0 ||
      percent > 100
    ) {
      return 'rollout_not_configured';
    }
    if (!input.countryCode || !countries.includes(input.countryCode)) {
      return 'country_not_eligible';
    }
    if (percent === 0) return 'rollout_excluded';
    if (percent === 100) return null;

    const secret = process.env.KPB_FEATURE_ROLLOUT_SECRET?.trim();
    if (!secret) return 'rollout_not_configured';

    const digest = createHmac('sha256', `${secret}:v1`)
      .update(`${input.feature}:${input.userId}`)
      .digest();
    return digest.readUInt32BE(0) % 100 < percent ? null : 'rollout_excluded';
  }

  private hasValidGuardianAuthorization(
    authorization: {
      status: string;
      verifiedAt: Date | null;
      expiresAt: Date | null;
      revokedAt: Date | null;
    } | null,
    now: Date,
  ): boolean {
    return Boolean(
      authorization &&
      authorization.status === 'verified' &&
      authorization.verifiedAt &&
      authorization.verifiedAt <= now &&
      authorization.revokedAt === null &&
      (authorization.expiresAt === null || authorization.expiresAt > now),
    );
  }

  private blocked(
    feature: CompetitionReadinessFeature,
    reason: FeatureAccessBlockReason,
  ): FeatureAccessDecision {
    return { allowed: false, feature, reason };
  }
}
