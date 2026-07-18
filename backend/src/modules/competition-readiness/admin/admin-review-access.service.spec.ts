import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { PrismaService } from '../../prisma/prisma.service';
import {
  ADMIN_REVIEW_CAPABILITIES,
  AdminReviewAccessService,
  type AdminReviewActor,
} from './admin-review-access.service';

describe('AdminReviewAccessService', () => {
  const activeGrant = {
    countryCodes: [],
    cohortIds: [],
    resourceScope: null,
  };
  const adminScopeGrantFindMany = jest.fn();
  const counsellorFindFirst = jest.fn();
  const counsellorFindUnique = jest.fn();
  const countryFindMany = jest.fn();
  const studyReviewFindUnique = jest.fn();
  const database = {
    adminScopeGrant: { findMany: adminScopeGrantFindMany },
    counsellor: {
      findFirst: counsellorFindFirst,
      findUnique: counsellorFindUnique,
    },
    country: { findMany: countryFindMany },
    studyReviewRequest: { findUnique: studyReviewFindUnique },
  };
  const execute = jest.fn(
    async (operation: (client: typeof database) => unknown) =>
      operation(database),
  );
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const service = new AdminReviewAccessService(prisma);

  const admin = actor(InternalRole.Admin, 'admin-1');
  const counselor = actor(InternalRole.Counselor, 'admin-counselor-1');
  const commercial = actor(InternalRole.Commercial, 'commercial-1');

  beforeEach(() => {
    jest.clearAllMocks();
    adminScopeGrantFindMany.mockResolvedValue([activeGrant]);
    counsellorFindFirst.mockResolvedValue({
      id: 'counsellor-1',
      fullName: 'Awa Conseillere',
      adminUserId: counselor.id,
    });
    countryFindMany.mockResolvedValue([]);
    counsellorFindUnique.mockResolvedValue({
      id: 'counsellor-1',
      countryOfResidence: 'NE',
    });
    studyReviewFindUnique.mockResolvedValue(
      review({ assignedCounsellorId: null, status: 'submitted' }),
    );
  });

  it('accepts an active capability grant and asks Prisma to exclude expired or revoked grants', async () => {
    await expect(
      service.assertCapability(admin, ADMIN_REVIEW_CAPABILITIES.viewAssigned),
    ).resolves.toBeUndefined();

    expect(adminScopeGrantFindMany).toHaveBeenCalledTimes(1);
    const query = adminScopeGrantFindMany.mock.calls[0][0] as {
      where: {
        adminUserId: string;
        capability: string;
        startsAt: { lte: Date };
        revokedAt: null;
        OR: [{ expiresAt: null }, { expiresAt: { gt: Date } }];
      };
    };
    expect(query.where).toMatchObject({
      adminUserId: admin.id,
      capability: ADMIN_REVIEW_CAPABILITIES.viewAssigned,
      revokedAt: null,
      OR: [
        { expiresAt: null },
        { expiresAt: { gt: expect.any(Date) } },
      ],
    });
    expect(query.where.startsAt.lte).toBeInstanceOf(Date);
    expect(query.where.startsAt.lte).toBe(query.where.OR[1].expiresAt.gt);
  });

  it.each(['expired', 'revoked']) (
    'fails closed when Prisma excludes a %s capability grant',
    async () => {
      adminScopeGrantFindMany.mockResolvedValue([]);

      await expect(
        service.assertCapability(
          admin,
          ADMIN_REVIEW_CAPABILITIES.viewAssigned,
        ),
      ).rejects.toMatchObject({
        status: 403,
        response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
      });
    },
  );

  it('resolves an active counselor through the stable admin-user link', async () => {
    await expect(service.resolveCounsellor(counselor)).resolves.toEqual({
      id: 'counsellor-1',
      fullName: 'Awa Conseillere',
      adminUserId: counselor.id,
    });

    expect(counsellorFindFirst).toHaveBeenCalledWith({
      where: {
        isActive: true,
        OR: [
          { adminUserId: counselor.id },
          {
            adminUserId: null,
            email: { equals: counselor.email, mode: 'insensitive' },
          },
        ],
      },
      select: { id: true, fullName: true, adminUserId: true },
    });
  });

  it('rejects a counselor actor that has no active linked counselor record', async () => {
    counsellorFindFirst.mockResolvedValue(null);

    await expect(service.resolveCounsellor(counselor)).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
  });

  it('allows an assigned linked counselor to open evidence', async () => {
    await expect(
      service.assertCanOpenEvidence(
        counselor,
        review({ assignedCounsellorId: 'counsellor-1' }),
      ),
    ).resolves.toBeUndefined();

    expect(adminScopeGrantFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          capability: ADMIN_REVIEW_CAPABILITIES.viewEvidence,
        }),
      }),
    );
    expect(counsellorFindFirst).toHaveBeenCalledTimes(1);
  });

  it('rejects a linked counselor when the review is unassigned or assigned elsewhere', async () => {
    for (const assignedCounsellorId of [null, 'counsellor-2']) {
      await expect(
        service.assertCanOpenEvidence(
          counselor,
          review({ assignedCounsellorId }),
        ),
      ).rejects.toMatchObject({
        status: 403,
        response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
      });
    }
  });

  it('fails closed when an availability grant country does not cover the counselor', async () => {
    adminScopeGrantFindMany.mockResolvedValue([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: null,
      },
    ]);
    countryFindMany.mockResolvedValue([{ id: 'country-ne', code: 'NE' }]);
    counsellorFindUnique.mockResolvedValue({
      id: 'counsellor-sn',
      countryOfResidence: 'SN',
    });

    await expect(
      service.assertCanManageCounsellor(admin, 'counsellor-sn'),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
  });

  it('fails closed when an availability country grant cannot be canonically resolved', async () => {
    adminScopeGrantFindMany.mockResolvedValue([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: null,
      },
    ]);
    countryFindMany.mockResolvedValue([]);
    counsellorFindUnique.mockResolvedValue({
      id: 'counsellor-1',
      countryOfResidence: 'NE',
    });

    await expect(
      service.assertCanManageCounsellor(admin, 'counsellor-1'),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
  });

  it('combines country and explicit counselor scope for the redacted selector', async () => {
    adminScopeGrantFindMany.mockResolvedValue([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: { counsellorIds: ['counsellor-1'] },
      },
    ]);
    countryFindMany.mockResolvedValue([{ id: 'country-ne', code: 'NE' }]);

    await expect(service.manageableCounsellorScope(admin)).resolves.toEqual({
      OR: [
        {
          AND: [
            { id: { in: ['counsellor-1'] } },
            {
              countryOfResidence: {
                in: expect.arrayContaining(['NE', 'country-ne']),
              },
            },
          ],
        },
      ],
    });
  });

  it('derives an exact assign-only counselor selector for the requested review', async () => {
    adminScopeGrantFindMany.mockResolvedValue([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: {
          reviewRequestIds: ['review-1'],
          counsellorIds: ['counsellor-1'],
        },
      },
    ]);
    countryFindMany.mockResolvedValue([{ id: 'country-ne', code: 'NE' }]);

    await expect(
      service.selectableCounsellorScope(admin, 'review-1'),
    ).resolves.toEqual({ OR: [{ id: { in: ['counsellor-1'] } }] });
    expect(adminScopeGrantFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          capability: ADMIN_REVIEW_CAPABILITIES.assign,
        }),
      }),
    );
  });

  it('rejects an assign-only selector when the grant does not cover the requested review', async () => {
    adminScopeGrantFindMany.mockResolvedValue([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: { reviewRequestIds: ['review-other'] },
      },
    ]);
    countryFindMany.mockResolvedValue([{ id: 'country-ne', code: 'NE' }]);

    await expect(
      service.selectableCounsellorScope(admin, 'review-1'),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
  });

  it('allows commercial detail only for a commercial-visible status with metadata capability', async () => {
    await expect(
      service.assertCanReadDetail(
        commercial,
        review({ assignedCounsellorId: null, status: 'triaged' }),
      ),
    ).resolves.toBe('metadata');
    expect(adminScopeGrantFindMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          capability: ADMIN_REVIEW_CAPABILITIES.viewMetadata,
        }),
      }),
    );
  });

  it('rejects commercial detail for submitted requests before reading private data', async () => {
    await expect(
      service.assertCanReadDetail(
        commercial,
        review({ assignedCounsellorId: null, status: 'submitted' }),
      ),
    ).rejects.toMatchObject({
      status: 403,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
    expect(adminScopeGrantFindMany).not.toHaveBeenCalled();
  });
});

function actor(role: InternalRole, id: string): AdminReviewActor {
  return {
    id,
    email: `${id}@kpb.education`,
    fullName: id,
    role,
  };
}

function review({
  assignedCounsellorId,
  status,
}: {
  assignedCounsellorId: string | null;
  status?: string;
}) {
  return {
    id: 'review-1',
    status,
    assignedCounsellorId,
    workspace: {
      scholarshipId: 'scholarship-1',
      scholarship: { id: 'scholarship-1', countryId: 'country-ne' },
    },
  };
}
