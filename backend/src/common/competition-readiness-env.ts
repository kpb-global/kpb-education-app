type Environment = Record<string, string | undefined>;

function enabled(value: string | undefined): boolean {
  return value?.trim().toLowerCase() === 'true';
}

function requiredSecret(
  env: Environment,
  name: string,
  minimumLength = 32,
): string {
  const value = env[name]?.trim() ?? '';
  if (Buffer.byteLength(value, 'utf8') < minimumLength) {
    throw new Error(
      `${name} must contain at least ${minimumLength} bytes when its feature is enabled in production.`,
    );
  }
  return value;
}

function integerInRange(
  env: Environment,
  name: string,
  defaultValue: number,
  minimum: number,
  maximum: number,
): number {
  const raw = env[name]?.trim();
  const value = raw ? Number(raw) : defaultValue;
  if (!Number.isSafeInteger(value) || value < minimum || value > maximum) {
    throw new Error(
      `${name} must be an integer between ${minimum} and ${maximum}.`,
    );
  }
  return value;
}

/**
 * Fail-fast validation for the Competition Readiness production rollout.
 *
 * Feature services still deny individual requests when a dependency becomes
 * unavailable. This validation catches contradictory flags and missing
 * cryptographic material before a production container starts accepting
 * traffic. It deliberately allows the default all-off configuration.
 */
