import { BadRequestException, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { InternalRole } from '../../../common/enums/internal-role.enum';
import { PrismaService } from '../../prisma/prisma.service';
import {
  CompetitionReadinessHttpException,
  databaseUnavailable,
} from '../common/competition-readiness.errors';
import {
  ADMIN_REVIEW_CAPABILITIES,
  AdminReviewAccessService,
  type AdminReviewActor,
} from './admin-review-access.service';
import type { AiUsageQueryDto } from './dto/ai-usage-query.dto';

const FEATURE = 'success_lab_diagnostic';
const DEFAULT_WINDOW_DAYS = 30;
const MAX_WINDOW_DAYS = 366;

type Cursor = { createdAt: string; id: string };

@Injectable()
export class AdminAiUsageService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly access: AdminReviewAccessService,
  ) {}

  async getUsage(actor: AdminReviewActor, query: AiUsageQueryDto) {
    if (
      actor.role !== InternalRole.Admin &&
      actor.role !== InternalRole.SuperAdmin
    ) {
      throw new CompetitionReadinessHttpException(
        'FORBIDDEN_SCOPE',
        403,
        'AI operations access is not available.',
      );
    }
    if (!this.prismaService.isEnabled) throw databaseUnavailable();
    await this.access.assertCapability(
      actor,
      ADMIN_REVIEW_CAPABILITIES.viewAiOperations,
    );

    const to = query.to ? new Date(query.to) : new Date();
    const from = query.from
      ? new Date(query.from)
      : new Date(to.getTime() - DEFAULT_WINDOW_DAYS * 24 * 60 * 60 * 1000);
    if (
      from >= to ||
      to.getTime() - from.getTime() > MAX_WINDOW_DAYS * 24 * 60 * 60 * 1000
    ) {
      throw new BadRequestException(
        `AI usage range must be positive and at most ${MAX_WINDOW_DAYS} days.`,
      );
    }
    const cursor = query.cursor ? this.decodeCursor(query.cursor) : null;
    const outcomes = this.databaseOutcomes(query.outcome);
    const baseWhere: Prisma.AiUsageAttemptWhereInput = {
      feature: FEATURE,
      createdAt: { gte: from, lt: to },
      ...(query.provider ? { provider: query.provider } : {}),
      ...(query.model ? { model: query.model } : {}),
      ...(outcomes ? { outcome: { in: outcomes } } : {}),
    };
    const pageWhere: Prisma.AiUsageAttemptWhereInput = cursor
      ? {
          AND: [
            baseWhere,
            {
              OR: [
                { createdAt: { lt: new Date(cursor.createdAt) } },
                {
                  createdAt: new Date(cursor.createdAt),
                  id: { lt: cursor.id },
                },
              ],
            },
          ],
        }
      : baseWhere;

    const result = await this.prismaService.execute(async (prisma) => {
      const [rows, grouped, cost, budget] = await Promise.all([
        prisma.aiUsageAttempt.findMany({
          where: pageWhere,
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          take: query.limit + 1,
          select: {
            id: true,
            attemptNumber: true,
            provider: true,
            model: true,
            promptVersion: true,
            inputTokens: true,
            cachedInputTokens: true,
            outputTokens: true,
            estimatedCostMicrosUsd: true,
            outcome: true,
            errorCode: true,
            startedAt: true,
            completedAt: true,
            createdAt: true,
          },
        }),
        prisma.aiUsageAttempt.groupBy({
          by: ['outcome'],
          where: baseWhere,
          _count: { _all: true },
        }),
        prisma.aiUsageAttempt.aggregate({
          where: baseWhere,
          _count: { _all: true },
          _sum: { estimatedCostMicrosUsd: true },
        }),
        prisma.aiBudgetPeriod.findFirst({
          where: {
            feature: FEATURE,
            startsAt: { lt: to },
            endsAt: { gt: from },
          },
          orderBy: { startsAt: 'desc' },
          select: {
            budgetMicrosUsd: true,
            reservedMicrosUsd: true,
            spentMicrosUsd: true,
          },
        }),
      ]);
      return { rows, grouped, cost, budget };
    });
    if (!result) throw databaseUnavailable();
    const page = result.rows.slice(0, query.limit);
    const last = page.at(-1);
    const counts = new Map(
      result.grouped.map((group) => [group.outcome, group._count._all]),
    );
    const settled = ['success', 'fallback', 'refused', 'error'].reduce(
      (sum, outcome) => sum + (counts.get(outcome) ?? 0),
      0,
    );
    const ratio = (value: number) =>
      settled === 0 ? 0 : Number((value / settled).toFixed(4));

    return {
      items: page.map((row) => ({
        id: row.id,
        diagnosticId: null,
        attemptNumber: row.attemptNumber,
        provider: row.provider,
        model: row.model,
        promptVersion: row.promptVersion,
        inputTokens: row.inputTokens,
        cachedInputTokens: row.cachedInputTokens,
        outputTokens: row.outputTokens,
        estimatedCostMicrosUsd:
          row.estimatedCostMicrosUsd?.toString() ?? null,
        outcome: this.publicOutcome(row.outcome),
        errorCode: row.errorCode,
        startedAt: row.startedAt?.toISOString() ?? null,
        completedAt: row.completedAt?.toISOString() ?? null,
      })),
      nextCursor:
        result.rows.length > query.limit && last
          ? this.encodeCursor({
              createdAt: last.createdAt.toISOString(),
              id: last.id,
            })
          : null,
      total: result.cost._count._all,
      summary: {
        requests: result.cost._count._all,
        validSuccessRate: ratio(counts.get('success') ?? 0),
        fallbackRate: ratio(counts.get('fallback') ?? 0),
        errorRate: ratio(
          (counts.get('error') ?? 0) + (counts.get('refused') ?? 0),
        ),
        estimatedCostMicrosUsd:
          result.cost._sum.estimatedCostMicrosUsd?.toString() ?? '0',
        budgetMicrosUsd: result.budget?.budgetMicrosUsd.toString() ?? '0',
        reservedMicrosUsd:
          result.budget?.reservedMicrosUsd.toString() ?? '0',
        spentMicrosUsd: result.budget?.spentMicrosUsd.toString() ?? '0',
      },
    };
  }

  private publicOutcome(outcome: string): string {
    if (outcome === 'success') return 'succeeded';
    if (outcome === 'error' || outcome === 'refused') return 'failed';
    return outcome;
  }

  private databaseOutcomes(outcome: string | undefined): string[] | null {
    if (!outcome) return null;
    if (outcome === 'succeeded') return ['success'];
    if (outcome === 'failed') return ['error', 'refused'];
    return [outcome];
  }

  private encodeCursor(cursor: Cursor): string {
    return Buffer.from(JSON.stringify(cursor), 'utf8').toString('base64url');
  }

  private decodeCursor(value: string): Cursor {
    try {
      const parsed = JSON.parse(
        Buffer.from(value, 'base64url').toString('utf8'),
      ) as Partial<Cursor>;
      if (
        typeof parsed.createdAt !== 'string' ||
        Number.isNaN(new Date(parsed.createdAt).getTime()) ||
        typeof parsed.id !== 'string' ||
        !parsed.id
      ) {
        throw new Error('invalid cursor');
      }
      return { createdAt: parsed.createdAt, id: parsed.id };
    } catch {
      throw new BadRequestException('Invalid AI usage cursor.');
    }
  }
}
