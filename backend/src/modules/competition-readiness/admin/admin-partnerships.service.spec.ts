import { BadRequestException } from '@nestjs/common';
import {
  PartnershipAgreementStatus,
  PartnershipAgreementType,
} from '@prisma/client';

import type { AdminSessionUser } from '../../auth/auth.service';
import type { PrismaService } from '../../prisma/prisma.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { IdempotencyService } from '../common/idempotency.service';
import type { AdminImpactAccessService } from './admin-impact-access.service';
import { AdminPartnershipsService } from './admin-partnerships.service';

const actor: AdminSessionUser = {
  id: 'admin-1',
  email: 'admin@example.test',
  fullName: 'Admin One',
  role: 'super_admin',
  languageScope: ['fr'],
};

function agreement(ownerAdminId = 'admin-2') {
  return {
    id: 'agreement-1',
    agreementKey: 'uwc-niger',
    revisionNumber: 1,
    supersedesId: null,
    isCurrent: true,
    lockVersion: 1,
    partnerId: 'partner-1',
    institutionId: null,
    status: PartnershipAgreementStatus.signed,
    agreementType: PartnershipAgreementType.pilot,
    purposeCodes: ['pilot_research'],
    countryCodes: ['NE'],
    canRecruitPilot: true,
    canVerifySubmission: false,
    canVerifyDecision: false,
    canShareAggregateData: false,
    canPubliclyNamePartner: false,
    canUsePartnerLogo: false,
    dataProtectionScope: null,
    safeguardingScope: { minors: true },
    agreementStorageKey: null,
    signedAt: new Date('2026-01-01T00:00:00.000Z'),
    startsAt: new Date('2026-01-01T00:00:00.000Z'),
    endsAt: new Date('2027-01-01T00:00:00.000Z'),
    ownerAdminId,
    lastVerifiedAt: null,
    createdAt: new Date('2026-01-01T00:00:00.000Z'),
    updatedAt: new Date('2026-01-01T00:00:00.000Z'),
    partner: { nameFr: 'UWC Niger', nameEn: 'UWC Niger' },
  };
}

function serviceWith(tx: Record<string, unknown>) {
  const prisma = {
    isEnabled: true,
    execute: jest.fn(async (operation: (db: object) => Promise<unknown>) =>
      operation({ $transaction: (callback: (client: object) => unknown) => callback(tx) }),
    ),
  } as unknown as PrismaService;
  const access = {
    assertAgreement: jest.fn().mockResolvedValue(undefined),
  } as unknown as AdminImpactAccessService;
  const idempotency = {
    reserve: jest.fn().mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-record-1',
    }),
    complete: jest.fn().mockResolvedValue({}),
  } as unknown as IdempotencyService;
  return new AdminPartnershipsService(
    prisma,
    access,
    idempotency,
    {} as DomainEventOutboxService,
  );
}

describe('AdminPartnershipsService security invariants', () => {
  it('rejects a string boolean before writing an immutable revision', async () => {
    const updateMany = jest.fn();
    const service = serviceWith({
      partnerAgreement: {
        findFirst: jest.fn().mockResolvedValue(agreement()),
        updateMany,
      },
    });

    await expect(
      service.revise(
        actor,
        'agreement-1',
        {
          expectedVersion: 1,
          changes: { canRecruitPilot: 'false' },
          reasonCode: 'contract_review',
        },
        'idem-1',
        'request-1',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(updateMany).not.toHaveBeenCalled();
  });

  it('does not accept a client-selected storage key', async () => {
    const service = serviceWith({});
    await expect(
      service.addEvidence(
        actor,
        'agreement-1',
        {
          kind: 'signed_contract',
          storageKey: '2026-01-01/00000000-0000-4000-8000-000000000000.pdf',
          reasonCode: 'contract_review',
        },
        'idem-1',
        'request-1',
      ),
    ).rejects.toThrow('Direct storage keys are disabled');
  });

  it('enforces HTTPS even when validation pipes are bypassed', async () => {
    const service = serviceWith({});
    await expect(
      service.addEvidence(
        actor,
        'agreement-1',
        {
          kind: 'signed_contract',
          externalUrl: 'http://partner.example.test/agreement.pdf',
          reasonCode: 'contract_review',
        },
        'idem-1',
        'request-1',
      ),
    ).rejects.toThrow('must use HTTPS');
  });

  it('requires a second operator to verify agreement evidence', async () => {
    const create = jest.fn();
    const service = serviceWith({
      partnerAgreement: {
        findFirst: jest.fn().mockResolvedValue(agreement('admin-1')),
      },
      partnerAgreementEvidence: { create },
    });
    await expect(
      service.addEvidence(
        actor,
        'agreement-1',
        {
          kind: 'signed_contract',
          externalUrl: 'https://partner.example.test/agreement.pdf',
          verified: true,
          reasonCode: 'contract_review',
        },
        'idem-1',
        'request-1',
      ),
    ).rejects.toThrow('second authorized operator');
    expect(create).not.toHaveBeenCalled();
  });
});
