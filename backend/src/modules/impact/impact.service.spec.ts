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