export function validateCompetitionReadinessEnvironment(
  env: Environment = process.env,
): void {
  if (env.NODE_ENV !== 'production') return;

  const competitionReadiness = enabled(
    env.KPB_COMPETITION_READINESS_ENABLED,
  );
  const successLab = enabled(env.KPB_SUCCESS_LAB_ENABLED);
  const artifacts = enabled(env.KPB_APPLICATION_ARTIFACTS_ENABLED);
  const studyReview = enabled(env.KPB_STUDY_REVIEW_ENABLED);
  const aiDiagnostic = enabled(env.KPB_AI_DIAGNOSTIC_ENABLED);
  const outcomeEvidence = enabled(env.KPB_OUTCOME_EVIDENCE_ENABLED);
  const publicImpact = enabled(env.KPB_IMPACT_PUBLIC_STATS_ENABLED);

  const childFlags = [
    ['KPB_SUCCESS_LAB_ENABLED', successLab],
    ['KPB_APPLICATION_ARTIFACTS_ENABLED', artifacts],
    ['KPB_STUDY_REVIEW_ENABLED', studyReview],
    ['KPB_AI_DIAGNOSTIC_ENABLED', aiDiagnostic],
    ['KPB_OUTCOME_EVIDENCE_ENABLED', outcomeEvidence],
    ['KPB_IMPACT_PUBLIC_STATS_ENABLED', publicImpact],
  ] as const;
  const contradictoryChild = childFlags.find(
    ([, value]) => value && !competitionReadiness,
  );
  if (contradictoryChild) {
    throw new Error(
      `${contradictoryChild[0]} cannot be enabled while KPB_COMPETITION_READINESS_ENABLED is false.`,
    );
  }

  for (const [name, value] of [
    ['KPB_APPLICATION_ARTIFACTS_ENABLED', artifacts],
    ['KPB_STUDY_REVIEW_ENABLED', studyReview],
    ['KPB_AI_DIAGNOSTIC_ENABLED', aiDiagnostic],
    ['KPB_OUTCOME_EVIDENCE_ENABLED', outcomeEvidence],
  ] as const) {
    if (value && !successLab) {
      throw new Error(
        `${name} cannot be enabled while KPB_SUCCESS_LAB_ENABLED is false.`,
      );
    }
  }

  if (studyReview && !artifacts) {
    throw new Error(
      'KPB_STUDY_REVIEW_ENABLED requires KPB_APPLICATION_ARTIFACTS_ENABLED.',
    );
  }
  if (outcomeEvidence && !artifacts) {
    throw new Error(
      'KPB_OUTCOME_EVIDENCE_ENABLED requires KPB_APPLICATION_ARTIFACTS_ENABLED.',
    );
  }

  if (competitionReadiness) {
    const buildSha = env.KPB_BUILD_SHA?.trim() ?? '';
    if (!/^[0-9a-f]{7,64}$/i.test(buildSha)) {
      throw new Error(
        'KPB_BUILD_SHA must contain the immutable Git commit SHA when Competition Readiness is enabled in production.',
      );
    }
  }

  const rolloutPercent = integerInRange(
    env,
    'KPB_SUCCESS_LAB_ROLLOUT_PERCENT',
    0,
    0,
    100,
  );
  integerInRange(env, 'KPB_STUDY_REVIEW_SLA_HOURS', 48, 1, 168);
  integerInRange(env, 'KPB_EVIDENCE_ACCESS_TTL_SECONDS', 60, 15, 300);
  integerInRange(
    env,
    'KPB_OUTCOME_EVIDENCE_MAX_PENDING_PER_WORKSPACE',
    20,
    1,
    100,
  );
  integerInRange(
    env,
    'KPB_AI_DIAGNOSTIC_MONTHLY_BUDGET_MICROS_USD',
    0,
    0,
    Number.MAX_SAFE_INTEGER,
  );
  integerInRange(env, 'KPB_OUTBOX_BATCH_SIZE', 10, 1, 100);
  integerInRange(env, 'KPB_OUTBOX_LEASE_MS', 300_000, 5_000, 900_000);
  integerInRange(env, 'KPB_OUTBOX_MAX_ATTEMPTS', 8, 1, 50);
  const outboxRetryCapMs = integerInRange(
    env,
    'KPB_OUTBOX_RETRY_CAP_MS',
    3_600_000,
    5_000,
    86_400_000,
  );
  const outboxRetryBaseMs = integerInRange(
    env,
    'KPB_OUTBOX_RETRY_BASE_MS',
    5_000,
    1_000,
    300_000,
  );
  if (outboxRetryCapMs < outboxRetryBaseMs) {
    throw new Error(
      'KPB_OUTBOX_RETRY_CAP_MS must be greater than or equal to KPB_OUTBOX_RETRY_BASE_MS.',
    );
  }

  if (successLab && rolloutPercent > 0) {
    const countries = (env.KPB_SUCCESS_LAB_PILOT_COUNTRIES ?? '')
      .split(',')
      .map((value) => value.trim().toUpperCase())
      .filter(Boolean);
    if (
      countries.length === 0 ||
      countries.some((country) => !/^[A-Z]{2}$/.test(country))
    ) {
      throw new Error(
        'KPB_SUCCESS_LAB_PILOT_COUNTRIES must contain ISO alpha-2 country codes when rollout is enabled.',
      );
    }
  }
  const activeSecrets: string[] = [];
  if (successLab && rolloutPercent > 0 && rolloutPercent < 100) {
    activeSecrets.push(requiredSecret(env, 'KPB_FEATURE_ROLLOUT_SECRET'));
  }
  if (successLab && rolloutPercent > 0) {
    activeSecrets.push(requiredSecret(env, 'KPB_ANALYTICS_ACTOR_SECRET'));
  }

  if (studyReview || outcomeEvidence) {
    activeSecrets.push(requiredSecret(env, 'KPB_EVIDENCE_ACCESS_SECRET'));
  }
  if (outcomeEvidence) {
    activeSecrets.push(
      requiredSecret(env, 'KPB_OUTCOME_REFERENCE_HMAC_SECRET'),
    );
  }
  if (new Set(activeSecrets).size !== activeSecrets.length) {
    throw new Error(
      'Competition Readiness cryptographic secrets must use distinct values.',
    );
  }

  if (artifacts && !env.CLAMAV_HOST?.trim()) {
    throw new Error(
      'CLAMAV_HOST must be set when application artifacts are enabled in production.',
    );
  }
}
