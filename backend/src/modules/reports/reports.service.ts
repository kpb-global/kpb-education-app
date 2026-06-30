import { Injectable } from '@nestjs/common';

import { mockAdminData } from '../../common/data/mock-admin';
import { PrismaService } from '../prisma/prisma.service';

const REVENUE_STATUSES = ['paid', 'in_progress', 'delivered'];

@Injectable()
export class ReportsService {
  constructor(private readonly prismaService: PrismaService) {}

  getOverview() {
    return mockAdminData.reports.overview;
  }

  getFunnel() {
    return { items: mockAdminData.reports.funnel };
  }

  getCounselorPerformance() {
    return { items: mockAdminData.reports.counselorPerformance };
  }

  getCampaignPerformance() {
    return { items: mockAdminData.reports.campaignPerformance };
  }

  async getServiceRevenue() {
    if (!this.prismaService.isEnabled) {
      return mockAdminData.reports.serviceRevenue;
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
      const isPaid = REVENUE_STATUSES.includes(purchase.status);
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
