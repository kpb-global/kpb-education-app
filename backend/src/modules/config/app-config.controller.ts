import { Controller, Get } from '@nestjs/common';

function enabled(value: string | undefined, defaultValue = false): boolean {
  if (value === undefined) return defaultValue;
  return value.trim().toLowerCase() === 'true';
}

function rolloutPercent(value: string | undefined): number {
  const parsed = Number(value ?? '0');
  if (!Number.isFinite(parsed)) return 0;
  return Math.max(0, Math.min(100, Math.round(parsed)));
}

/**
 * Public, unauthenticated app configuration. The mobile client reads this at
 * boot to decide whether the installed build is still supported (force-update
 * gate). `minVersion` defaults to 0.0.0 — i.e. no build is ever blocked until
 * operators explicitly raise KPB_MIN_APP_VERSION.
 */
@Controller('config')
export class AppConfigController {
  @Get('app')
  getAppConfig() {
    const competitionReadiness = enabled(
      process.env.KPB_COMPETITION_READINESS_ENABLED,
    );
    const successLab =
      competitionReadiness && enabled(process.env.KPB_SUCCESS_LAB_ENABLED);
    const aiDiagnostic =
      successLab &&
      enabled(process.env.KPB_AI_DIAGNOSTIC_ENABLED) &&
      !enabled(process.env.KPB_AI_DIAGNOSTIC_KILL_SWITCH, true);

    return {
      minVersion: process.env.KPB_MIN_APP_VERSION?.trim() || '0.0.0',
      androidStoreUrl:
        process.env.KPB_ANDROID_STORE_URL?.trim() ||
        'https://play.google.com/store/apps/details?id=com.kpbeducation.app',
      iosStoreUrl: process.env.KPB_IOS_STORE_URL?.trim() || '',
      features: {
        competitionReadiness,
        successLab,
        aiDiagnostic,
        outcomeEvidence:
          competitionReadiness &&
          successLab &&
          enabled(process.env.KPB_OUTCOME_EVIDENCE_ENABLED),
        publicImpactStats:
          competitionReadiness &&
          enabled(process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED),
      },
      successLabRollout: {
        countryCodes: (process.env.KPB_SUCCESS_LAB_PILOT_COUNTRIES ?? '')
          .split(',')
          .map((value) => value.trim().toUpperCase())
          .filter(Boolean),
        percent: rolloutPercent(process.env.KPB_SUCCESS_LAB_ROLLOUT_PERCENT),
      },
    };
  }
}
