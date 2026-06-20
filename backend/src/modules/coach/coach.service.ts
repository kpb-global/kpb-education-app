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

        // RAG: ground the reply in verified catalog facts for this question.
        const verifiedContext = await this.retrieveContext(
          params.message,
          (params.profile.targetCountryIds as string[] | undefined) ?? [],
        );

        const system = buildCoachSystemPrompt({
          fullName: params.profile.fullName as string | undefined,
          currentLevel: params.profile.currentLevel as string | undefined,
          targetCountryIds: params.profile.targetCountryIds as string[] | undefined,
          monthlyBudgetEur: params.profile.monthlyBudgetEur as number | undefined,
          verifiedContext,
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

  // ── RAG retrieval ───────────────────────────────────────────────────────────

  /// Pull the verified catalog facts most relevant to the question (the user's
  /// target countries + any country/scholarship named in the message), as a
  /// compact, citable context block. Returns '' when the DB is unavailable — the
  /// prompt then tells the model it has no verified data (so it won't invent).
  private async retrieveContext(
    message: string,
    targetCountryIds: string[],
  ): Promise<string> {
    const q = ' ' + message.toLowerCase() + ' ';
    const targets = new Set(targetCountryIds.map((c) => c.toLowerCase()));

    const [countries, scholarships] = await Promise.all([
      this.prisma.tryExecute((p) =>
        p.country.findMany({ where: { isActive: true }, take: 30 }),
      ),
      this.prisma.tryExecute((p) =>
        p.scholarship.findMany({
          where: { isActive: true, moderationStatus: 'approved' },
          orderBy: { nameFr: 'asc' },
          take: 60,
        }),
      ),
    ]);
    if (!countries && !scholarships) return '';

    const relCountries = (countries ?? [])
      .filter(
        (c) =>
          targets.has(c.id.toLowerCase()) ||
          targets.has(c.code.toLowerCase()) ||
          (!!c.nameFr && q.includes(c.nameFr.toLowerCase())) ||
          (!!c.nameEn && q.includes(c.nameEn.toLowerCase())),
      )
      .slice(0, 4);
    const relCountryIds = new Set(relCountries.map((c) => c.id));

    const relScholarships = (scholarships ?? [])
      .filter(
        (s) =>
          relCountryIds.has(s.countryId) ||
          (!!s.nameFr && q.includes(s.nameFr.toLowerCase())) ||
          (!!s.nameEn && q.includes(s.nameEn.toLowerCase())),
      )
      .slice(0, 6);

    const lines: string[] = [];
    if (relCountries.length) {
      lines.push('PAYS:');
      for (const c of relCountries) {
        const verified = c.lastVerifiedAt
          ? `vérifié ${c.lastVerifiedAt.toISOString().slice(0, 10)}`
          : 'à confirmer';
        lines.push(
          `- ${c.nameFr}: frais ${c.tuitionRangeFr || 'n/d'}; coût de vie ${c.livingCostRangeFr || 'n/d'}; visa ${c.visaOverviewFr || 'n/d'}; admission ${c.admissionDifficultyFr || 'n/d'} [source: catalogue KPB, ${verified}]`,
        );
      }
    }
    if (relScholarships.length) {
      lines.push('BOURSES:');
      for (const s of relScholarships) {
        const elig = (s.eligibilityFr ?? []).slice(0, 2).join(' / ');
        lines.push(
          `- ${s.nameFr} (${s.countryNameFr || s.countryId}): financement ${s.typeOfFundingFr || 'n/d'}; date limite ${s.deadlineLabelFr || 'n/d'}; éligibilité ${elig || 'voir détail'} [source: ${s.sourceUrl || 'catalogue KPB'}]`,
        );
      }
    }
    return lines.join('\n');
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
