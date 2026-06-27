import { Injectable, Logger } from '@nestjs/common';

export type LlmMessage = { role: 'user' | 'assistant' | 'system'; content: string };
type Lang = 'fr' | 'en';

type GroqChatResponse = {
  choices?: Array<{
    message?: { content?: string };
    delta?: { content?: string };
  }>;
};

const GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_GROQ_MODEL = 'llama-3.3-70b-versatile';
const DEFAULT_TIMEOUT_MS = 18000;

@Injectable()
export class LlmService {
  private readonly logger = new Logger(LlmService.name);

  get isConfigured(): boolean {
    return Boolean(this.apiKey);
  }

  private get apiKey(): string | undefined {
    return process.env.GROQ_API_KEY?.trim();
  }

  private get model(): string {
    return process.env.GROQ_MODEL?.trim() || DEFAULT_GROQ_MODEL;
  }

  /// Per-request upper bound so a stalled Groq connection can never hang the
  /// SSE response (or a JSON call) indefinitely. Configurable via env.
  private get timeoutMs(): number {
    const raw = Number(process.env.GROQ_TIMEOUT_MS);
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
    if (!this.apiKey) {
      return { data: params.fallback, model: 'local-fallback' };
    }

    const body = JSON.stringify({
      model: this.model,
      max_tokens: params.maxTokens ?? 1200,
      temperature: 0.4,
      response_format: { type: 'json_object' },
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
        const response = await this.fetchWithTimeout(GROQ_CHAT_URL, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${this.apiKey}`,
          },
          body,
        });

        if (!response.ok) {
          const errBody = await response.text();
          this.logger.warn(
            `Groq error ${response.status} (attempt ${attempt + 1}): ${errBody.slice(0, 200)}`,
          );
          if (response.status >= 500 && attempt === 0) continue;
          return { data: params.fallback, model: 'local-fallback' };
        }

        const payload = (await response.json()) as GroqChatResponse;
        const text = payload.choices?.[0]?.message?.content ?? '';
        const jsonMatch = text.match(/\{[\s\S]*\}/);
        if (!jsonMatch) {
          return { data: params.fallback, model: 'local-fallback' };
        }
        return { data: JSON.parse(jsonMatch[0]) as T, model: this.model };
      } catch (error) {
        this.logger.warn(
          `Groq call failed (attempt ${attempt + 1}): ${String(error)}`,
        );
        if (attempt === 0) continue;
        return { data: params.fallback, model: 'local-fallback' };
      }
    }
    return { data: params.fallback, model: 'local-fallback' };
  }

  async *streamText(params: {
    system: string;
    messages: LlmMessage[];
    maxTokens?: number;
    lang?: Lang;
  }): AsyncGenerator<string> {
    const lang: Lang = params.lang === 'en' ? 'en' : 'fr';

    if (!this.apiKey) {
      yield* this.fallbackWords(this.noKeyFallback(lang));
      return;
    }

    const conversationMessages = params.messages.filter(
      (item) => item.role !== 'system',
    );
    const body = JSON.stringify({
      model: this.model,
      max_tokens: params.maxTokens ?? 600,
      temperature: 0.6,
      stream: true,
      messages: [{ role: 'system', content: params.system }, ...conversationMessages],
    });

    // One transient retry on the initial connection before yielding the
    // localized "temporarily unavailable" fallback (graceful degradation).
    let response: Response | null = null;
    for (let attempt = 0; attempt < 2; attempt++) {
      try {
        response = await this.fetchWithTimeout(GROQ_CHAT_URL, {
          method: 'POST',
          headers: {
            'content-type': 'application/json',
            authorization: `Bearer ${this.apiKey}`,
          },
          body,
        });
        if (response.ok && response.body) break;
        const errBody = response.ok ? '' : await response.text();
        this.logger.warn(
          `Groq stream error ${response.status} (attempt ${attempt + 1}): ${errBody.slice(0, 200)}`,
        );
        if (response.status >= 500 && attempt === 0) {
          response = null;
          continue;
        }
        response = null;
        break;
      } catch (error) {
        this.logger.warn(
          `Groq stream failed (attempt ${attempt + 1}): ${String(error)}`,
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
          const event = JSON.parse(payload) as GroqChatResponse;
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
