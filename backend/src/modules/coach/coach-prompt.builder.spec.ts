import { buildCoachSystemPrompt } from './coach-prompt.builder';

describe('buildCoachSystemPrompt (RAG grounding)', () => {
  it('injects the verified context and the no-invention grounding rule', () => {
    const prompt = buildCoachSystemPrompt({
      fullName: 'Awa Diallo',
      verifiedContext:
        'PAYS:\n- France: frais 2 700 - 12 000 EUR/an [source: catalogue KPB, vérifié 2026-06-20]',
    });
    expect(prompt).toContain('CONTEXTE VÉRIFIÉ');
    expect(prompt).toContain('France: frais 2 700');
    expect(prompt).toContain('invente JAMAIS');
    // Guardrail: route to a human when the data is missing.
    expect(prompt).toContain('conseiller KPB');
  });

  it('declares no verified data when the context is empty', () => {
    const prompt = buildCoachSystemPrompt({ fullName: 'Test' });
    expect(prompt).toContain('Aucune donnée vérifiée');
  });
});
