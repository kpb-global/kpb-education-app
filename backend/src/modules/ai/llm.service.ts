import { Injectable, Logger } from '@nestjs/common';

export type LlmMessage = {
  role: 'user' | 'assistant' | 'system';
  content: string;
};
type Lang = 'fr' | 'en';

export type LlmProviderName = 'openrouter' | 'groq';

type ProviderConfig = {
  name: LlmProviderName;
  chatUrl: string;
  apiKey: string;
  model: string;
};

type ProviderChatResponse = {
  id?: string;
  choices?: Array<{
    message?: { content?: string; refusal?: string | null };
    delta?: { content?: string };
  }>;
  usage?: {
    prompt_tokens?: number;
    completion_tokens?: number;
    total_tokens?: number;
    prompt_tokens_details?: { cached_tokens?: number };
  };
};

export type JsonSchema = Readonly<Record<string, unknown>>;

export type StructuredCompletionRequest<T> = {
  feature: 'success_lab_diagnostic';
  attemptKey: string;
  system: string;
  user: string;
  responseSchema: JsonSchema;
  validate: (value: unknown) => value is T;
  fallback: T;
  temperature: number;
  maxTokens: number;
  promptVersion: string;
  model: string;
};

export type StructuredCompletionResult<T> = {
  data: T;
  provider: LlmProviderName | 'local';
  model: string;
  providerRequestId?: string;
  inputTokens?: number;
  cachedInputTokens?: number;
  outputTokens?: number;
  totalTokens?: number;
  latencyMs: number;
  outcome: 'success' | 'fallback' | 'refused' | 'error';
  fallbackReason?: string;
};

const OPENROUTER_CHAT_URL = 'https://openrouter.ai/api/v1/chat/completions';
const GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_OPENROUTER_MODEL = 'deepseek/deepseek-v4-flash';
const DEFAULT_GROQ_MODEL = 'llama-3.3-70b-versatile';
const DEFAULT_TIMEOUT_MS = 18000;

@Injectable()
export class LlmService {
  private readonly logger = new Logger(LlmService.name);

  get isConfigured(): boolean {
    return Boolean(this.provider);
  }

  /** Ledger/analytics label of the active provider ('openrouter' when unset). */
  get providerName(): LlmProviderName {
    return this.provider?.name ?? 'openrouter';
  }

  /**
   * Active provider, resolved from the environment on every call so ops can
   * rotate keys without a restart. LLM_* (OpenRouter by default) wins; the
   * legacy GROQ_* variables keep working until ops finishes the migration.
   */
  private get provider(): ProviderConfig | undefined {
    const llmKey = process.env.LLM_API_KEY?.trim();
    if (llmKey) {
      const name: LlmProviderName =
        process.env.LLM_PROVIDER?.trim().toLowerCase() === 'groq'
          ? 'groq'
          : 'openrouter';
      return {
        name,
        chatUrl:
          process.env.LLM_CHAT_COMPLETIONS_URL?.trim() ||
          (name === 'groq' ? GROQ_CHAT_URL : OPENROUTER_CHAT_URL),
        apiKey: llmKey,
        model:
          process.env.LLM_MODEL?.trim() ||
          (name === 'groq' ? DEFAULT_GROQ_MODEL : DEFAULT_OPENROUTER_MODEL),
      };
    }
    const groqKey = process.env.GROQ_API_KEY?.trim();
    if (groqKey) {
      return {
        name: 'groq',
        chatUrl: GROQ_CHAT_URL,
        apiKey: groqKey,
        model: process.env.GROQ_MODEL?.trim() || DEFAULT_GROQ_MODEL,
      };
    }
    return undefined;
  }

  /**
   * OpenRouter fans requests out to third-party clouds; student prompts must
   * never be retained there (IA-T2 posture, same promise as the consent copy).
   * `data_collection: 'deny'` pins routing to no-retention providers and
   * `require_parameters` keeps requests off providers that would silently drop
   * `response_format`. The key collision is intentional: OpenRouter's routing
   * field is literally named `provider`.
   */
  private routingPolicy(name: LlmProviderName): Record<string, unknown> {
    return name === 'openrouter'
      ? { provider: { data_collection: 'deny', require_parameters: true } }
      : {};
  }

  /// Per-request upper bound so a stalled provider connection can never hang
  /// the SSE response (or a JSON call) indefinitely. Configurable via env.
  private get timeoutMs(): number {
    const raw = Number(
      process.env.LLM_TIMEOUT_MS ?? process.env.GROQ_TIMEOUT_MS,
    );
    return Number.isFinite(raw) && raw > 0 ? raw : DEFAULT_TIMEOUT_MS;
  }

