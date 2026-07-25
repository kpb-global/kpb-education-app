import { PrismaService } from '../prisma/prisma.service';
import { StorageService } from '../storage/storage.service';
import { ProfilesService } from './profiles.service';

/**
 * KPB-169 collapsed the per-type opt-out booleans into one array column. The
 * load-bearing guarantees:
 *   • a legacy client that knows ONE type must not blank the other preferences;
 *   • unknown keys never reach the column;
 *   • a PATCH that touches no preference leaves the column alone.
 */
describe('ProfilesService — notification opt-out types', () => {
  function make(stored: string[] = []) {
    const updates: Array<Record<string, unknown>> = [];
    const row = {
      id: 'u1',
      disabledNotificationTypes: stored,
      updatedAt: new Date('2026-07-25T00:00:00Z'),
      fieldIds: [],
      targetCountryIds: [],
      availableDocuments: [],
    };
    const client = {
      userProfile: {
        findUnique: async () => row,
        update: async ({ data }: { data: Record<string, unknown> }) => {
          updates.push(data);
          return {
            ...row,
            ...data,
            disabledNotificationTypes:
              (data.disabledNotificationTypes as string[]) ?? stored,
          };
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const service = new ProfilesService(prisma, {} as StorageService);
    return { service, updates };
  }

  it('writes the array when a client sends it directly', async () => {
    const { service, updates } = make([]);
    await service.updateMe(
      { disabledNotificationTypes: ['weekly_digest'] },
      'u1',
    );
    expect(updates[0].disabledNotificationTypes).toEqual(['weekly_digest']);
  });

  it('drops unknown keys instead of storing them', async () => {
    const { service, updates } = make([]);
    await service.updateMe(
      { disabledNotificationTypes: ['weekly_digest', 'not_a_type', ''] },
      'u1',
    );
    expect(updates[0].disabledNotificationTypes).toEqual(['weekly_digest']);
  });

  it('a legacy boolean toggles ONE type and preserves the others', async () => {
    const { service, updates } = make(['weekly_digest', 'parcours_weekly']);
    await service.updateMe({ dailyScholarshipOptOut: true }, 'u1');
    expect(updates[0].disabledNotificationTypes).toEqual([
      'daily_scholarship',
      'parcours_weekly',
      'weekly_digest',
    ]);
  });

  it('a legacy boolean set back to false opts the student back in', async () => {
    const { service, updates } = make(['daily_scholarship', 'weekly_digest']);
    await service.updateMe({ dailyScholarshipOptOut: false }, 'u1');
    expect(updates[0].disabledNotificationTypes).toEqual(['weekly_digest']);
  });

  it('leaves the column untouched when the PATCH has no preference field', async () => {
    const { service, updates } = make(['weekly_digest']);
    await service.updateMe({ fullName: 'Awa' }, 'u1');
    expect(updates[0]).not.toHaveProperty('disabledNotificationTypes');
  });

  it('mirrors the array back as the legacy booleans for older clients', async () => {
    const { service } = make(['daily_scholarship']);
    const out = (await service.updateMe(
      { fullName: 'Awa' },
      'u1',
    )) as Record<string, unknown>;
    expect(out.dailyScholarshipOptOut).toBe(true);
    expect(out.weeklyDigestOptOut).toBe(false);
    expect(out.disabledNotificationTypes).toEqual(['daily_scholarship']);
  });
});
