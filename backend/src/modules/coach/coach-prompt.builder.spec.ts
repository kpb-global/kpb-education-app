import {
  budgetBucket,
  buildCoachSystemPrompt,
  buildCoachSuggestions,
  resolveCoachLanguage,
  unsourcedFigureCaveat,
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

  it('does NOT send the student name to the LLM (PII minimization)', () => {
    const fr = buildCoachSystemPrompt({
      fullName: 'Awa Diallo',
      currentLevel: 'Licence',
    });
    expect(fr).not.toContain('Awa');
    expect(fr).not.toContain('Diallo');
    expect(fr).not.toContain('Prénom');
    expect(fr).toContain('pseudonymisé');

    const en = buildCoachSystemPrompt({
      fullName: 'John Mensah',
      language: 'en',
    });
    expect(en).not.toContain('John');
    expect(en).not.toContain('Mensah');
    expect(en).not.toContain('First name');
    expect(en).toContain('pseudonymized');
  });

  it('buckets the budget into a coarse range, never the exact figure', () => {
    const fr = buildCoachSystemPrompt({ monthlyBudgetEur: 1450 });
    expect(fr).toContain('1000–2000');
    expect(fr).not.toContain('1450');
    expect(budgetBucket(300, 'en')).toBe('< 500 €/month (range)');
    expect(budgetBucket(750, 'fr')).toBe('500–1000 €/mois (tranche)');
    expect(budgetBucket(5000, 'en')).toBe('> 2000 €/month (range)');
    expect(budgetBucket(undefined, 'fr')).toBe('non renseigné');
    expect(budgetBucket(0, 'en')).toBe('not specified');
  });

  describe('unsourcedFigureCaveat (output guardrail)', () => {
    it('flags a currency figure when there was no verified context', () => {
      expect(
        unsourcedFigureCaveat('Les frais sont 3 000 € par an.', '', 'fr'),
      ).toContain('conseiller KPB');
      expect(
        unsourcedFigureCaveat('Tuition is about $20,000.', '', 'en'),
      ).toContain('KPB advisor');
    });

    it('stays silent when verified context grounded the answer', () => {
      expect(
        unsourcedFigureCaveat('Les frais sont 3 000 €.', 'PAYS:\n- France: …', 'fr'),
      ).toBeNull();
    });

    it('stays silent when the reply has no concrete figure', () => {
      expect(
        unsourcedFigureCaveat('Contacte un conseiller KPB pour les détails.', '', 'fr'),
      ).toBeNull();
    });
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
