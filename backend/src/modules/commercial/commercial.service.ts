import { Injectable, NotFoundException, ServiceUnavailableException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { CasesService } from '../cases/cases.service';

const LEAD_TAGS = [
  'qualified',
  'not_qualified',
  'awaiting_payment',
  'converted',
  'lost',
  'to_follow_up',
] as const;

export type LeadTag = (typeof LEAD_TAGS)[number];

@Injectable()
export class CommercialService {
  constructor(
    private readonly prismaService: PrismaService,
    private readonly casesService: CasesService,
  ) {}

  private assertDb() {
    if (!this.prismaService.isEnabled) {
      throw new ServiceUnavailableException('Database is not configured.');
    }
  }

  async listLeads(counsellorEmail?: string, filter?: string) {
    this.assertDb();
    const counsellor = counsellorEmail
      ? await this.prismaService.execute((prisma) =>
          prisma.counsellor.findFirst({ where: { email: counsellorEmail } }),
        )
      : null;

    const allCases = counsellor
      ? await this.prismaService.execute((prisma) =>
          prisma.case.findMany({
            where: { counsellorId: counsellor.id },
            include: {
              user: true,
              messages: { orderBy: { createdAt: 'desc' }, take: 20 },
            },
            orderBy: { createdAt: 'desc' },
          }),
        )
      : [];

    const mapped = (allCases ?? []).map((item) => {
      // Count student messages since last commercial interaction ≈ unread
      const cutoff = item.lastCommercialInteractionAt;
      const unreadMessages = item.messages.filter(
        (m) =>
          m.senderRole === 'student' &&
          (cutoff == null || m.createdAt > cutoff),
      ).length;

      return {
        id: item.id,
        referenceCode: item.referenceCode,
        title: item.title,
        status: item.status,
        leadTag: item.leadTag,
        discussionMotive: item.discussionMotive,
        studentName: item.user.fullName,
        studentLevel: item.user.currentLevel,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
        lastCommercialInteractionAt: item.lastCommercialInteractionAt,
        unreadMessages,
      };
    });

    switch (filter) {
      case 'new':
        return mapped.filter(
          (item) =>
            item.status === 'submitted' || item.status === 'counselor_assigned',
        );
      case 'today': {
        const start = new Date();
        start.setHours(0, 0, 0, 0);
        return mapped.filter((item) => item.createdAt >= start);
      }
      case 'qualified':
        return mapped.filter((item) => item.leadTag === 'qualified');
      default:
        return mapped;
    }
  }

  async updateLead(
    caseId: string,
    input: { leadTag?: LeadTag; discussionMotive?: string },
  ) {
    this.assertDb();
    const existing = await this.prismaService.execute((prisma) =>
      prisma.case.findUnique({ where: { id: caseId } }),
    );
    if (!existing) {
      throw new NotFoundException(`Case ${caseId} not found.`);
    }

    if (input.leadTag && !LEAD_TAGS.includes(input.leadTag)) {
      throw new NotFoundException(`Invalid lead tag ${input.leadTag}`);
    }

    await this.prismaService.execute((prisma) =>
      prisma.case.update({
        where: { id: caseId },
        data: {
          ...(input.leadTag ? { leadTag: input.leadTag } : {}),
          ...(input.discussionMotive !== undefined
            ? { discussionMotive: input.discussionMotive.slice(0, 100) }
            : {}),
          lastCommercialInteractionAt: new Date(),
        },
      }),
    );

    return this.casesService.findOne(caseId);
  }

  async performance() {
    this.assertDb();
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const counsellors = await this.prismaService.execute((prisma) =>
      prisma.counsellor.findMany({
        where: { isActive: true },
        include: {
          cases: {
            include: {
              messages: { orderBy: { createdAt: 'desc' }, take: 5 },
            },
          },
        },
        orderBy: { fullName: 'asc' },
      }),
    );

    return {
      items: (counsellors ?? []).map((counsellor) => {
        const cases = counsellor.cases;
        const convertedLast30Days = cases.filter(
          (c) =>
            c.leadTag === 'converted' && c.updatedAt >= thirtyDaysAgo,
        ).length;

        const respondedCases = cases.filter(
          (c) => c.lastCommercialInteractionAt != null,
        );
        const avgFirstResponseMinutes =
          respondedCases.length > 0
            ? Math.round(
                respondedCases.reduce((sum, c) => {
                  const diff =
                    (c.lastCommercialInteractionAt as Date).getTime() -
                    c.createdAt.getTime();
                  return sum + diff / 60_000;
                }, 0) / respondedCases.length,
              )
            : null;

        const tagBreakdown: Record<string, number> = {};
        for (const c of cases) {
          if (c.leadTag) {
            tagBreakdown[c.leadTag] = (tagBreakdown[c.leadTag] ?? 0) + 1;
          }
        }

        return {
          id: counsellor.id,
          fullName: counsellor.fullName,
          email: counsellor.email,
          totalLeads: cases.length,
          convertedLast30Days,
          avgFirstResponseMinutes,
          tagBreakdown,
          avgRating: counsellor.avgRating,
          reviewCount: counsellor.reviewCount,
        };
      }),
    };
  }

  async stats(counsellorEmail?: string) {
    const leads = await this.listLeads(counsellorEmail);

    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const convertedLast30Days = leads.filter(
      (item) =>
        item.leadTag === 'converted' && item.updatedAt >= thirtyDaysAgo,
    ).length;

    // Average first-response time: cases where a commercial has interacted
    // (lastCommercialInteractionAt set). Difference from createdAt ≈ first response.
    const respondedLeads = (leads as Array<{
      createdAt: Date;
      lastCommercialInteractionAt?: Date | null;
    }>).filter((item) => item.lastCommercialInteractionAt != null);

    const avgFirstResponseMinutes =
      respondedLeads.length > 0
        ? Math.round(
            respondedLeads.reduce((sum, item) => {
              const diffMs =
                (item.lastCommercialInteractionAt as Date).getTime() -
                item.createdAt.getTime();
              return sum + diffMs / 60_000;
            }, 0) / respondedLeads.length,
          )
        : null;

    return {
      totalLeads: leads.length,
      convertedLast30Days,
      avgFirstResponseMinutes,
    };
  }
}
