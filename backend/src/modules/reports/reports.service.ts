import { Injectable } from '@nestjs/common';

import { VERIFICATION_POLICIES } from '../admin-catalog/admin-catalog.service';
import { PrismaService } from '../prisma/prisma.service';

const REVENUE_STATUSES = ['paid', 'in_progress', 'delivered'] as const;
// Terminal case statuses — everything else counts as "active" pipeline.
const CLOSED_CASE_STATUSES = ['completed', 'rejected', 'cancelled'] as const;
// Roles whose first message on a case counts as the advisor's first response
// (same set the reassignment cron treats as staff activity).
const ADVISOR_ROLES = ['counselor', 'advisor', 'commercial'] as const;
// Statuses meaning the application actually went out the door.
const APPLICATION_SUBMITTED_STATUSES = [
  'application_submitted',
  'waiting_decision',
  'completed',
] as const;

const WEEK_MS = 7 * 24 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;
// Weeks shown on the dashboard's North-Star bar chart.
const NORTH_STAR_WEEKS = 8;
// A lead counts as "qualified" once it has at least reached that tag —
// converted leads necessarily passed through qualification.
const QUALIFIED_LEAD_TAGS = ['qualified', 'converted'] as const;

/// Monday 00:00 UTC of the week containing [date].
function weekStartUtc(date: Date): Date {
  const day = date.getUTCDay(); // 0 = Sunday
  const daysSinceMonday = (day + 6) % 7;
  const start = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
  start.setUTCDate(start.getUTCDate() - daysSinceMonday);
  return start;
}

function verificationDueWhere(cadenceDays: number, now: Date) {
  const cutoff = new Date(now.getTime() - cadenceDays * DAY_MS);
  return {
    OR: [{ lastVerifiedAt: null }, { lastVerifiedAt: { lt: cutoff } }],
  };
}

interface FirstResponseSample {
  createdAt: Date;
  messages: { createdAt: Date }[];
}

function averageResponseHours(samples: FirstResponseSample[]): number | null {
  const deltas = samples
    .filter((sample) => sample.messages.length > 0)
    .map(
      (sample) =>
        (sample.messages[0].createdAt.getTime() -
          sample.createdAt.getTime()) /
        (60 * 60 * 1000),
    )
    .filter((hours) => hours >= 0);
  if (deltas.length === 0) {
    return null;
  }
  return deltas.reduce((sum, hours) => sum + hours, 0) / deltas.length;
}

@Injectable()
export class ReportsService {
  constructor(private readonly prismaService: PrismaService) {}

  async getOverview() {
    const empty = {
      activeCases: 0,
      awaitingDocuments: 0,
      submittedThisWeek: 0,
      paidServicePurchases: 0,
      counselorResponseSlaHours: null as number | null,
    };
    if (!this.prismaService.isEnabled) {
      return empty;
    }

    const weekAgo = new Date(Date.now() - WEEK_MS);
    const result = await this.prismaService.execute(async (prisma) => {
      const [
        activeCases,
        awaitingDocuments,
        submittedThisWeek,
        paidServicePurchases,
        responseSamples,
      ] = await Promise.all([
        prisma.case.count({
          where: { status: { notIn: [...CLOSED_CASE_STATUSES] } },
        }),
        prisma.case.count({ where: { status: 'documents_needed' } }),
        prisma.case.count({ where: { createdAt: { gte: weekAgo } } }),
        prisma.servicePurchase.count({
          where: { status: { in: [...REVENUE_STATUSES] } },
        }),
        prisma.case.findMany({
          where: {
            messages: { some: { senderRole: { in: [...ADVISOR_ROLES] } } },
          },
          select: {
            createdAt: true,
            messages: {
              where: { senderRole: { in: [...ADVISOR_ROLES] } },
              orderBy: { createdAt: 'asc' },
              take: 1,
              select: { createdAt: true },
            },
          },
        }),
      ]);

      return {
        activeCases,
        awaitingDocuments,
        submittedThisWeek,
        paidServicePurchases,
        counselorResponseSlaHours: averageResponseHours(responseSamples),
      };
    });

    return result ?? empty;
  }

