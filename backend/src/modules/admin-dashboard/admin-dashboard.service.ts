// M13 — Admin Dashboard KPIs.
// Aggregates real-time operational metrics for the KPB admin panel.
// All queries use tryExecute so the endpoint degrades gracefully without DB.

import { Injectable } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getKpis() {
    const thirtyDaysAgo = new Date();
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

    const oneDayAgo = new Date();
    oneDayAgo.setHours(oneDayAgo.getHours() - 24);

    // ── Users ──────────────────────────────────────────────────────────────
    const [totalStudents, totalParents, totalPartners] = await Promise.all([
      this.prisma.tryExecute((db) =>
        db.userProfile.count({ where: { accountType: 'student' } }),
      ),
      this.prisma.tryExecute((db) =>
        db.userProfile.count({ where: { accountType: 'parent' } }),
      ),
      this.prisma.tryExecute((db) =>
        db.userProfile.count({ where: { accountType: 'partner' } }),
      ),
    ]);

    const newUsersLast30Days = await this.prisma.tryExecute((db) =>
      db.userProfile.count({ where: { createdAt: { gte: thirtyDaysAgo } } }),
    );

    // ── Cases by status ─────────────────────────────────────────────────────
    const caseGroups = await this.prisma.tryExecute((db) =>
      db.case.groupBy({ by: ['status'], _count: { _all: true } }),
    );
    const casesByStatus: Record<string, number> = {};
    for (const group of caseGroups ?? []) {
      casesByStatus[group.status] = group._count._all;
    }

    const totalCases = Object.values(casesByStatus).reduce((a, b) => a + b, 0);
    const newCases = (casesByStatus['submitted'] ?? 0) +
      (casesByStatus['counselor_assigned'] ?? 0);
    const activeCases =
      (casesByStatus['in_progress'] ?? 0) +
      (casesByStatus['awaiting_student'] ?? 0) +
      (casesByStatus['documents_needed'] ?? 0) +
      (casesByStatus['scheduled'] ?? 0);
    const completedCases = casesByStatus['completed'] ?? 0;

    // ── Lead tags (commercial performance signal) ───────────────────────────
    const leadTagGroups = await this.prisma.tryExecute((db) =>
      db.case.groupBy({
        by: ['leadTag'],
        where: { leadTag: { not: null } },
        _count: { _all: true },
      }),
    );
    const leadTagBreakdown: Record<string, number> = {};
    for (const group of leadTagGroups ?? []) {
      if (group.leadTag) {
        leadTagBreakdown[group.leadTag] = group._count._all;
      }
    }
    const convertedTotal = leadTagBreakdown['converted'] ?? 0;

    // ── Notifications sent in last 24 h ─────────────────────────────────────
    const notifsSent24h = await this.prisma.tryExecute((db) =>
      db.notificationDelivery.count({
        where: {
          deliveredAt: { gte: oneDayAgo },
          status: 'delivered',
        },
      }),
    );

    // ── Orientation sessions ─────────────────────────────────────────────────
    const orientationSessionsTotal = await this.prisma.tryExecute((db) =>
      db.orientationSession.count(),
    );

    return {
      users: {
        students: totalStudents ?? 0,
        parents: totalParents ?? 0,
        partners: totalPartners ?? 0,
        total: (totalStudents ?? 0) + (totalParents ?? 0) + (totalPartners ?? 0),
        newLast30Days: newUsersLast30Days ?? 0,
      },
      cases: {
        total: totalCases,
        new: newCases,
        active: activeCases,
        completed: completedCases,
        byStatus: casesByStatus,
      },
      leads: {
        breakdown: leadTagBreakdown,
        convertedTotal,
        conversionRate:
          totalCases > 0
            ? Math.round((convertedTotal / totalCases) * 100)
            : 0,
      },
      notifications: {
        sentLast24h: notifsSent24h ?? 0,
      },
      orientationSessions: orientationSessionsTotal ?? 0,
      generatedAt: new Date().toISOString(),
    };
  }
}
