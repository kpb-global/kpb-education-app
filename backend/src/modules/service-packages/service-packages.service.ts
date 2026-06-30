import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';

type ProviderName = 'cinetpay' | 'paydunya' | 'stripe' | 'manual';
type PurchaseStatus =
  | 'pending_payment'
  | 'paid'
  | 'in_progress'
  | 'delivered'
  | 'cancelled'
  | 'refunded';

const PURCHASE_STATUSES: PurchaseStatus[] = [
  'pending_payment',
  'paid',
  'in_progress',
  'delivered',
  'cancelled',
  'refunded',
];

const RECOGNIZED_REVENUE_STATUSES = new Set<PurchaseStatus>([
  'paid',
  'in_progress',
  'delivered',
]);

/**
 * Catalog + purchase orchestration for Phase 3 monetized bundles.
 *
 * Two product families live here:
 *   1. "Dossier prêt" — fixed-price CV + motivation + reco-letter review
 *      bundle in FR + EN. This is the flagship SKU parents are willing to
 *      pay for.
 *   2. Scholarship / visa prep kits (10k–25k FCFA) — self-serve packets
 *      bundled with templates, checklists, and one counsellor sync-up.
 *
 * A ServicePurchase is always created first with `status: pending_payment`.
 * A PaymentIntent is then attached (CinetPay / Paydunya / manual). When the
 * payment webhook settles the intent to `paid`, `reconcilePurchase()` flips
 * the purchase to `paid` so ops can start delivery.
 *
 * We do *not* auto-refund on payment failure — ops investigates because the
 * failure mode is usually a stuck mobile-money transfer that resolves itself.
 */
@Injectable()
export class ServicePackagesService {
  private readonly logger = new Logger(ServicePackagesService.name);

  constructor(
    private readonly prismaService: PrismaService,
    private readonly paymentsService: PaymentsService,
  ) {}

  // ── Public catalog ────────────────────────────────────────────────────────

  async listPublic(params: { category?: string } = {}) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePackage.findMany({
        where: {
          isActive: true,
          ...(params.category
            ? { category: params.category as never }
            : {}),
        },
        orderBy: [{ displayOrder: 'asc' }, { priceXOF: 'asc' }],
        select: {
          id: true,
          code: true,
          nameFr: true,
          nameEn: true,
          summaryFr: true,
          summaryEn: true,
          descriptionFr: true,
          descriptionEn: true,
          category: true,
          priceXOF: true,
          deliverablesFr: true,
          deliverablesEn: true,
          turnaroundFr: true,
          turnaroundEn: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async getPublic(code: string) {
    const pkg = await this.prismaService.execute((prisma) =>
      prisma.servicePackage.findUnique({ where: { code } }),
    );
    if (!pkg || !pkg.isActive) {
      throw new NotFoundException(`Service package ${code} not found.`);
    }
    return pkg;
  }

  // ── Purchases (student-facing) ────────────────────────────────────────────

  /**
   * Kick off a purchase. We:
   *   1. Create a ServicePurchase row (pending_payment).
   *   2. Ask PaymentsService to init a PaymentIntent for the package price.
   *   3. Link intent → purchase, return the checkout URL to the mobile app.
   *
   * Prefer CinetPay by default (broadest MoMo coverage). Student can override.
   */
  async purchase(input: {
    userId: string;
    packageCode: string;
    provider?: ProviderName;
    caseId?: string;
    returnUrl: string;
    cancelUrl: string;
    customer: { email: string; phone: string; fullName: string };
  }) {
    const pkg = await this.getPublic(input.packageCode);

    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.create({
        data: {
          packageId: pkg.id,
          userId: input.userId,
          caseId: input.caseId,
          amountXOF: pkg.priceXOF,
          status: 'pending_payment',
          source: 'checkout',
        },
      }),
    );
    if (!purchase) {
      throw new Error('Failed to create service purchase.');
    }

    const intent = await this.paymentsService.createIntent({
      userId: input.userId,
      provider: input.provider ?? 'cinetpay',
      amountMinor: pkg.priceXOF,
      currency: 'XOF',
      caseId: input.caseId,
      description: `KPB — ${pkg.nameFr}`,
      customer: input.customer,
      returnUrl: input.returnUrl,
      cancelUrl: input.cancelUrl,
    });
    if (!intent) {
      throw new Error('Failed to create payment intent for purchase.');
    }

    const linked = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.update({
        where: { id: purchase.id },
        data: { paymentIntentId: intent.id },
        include: { package: true, case: true, paymentIntent: true },
      }),
    );
    return linked;
  }

  /**
   * WhatsApp-first sales flow: create the purchase row and let a counsellor
   * collect/confirm payment manually. No PaymentIntent or checkout URL.
   */
  async createWhatsAppPurchase(input: {
    userId: string;
    packageCode: string;
    caseId?: string;
    source?: string;
  }) {
    const pkg = await this.getPublic(input.packageCode);
    const source = this.normalizeSource(input.source);
    const linkedCase = input.caseId
      ? await this.getOwnedCase(input.userId, input.caseId)
      : null;

    const notes = [
      'Created from mobile WhatsApp CTA.',
      `SKU: ${pkg.code}`,
      `Source: ${source}`,
      linkedCase ? `Case: ${linkedCase.referenceCode}` : null,
      linkedCase?.requestedCountryId
        ? `Destination: ${linkedCase.requestedCountryId}`
        : null,
    ]
      .filter(Boolean)
      .join('\n');

    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.create({
        data: {
          packageId: pkg.id,
          userId: input.userId,
          caseId: linkedCase?.id,
          amountXOF: pkg.priceXOF,
          status: 'pending_payment',
          source,
          internalNotes: notes,
        },
        include: {
          package: true,
          case: {
            select: {
              id: true,
              referenceCode: true,
              requestedCountryId: true,
              source: true,
            },
          },
          paymentIntent: true,
        },
      }),
    );
    if (!purchase) {
      throw new Error('Failed to create WhatsApp service purchase.');
    }
    return purchase;
  }

