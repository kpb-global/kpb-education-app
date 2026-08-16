import {
  ExecutionContext,
  ForbiddenException,
  UnauthorizedException,
} from '@nestjs/common';

import { LlmService } from './llm.service';
import { AiConsentGuard } from './ai-consent.guard';
import { AiConsentService } from './ai-consent.service';
import { PrismaService } from '../prisma/prisma.service';
import { CvSummaryDto, ToolsService } from '../tools/tools.service';

/**
 * IA-T1: the assertion that matters is that Groq (`completeJson`) is never
 * reached when consent is missing — not merely that HTTP is 403. The guard
 * plus the service are composed the same way the request pipeline would:
 * canActivate first, then ToolsService.
 */
describe('AiConsentGuard + ToolsService (completeJson never called)', () => {
  const dto: CvSummaryDto = {
    name: 'Awa Traoré',
    studyLevel: 'Bachelor 3',
    fieldOfStudy: 'Informatique',
  };

  function mockContext(userId?: string): ExecutionContext {
    return {
      switchToHttp: () => ({
        getRequest: () => ({
          studentUser: userId ? { id: userId } : undefined,
        }),
      }),
    } as unknown as ExecutionContext;
  }

  function setup(profile: unknown) {
    const completeJson = jest.fn(async () => ({
      data: { fr: 'Résumé FR', en: 'Summary EN' },
    }));
    const llm = { isConfigured: true, completeJson } as unknown as LlmService;
    const tools = new ToolsService(llm);
    const prisma = {
      tryExecute: async () => profile,
    } as unknown as PrismaService;
    const consent = new AiConsentService(prisma);
    const guard = new AiConsentGuard(consent);
    return { completeJson, tools, guard };
  }

  async function invokeCvSummary(
    guard: AiConsentGuard,
    tools: ToolsService,
    userId?: string,
  ) {
    await guard.canActivate(mockContext(userId));
    return tools.generateCvSummary(dto);
  }

  it('does not call completeJson when AI consent is missing', async () => {
    const { completeJson, tools, guard } = setup({
      aiConsentedAt: null,
      birthDate: null,
      guardianConsentedAt: null,
    });

    await expect(invokeCvSummary(guard, tools, 'user-a')).rejects.toBeInstanceOf(
      ForbiddenException,
    );
    expect(completeJson).not.toHaveBeenCalled();
  });

  it('does not call completeJson for a minor without guardian consent', async () => {
    const birth = new Date();
    birth.setFullYear(birth.getFullYear() - 15);
    const { completeJson, tools, guard } = setup({
      aiConsentedAt: new Date(),
      birthDate: birth,
      guardianConsentedAt: null,
    });

    try {
      await invokeCvSummary(guard, tools, 'user-a');
      fail('expected ForbiddenException');
    } catch (error) {
      expect(error).toBeInstanceOf(ForbiddenException);
      expect((error as ForbiddenException).getResponse()).toMatchObject({
        code: 'guardian_consent_required',
      });
    }
    expect(completeJson).not.toHaveBeenCalled();
  });

  it('fail-open: tryExecute → null lets completeJson run', async () => {
    const { completeJson, tools, guard } = setup(null);

    await expect(invokeCvSummary(guard, tools, 'user-a')).resolves.toEqual({
      fr: 'Résumé FR',
      en: 'Summary EN',
    });
    expect(completeJson).toHaveBeenCalledTimes(1);
  });

  it('calls completeJson when consent is recorded', async () => {
    const { completeJson, tools, guard } = setup({
      aiConsentedAt: new Date(),
      birthDate: null,
      guardianConsentedAt: null,
    });

    await expect(invokeCvSummary(guard, tools, 'user-a')).resolves.toEqual({
      fr: 'Résumé FR',
      en: 'Summary EN',
    });
    expect(completeJson).toHaveBeenCalledTimes(1);
  });

  it('rejects an unauthenticated request before any LLM call', async () => {
    const { completeJson, tools, guard } = setup(null);
    await expect(invokeCvSummary(guard, tools, undefined)).rejects.toBeInstanceOf(
      UnauthorizedException,
    );
    expect(completeJson).not.toHaveBeenCalled();
  });
});
