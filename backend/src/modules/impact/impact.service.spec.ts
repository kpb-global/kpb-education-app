import { PrismaService } from '../prisma/prisma.service';
import { ImpactService } from './impact.service';

const IMPACT_FLAGS = [
  'KPB_COMPETITION_READINESS_ENABLED',
  'KPB_IMPACT_PUBLIC_STATS_ENABLED',
] as const;

type SnapshotMetric = {
  metricKey: string;
  metricVersion: number;
  value: number;
  sampleSize: number;
  caveat: null | string;
};

type PublishedReviewRow = {
  id: string;
  counsellorId: string;
  reviewerName: string;
  rating: number;
  body: string;
  createdAt: Date;
};

function metric(metricKey: string, value: number, sampleSize = 20): SnapshotMetric {
  return { metricKey, metricVersion: 1, value, sampleSize, caveat: null };
}

function activeTestimonialReceipt(overrides: Record<string, unknown> = {}) {
  return {
    userId: 'student-1',
    purpose: 'public_testimonial',
    grantedAt: new Date('2026-01-01T00:00:00.000Z'),
    revokedAt: null,
    user: { birthDate: new Date('1998-01-01T00:00:00.000Z') },
    notice: {
      purpose: 'public_testimonial',
      effectiveAt: new Date('2025-12-01T00:00:00.000Z'),
      retiredAt: null,
    },
    guardianAuthorization: null,
    ...overrides,
  };
}

function makePrisma(options: {
  snapshot?: { metrics: SnapshotMetric[]; generatedAt: Date } | null;
  orientationSessions?: number;
  partners?: Array<{ partnerId: string }>;
  countries?: number;
  scholarships?: number;
  testimonialReceipts?: ReturnType<typeof activeTestimonialReceipt>[];
  reviewAggregate?: { average: number | null; count: number };
  reviews?: PublishedReviewRow[];
  available?: boolean;
} = {}) {
  const db = {
    impactSnapshot: {
      findFirst: jest.fn().mockResolvedValue(options.snapshot ?? null),
    },
    orientationSession: {
      count: jest.fn().mockResolvedValue(options.orientationSessions ?? 0),
    },
    partnerAgreement: {
      findMany: jest.fn().mockResolvedValue(options.partners ?? []),
    },
    country: { count: jest.fn().mockResolvedValue(options.countries ?? 0) },
    scholarship: {
      count: jest.fn().mockResolvedValue(options.scholarships ?? 0),
    },
    consentReceipt: {
      findMany: jest
        .fn()
        .mockResolvedValue(options.testimonialReceipts ?? []),
    },
    counsellorReview: {
      aggregate: jest.fn().mockResolvedValue({
        _avg: { rating: options.reviewAggregate?.average ?? null },
        _count: { _all: options.reviewAggregate?.count ?? 0 },
      }),
      findMany: jest.fn().mockResolvedValue(options.reviews ?? []),
    },
  };
  const prisma = {
    execute: jest.fn(async (operation: (client: typeof db) => unknown) =>
      options.available === false ? null : operation(db),
    ),
    __db: db,
  } as unknown as PrismaService & { __db: typeof db };
  return prisma;
}

