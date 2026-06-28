import { PrismaService } from '../prisma/prisma.service';
import { ImpactService } from './impact.service';

/**
 * Guards KPB-71: impact stats must derive from real data, never hardcoded
 * constants. In particular satisfactionRate is null until reviews exist (no
 * fabricated "96%"), countriesCovered comes from the catalogue (not a literal
 * 9), and the former invented EUR figure is replaced by a real scholarship
 * count.
 */
describe('ImpactService.getStats', () => {
  function makePrisma(
    opts: {
      students?: number;
      completed?: number;
      orientation?: number;
      partners?: number;
      countries?: number;
      scholarships?: number;
      reviews?: number;
      avgRating?: number | null;
    } | null,
  ) {
    if (opts === null) {
      return { tryExecute: async () => null } as unknown as PrismaService;
    }
    const db = {
      userProfile: { count: async () => opts.students ?? 0 },
      case: { count: async () => opts.completed ?? 0 },
      orientationSession: { count: async () => opts.orientation ?? 0 },
      institution: { count: async () => opts.partners ?? 0 },
      country: { count: async () => opts.countries ?? 0 },
      scholarship: { count: async () => opts.scholarships ?? 0 },
      counsellorReview: {
        aggregate: async () => ({
          _avg: { rating: opts.avgRating ?? null },
          _count: { _all: opts.reviews ?? 0 },
        }),
      },
    };
    return {
      tryExecute: async (fn: (c: typeof db) => unknown) => fn(db),
    } as unknown as PrismaService;
  }

  it('derives real aggregates and leaves satisfaction null with no reviews', async () => {
    const svc = new ImpactService(
      makePrisma({
        students: 120,
        completed: 18,
        countries: 9,
        scholarships: 42,
        partners: 7,
        reviews: 0,
      }),
    );
    const s = await svc.getStats();
    expect(s.studentsGuided).toBe(120);
    expect(s.admissionsSecured).toBe(18);
    expect(s.countriesCovered).toBe(9); // from catalogue, not a literal
    expect(s.scholarshipsTracked).toBe(42);
    expect(s.partnerInstitutions).toBe(7);
    expect(s.satisfactionRate).toBeNull(); // never fabricated
    expect(s.reviewsCount).toBe(0);
    expect(s).not.toHaveProperty('scholarshipsValueEur');
    expect(s.generatedAt).toBeDefined();
  });

  it('computes satisfaction from published review ratings (1–5 → 0–100)', async () => {
    const svc = new ImpactService(
      makePrisma({ reviews: 8, avgRating: 4.5, countries: 9 }),
    );
    const s = await svc.getStats();
    expect(s.satisfactionRate).toBe(90);
    expect(s.reviewsCount).toBe(8);
  });

  it('degrades to zeros / null without a database', async () => {
    const svc = new ImpactService(makePrisma(null));
    const s = await svc.getStats();
    expect(s.studentsGuided).toBe(0);
    expect(s.countriesCovered).toBe(0);
    expect(s.scholarshipsTracked).toBe(0);
    expect(s.satisfactionRate).toBeNull();
  });
});

/**
 * Guards KPB-79: published-testimonials feed must surface only published
 * reviews, newest-first, capped, and must never leak PII (reviewerUserId,
 * caseId). It degrades to an empty list without a DB.
 */
describe('ImpactService.getPublishedReviews', () => {
  function makePrisma(
    rows:
      | Array<{
          id: string;
          counsellorId: string;
          reviewerName: string;
          rating: number;
          body: string;
          createdAt: Date;
        }>
      | null,
  ) {
    if (rows === null) {
      return { tryExecute: async () => null } as unknown as PrismaService;
    }
    // Capture the args Prisma is called with so we can assert the query shape.
    const captured: { args?: Record<string, unknown> } = {};
    const db = {
      counsellorReview: {
        findMany: async (args: Record<string, unknown>) => {
          captured.args = args;
          return rows;
        },
      },
    };
    const prisma = {
      tryExecute: async (fn: (c: typeof db) => unknown) => fn(db),
      __captured: captured,
    } as unknown as PrismaService & {
      __captured: { args?: Record<string, unknown> };
    };
    return prisma;
  }

  const sample = [
    {
      id: 'r1',
      counsellorId: 'c1',
      reviewerName: 'Aïcha',
      rating: 5,
      body: 'Super accompagnement',
      createdAt: new Date('2026-06-20T10:00:00.000Z'),
    },
    {
      id: 'r2',
      counsellorId: 'c2',
      reviewerName: 'Boris',
      rating: 4,
      body: 'Très utile',
      createdAt: new Date('2026-06-10T10:00:00.000Z'),
    },
  ];

  it('returns published-only reviews, newest first, capped by limit', async () => {
    const prisma = makePrisma(sample) as unknown as PrismaService & {
      __captured: { args?: Record<string, unknown> };
    };
    const svc = new ImpactService(prisma);

    const out = await svc.getPublishedReviews(10);

    expect(out.count).toBe(2);
    expect(out.reviews.map((r) => r.id)).toEqual(['r1', 'r2']);

    const args = prisma.__captured.args!;
    // Published-only filter
    expect(args.where).toEqual({ isPublished: true });
    // Newest first
    expect(args.orderBy).toEqual({ createdAt: 'desc' });
    // Limit honoured
    expect(args.take).toBe(10);
  });

  it('respects a custom limit', async () => {
    const prisma = makePrisma(sample) as unknown as PrismaService & {
      __captured: { args?: Record<string, unknown> };
    };
    const svc = new ImpactService(prisma);

    await svc.getPublishedReviews(3);
    expect(prisma.__captured.args!.take).toBe(3);
  });

  it('selects only public-safe fields — no reviewerUserId or caseId', async () => {
    const prisma = makePrisma(sample) as unknown as PrismaService & {
      __captured: { args?: Record<string, unknown> };
    };
    const svc = new ImpactService(prisma);

    await svc.getPublishedReviews();

    const select = prisma.__captured.args!.select as Record<string, boolean>;
    expect(select).toEqual({
      id: true,
      counsellorId: true,
      reviewerName: true,
      rating: true,
      body: true,
      createdAt: true,
    });
    expect(select).not.toHaveProperty('reviewerUserId');
    expect(select).not.toHaveProperty('caseId');
  });

  it('serialises createdAt to an ISO string', async () => {
    const prisma = makePrisma(sample);
    const svc = new ImpactService(prisma);

    const out = await svc.getPublishedReviews();
    expect(out.reviews[0].createdAt).toBe('2026-06-20T10:00:00.000Z');
  });

  it('degrades to an empty list without a database', async () => {
    const svc = new ImpactService(makePrisma(null));
    const out = await svc.getPublishedReviews();
    expect(out).toEqual({ reviews: [], count: 0 });
  });
});
