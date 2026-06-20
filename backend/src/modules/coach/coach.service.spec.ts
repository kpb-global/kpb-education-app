import { NotFoundException } from '@nestjs/common';

import { LlmService } from '../ai/llm.service';
import { PrismaService } from '../prisma/prisma.service';
import { CoachQuotaService } from './coach-quota.service';
import { CoachService } from './coach.service';

/**
 * Guards the IDOR fix: a coach conversation must only be readable by its owner.
 * Prisma is stubbed to null so the service uses its in-memory conversation path.
 */
describe('CoachService — conversation ownership', () => {
  function makeService(): CoachService {
    const llm = {} as unknown as LlmService;
    const quota = {
      getQuota: () => ({ remaining: 5, limit: 5, allowed: true }),
    } as unknown as CoachQuotaService;
    const prisma = {
      tryExecute: async () => null,
    } as unknown as PrismaService;
    return new CoachService(llm, quota, prisma);
  }

  it('returns messages for the conversation owner', async () => {
    const service = makeService();
    const created = await service.createConversation('user-a', {
      fullName: 'Aïcha',
    });
    const messages = await service.getMessages(created.conversationId, 'user-a');
    expect(messages.length).toBeGreaterThan(0);
  });

  it("rejects another user's conversation as not found", async () => {
    const service = makeService();
    const created = await service.createConversation('user-a', {
      fullName: 'Aïcha',
    });
    await expect(
      service.getMessages(created.conversationId, 'user-b'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
