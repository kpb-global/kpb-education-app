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

function prismaFor(client: object): PrismaService {
  return {
    isEnabled: true,
    execute: jest.fn(async (operation: (db: object) => Promise<unknown>) =>
      operation(client),
    ),
  } as unknown as PrismaService;
}
