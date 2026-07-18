import { InternalRole } from '../../../common/enums/internal-role.enum';
import type { AdminSessionUser } from '../../auth/auth.service';
import type { PrismaService } from '../../prisma/prisma.service';
import { AdminOutcomesAccessService } from './admin-outcomes-access.service';

describe('AdminOutcomesAccessService', () => {
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const service = new AdminOutcomesAccessService(prisma);

  const actor = (
    role: InternalRole,
    id = 'admin-1',
  ): AdminSessionUser => ({
    id,
    role,
    email: `${id}@kpb.education`,
    fullName: id,
    languageScope: ['fr'],
  });

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_COMPETITION_READINESS_ENABLED = 'true';
    process.env.KPB_SUCCESS_LAB_ENABLED = 'true';
    process.env.KPB_OUTCOME_EVIDENCE_ENABLED = 'true';
  });

  it('rejects commercial operators before reading outcome data', async () => {
    await expect(
      service.whereFor(actor(InternalRole.Commercial), 'submission'),
    ).rejects.toMatchObject({ status: 403 });
    expect(execute).not.toHaveBeenCalled();
  });

  it('rejects an admin without an active verify_outcomes grant', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({ adminScopeGrant: { findMany: jest.fn().mockResolvedValue([]) } }),
    );

    await expect(
      service.whereFor(actor(InternalRole.Admin), 'admission'),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('allows super admin to bypass grants but still respects an explicit country filter', async () => {
    const findCountries = jest.fn().mockResolvedValue([
      { id: 'country-ne', code: 'NE' },
    ]);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({ country: { findMany: findCountries } }),
    );

    const where = await service.whereFor(
      actor(InternalRole.SuperAdmin),
      'funding',
      'NE',
    );

    expect(where).toEqual({
      workspace: {
        scholarship: {
          countryId: { in: expect.arrayContaining(['NE', 'country-ne']) },
        },
      },
    });
  });

  it('builds a country and resource bounded scope for moderators', async () => {
    const grants = [
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: {
          workspaceIds: ['workspace-1'],
          scholarshipIds: ['scholarship-1'],
        },
      },
    ];
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        adminScopeGrant: { findMany: jest.fn().mockResolvedValue(grants) },
        country: {
          findMany: jest
            .fn()
            .mockResolvedValue([{ id: 'country-ne', code: 'NE' }]),
        },
      }),
    );

    const where = await service.whereFor(
      actor(InternalRole.Moderator),
      'submission',
    );

    expect(JSON.stringify(where)).toContain('workspace-1');
    expect(JSON.stringify(where)).toContain('scholarship-1');
    expect(JSON.stringify(where)).toContain('country-ne');
  });

  it('blocks a verifier who was the assigned counsellor on the same workspace', async () => {
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        counsellor: {
          findFirst: jest.fn().mockResolvedValue({ id: 'counsellor-1' }),
        },
        studyReviewRequest: {
          findFirst: jest.fn().mockResolvedValue({ id: 'review-1' }),
        },
      }),
    );

    await expect(
      service.assertIndependentVerifier(actor(InternalRole.Admin), {
        id: 'submission-1',
        workspaceId: 'workspace-1',
      }),
    ).rejects.toMatchObject({ status: 403 });
  });

  it('keeps outcome access dark when the Success Lab master flag is off', async () => {
    process.env.KPB_SUCCESS_LAB_ENABLED = 'false';
    await expect(
      service.whereFor(actor(InternalRole.SuperAdmin), 'submission'),
    ).rejects.toMatchObject({ status: 404 });
    expect(execute).not.toHaveBeenCalled();
  });
});