  /// `fetch` with an AbortController-backed timeout. Throws on timeout so the
  /// caller's retry/fallback path engages.
  private async fetchWithTimeout(
    url: string,
    init: RequestInit,
  ): Promise<Response> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), this.timeoutMs);
    try {
      return await fetch(url, { ...init, signal: controller.signal });
    } finally {
      clearTimeout(timer);
    }
  }

  async completeJson<T>(params: {
    system: string;
    user: string;
    maxTokens?: number;
    fallback: T;
  }): Promise<{ data: T; model: string }> {
    const config = this.provider;
    if (!config) {
      return { data: params.fallback, model: 'local-fallback' };
    }

    const body = JSON.stringify({
      model: config.model,
      max_tokens: params.maxTokens ?? 1200,
      temperature: 0.4,
      response_format: { type: 'json_object' },
      ...this.routingPolicy(config.name),
      messages: [
        {
          role: 'system',
          content: `${params.system}\nRéponds uniquement avec un objet JSON valide.`,
        },
        { role: 'user', content: params.user },
      ],
    });

    // One transient retry (timeout / network / 5xx) before degrading to the
    // local fallback, so a single blip doesn't drop the feature.
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        const response = await this.fetchWithTimeout(config.chatUrl, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${config.apiKey}`,
          },
          body,
        });

        if (!response.ok) {
          // Drain the provider response but never log it: error bodies can
          // echo prompts, document excerpts or provider diagnostics.
          await response.text();
          this.logger.warn(
            `${config.name} error ${response.status} (attempt ${attempt + 1}).`,
          );
          if (response.status >= 500 && attempt === 0) continue;
          return { data: params.fallback, model: 'local-fallback' };
        }

        const payload = (await response.json()) as ProviderChatResponse;
        const text = payload.choices?.[0]?.message?.content ?? '';
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
          return { data: params.fallback, model: 'local-fallback' };
        }
        return { data: JSON.parse(jsonMatch[0]) as T, model: config.model };
      } catch {
        this.logger.warn(
          `${config.name} call failed (attempt ${attempt + 1}).`,
        );
        if (attempt === 0) continue;
        return { data: params.fallback, model: 'local-fallback' };
      }
    }
    return { data: params.fallback, model: 'local-fallback' };
  }

  /**
   * Executes exactly one provider attempt and returns a fully validated value.
   * Retry policy belongs to the feature service so every paid attempt can be
   * recorded independently in the usage ledger.
   */
  async completeStructured<T>(
    params: StructuredCompletionRequest<T>,
  ): Promise<StructuredCompletionResult<T>> {
    const startedAt = Date.now();
    const model = params.model.trim();
    const config = this.provider;
    if (!config || !model) {
      return this.structuredFallback(
        params.fallback,
        startedAt,
        'provider_unconfigured',
      );
    }

    // OpenRouter routing already excludes providers that cannot honor a strict
    // schema; on Groq only the gpt-oss models accept strict mode.
    const strict =
      config.name === 'openrouter' ||
      /^openai\/gpt-oss-(?:20b|120b)$/.test(model);
    const body = JSON.stringify({
      model,
      max_tokens: params.maxTokens,
      temperature: params.temperature,
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'success_lab_diagnostic',
          strict,
          schema: params.responseSchema,
        },
      },
      ...this.routingPolicy(config.name),
      messages: [
        {
          role: 'system',
          content: `${params.system}\nReturn only the JSON object required by the schema.`,
        },
        { role: 'user', content: params.user },
      ],
    });

    try {
      const response = await this.fetchWithTimeout(config.chatUrl, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${config.apiKey}`,
          'x-client-request-id': params.attemptKey,
        },
        body,
      });
      const latencyMs = Date.now() - startedAt;
      if (!response.ok) {
        this.logger.warn(
          `${config.name} structured request failed (${response.status}, feature=${params.feature}, prompt=${params.promptVersion}).`,
        );
        return {
          data: params.fallback,
          provider: config.name,
          model,
          latencyMs,
          outcome: 'error',
          fallbackReason:
            response.status === 429
              ? 'provider_rate_limited'
              : response.status >= 500
                ? 'provider_unavailable'
                : 'provider_rejected_request',
        };
      }

      const payload = (await response.json()) as ProviderChatResponse;
      const usage = payload.usage;
      const refusal = payload.choices?.[0]?.message?.refusal;
      if (refusal) {
        return {
          data: params.fallback,
          provider: config.name,
          model,
          providerRequestId: payload.id,
          inputTokens: usage?.prompt_tokens,
          cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens,
          outputTokens: usage?.completion_tokens,
          totalTokens: usage?.total_tokens,
          latencyMs,
          outcome: 'refused',
          fallbackReason: 'provider_refusal',
        };
      }

      const raw = payload.choices?.[0]?.message?.content?.trim();
      if (!raw) {
        return this.invalidStructuredResponse(
          params,
          config.name,
          payload,
          latencyMs,
          'provider_empty_response',
        );
      }
      let parsed: unknown;
      try {
        parsed = JSON.parse(raw);
      } catch {
        return this.invalidStructuredResponse(
          params,
          config.name,
          payload,
          latencyMs,
          'provider_invalid_json',
        );
      }
      if (!params.validate(parsed)) {
        return this.invalidStructuredResponse(
          params,
          config.name,
          payload,
          latencyMs,
          'provider_schema_mismatch',
        );
      }

      return {
        data: parsed,
        provider: config.name,
        model,
        providerRequestId: payload.id,
        inputTokens: usage?.prompt_tokens,
        cachedInputTokens: usage?.prompt_tokens_details?.cached_tokens,
        outputTokens: usage?.completion_tokens,
        totalTokens: usage?.total_tokens,
        latencyMs,
        outcome: 'success',
      };
    } catch (error) {
      const timedOut = error instanceof Error && error.name === 'AbortError';
      this.logger.warn(
        `${config.name} structured request failed (feature=${params.feature}, prompt=${params.promptVersion}, error=${timedOut ? 'timeout' : 'network'}).`,
      );
      return {
        data: params.fallback,
        provider: config.name,
        model,
        latencyMs: Date.now() - startedAt,
        outcome: 'error',
        fallbackReason:
          timedOut
            ? 'provider_timeout'
            : 'provider_network_error',
      };
    }
  }

  private structuredFallback<T>(
    fallback: T,
    startedAt: number,
    reason: string,
  ): StructuredCompletionResult<T> {
    return {
      data: fallback,
      provider: 'local',
      model: 'local-fallback',
      latencyMs: Date.now() - startedAt,
      outcome: 'fallback',
      fallbackReason: reason,
    };
  }

  private invalidStructuredResponse<T>(
    params: StructuredCompletionRequest<T>,
    provider: LlmProviderName,
    payload: ProviderChatResponse,
    latencyMs: number,
    reason: string,
  ): StructuredCompletionResult<T> {
    return {
      data: params.fallback,
      provider,
      model: params.model,
      providerRequestId: payload.id,
      inputTokens: payload.usage?.prompt_tokens,
      cachedInputTokens: payload.usage?.prompt_tokens_details?.cached_tokens,
      outputTokens: payload.usage?.completion_tokens,
      totalTokens: payload.usage?.total_tokens,
      latencyMs,
      outcome: 'error',
      fallbackReason: reason,
    };
  }

  async *streamText(params: {
    system: string;
    messages: LlmMessage[];
    maxTokens?: number;
    lang?: Lang;
  }): AsyncGenerator<string> {
    const lang: Lang = params.lang === 'en' ? 'en' : 'fr';

    const config = this.provider;
    if (!config) {
      yield* this.fallbackWords(this.noKeyFallback(lang));
      return;
    }

    const conversationMessages = params.messages.filter(
      (item) => item.role !== 'system',
    );
    const body = JSON.stringify({
      model: config.model,
      max_tokens: params.maxTokens ?? 600,
      temperature: 0.6,
      stream: true,
      ...this.routingPolicy(config.name),
      messages: [
        { role: 'system', content: params.system },
        ...conversationMessages,
      ],
    });

    // One transient retry on the initial connection before yielding the
    // localized "temporarily unavailable" fallback (graceful degradation).
    let response: Response | null = null;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        response = await this.fetchWithTimeout(config.chatUrl, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${config.apiKey}`,
          },
          body,
        });
        if (response.ok && response.body) break;
        if (!response.ok) await response.text();
        this.logger.warn(
          `${config.name} stream error ${response.status} (attempt ${attempt + 1}).`,
        );
        if (response.status >= 500 && attempt === 0) {
          response = null;
          continue;
        }
        response = null;
        break;
      } catch {
        this.logger.warn(
          `${config.name} stream failed (attempt ${attempt + 1}).`,
        );
        response = null;
        if (attempt === 0) continue;
      }
    }

    if (!response || !response.ok || !response.body) {
      yield this.unavailableFallback(lang);
      return;
    }

    const reader = response.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const lines = buffer.split('\n');
      buffer = lines.pop() ?? '';

      for (const line of lines) {
        const trimmed = line.trim();
        if (!trimmed.startsWith('data:')) continue;
        const payload = trimmed.slice(5).trim();
        if (!payload || payload === '[DONE]') continue;
        try {
          const event = JSON.parse(payload) as ProviderChatResponse;
          const chunk = event.choices?.[0]?.delta?.content;
          if (chunk) {
            yield chunk;
          }
        } catch {
          // Ignore malformed SSE chunks.
        }
      }
    }
  }

  // ── Localized fallbacks ─────────────────────────────────────────────────────

  private noKeyFallback(lang: Lang): string {
    return lang === 'en'
      ? 'I am the KPB Coach. The AI service is not configured yet. In the meantime, explore the 9 KPB destinations and request guidance from the app.'
      : 'Je suis le Coach KPB. Le service IA n’est pas encore configuré. En attendant, explore les 9 destinations KPB et demande un accompagnement depuis l’app.';
  }

  private unavailableFallback(lang: Lang): string {
    return lang === 'en'
      ? 'Sorry, the AI coach is temporarily unavailable. Please try again shortly or contact a KPB advisor.'
      : 'Désolé, le coach IA est momentanément indisponible. Réessaie dans un instant ou contacte un conseiller KPB.';
  }

  private *fallbackWords(text: string): Generator<string> {
    for (const word of text.split(' ')) {
      yield `${word} `;
    }
  }
}
