import { Injectable, Logger } from '@nestjs/common';

export type LlmMessage = { role: 'user' | 'assistant' | 'system'; content: string };

type GroqChatResponse = {
  choices?: Array<{
    message?: { content?: string };
    delta?: { content?: string };
  }>;
};

const GROQ_CHAT_URL = 'https://api.groq.com/openai/v1/chat/completions';
const DEFAULT_GROQ_MODEL = 'llama-3.3-70b-versatile';

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

  async completeJson<T>(params: {
    system: string;
    user: string;
    maxTokens?: number;
    fallback: T;
  }): Promise<{ data: T; model: string }> {
    if (!this.apiKey) {
      return { data: params.fallback, model: 'local-fallback' };
    }

    try {
      const response = await fetch(GROQ_CHAT_URL, {
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: `Bearer ${this.apiKey}`,
        },
        body: JSON.stringify({
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
        }),
      });

      if (!response.ok) {
        const body = await response.text();
        this.logger.warn(`Groq error ${response.status}: ${body.slice(0, 200)}`);
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
      this.logger.warn(`Groq call failed: ${String(error)}`);
      return { data: params.fallback, model: 'local-fallback' };
    }
  }

  async *streamText(params: {
    system: string;
    messages: LlmMessage[];
    maxTokens?: number;
  }): AsyncGenerator<string> {
    if (!this.apiKey) {
      const fallback =
        'Je suis le Coach KPB. Configure GROQ_API_KEY pour des réponses personnalisées. En attendant, explore les 9 destinations KPB et demande un accompagnement depuis l’app.';
      for (const word of fallback.split(' ')) {
        yield `${word} `;
      }
      return;
    }

    const conversationMessages = params.messages.filter((item) => item.role !== 'system');
    const response = await fetch(GROQ_CHAT_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${this.apiKey}`,
      },
      body: JSON.stringify({
        model: this.model,
        max_tokens: params.maxTokens ?? 600,
        temperature: 0.6,
        stream: true,
        messages: [
          { role: 'system', content: params.system },
          ...conversationMessages,
        ],
      }),
    });

    if (!response.ok || !response.body) {
      const body = response.ok ? '' : await response.text();
      this.logger.warn(
        `Groq stream error ${response.status}: ${body.slice(0, 200)}`,
      );
      yield 'Désolé, le coach IA est momentanément indisponible.';
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
}
