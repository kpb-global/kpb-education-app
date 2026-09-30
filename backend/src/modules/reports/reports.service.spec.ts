import { PrismaService } from '../prisma/prisma.service';
import { ReportsService } from './reports.service';

describe('ReportsService — verified outcomes', () => {
  it('builds the overview from current verified outcomes, never Case.completed', async () => {
    const caseCount = jest
      .fn()
      .mockResolvedValueOnce(8)
      .mockResolvedValueOnce(3);
    const submissionCount = jest.fn().mockResolvedValue(6);
    const decisionCount = jest.fn(
      async (args: { where: { admissionDecision?: string } }) =>
        args.where.admissionDecision === 'admitted' ? 4 : 7,
    );
    const fundingCount = jest.fn().mockResolvedValue(2);
    const db = {
      case: {
        count: caseCount,
        findMany: jest.fn().mockResolvedValue([]),
      },
      applicationSubmission: { count: submissionCount },
      applicationDecisionRecord: { count: decisionCount },
      fundingDecisionRecord: { count: fundingCount },
      servicePurchase: { count: jest.fn().mockResolvedValue(5) },
    };
    const service = new ReportsService(prismaFor(db));

    const result = await service.getOverview();

    expect(result).toMatchObject({
      activeCases: 8,
      awaitingDocuments: 3,
      submittedThisWeek: 6,
      admissionsSecured: 4,
      scholarshipsSecured: 2,
      knownDecisions: 7,
      paidServicePurchases: 5,
    });
    expect(submissionCount).toHaveBeenCalledWith({
      where: {
        verificationStatus: 'verified',
        submittedAt: { gte: expect.any(Date) },
      },
    });
    expect(decisionCount).toHaveBeenNthCalledWith(1, {
      where: {
        isCurrent: true,
        admissionDecision: 'admitted',
        verificationStatus: 'verified',
      },
    });
    expect(decisionCount).toHaveBeenNthCalledWith(2, {
      where: { isCurrent: true, verificationStatus: 'verified' },
    });
    expect(fundingCount).toHaveBeenCalledWith({
      where: {
        isCurrent: true,
        fundingDecision: { in: ['full', 'partial'] },
        verificationStatus: 'verified',
      },
    });
    expect(caseCount).not.toHaveBeenCalledWith({
      where: { status: 'completed' },
    });
  });

  it('uses verified submission outcomes for the funnel application stage', async () => {
    const caseCount = jest.fn().mockResolvedValue(12);
    const submissionCount = jest.fn().mockResolvedValue(9);
    const db = {
      userProfile: { count: jest.fn().mockResolvedValue(100) },
      case: { count: caseCount },
      applicationSubmission: { count: submissionCount },
      servicePurchase: { count: jest.fn().mockResolvedValue(4) },
    };
    const service = new ReportsService(prismaFor(db));

    await expect(service.getFunnel()).resolves.toEqual({
      items: [
        { key: 'studentSignups', value: 100 },
        { key: 'casesCreated', value: 12 },
        { key: 'applicationsSubmitted', value: 9 },
        { key: 'paidServicePurchases', value: 4 },
      ],
    });
    expect(submissionCount).toHaveBeenCalledWith({
      where: { verificationStatus: 'verified' },
    });
    expect(caseCount).toHaveBeenCalledTimes(1);
    expect(caseCount).toHaveBeenCalledWith();
  });

  it('returns honest zero outcome metrics when the database is disabled', async () => {
    const service = new ReportsService({
      isEnabled: false,
      execute: jest.fn(),
    } as unknown as PrismaService);

    await expect(service.getOverview()).resolves.toMatchObject({
      submittedThisWeek: 0,
      admissionsSecured: 0,
      scholarshipsSecured: 0,
      knownDecisions: 0,
    });
    await expect(service.getFunnel()).resolves.toEqual({ items: [] });
  });
});

/**
 * Le compteur « Action immédiate requise » du tableau de bord.
 *
 * Il additionne pays, établissements, formations et bourses à revérifier. Sa
 * règle « à revérifier » vivait en DEUX exemplaires, l'un dans la file admin,
 * l'autre ici — et la revue de l'import « Études en France » n'avait d'abord
 * trouvé que le premier. Sans exclusion, ce chiffre aurait affiché « 10 600 »
 * dès l'import, pour des fiches qui n'ont jamais été publiées.
 */
describe('ReportsService — compteur « Action immédiate requise »', () => {
  function dashboardDb(counts: {
    institutions?: number;
    programs?: number;
    countries?: number;
    scholarships?: number;
  }) {
    const wheres: Record<string, unknown[]> = { institution: [], program: [] };
    const db = {
      case: {
        findMany: jest.fn().mockResolvedValue([]),
        count: jest.fn().mockResolvedValue(0),
      },
      country: { count: jest.fn().mockResolvedValue(counts.countries ?? 0) },
      institution: {
        count: jest.fn(async (args: { where: unknown }) => {
          wheres.institution.push(args.where);
          return counts.institutions ?? 0;
        }),
      },
      program: {
        count: jest.fn(async (args: { where: unknown }) => {
          wheres.program.push(args.where);
          return counts.programs ?? 0;
        }),
      },
      scholarship: {
        count: jest.fn().mockResolvedValue(counts.scholarships ?? 0),
      },
      forumModerationAction: { count: jest.fn().mockResolvedValue(0) },
    };
    return { db, wheres };
  }

  it('additionne les quatre familles à revérifier', async () => {
    const { db } = dashboardDb({
      countries: 1,
      institutions: 2,
      programs: 30,
      scholarships: 4,
    });
    const result = await new ReportsService(prismaFor(db)).getDashboardActivation();
    expect(result.urgent.verificationDue).toBe(37);
  });

  it('ne compte jamais une ligne EEF importée et pas encore publiée', async () => {
    const { db, wheres } = dashboardDb({});

    await new ReportsService(prismaFor(db)).getDashboardActivation();

    expect((wheres.program[0] as { AND: unknown[] }).AND).toContainEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-prog-' } }, { isActive: false }],
      },
    });
    expect((wheres.institution[0] as { AND: unknown[] }).AND).toContainEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-univ-' } }, { isActive: false }],
      },
    });
  });

  // « Utilise la MÊME règle que la file admin » ne se prouve pas ici : on ne voit
  // que ce service. La comparaison des deux, catégorie par catégorie, sur une
  // horloge figée, vit dans `admin-catalog/verification-due.consumers.spec.ts` —
  // là où les deux services sont sous les yeux du même test.
});

function prismaFor(client: object): PrismaService {
  return {
    isEnabled: true,
    execute: jest.fn(async (operation: (db: object) => Promise<unknown>) =>
      operation(client),
    ),
  } as unknown as PrismaService;
}
