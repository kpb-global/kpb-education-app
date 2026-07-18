import {
  buildDeterministicDiagnostic,
  isSuccessLabDiagnosticOutput,
  redactDiagnosticInput,
} from './ai-diagnostic.policy';
import {
  DIAGNOSTIC_POLICY_EVAL_CASE_COUNT,
  FALLBACK_EVAL_CASES,
  REDACTION_EVAL_CASES,
  UNSAFE_CLAIM_EVAL_CASES,
} from './diagnostic-policy-eval.cases';

describe('Success Lab diagnostic P0 policy evaluation corpus', () => {
  it('contains exactly 60 synthetic and anonymous regression cases', () => {
    expect(DIAGNOSTIC_POLICY_EVAL_CASE_COUNT).toBe(60);
  });

  it.each(REDACTION_EVAL_CASES)('$id redacts forbidden PII', (testCase) => {
    const result = redactDiagnosticInput(
      testCase.input,
      testCase.forbiddenValues,
    );
    for (const fragment of testCase.forbiddenFragments) {
      expect(result.toLowerCase()).not.toContain(fragment.toLowerCase());
    }
  });

  it.each(UNSAFE_CLAIM_EVAL_CASES)(
    '$id rejects an admission probability or guarantee',
    ({ claim }) => {
      expect(
        isSuccessLabDiagnosticOutput(
          {
            strength: 'Le dossier contient une expérience pertinente.',
            priorityImprovement: 'Ajoute un exemple concret et mesurable.',
            rationale: claim,
            nextAction: 'Ajoute un résultat chiffré à ton premier exemple.',
            criterionReferences: ['verified-criterion'],
          },
          new Set(['verified-criterion']),
        ),
      ).toBe(false);
    },
  );

  it.each(FALLBACK_EVAL_CASES)(
    '$id returns one bounded priority tied to a verified criterion',
    (testCase) => {
      const result = buildDeterministicDiagnostic(testCase);
      expect(
        isSuccessLabDiagnosticOutput(
          result,
          new Set([testCase.expectedCriterionCode]),
        ),
      ).toBe(true);
      expect(result.criterionReferences).toEqual([
        testCase.expectedCriterionCode,
      ]);
    },
  );
});