  /// Dashboard activation block (App-engagement handoff, "Admin — Tableau de
  /// bord"): the weekly North-Star series + the "Action immédiate requise"
  /// counters. Everything is a real aggregate — no fabricated series.
  async getDashboardActivation() {
    const empty = {
      weeklyQualifiedLeads: [] as { weekStart: string; count: number }[],
      urgent: {
        awaitingDocuments: 0,
        verificationDue: 0,
        moderationQueue: 0,
      },
    };
    if (!this.prismaService.isEnabled) {
      return empty;
    }

    const now = new Date();
    const currentWeekStart = weekStartUtc(now);
    const rangeStart = new Date(
      currentWeekStart.getTime() - (NORTH_STAR_WEEKS - 1) * WEEK_MS,
    );

    const result = await this.prismaService.execute(async (prisma) => {
      const [
        qualifiedLeads,
        awaitingDocuments,
        countriesDue,
        institutionsDue,
        programsDue,
        scholarshipsDue,
        moderationQueue,
      ] = await Promise.all([
        // The Case model has no "tagged at" timestamp, so the series is
        // honestly bucketed by the lead's CREATION week (stable, unlike
        // updatedAt) — the chart hint states this.
        prisma.case.findMany({
          where: {
            leadTag: { in: [...QUALIFIED_LEAD_TAGS] },
            createdAt: { gte: rangeStart },
          },
          select: { createdAt: true },
        }),
        prisma.case.count({ where: { status: 'documents_needed' } }),
        prisma.country.count({
          where: {
            isActive: true,
            ...verificationDueWhere(
              VERIFICATION_POLICIES.countryVisa.cadenceDays,
              now,
            ),
          },
        }),
        prisma.institution.count({
          where: verificationDueWhere(
            VERIFICATION_POLICIES.institutionScolarite.cadenceDays,
            now,
          ),
        }),
        prisma.program.count({
          where: verificationDueWhere(
            VERIFICATION_POLICIES.programScolarite.cadenceDays,
            now,
          ),
        }),
        prisma.scholarship.count({
          where: {
            isActive: true,
            moderationStatus: 'approved',
            ...verificationDueWhere(
              VERIFICATION_POLICIES.scholarshipDeadline.cadenceDays,
              now,
            ),
          },
        }),
        prisma.forumModerationAction.count(),
      ]);

      const buckets = new Map<string, number>();
      for (let i = 0; i < NORTH_STAR_WEEKS; i++) {
        const week = new Date(rangeStart.getTime() + i * WEEK_MS);
        buckets.set(week.toISOString().slice(0, 10), 0);
      }
      for (const lead of qualifiedLeads) {
        const key = weekStartUtc(lead.createdAt).toISOString().slice(0, 10);
        if (buckets.has(key)) {
          buckets.set(key, (buckets.get(key) ?? 0) + 1);
        }
      }

      return {
        weeklyQualifiedLeads: Array.from(buckets.entries()).map(
          ([weekStart, count]) => ({ weekStart, count }),
        ),
        urgent: {
          awaitingDocuments,
          verificationDue:
            countriesDue + institutionsDue + programsDue + scholarshipsDue,
          moderationQueue,
        },
      };
    });

    return result ?? empty;
  }

  async getFunnel() {
    if (!this.prismaService.isEnabled) {
      return { items: [] };
    }

    const items = await this.prismaService.execute(async (prisma) => {
      const [studentSignups, casesCreated, applicationsSubmitted, paidServicePurchases] =
        await Promise.all([
          prisma.userProfile.count({ where: { accountType: 'student' } }),
          prisma.case.count(),
          prisma.case.count({
            where: { status: { in: [...APPLICATION_SUBMITTED_STATUSES] } },
          }),
          prisma.servicePurchase.count({
            where: { status: { in: [...REVENUE_STATUSES] } },
          }),
        ]);

      return [
        { key: 'studentSignups', value: studentSignups },
        { key: 'casesCreated', value: casesCreated },
        { key: 'applicationsSubmitted', value: applicationsSubmitted },
        { key: 'paidServicePurchases', value: paidServicePurchases },
      ];
    });

    return { items: items ?? [] };
  }

