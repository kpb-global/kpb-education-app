import { NotFoundException } from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { PaymentsService } from '../payments/payments.service';
import { ServicePackagesService } from './service-packages.service';

/**
 * Guards KPB-56: the WhatsApp sales path must create a `pending_payment`
 * ServicePurchase with NO PaymentIntent (no in-app checkout), and must be
 * idempotent per (user, package, case) so repeated CTA taps don't mint
 * duplicate rows that inflate the per-SKU demand signal.
 */
describe('ServicePackagesService — WhatsApp purchase', () => {
  const activePkg = {
    id: 'pkg-1',
    code: 'dossier_pret',
    isActive: true,
    priceXOF: 50000,
    nameFr: 'Dossier prêt',
  };

  function makeService(opts: { existing?: unknown; pkg?: unknown } = {}) {
    const created: Array<Record<string, unknown>> = [];
    let intentCalls = 0;
    const client = {
      servicePackage: {
        findUnique: async () => opts.pkg ?? activePkg,
      },
      servicePurchase: {
        findFirst: async () => opts.existing ?? null,
        create: async ({ data }: { data: Record<string, unknown> }) => {
          created.push(data);
          return { id: 'sp-new', ...data, package: activePkg, case: null };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const payments = {
      createIntent: async () => {
        intentCalls += 1;
        return { id: 'pi-1' };
      },
    } as unknown as PaymentsService;
    return {
      service: new ServicePackagesService(prisma, payments),
      created,
      getIntentCalls: () => intentCalls,
    };
  }

  it('creates a pending_payment purchase with NO PaymentIntent', async () => {
    const { service, created, getIntentCalls } = makeService();
    const result = await service.createWhatsAppPurchase({
      userId: 'u1',
      packageCode: 'dossier_pret',
      source: 'service_packages',
    });
    expect(created).toHaveLength(1);
    expect(created[0].status).toBe('pending_payment');
    expect(created[0].paymentIntentId).toBeUndefined();
    expect(getIntentCalls()).toBe(0);
    expect(result).toBeTruthy();
  });

  it('is idempotent: reuses the open pending request instead of creating a duplicate', async () => {
    const existing = {
      id: 'sp-existing',
      status: 'pending_payment',
      package: activePkg,
      case: null,
    };
    const { service, created } = makeService({ existing });
    const result = (await service.createWhatsAppPurchase({
      userId: 'u1',
      packageCode: 'dossier_pret',
    })) as { id: string };
    expect(created).toHaveLength(0);
    expect(result.id).toBe('sp-existing');
  });

  it('rejects an unknown / inactive package', async () => {
    const { service } = makeService({ pkg: { ...activePkg, isActive: false } });
    await expect(
      service.createWhatsAppPurchase({
        userId: 'u1',
        packageCode: 'dossier_pret',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
