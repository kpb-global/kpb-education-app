import { LlmService, StructuredCompletionRequest } from './llm.service';

type Diagnostic = {
  strength: string;
  priorityImprovement: string;
  rationale: string;
  nextAction: string;
};

const fallback: Diagnostic = {
  strength: 'Ton dossier est commencé.',
  priorityImprovement: 'Complète la prochaine étape de ta checklist.',
  rationale: 'Cette action est vérifiable sans analyse automatique.',
  nextAction: 'Ouvre ton atelier et termine une étape.',
};

const request: StructuredCompletionRequest<Diagnostic> = {
  feature: 'success_lab_diagnostic',
  attemptKey: 'attempt-1',
  system: 'Give one bounded application improvement.',
  user: 'Verified application context.',
  responseSchema: {
    type: 'object',
    properties: {
      strength: { type: 'string' },
      priorityImprovement: { type: 'string' },
      rationale: { type: 'string' },
      nextAction: { type: 'string' },
    },
    required: ['strength', 'priorityImprovement', 'rationale', 'nextAction'],
    additionalProperties: false,
  },
  validate: (value): value is Diagnostic =>
    Boolean(
      value &&
      typeof value === 'object' &&
      typeof (value as Diagnostic).strength === 'string' &&
      typeof (value as Diagnostic).priorityImprovement === 'string' &&
      typeof (value as Diagnostic).rationale === 'string' &&
      typeof (value as Diagnostic).nextAction === 'string',
    ),
  fallback,
  temperature: 0.1,
  maxTokens: 220,
  promptVersion: 'success-lab-v1',
  model: 'openai/gpt-oss-20b',
};

describe('LlmService.completeStructured', () => {
  const previousApiKey = process.env.GROQ_API_KEY;
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    if (previousApiKey === undefined) delete process.env.GROQ_API_KEY;
    else process.env.GROQ_API_KEY = previousApiKey;
  });

  it('fails closed to the deterministic result when no provider is configured', async () => {
    delete process.env.GROQ_API_KEY;

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        data: fallback,
        provider: 'local',
        model: 'local-fallback',
        outcome: 'fallback',
        fallbackReason: 'provider_unconfigured',
      }),
    );
  });

  it('returns only a whole JSON document that passes runtime validation', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    const data: Diagnostic = {
      strength: 'Objectif clair',
      priorityImprovement: 'Ajouter une preuve chiffrée',
      rationale: 'Le critère leadership demande des résultats démontrables.',
      nextAction: 'Ajoute un résultat mesurable à ton premier exemple.',
    };
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          id: 'provider-1',
          choices: [{ message: { content: JSON.stringify(data) } }],
          usage: {
            prompt_tokens: 110,
            completion_tokens: 45,
            total_tokens: 155,
            prompt_tokens_details: { cached_tokens: 10 },
          },
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        data,
        provider: 'groq',
        model: 'openai/gpt-oss-20b',
        providerRequestId: 'provider-1',
        inputTokens: 110,
        cachedInputTokens: 10,
        outputTokens: 45,
        totalTokens: 155,
        outcome: 'success',
      }),
    );
    expect(global.fetch).toHaveBeenCalledWith(
      expect.any(String),
      expect.objectContaining({
        body: expect.stringContaining('"strict":true'),
      }),
    );
  });

  it('does not extract a JSON-looking substring from an invalid response', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          choices: [
            {
              message: {
                content: `Here is the result: ${JSON.stringify(fallback)}`,
              },
            },
          ],
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        data: fallback,
        outcome: 'error',
        fallbackReason: 'provider_invalid_json',
      }),
    );
  });

  it('rejects valid JSON that does not satisfy the application schema', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        JSON.stringify({
          choices: [{ message: { content: '{"strength":"only one key"}' } }],
        }),
        { status: 200 },
      ),
    );

    await expect(new LlmService().completeStructured(request)).resolves.toEqual(
      expect.objectContaining({
        outcome: 'error',
        fallbackReason: 'provider_schema_mismatch',
      }),
    );
  });

  it('never logs provider error bodies that can echo student content', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue(
      new Response(
        'student@example.test passport-123 secret-access-token',
        { status: 400 },
      ),
    );
    const service = new LlmService();
    const warn = jest.fn();
    Object.defineProperty(service, 'logger', { value: { warn } });

    await service.completeJson({
      system: 'system',
      user: 'private student content',
      fallback,
    });

    const output = JSON.stringify(warn.mock.calls);
    expect(output).toContain('Groq error 400');
    expect(output).not.toContain('student@example.test');
    expect(output).not.toContain('passport-123');
    expect(output).not.toContain('secret-access-token');
  });

  it('never logs raw provider exceptions', async () => {
    process.env.GROQ_API_KEY = 'test-key';
    global.fetch = jest
      .fn()
      .mockRejectedValue(
        new Error('student@example.test Authorization Bearer secret-token'),
      );
    const service = new LlmService();
    const warn = jest.fn();
    Object.defineProperty(service, 'logger', { value: { warn } });

    await service.completeJson({
      system: 'system',
      user: 'private student content',
      fallback,
    });

    const output = JSON.stringify(warn.mock.calls);
    expect(output).toContain('Groq call failed');
    expect(output).not.toContain('student@example.test');
    expect(output).not.toContain('secret-token');
  });
});