describe('ImpactService public impact', () => {
  const previousEnvironment = Object.fromEntries(
    IMPACT_FLAGS.map((key) => [key, process.env[key]]),
  ) as Record<(typeof IMPACT_FLAGS)[number], string | undefined>;

  beforeEach(() => {
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED = 'true';
  });

  afterAll(() => {
    for (const key of IMPACT_FLAGS) {
      const value = previousEnvironment[key];
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  });

  it('derives public outcome claims only from one immutable public-safe snapshot', async () => {
    const prisma = makePrisma({
      snapshot: {
        metrics: [
          metric('pilot_participants', 120, 120),
          metric('verified_submissions', 31, 31),
          metric('verified_admissions', 18, 20),
          metric('verified_funding_awards', 11, 20),
        ],
        generatedAt: new Date('2026-07-01T00:00:00.000Z'),
      },
      orientationSessions: 14,
      partners: [{ partnerId: 'partner-a' }, { partnerId: 'partner-b' }],
      countries: 9,
      scholarships: 42,
      testimonialReceipts: [activeTestimonialReceipt()],
      reviewAggregate: { average: 4.5, count: 8 },
    });

    const stats = await new ImpactService(prisma).getStats();

    expect(stats).toMatchObject({
      studentsGuided: 120,
      admissionsSecured: 18,
      verifiedApplicationsSubmitted: 31,
      scholarshipsSecured: 11,
      knownDecisions: 18,
      orientationSessions: 14,
      partnerInstitutions: 2,
      countriesCovered: 9,
      scholarshipsTracked: 42,
      satisfactionRate: 90,
      reviewsCount: 8,
      generatedAt: '2026-07-01T00:00:00.000Z',
    });
    expect(prisma.__db.impactSnapshot.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { isPublicSafe: true } }),
    );
    expect(prisma.__db.partnerAgreement.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ isCurrent: true, status: 'active' }),
        distinct: ['partnerId'],
      }),
    );
    expect(prisma.__db).not.toHaveProperty('userProfile');
    expect(prisma.__db).not.toHaveProperty('case');
    expect(prisma.__db).not.toHaveProperty('applicationSubmission');
  });

  it('suppresses invalid, duplicated, caveated, and small public metric cells', async () => {
    const prisma = makePrisma({
      snapshot: {
        metrics: [
          metric('pilot_participants', 19, 19),
          metric('verified_submissions', 4, 20),
          metric('verified_submissions', 5, 20),
          { ...metric('verified_admissions', 7, 20), caveat: 'provisional' },
          { ...metric('verified_funding_awards', 3, 20), metricVersion: 2 },
        ],
        generatedAt: new Date('2026-07-01T00:00:00.000Z'),
      },
    });

    const stats = await new ImpactService(prisma).getStats();

    expect(stats.studentsGuided).toBe(0);
    expect(stats.verifiedApplicationsSubmitted).toBe(0);
    expect(stats.admissionsSecured).toBe(0);
    expect(stats.scholarshipsSecured).toBe(0);
  });

  it('requires both public-impact flags and fails closed when the database is unavailable', async () => {
    process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED = 'false';
    await expect(new ImpactService(makePrisma()).getStats()).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'FEATURE_DISABLED' }),
    });

    process.env.KPB_IMPACT_PUBLIC_STATS_ENABLED = 'true';
    await expect(
      new ImpactService(makePrisma({ available: false })).getStats(),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'DATABASE_UNAVAILABLE' }),
    });
  });

  it('releases published testimonials only for active, eligible consent receipts', async () => {
    const rows: PublishedReviewRow[] = [
      {
        id: 'review-1',
        counsellorId: 'counsellor-1',
        reviewerName: 'Aïcha',
        rating: 5,
        body: 'Super accompagnement',
        createdAt: new Date('2026-06-20T10:00:00.000Z'),
      },
    ];
    const prisma = makePrisma({
      testimonialReceipts: [activeTestimonialReceipt()],
      reviews: rows,
    });

    const published = await new ImpactService(prisma).getPublishedReviews(10);

    expect(published).toEqual({
      reviews: [
        {
          ...rows[0],
          createdAt: '2026-06-20T10:00:00.000Z',
        },
      ],
      count: 1,
    });
    expect(prisma.__db.counsellorReview.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          isPublished: true,
          reviewerUserId: { not: null, in: ['student-1'] },
        },
        orderBy: { createdAt: 'desc' },
        take: 10,
        select: expect.not.objectContaining({ reviewerUserId: expect.anything() }),
      }),
    );
  });

  it('excludes a minor testimonial without a current guardian authorization', async () => {
    const prisma = makePrisma({
      testimonialReceipts: [
        activeTestimonialReceipt({
          user: { birthDate: new Date('2012-01-01T00:00:00.000Z') },
        }),
      ],
      reviews: [
        {
          id: 'review-1',
          counsellorId: 'counsellor-1',
          reviewerName: 'Aïcha',
          rating: 5,
          body: 'Super accompagnement',
          createdAt: new Date('2026-06-20T10:00:00.000Z'),
        },
      ],
    });

    await expect(new ImpactService(prisma).getPublishedReviews()).resolves.toEqual({
      reviews: [],
      count: 0,
    });
    expect(prisma.__db.counsellorReview.findMany).not.toHaveBeenCalled();
  });

  it('fails closed for published reviews when the database is unavailable', async () => {
    await expect(
      new ImpactService(makePrisma({ available: false })).getPublishedReviews(),
    ).rejects.toMatchObject({
      response: expect.objectContaining({ code: 'DATABASE_UNAVAILABLE' }),
    });
  });
});
