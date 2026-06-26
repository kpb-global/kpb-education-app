import {
  buildCoachSystemPrompt,
  buildCoachSuggestions,
  resolveCoachLanguage,
} from './coach-prompt.builder';

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

  it('answers in English when language is en, keeping source citations', () => {
    const prompt = buildCoachSystemPrompt({
      fullName: 'John Mensah',
      language: 'en',
      verifiedContext:
        'COUNTRIES:\n- Canada: tuition CAD 20,000/yr [source: KPB catalogue, verified 2026-06-20]',
    });
    expect(prompt).toContain('Reply in English');
    expect(prompt).toContain('VERIFIED CONTEXT');
    expect(prompt).toContain('Canada: tuition');
    expect(prompt).toContain('NEVER invent');
    expect(prompt).toContain('contact a KPB advisor');
    // Must not leak the French persona.
    expect(prompt).not.toContain('Réponds en français');
  });

  it('declares no verified data in English when context is empty (en)', () => {
    const prompt = buildCoachSystemPrompt({ fullName: 'Test', language: 'en' });
    expect(prompt).toContain('No verified data');
  });

  it('localizes suggestions and resolves locale strings', () => {
    expect(resolveCoachLanguage('en_US')).toBe('en');
    expect(resolveCoachLanguage('fr')).toBe('fr');
    expect(resolveCoachLanguage(undefined)).toBe('fr');
    const en = buildCoachSuggestions({ language: 'en' });
    expect(en.some((s) => /budget/i.test(s))).toBe(true);
    expect(en.join(' ')).not.toContain('Quelles');
  });
});
