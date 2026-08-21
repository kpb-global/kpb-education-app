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
 * An env-provided instant, or null when it is absent or unparseable.
 *
 * Null rather than a best guess, on purpose. This value drives the campaign
 * window the « Études en France » teaser prints, and a typo in a deploy
 * variable must make the app say nothing about dates — not print
 * "Invalid Date", and not silently fall back to today, which would announce a
 * campaign opening the moment anyone opens the screen.
 */
function isoInstant(value: string | undefined): string | null {
  const raw = value?.trim();
  if (!raw) return null;
  const parsed = new Date(raw);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
}

/**
 * The listings actually published. These serve whenever the env vars are unset,
 * which makes them a fallback and not merely a default: the force-update screen
 * cannot be dismissed and its only button is disabled without a usable URL, so a
 * wrong fallback locks every user out of the app on the day
 * KPB_MIN_APP_VERSION is raised.
 */
const PUBLISHED_ANDROID_STORE_URL =
  'https://play.google.com/store/apps/details?id=com.karatou.android';
const PUBLISHED_IOS_STORE_URL = 'https://apps.apple.com/app/id1128659292';

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

    // ── Espace « Études en France » ────────────────────────────────────────
    //
    // Deux surfaces, UNE variable à basculer le jour J. Le teaser dit « en
    // préparation » ; l'espace réel dit le contraire par sa seule existence.
    // Les laisser s'allumer indépendamment garantissait qu'un jour de
    // lancement les afficherait tous les deux — « bientôt » à côté d'un espace
    // vivant. `eef` retire donc le teaser de lui-même : mettre KPB_EEF_ENABLED
    // à true suffit, et rien à désactiver dans un second temps (l'oubli
    // classique, celui qu'on ne voit pas depuis un tableau de bord).
    const eef = enabled(process.env.KPB_EEF_ENABLED);
    const eefTeaser = !eef && enabled(process.env.KPB_EEF_TEASER_ENABLED);

    return {
      minVersion: process.env.KPB_MIN_APP_VERSION?.trim() || '0.0.0',
      androidStoreUrl:
        process.env.KPB_ANDROID_STORE_URL?.trim() ||
        PUBLISHED_ANDROID_STORE_URL,
      iosStoreUrl:
        process.env.KPB_IOS_STORE_URL?.trim() || PUBLISHED_IOS_STORE_URL,
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
        eefTeaser,
        eef,
      },
      // La fenêtre de campagne est SERVIE, jamais compilée. Une build vit ~90
      // jours ; une date d'ouverture écrite dans le binaire devient fausse
      // pendant sa vie utile et n'est plus corrigible sans passer par les
      // stores — c'est la leçon qu'IntakeCalendar porte déjà côté mobile.
      // Null quand ce n'est pas configuré : le client n'annonce alors aucune
      // date, plutôt qu'une date inventée.
      eefCampaign: {
        opensAt: isoInstant(process.env.KPB_EEF_CAMPAIGN_OPENS_AT),
        closesAt: isoInstant(process.env.KPB_EEF_CAMPAIGN_CLOSES_AT),
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
