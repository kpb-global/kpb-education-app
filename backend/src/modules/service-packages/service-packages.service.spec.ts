import { NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';

import { PaymentsService } from '../payments/payments.service';
import { PrismaService } from '../prisma/prisma.service';
import { ServicePackagesService } from './service-packages.service';

function makeDb() {
  return {
    servicePackage: {
      findUnique: jest.fn(),
      findMany: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
    },
    servicePurchase: {
      create: jest.fn(),
      findMany: jest.fn(),
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    case: {
      findFirst: jest.fn(),
    },
  };
}

describe('ServicePackagesService', () => {
  let service: ServicePackagesService;
  let db: ReturnType<typeof makeDb>;

  const prismaMock = {
    isEnabled: true,
    execute: jest.fn(),
  };
  const paymentsMock = {
    createIntent: jest.fn(),
  };

  const activePackage = {
    id: 'pkg-1',
    code: 'dossier-pret-fr-en',
    nameFr: 'Dossier prêt FR + EN',
    nameEn: 'Ready file FR + EN',
    summaryFr: 'CV et lettres relus',
    summaryEn: 'Reviewed CV and letters',
    descriptionFr: 'Description',
    descriptionEn: 'Description',
    category: 'dossier_pret',
    priceXOF: 25000,
    deliverablesFr: [],
    deliverablesEn: [],
    turnaroundFr: '3 jours',
    turnaroundEn: '3 days',
    isActive: true,
  };

  beforeEach(async () => {
    db = makeDb();
    prismaMock.execute.mockImplementation(
      (operation: (client: unknown) => unknown) => operation(db),
    );

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        ServicePackagesService,
        { provide: PrismaService, useValue: prismaMock },
        { provide: PaymentsService, useValue: paymentsMock },
      ],
    }).compile();

    service = module.get<ServicePackagesService>(ServicePackagesService);
    jest.clearAllMocks();
    prismaMock.execute.mockImplementation(
      (operation: (client: unknown) => unknown) => operation(db),
    );
  });

  it('creates a WhatsApp purchase without creating a PaymentIntent', async () => {
    db.servicePackage.findUnique.mockResolvedValue(activePackage);
    db.case.findFirst.mockResolvedValue({
      id: 'case-1',
      referenceCode: 'KPB-2026-001',
      requestedCountryId: 'france',
      source: 'mobile_app',
    });
    db.servicePurchase.create.mockResolvedValue({
      id: 'purchase-1',
      status: 'pending_payment',
    });

    await expect(
      service.createWhatsAppPurchase({
        userId: 'user-1',
        packageCode: 'dossier-pret-fr-en',
        caseId: 'case-1',
        source: 'Case Detail WhatsApp',
      }),
    ).resolves.toEqual({ id: 'purchase-1', status: 'pending_payment' });

    expect(paymentsMock.createIntent).not.toHaveBeenCalled();
    expect(db.case.findFirst).toHaveBeenCalledWith({
      where: { id: 'case-1', userId: 'user-1' },
      select: {
        id: true,
        referenceCode: true,
        requestedCountryId: true,
        source: true,
      },
    });
    expect(db.servicePurchase.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          packageId: 'pkg-1',
          userId: 'user-1',
          caseId: 'case-1',
          amountXOF: 25000,
          status: 'pending_payment',
          source: 'case_detail_whatsapp',
          internalNotes: expect.stringContaining('SKU: dossier-pret-fr-en'),
        }),
      }),
    );
  });

  it('refuses to link a WhatsApp purchase to another student case', async () => {
    db.servicePackage.findUnique.mockResolvedValue(activePackage);
    db.case.findFirst.mockResolvedValue(null);

    await expect(
      service.createWhatsAppPurchase({
        userId: 'user-1',
        packageCode: 'dossier-pret-fr-en',
        caseId: 'case-2',
      }),
    ).rejects.toBeInstanceOf(NotFoundException);
    expect(db.servicePurchase.create).not.toHaveBeenCalled();
  });

  it('attributes recognized and pending service revenue by SKU and destination', async () => {
    db.servicePurchase.findMany.mockResolvedValue([
      {
        status: 'paid',
        amountXOF: 25000,
        package: {
          code: 'dossier-pret-fr-en',
          nameFr: 'Dossier prêt FR + EN',
          category: 'dossier_pret',
        },
        case: {
          requestedCountryId: 'france',
        },
      },
      {
        status: 'pending_payment',
        amountXOF: 15000,
        package: {
          code: 'kit-bourse',
          nameFr: 'Kit bourse',
          category: 'scholarship_kit',
        },
        case: {
          requestedCountryId: 'canada',
        },
      },
    ]);

    const result = await service.getRevenueAttribution();

    expect(result.bySku).toEqual([
      expect.objectContaining({
        sku: 'dossier-pret-fr-en',
        paidCount: 1,
        recognizedRevenueXOF: 25000,
      }),
      expect.objectContaining({
        sku: 'kit-bourse',
        pendingCount: 1,
        pendingPipelineXOF: 15000,
      }),
    ]);
    expect(result.byDestination).toEqual([
      expect.objectContaining({
        destinationId: 'france',
        recognizedRevenueXOF: 25000,
      }),
      expect.objectContaining({
        destinationId: 'canada',
        pendingPipelineXOF: 15000,
      }),
    ]);
  });
});
