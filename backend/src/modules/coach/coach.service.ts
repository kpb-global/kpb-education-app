import { Injectable, MessageEvent, NotFoundException } from '@nestjs/common';
import { Observable } from 'rxjs';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { buildCoachSystemPrompt, buildCoachSuggestions } from './coach-prompt.builder';
import { CoachQuotaService } from './coach-quota.service';

type CoachRole = 'user' | 'assistant';

type CoachMessage = { role: CoachRole; content: string; createdAt: string };

type Conversation = {
  id: string;
  userId: string;
  messages: CoachMessage[];
  createdAt: string;
};

@Injectable()
export class CoachService {
  /**
   * In-memory store. Used as the source of truth only when the database is
   * unavailable (no `DATABASE_URL`); otherwise conversations live in Postgres
   * and this map is bypassed.
   */
  private readonly conversations = new Map<string, Conversation>();

  constructor(
    private readonly llmService: LlmService,
    private readonly quotaService: CoachQuotaService,
    private readonly prisma: PrismaService,
  ) {}

  getQuota(userId: string) {
    return this.quotaService.getQuota(userId);
  }

  getSuggestions(profile: Record<string, unknown>) {
    return {
      suggestions: buildCoachSuggestions({
        fullName: profile.fullName as string | undefined,
        targetCountryIds: profile.targetCountryIds as string[] | undefined,
      }),
    };
  }

  async createConversation(userId: string, profile: Record<string, unknown>) {
    const firstName = String(profile.fullName ?? 'Étudiant').split(' ')[0];
    const greetingContent = `Salut ${firstName} ! Je suis ton Coach KPB. Pose-moi tes questions sur les études à l'étranger, le budget ou les écoles partenaires.`;

    const persisted = await this.prisma.tryExecute((client) =>
      client.coachConversation.create({
        data: {
          userId,
          messages: {
            create: { role: 'assistant', content: greetingContent },
          },
        },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      }),
    );

    if (persisted) {
      const greeting = persisted.messages[0];
      return {
        conversationId: persisted.id,
        greeting: {
          role: greeting.role as CoachRole,
          content: greeting.content,
          createdAt: greeting.createdAt.toISOString(),
        },
        ...this.quotaService.getQuota(userId),
      };
    }

    // ── In-memory fallback ──────────────────────────────────────────────────
    const id = `coach-${Date.now()}`;
    const conversation: Conversation = {
      id,
      userId,
      createdAt: new Date().toISOString(),
      messages: [
        {
          role: 'assistant',
          content: greetingContent,
          createdAt: new Date().toISOString(),
        },
      ],
    };
    this.conversations.set(id, conversation);
    return {
      conversationId: id,
      greeting: conversation.messages[0],
      ...this.quotaService.getQuota(userId),
    };
  }

  async getMessages(conversationId: string): Promise<CoachMessage[]> {
    const conversation = await this.loadConversation(conversationId);
    if (!conversation) {
      throw new NotFoundException(`Conversation ${conversationId} not found.`);
    }
    return conversation.messages;
  }

  streamReply(params: {
    conversationId: string;
    userId: string;
    message: string;
    profile: Record<string, unknown>;
  }): Observable<MessageEvent> {
    return new Observable((subscriber) => {
      void (async () => {
        const conversation = await this.loadConversation(params.conversationId);
        if (!conversation) {
          subscriber.next({
            data: {
              type: 'error',
              message: `Conversation ${params.conversationId} not found.`,
            },
          } as MessageEvent);
          subscriber.complete();
          return;
        }

        const quota = this.quotaService.consume(params.userId);
        if (!quota.allowed) {
          subscriber.next({
            data: {
              type: 'error',
              message:
                'Quota hebdomadaire atteint (5 messages). Premium bientôt disponible.',
            },
          } as MessageEvent);
          subscriber.complete();
          return;
        }

        await this.appendMessage(conversation, 'user', params.message);

        const system = buildCoachSystemPrompt({
          fullName: params.profile.fullName as string | undefined,
          currentLevel: params.profile.currentLevel as string | undefined,
          targetCountryIds: params.profile.targetCountryIds as string[] | undefined,
          monthlyBudgetEur: params.profile.monthlyBudgetEur as number | undefined,
        });

        const history = conversation.messages.slice(-8).map((item) => ({
          role: item.role,
          content: item.content,
        }));

        let full = '';
        try {
          for await (const chunk of this.llmService.streamText({
            system,
            messages: history,
          })) {
            full += chunk;
            subscriber.next({ data: { type: 'token', text: chunk } } as MessageEvent);
          }
          await this.appendMessage(conversation, 'assistant', full.trim());
          subscriber.next({
            data: {
              type: 'done',
              quotaRemaining: quota.remaining,
            },
          } as MessageEvent);
          subscriber.complete();
        } catch (error) {
          subscriber.next({
            data: { type: 'error', message: String(error) },
          } as MessageEvent);
          subscriber.complete();
        }
      })();
    });
  }

  // ── Storage helpers ─────────────────────────────────────────────────────────

  private async loadConversation(id: string): Promise<Conversation | null> {
    const persisted = await this.prisma.tryExecute((client) =>
      client.coachConversation.findUnique({
        where: { id },
        include: { messages: { orderBy: { createdAt: 'asc' } } },
      }),
    );

    if (persisted) {
      return {
        id: persisted.id,
        userId: persisted.userId,
        createdAt: persisted.createdAt.toISOString(),
        messages: persisted.messages.map((m) => ({
          role: m.role as CoachRole,
          content: m.content,
          createdAt: m.createdAt.toISOString(),
        })),
      };
    }

    return this.conversations.get(id) ?? null;
  }

  private async appendMessage(
    conversation: Conversation,
    role: CoachRole,
    content: string,
  ): Promise<void> {
    const message: CoachMessage = {
      role,
      content,
      createdAt: new Date().toISOString(),
    };

    // Keep the in-memory snapshot in sync so `history` reflects this turn even
    // when persistence is enabled (we already hold the hydrated conversation).
    conversation.messages.push(message);

    const persisted = await this.prisma.tryExecute((client) =>
      client.coachMessage.create({
        data: { conversationId: conversation.id, role, content },
      }),
    );

    if (persisted) {
      await this.prisma.tryExecute((client) =>
        client.coachConversation.update({
          where: { id: conversation.id },
          data: { updatedAt: new Date() },
        }),
      );
    } else if (!this.conversations.has(conversation.id)) {
      // DB disabled and this conversation isn't tracked yet — register it.
      this.conversations.set(conversation.id, conversation);
    }
  }
}
