import type { PrismaService } from '../../prisma/prisma.service';
import {
  ADMIN_IMPACT_CAPABILITIES,
  AdminImpactAccessService,
} from './admin-impact-access.service';

function service(grants: unknown[]) {
  const client = {
    adminScopeGrant: {
      findMany: jest.fn().mockResolvedValue(grants),
    },
  };
  const prisma = {
    isEnabled: true,
    execute: jest.fn(async (operation: (db: typeof client) => unknown) =>
      operation(client),
    ),
  } as unknown as PrismaService;
  return new AdminImpactAccessService(prisma);
}

const actor = {
  id: 'admin-1',
  email: 'admin@example.test',
  fullName: 'Admin One',
  role: 'admin',
  languageScope: ['fr'],
};

describe('AdminImpactAccessService', () => {
  it('enforces the coarse role matrix before scoped grants', async () => {
    const grant = {
      countryCodes: [],
      cohortIds: [],
      resourceScope: null,
    };
    const target = service([grant]);
    const commercial = { ...actor, role: 'commercial' };
    const moderator = { ...actor, role: 'moderator' };

    await expect(
      target.listScope(
        commercial,
        ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
      ),
    ).resolves.toBeDefined();
    await expect(
      target.listScope(
        commercial,
        ADMIN_IMPACT_CAPABILITIES.recruitPilotParticipants,
      ),
    ).resolves.toBeDefined();
    await expect(
      target.listScope(
        commercial,
        ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates,
      ),
    ).rejects.toMatchObject({ status: 403 });

    await expect(
      target.listScope(
        moderator,
        ADMIN_IMPACT_CAPABILITIES.viewPilotAggregates,
      ),
    ).resolves.toBeDefined();
    await expect(
      target.listScope(
        moderator,
        ADMIN_IMPACT_CAPABILITIES.managePilots,
      ),
    ).rejects.toMatchObject({ status: 403 });

    await expect(
      target.listScope(
        actor,
        ADMIN_IMPACT_CAPABILITIES.freezeImpactSnapshots,
      ),
    ).resolves.toBeDefined();
  });

  it('fails closed without a grant and lets super-admin bypass grants', async () => {
    const target = service([]);
    await expect(
      target.listScope(actor, ADMIN_IMPACT_CAPABILITIES.managePilots),
    ).rejects.toMatchObject({ status: 403 });

    await expect(
      target.listScope(
        { ...actor, role: 'super_admin' },
        ADMIN_IMPACT_CAPABILITIES.managePilots,
      ),
    ).resolves.toEqual({
      grants: null,
      countryCodes: null,
      resources: null,
    });
  });

  it('applies a country-only grant to otherwise unrestricted resources', async () => {
    const target = service([
      { countryCodes: ['NE'], cohortIds: [], resourceScope: null },
    ]);
    const scope = await target.listScope(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
    );
    expect(
      target.agreementCovered(scope, {
        id: 'agreement-ne',
        partnerId: 'partner-1',
        countryCodes: ['NE'],
      }),
    ).toBe(true);
    expect(
      target.agreementCovered(scope, {
        id: 'agreement-sn',
        partnerId: 'partner-1',
        countryCodes: ['SN'],
      }),
    ).toBe(false);
  });

  it('does not combine the country of one grant with the resource of another', async () => {
    const target = service([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: { partnerIds: ['partner-a'] },
      },
      {
        countryCodes: ['SN'],
        cohortIds: [],
        resourceScope: { partnerIds: ['partner-b'] },
      },
    ]);
    const scope = await target.listScope(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePartnerAgreements,
    );

    expect(
      target.agreementCovered(scope, {
        id: 'agreement-a',
        partnerId: 'partner-a',
        countryCodes: ['SN'],
      }),
    ).toBe(false);
    expect(
      target.agreementCovered(scope, {
        id: 'agreement-a',
        partnerId: 'partner-a',
        countryCodes: ['NE'],
      }),
    ).toBe(true);
  });

  it('requires every pilot country to fit one atomic grant', async () => {
    const target = service([
      {
        countryCodes: ['NE'],
        cohortIds: [],
        resourceScope: { pilotIds: ['pilot-1'] },
      },
    ]);
    const scope = await target.listScope(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePilots,
    );
    expect(
      target.pilotCovered(scope, {
        id: 'pilot-1',
        countryCodes: ['NE', 'SN'],
      }),
    ).toBe(false);
  });

  it('honours cohortIds stored on the grant itself', async () => {
    const target = service([
      {
        countryCodes: ['NE'],
        cohortIds: ['cohort-1'],
        resourceScope: null,
      },
    ]);
    const scope = await target.listScope(
      actor,
      ADMIN_IMPACT_CAPABILITIES.managePilots,
    );
    expect(
      target.pilotCovered(
        scope,
        { id: 'pilot-1', countryCodes: ['NE'] },
        'cohort-1',
      ),
    ).toBe(true);
    expect(
      target.pilotCovered(
        scope,
        { id: 'pilot-1', countryCodes: ['NE'] },
        'cohort-2',
      ),
    ).toBe(false);
  });
});
