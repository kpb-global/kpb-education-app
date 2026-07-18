import { BadRequestException } from '@nestjs/common';

import type { PrismaService } from '../../prisma/prisma.service';
import type { AdminImpactAccessService } from '../admin/admin-impact-access.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { IdempotencyService } from '../common/idempotency.service';
import {
  assertResearchPayload,
  ImpactPilotsService,
} from './impact-pilots.service';

type Consent = {
  grantedAt: Date;
  notice: { purpose: string; effectiveAt: Date; retiredAt: Date | null };
  guardianAuthorization: {
    minorUserId: string;
    status: string;
    verifiedAt: Date | null;
    expiresAt: Date | null;
    revokedAt: Date | null;
  } | null;
  user: { birthDate: Date | null; countryOfResidence: string };
};

function service() {
  return new ImpactPilotsService(
    {} as PrismaService,
    {} as AdminImpactAccessService,
    {} as IdempotencyService,
    {} as DomainEventOutboxService,
  );
}

function assertConsent(consent: Consent | null, now: Date) {
  const target = service() as unknown as {
    assertActivePilotConsent(value: Consent | null, userId: string, at: Date): void;
  };
  return () => target.assertActivePilotConsent(consent, 'student-1', now);
}

function assertRecruitmentCoverage(
  agreements: Array<{
    isCurrent: boolean;
    status: string;
    canRecruitPilot: boolean;
    canShareAggregateData: boolean;
    purposeCodes: string[];
    countryCodes: string[];
    startsAt: Date | null;
    endsAt: Date | null;
  }>,
  countryCodes: string[],
) {
  const target = service() as unknown as {
    assertRecruitingAgreement(
      values: typeof agreements,
      pilot: { countryCodes: string[]; recruitmentStartsAt: Date | null; endsAt: Date | null },
      now: Date,
    ): void;
  };
  return () =>
    target.assertRecruitingAgreement(
      agreements,
      { countryCodes, recruitmentStartsAt: null, endsAt: null },
      new Date(),
    );
}

describe('ImpactPilotsService consent and minimisation', () => {
  const now = new Date('2026-07-18T12:00:00.000Z');
  const base: Consent = {
    grantedAt: new Date('2026-07-01T00:00:00.000Z'),
    notice: {
      purpose: 'pilot_research',
      effectiveAt: new Date('2026-06-01T00:00:00.000Z'),
      retiredAt: null,
    },
    guardianAuthorization: null,
    user: {
      birthDate: new Date('2000-01-01T00:00:00.000Z'),
      countryOfResidence: 'NE',
    },
  };

  it('accepts an adult under the current pilot notice', () => {
    expect(assertConsent(base, now)).not.toThrow();
  });

  it('fails closed when birth date is absent or notice is retired', () => {
    expect(
      assertConsent({ ...base, user: { ...base.user, birthDate: null } }, now),
    ).toThrow(BadRequestException);
    expect(
      assertConsent(
        {
          ...base,
          notice: {
            ...base.notice,
            retiredAt: new Date('2026-07-10T00:00:00.000Z'),
          },
        },
        now,
      ),
    ).toThrow(BadRequestException);
  });

  it('requires a non-expired verified guardian authorization for a minor', () => {
    const minor = {
      ...base,
      user: {
        ...base.user,
        birthDate: new Date('2012-01-01T00:00:00.000Z'),
      },
      guardianAuthorization: {
        minorUserId: 'student-1',
        status: 'verified',
        verifiedAt: new Date('2026-06-30T00:00:00.000Z'),
        expiresAt: new Date('2026-07-17T00:00:00.000Z'),
        revokedAt: null,
      },
    } satisfies Consent;
    expect(assertConsent(minor, now)).toThrow('guardian authorization');
    expect(
      assertConsent(
        {
          ...minor,
          guardianAuthorization: {
            ...minor.guardianAuthorization,
            expiresAt: new Date('2027-01-01T00:00:00.000Z'),
          },
        },
        now,
      ),
    ).not.toThrow();
  });

  it('rejects PII keys and oversized research payloads', () => {
    expect(() => assertResearchPayload({ email: 'student@example.test' }, 'answers')).toThrow(
      'prohibited personal-data',
    );
    expect(() =>
      assertResearchPayload({ rubric: 'x'.repeat(33 * 1024) }, 'answers'),
    ).toThrow('32 KB');
  });

  it('requires active partner agreements to cover every country of a multi-country pilot', () => {
    const agreement = {
      isCurrent: true,
      status: 'active',
      canRecruitPilot: true,
      canShareAggregateData: true,
      purposeCodes: ['pilot_research'],
      countryCodes: ['NE'],
      startsAt: null,
      endsAt: null,
    };
    expect(assertRecruitmentCoverage([agreement], ['NE', 'CI'])).toThrow(
      'covering its window and countries',
    );
    expect(
      assertRecruitmentCoverage(
        [agreement, { ...agreement, countryCodes: ['CI'] }],
        ['NE', 'CI'],
      ),
    ).not.toThrow();
    expect(
      assertRecruitmentCoverage([{ ...agreement, countryCodes: [] }], ['NE', 'CI']),
    ).not.toThrow();
  });
});
