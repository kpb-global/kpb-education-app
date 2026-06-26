import { Injectable, MessageEvent, NotFoundException } from '@nestjs/common';
import { Observable } from 'rxjs';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import {
  buildCoachSystemPrompt,
  buildCoachSuggestions,
  resolveCoachLanguage,
  type CoachLanguage,
} from './coach-prompt.builder';
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
        language: resolveCoachLanguage(profile.preferredLanguage as string),
      }),
    };
  }

  async createConversation(userId: string, profile: Record<string, unknown>) {
    const lang = resolveCoachLanguage(profile.preferredLanguage as string);
    const firstName = String(
      profile.fullName ?? (lang === 'en' ? 'Student' : 'Étudiant'),
    ).split(' ')[0];
    const greetingContent =
      lang === 'en'
        ? `Hi ${firstName}! I'm your KPB Coach. Ask me anything about studying abroad, your budget, or partner schools.`
        : `Salut ${firstName} ! Je suis ton Coach KPB. Pose-moi tes questions sur les études à l'étranger, le budget ou les écoles partenaires.`;

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

  async getMessages(
    conversationId: string,
    userId: string,
  ): Promise<CoachMessage[]> {
    const conversation = await this.loadConversation(conversationId);
    // Treat "not yours" the same as "not found" so we don't leak existence.
    if (!conversation || conversation.userId !== userId) {
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
        // Ownership check: reject streaming into someone else's conversation
        // (same "not found" message so existence isn't leaked).
        if (!conversation || conversation.userId !== params.userId) {
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

        const lang = resolveCoachLanguage(
          params.profile.preferredLanguage as string,
        );

        // RAG: ground the reply in verified catalog facts for this question.
        const verifiedContext = await this.retrieveContext(
          params.message,
          (params.profile.targetCountryIds as string[] | undefined) ?? [],
          lang,
        );

        const system = buildCoachSystemPrompt({
          fullName: params.profile.fullName as string | undefined,
          currentLevel: params.profile.currentLevel as string | undefined,
          targetCountryIds: params.profile.targetCountryIds as string[] | undefined,
          monthlyBudgetEur: params.profile.monthlyBudgetEur as number | undefined,
          verifiedContext,
          language: lang,
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
    lang: CoachLanguage = 'fr',
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

    const en = lang === 'en';
    const na = en ? 'n/a' : 'n/d';
    const lines: string[] = [];
    if (relCountries.length) {
      lines.push(en ? 'COUNTRIES:' : 'PAYS:');
      for (const c of relCountries) {
        const date = c.lastVerifiedAt
          ? c.lastVerifiedAt.toISOString().slice(0, 10)
          : null;
        const verified = en
          ? date
            ? `verified ${date}`
            : 'to confirm'
          : date
            ? `vérifié ${date}`
            : 'à confirmer';
        const src = en ? 'KPB catalogue' : 'catalogue KPB';
        lines.push(
          en
            ? `- ${c.nameEn}: tuition ${c.tuitionRangeEn || na}; living cost ${c.livingCostRangeEn || na}; visa ${c.visaOverviewEn || na}; admission ${c.admissionDifficultyEn || na} [source: ${src}, ${verified}]`
            : `- ${c.nameFr}: frais ${c.tuitionRangeFr || na}; coût de vie ${c.livingCostRangeFr || na}; visa ${c.visaOverviewFr || na}; admission ${c.admissionDifficultyFr || na} [source: ${src}, ${verified}]`,
        );
      }
    }
    if (relScholarships.length) {
      lines.push(en ? 'SCHOLARSHIPS:' : 'BOURSES:');
      for (const s of relScholarships) {
        const elig = en
          ? (s.eligibilityEn ?? []).slice(0, 2).join(' / ')
          : (s.eligibilityFr ?? []).slice(0, 2).join(' / ');
        const fallbackSrc = en ? 'KPB catalogue' : 'catalogue KPB';
        lines.push(
          en
            ? `- ${s.nameEn} (${s.countryNameEn || s.countryId}): funding ${s.typeOfFundingEn || na}; deadline ${s.deadlineLabelEn || na}; eligibility ${elig || 'see details'} [source: ${s.sourceUrl || fallbackSrc}]`
            : `- ${s.nameFr} (${s.countryNameFr || s.countryId}): financement ${s.typeOfFundingFr || na}; date limite ${s.deadlineLabelFr || na}; éligibilité ${elig || 'voir détail'} [source: ${s.sourceUrl || fallbackSrc}]`,
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
