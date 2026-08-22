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
 * A comma-separated env list, trimmed, de-duplicated, blanks dropped.
 *
 * Deliberately NOT upper-cased, unlike the Success Lab country codes just
 * below: this list is matched against a mobile profile's `countryOfResidence`,
 * which holds a French display name ("Niger", "Côte d'Ivoire") and not an ISO
 * code. Normalisation is the client's job — it is the side that knows what it
 * is comparing against — so the wire keeps whatever operators typed, and both
 * `NE` and `Niger` are accepted spellings.
 */
function nameList(value: string | undefined): string[] {
  const seen = new Set<string>();
  for (const entry of (value ?? '').split(',')) {
    const trimmed = entry.trim();
    if (trimmed) seen.add(trimmed);
  }
  return [...seen];
}

/**
 * Le JOUR de campagne écrit par l'exploitation, servi tel quel — jamais un
 * instant.
 *
 * ## Le défaut que cette fonction remplace
 *
 * Elle s'appelait `isoInstant` et faisait `new Date(raw).toISOString()`. Sur
 * une valeur portant un décalage explicite, cette seule ligne détruisait le
 * jour :
 *
 * ```
 * KPB_EEF_CAMPAIGN_OPENS_AT=2026-10-01T00:00:00+02:00   (l'heure de Paris)
 *   → servi « 2026-09-30T22:00:00.000Z »
 *   → tout client lit le 30 septembre, quel que soit son fuseau
 * ```
 *
 * Écrire l'heure de Paris est le réflexe naturel pour une procédure française,
 * et le client ne pouvait rien y faire : l'information était déjà perdue sur le
 * fil. Un correctif côté mobile — extraire `AAAA-MM-JJ` du texte reçu — ne
 * réparait donc que la moitié du problème, celle du fuseau de l'appareil.
 *
 * ## Ce qu'elle fait
 *
 * « La campagne ouvre le 1er octobre » est une date d'HORLOGE MURALE, pas un
 * instant : elle ne désigne pas le même moment à Dakar et à Montréal, et c'est
 * voulu. On lit donc les composantes du TEXTE, avant toute conversion, et on
 * sert un jour nu `AAAA-MM-JJ`. Aucun fuseau n'entre dans l'équation, donc
 * aucun décalage n'en sort.
 *
 * L'heure éventuellement écrite par l'exploitation est ignorée, pas honorée :
 * une échéance administrative se compte en jours. Voir `EefCalendar.phase`
 * côté mobile, qui compare des jours avec des bornes inclusives.
 *
 * Null plutôt qu'une approximation, sur une valeur illisible : ce jour pilote
 * la fenêtre qu'imprime la vitrine « Études en France », et une faute de frappe
 * dans une variable de déploiement doit faire taire l'app — pas afficher
 * « Invalid Date », pas retomber sur aujourd'hui, ce qui annoncerait une
 * campagne s'ouvrant à l'instant où l'écran s'ouvre.
 */
function campaignDay(value: string | undefined): string | null {
  const raw = value?.trim();
  if (!raw) return null;

  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw);
  if (!match) return null;

  const [year, month, day] = match.slice(1).map(Number);

  // `new Date(Date.UTC(2026, 12, 1))` vaut janvier 2027, et un 30 février
  // devient le 2 mars : normaliser une saisie fautive fabriquerait une date que
  // personne n'a écrite. On la refuse, et l'app n'annonce rien.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (
    probe.getUTCFullYear() !== year ||
    probe.getUTCMonth() !== month - 1 ||
    probe.getUTCDate() !== day
  ) {
    return null;
  }

  return match[0];
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
        // Des JOURS nus `AAAA-MM-JJ`, pas des instants — voir [campaignDay].
        // Un instant sur le fil se reprojette dans le fuseau du lecteur, et
        // « le 1er octobre » devient « le 30 septembre » pour une moitié du
        // public.
        opensAt: campaignDay(process.env.KPB_EEF_CAMPAIGN_OPENS_AT),
        closesAt: campaignDay(process.env.KPB_EEF_CAMPAIGN_CLOSES_AT),
        // Pays où la procédure est SUSPENDUE — le service ne traite pas les
        // dossiers, quelle que soit la date d'ouverture de la plateforme.
        //
        // Au 21/08/2026 : le Niger, la page officielle de l'ambassade indiquant
        // que la dénonciation de la convention du centre qui hébergeait Campus
        // France rend impossible le traitement des dossiers d'étudiants
        // nigériens (voir docs/eef-campaign-calendar-2027-2028-research.md).
        // Annoncer une ouverture à ces étudiants les enverrait vers une
        // démarche que l'État français déclare inopérante.
        //
        // Servi et non compilé pour la même raison que tout le reste ici : une
        // réouverture ne doit pas attendre une soumission App Store.
        suspendedCountries: nameList(
          process.env.KPB_EEF_SUSPENDED_COUNTRIES,
        ),
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
