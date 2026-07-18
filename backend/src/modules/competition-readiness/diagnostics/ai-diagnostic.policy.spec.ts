import {
  buildDeterministicDiagnostic,
  diagnosticInputFingerprint,
  isSuccessLabDiagnosticOutput,
  redactDiagnosticInput,
} from './ai-diagnostic.policy';

describe('AI diagnostic policy', () => {
  it('redacts common identifiers and enforces the input cap', () => {
    const result = redactDiagnosticInput(
      'Aminou Test aminou@example.com +227 90 00 00 00 https://example.com ' +
        'x'.repeat(100),
      ['Aminou Test'],
      80,
    );

    expect(result).not.toContain('Aminou Test');
    expect(result).not.toContain('aminou@example.com');
    expect(result).not.toContain('+227');
    expect(result).not.toContain('https://');
    expect(result.length).toBeLessThanOrEqual(80);
  });

  it('returns one deterministic priority linked to a verified criterion', () => {
    const result = buildDeterministicDiagnostic({
      language: 'fr',
      criteria: [{ code: 'eligibility-001', label: 'Leadership démontré' }],
      steps: [
        {
          code: 'profile',
          title: 'Profil',
          status: 'completed',
          isRequired: true,
        },
        {
          code: 'cv',
          title: 'Préparer mon CV',
          status: 'in_progress',
          isRequired: true,
        },
      ],
    });

    expect(result.priorityImprovement).toContain('Préparer mon CV');
    expect(result.criterionReferences).toEqual(['eligibility-001']);
    expect(result.strength).toContain('1 étape');
  });

  it('rejects extra fields, unverified criteria and admission claims', () => {
    const allowed = new Set(['eligibility-001']);
    const valid = {
      strength: 'Ton objectif de candidature est clairement présenté.',
      priorityImprovement: 'Ajoute une preuve mesurable de ton leadership.',
      rationale:
        'Le critère leadership demande un résultat concret et vérifiable.',
      nextAction: 'Ajoute un chiffre précis à ton premier exemple.',
      criterionReferences: ['eligibility-001'],
    };

    expect(isSuccessLabDiagnosticOutput(valid, allowed)).toBe(true);
    expect(isSuccessLabDiagnosticOutput({ ...valid, score: 98 }, allowed)).toBe(
      false,
    );
    expect(
      isSuccessLabDiagnosticOutput(
        { ...valid, criterionReferences: ['invented'] },
        allowed,
      ),
    ).toBe(false);
    expect(
      isSuccessLabDiagnosticOutput(
        { ...valid, rationale: 'Tu as 90% de chance admission.' },
        allowed,
      ),
    ).toBe(false);
  });

  it('creates a stable fingerprint without raw content', () => {
    const input = {
      promptVersion: 'success-lab-v1',
      language: 'fr' as const,
      workspaceVersion: 3,
      criteriaVersion: 'criteria-2026-07-17',
      artifactSha256: 'abc123',
    };

    expect(diagnosticInputFingerprint(input)).toBe(
      diagnosticInputFingerprint({ ...input }),
    );
    expect(
      diagnosticInputFingerprint({ ...input, workspaceVersion: 4 }),
    ).not.toBe(diagnosticInputFingerprint(input));
  });
});
