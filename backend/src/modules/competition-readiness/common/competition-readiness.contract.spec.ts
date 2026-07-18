import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import {
  ADMISSION_DECISIONS,
  COMPETITION_READINESS_ERROR_CODES,
  COMPETITION_READINESS_SCHEMA_VERSION,
  EVIDENCE_VERIFICATION_STATUSES,
  FUNDING_DECISIONS,
  OUTCOME_EVIDENCE_KINDS,
  OUTCOME_TYPES,
  SCHOLARSHIP_WORKSPACE_STATUSES,
  WORKSPACE_STEP_CATEGORIES,
  WORKSPACE_STEP_STATUSES,
} from './competition-readiness.contract';
import { featureDisabled } from './competition-readiness.errors';

describe('Competition Readiness v1 contract', () => {
  it('keeps the stable error codes unique', () => {
    expect(new Set(COMPETITION_READINESS_ERROR_CODES).size).toBe(
      COMPETITION_READINESS_ERROR_CODES.length,
    );
  });

  it('freezes the public outcome enums without duplicate wire values', () => {
    for (const values of [
      OUTCOME_TYPES,
      OUTCOME_EVIDENCE_KINDS,
      EVIDENCE_VERIFICATION_STATUSES,
      ADMISSION_DECISIONS,
      FUNDING_DECISIONS,
    ]) {
      expect(new Set(values).size).toBe(values.length);
    }
  });

  it('ships a fixture that only uses frozen v1 enum values', () => {
    const fixture = JSON.parse(
      readFileSync(
        join(
          process.cwd(),
          'src/modules/competition-readiness/contracts/fixtures/workspace-v1.fixture.json',
        ),
        'utf8',
      ),
    ) as {
      schemaVersion: number;
      status: string;
      steps: Array<{ status: string; category: string }>;
    };

    expect(fixture.schemaVersion).toBe(COMPETITION_READINESS_SCHEMA_VERSION);
    expect(SCHOLARSHIP_WORKSPACE_STATUSES).toContain(fixture.status);
    for (const step of fixture.steps) {
      expect(WORKSPACE_STEP_STATUSES).toContain(step.status);
      expect(WORKSPACE_STEP_CATEGORIES).toContain(step.category);
    }
  });

  it('returns a code-based, non-PII feature-disabled response', () => {
    expect(featureDisabled('success_lab').getResponse()).toEqual({
      code: 'FEATURE_DISABLED',
      message: 'Feature is not available.',
      details: { feature: 'success_lab' },
    });
  });
});