  async getCounselorPerformance() {
    if (!this.prismaService.isEnabled) {
      return { items: [] };
    }

    const cases = await this.prismaService.execute((prisma) =>
      prisma.case.findMany({
        where: { assignedAdvisorName: { not: null } },
        select: {
          assignedAdvisorName: true,
          status: true,
          createdAt: true,
          messages: {
            where: { senderRole: { in: [...ADVISOR_ROLES] } },
            orderBy: { createdAt: 'asc' },
            take: 1,
            select: { createdAt: true },
          },
        },
      }),
    );

    const byAdvisor = new Map<
      string,
      { activeCases: number; samples: FirstResponseSample[] }
    >();
    for (const caseRow of cases ?? []) {
      const advisorName = caseRow.assignedAdvisorName;
      if (!advisorName) {
        continue;
      }
      const row =
        byAdvisor.get(advisorName) ?? { activeCases: 0, samples: [] };
      if (
        !(CLOSED_CASE_STATUSES as readonly string[]).includes(caseRow.status)
      ) {
        row.activeCases += 1;
      }
      row.samples.push({
        createdAt: caseRow.createdAt,
        messages: caseRow.messages,
      });
      byAdvisor.set(advisorName, row);
    }

    const items = Array.from(byAdvisor.entries())
      .map(([counselor, row]) => ({
        counselor,
        activeCases: row.activeCases,
        avgResponseHours: averageResponseHours(row.samples),
      }))
      .sort((a, b) => b.activeCases - a.activeCases);

    return { items };
  }

  async getCampaignPerformance() {
    if (!this.prismaService.isEnabled) {
      return { items: [] };
    }

    const campaigns = await this.prismaService.execute((prisma) =>
      prisma.notificationCampaign.findMany({
        orderBy: { createdAt: 'desc' },
        select: {
          name: true,
          deliveries: { select: { status: true } },
        },
      }),
    );

    const items = (campaigns ?? []).map((campaign) => ({
      campaign: campaign.name,
      sent: campaign.deliveries.length,
      delivered: campaign.deliveries.filter(
        (delivery) => delivery.status === 'delivered',
      ).length,
    }));

    return { items };
  }

  async getServiceRevenue() {
    if (!this.prismaService.isEnabled) {
      return { bySku: [], byDestination: [] };
    }

    const purchases = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findMany({
        include: {
          package: {
            select: {
              code: true,
              nameFr: true,
              category: true,
            },
          },
          case: {
            select: {
              requestedCountryId: true,
              referenceCode: true,
            },
          },
        },
      }),
    );

    const bySku = new Map<
      string,
      {
        sku: string;
        packageName: string;
        category: string;
        purchasesCount: number;
        paidCount: number;
        pendingCount: number;
        recognizedRevenueXOF: number;
        pendingPipelineXOF: number;
      }
    >();
    const byDestination = new Map<
      string,
      {
        destinationId: string;
        purchasesCount: number;
        paidCount: number;
        pendingCount: number;
        recognizedRevenueXOF: number;
        pendingPipelineXOF: number;
      }
    >();

    for (const purchase of purchases ?? []) {
      const isPaid = (REVENUE_STATUSES as readonly string[]).includes(
        purchase.status,
      );
      const isPending = purchase.status === 'pending_payment';
      const amount = purchase.amountXOF;
      const skuKey = purchase.package.code;
      const destinationKey = purchase.case?.requestedCountryId ?? 'unassigned';

      const skuRow =
        bySku.get(skuKey) ??
        {
          sku: skuKey,
          packageName: purchase.package.nameFr,
          category: purchase.package.category,
          purchasesCount: 0,
          paidCount: 0,
          pendingCount: 0,
          recognizedRevenueXOF: 0,
          pendingPipelineXOF: 0,
        };
      skuRow.purchasesCount += 1;
      skuRow.paidCount += isPaid ? 1 : 0;
      skuRow.pendingCount += isPending ? 1 : 0;
      skuRow.recognizedRevenueXOF += isPaid ? amount : 0;
      skuRow.pendingPipelineXOF += isPending ? amount : 0;
      bySku.set(skuKey, skuRow);

      const destinationRow =
        byDestination.get(destinationKey) ??
        {
          destinationId: destinationKey,
          purchasesCount: 0,
          paidCount: 0,
          pendingCount: 0,
          recognizedRevenueXOF: 0,
          pendingPipelineXOF: 0,
        };
      destinationRow.purchasesCount += 1;
      destinationRow.paidCount += isPaid ? 1 : 0;
      destinationRow.pendingCount += isPending ? 1 : 0;
      destinationRow.recognizedRevenueXOF += isPaid ? amount : 0;
      destinationRow.pendingPipelineXOF += isPending ? amount : 0;
      byDestination.set(destinationKey, destinationRow);
    }

    return {
      bySku: Array.from(bySku.values()).sort(
        (a, b) => b.recognizedRevenueXOF - a.recognizedRevenueXOF,
      ),
      byDestination: Array.from(byDestination.values()).sort(
        (a, b) => b.recognizedRevenueXOF - a.recognizedRevenueXOF,
      ),
    };
  }
}