  /** Student's own purchase history (most-recent first). */
  async listForUser(userId: string) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        include: { package: true, case: true, paymentIntent: true },
      }),
    );
    return { items: items ?? [] };
  }

  async getForUser(userId: string, id: string) {
    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findFirst({
        where: { id, userId },
        include: { package: true, case: true, paymentIntent: true },
      }),
    );
    if (!purchase) {
      throw new NotFoundException(`Purchase ${id} not found.`);
    }
    return purchase;
  }

  // ── Admin CRUD ────────────────────────────────────────────────────────────

  async listAdmin() {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePackage.findMany({
        orderBy: [{ displayOrder: 'asc' }, { createdAt: 'desc' }],
      }),
    );
    return { items: items ?? [] };
  }

  async createPackage(data: {
    code: string;
    nameFr: string;
    nameEn: string;
    summaryFr: string;
    summaryEn: string;
    descriptionFr: string;
    descriptionEn: string;
    category: string;
    priceXOF: number;
    deliverablesFr?: string[];
    deliverablesEn?: string[];
    turnaroundFr?: string;
    turnaroundEn?: string;
    displayOrder?: number;
    isActive?: boolean;
  }) {
    if (data.priceXOF < 0) {
      throw new BadRequestException('priceXOF cannot be negative.');
    }
    return this.prismaService.execute((prisma) =>
      prisma.servicePackage.create({
        data: {
          ...data,
          category: data.category as never,
          deliverablesFr: data.deliverablesFr ?? [],
          deliverablesEn: data.deliverablesEn ?? [],
        },
      }),
    );
  }

  async updatePackage(
    id: string,
    data: Partial<{
      nameFr: string;
      nameEn: string;
      summaryFr: string;
      summaryEn: string;
      descriptionFr: string;
      descriptionEn: string;
      priceXOF: number;
      deliverablesFr: string[];
      deliverablesEn: string[];
      turnaroundFr: string;
      turnaroundEn: string;
      displayOrder: number;
      isActive: boolean;
    }>,
  ) {
    return this.prismaService.execute((prisma) =>
      prisma.servicePackage.update({ where: { id }, data }),
    );
  }

  async listPurchasesAdmin(status?: string) {
    const items = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findMany({
        where: status ? { status: status as never } : {},
        orderBy: { createdAt: 'desc' },
        include: {
          package: true,
          user: { select: { id: true, fullName: true, email: true } },
          case: {
            select: {
              id: true,
              referenceCode: true,
              requestedCountryId: true,
              source: true,
            },
          },
          paymentIntent: true,
        },
      }),
    );
    return { items: items ?? [] };
  }

  async updatePurchaseStatus(
    id: string,
    status: string,
    internalNotes?: string,
  ) {
    if (!PURCHASE_STATUSES.includes(status as PurchaseStatus)) {
      throw new BadRequestException(`Unknown purchase status: ${status}`);
    }
    return this.prismaService.execute((prisma) =>
      prisma.servicePurchase.update({
        where: { id },
        data: {
          status: status as never,
          internalNotes,
          deliveredAt: status === 'delivered' ? new Date() : undefined,
        },
      }),
    );
  }

  /**
   * Called by the payments webhook loop: if a paid intent has a matching
   * purchase row still in `pending_payment`, advance it to `paid`. Safe to
   * call repeatedly (idempotent) since we check current status first.
   */
  async reconcilePurchase(paymentIntentId: string) {
    const purchase = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findUnique({
        where: { paymentIntentId },
        include: { paymentIntent: true },
      }),
    );
    if (!purchase) return null;
    if (purchase.status !== 'pending_payment') {
      return purchase;
    }
    if (purchase.paymentIntent?.status !== 'paid') {
      return purchase;
    }
    const updated = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.update({
        where: { id: purchase.id },
        data: { status: 'paid' },
      }),
    );
    this.logger.log(
      `Purchase ${purchase.id} reconciled → paid (intent ${paymentIntentId})`,
    );
    return updated;
  }

  async getRevenueAttribution() {
    const purchases = await this.prismaService.execute((prisma) =>
      prisma.servicePurchase.findMany({
        orderBy: { createdAt: 'desc' },
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
              id: true,
              referenceCode: true,
              requestedCountryId: true,
              source: true,
            },
          },
        },
      }),
    );

    const skuRows = new Map<
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
    const destinationRows = new Map<
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
      const status = purchase.status as PurchaseStatus;
      const isRecognized = RECOGNIZED_REVENUE_STATUSES.has(status);
      const isPending = status === 'pending_payment';
      const amount = purchase.amountXOF;
      const skuKey = purchase.package.code;
      const destinationKey = purchase.case?.requestedCountryId ?? 'unassigned';

      const skuRow =
        skuRows.get(skuKey) ??
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
      skuRow.paidCount += isRecognized ? 1 : 0;
      skuRow.pendingCount += isPending ? 1 : 0;
      skuRow.recognizedRevenueXOF += isRecognized ? amount : 0;
      skuRow.pendingPipelineXOF += isPending ? amount : 0;
      skuRows.set(skuKey, skuRow);

      const destinationRow =
        destinationRows.get(destinationKey) ??
        {
          destinationId: destinationKey,
          purchasesCount: 0,
          paidCount: 0,
          pendingCount: 0,
          recognizedRevenueXOF: 0,
          pendingPipelineXOF: 0,
        };
      destinationRow.purchasesCount += 1;
      destinationRow.paidCount += isRecognized ? 1 : 0;
      destinationRow.pendingCount += isPending ? 1 : 0;
      destinationRow.recognizedRevenueXOF += isRecognized ? amount : 0;
      destinationRow.pendingPipelineXOF += isPending ? amount : 0;
      destinationRows.set(destinationKey, destinationRow);
    }

    const bySku = Array.from(skuRows.values()).sort(
      (a, b) => b.recognizedRevenueXOF - a.recognizedRevenueXOF,
    );
    const byDestination = Array.from(destinationRows.values()).sort(
      (a, b) => b.recognizedRevenueXOF - a.recognizedRevenueXOF,
    );

    return { bySku, byDestination };
  }

  private normalizeSource(source?: string) {
    const normalized = (source ?? 'service_package_whatsapp')
      .trim()
      .toLowerCase()
      .replace(/[^a-z0-9_-]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 80);
    return normalized || 'service_package_whatsapp';
  }

  private async getOwnedCase(userId: string, caseId: string) {
    const linkedCase = await this.prismaService.execute((prisma) =>
      prisma.case.findFirst({
        where: { id: caseId, userId },
        select: {
          id: true,
          referenceCode: true,
          requestedCountryId: true,
          source: true,
        },
      }),
    );
    if (!linkedCase) {
      throw new NotFoundException(`Case ${caseId} not found.`);
    }
    return linkedCase;
  }
}
