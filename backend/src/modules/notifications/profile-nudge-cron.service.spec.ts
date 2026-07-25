import { NotificationDispatchService } from './notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { ProfileNudgeCronService } from './profile-nudge-cron.service';

/** Guards KPB-76: incomplete students get a /profile-deep-linked nudge, and
 *  each candidate is stamped (throttle) regardless of the push outcome.
 *  KPB-173: the nudge goes through NotificationDispatchService, so quiet hours,
 *  the daily cap and the durable feed apply to it like every other reminder. */
describe('ProfileNudgeCronService', () => {
  function makeService(
    candidates: Array<{
      id: string;
      preferredLanguage: string;
      countryOfResidence?: string;
    }>,
    outcome: 'pushed' | 'quiet_hours' = 'pushed',
  ) {
    const dispatched: Array<Record<string, unknown>> = [];
    const updated: string[] = [];
    const client = {
      userProfile: {
        findMany: async () => candidates,
        update: async ({ where }: { where: { id: string } }) => {
          updated.push(where.id);
          return {};
        },
      },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    const dispatch = {
      dispatch: async (input: Record<string, unknown>) => {
        dispatched.push(input);
        return outcome;
      },
    } as unknown as NotificationDispatchService;
    return {
      service: new ProfileNudgeCronService(prisma, dispatch),
      dispatched,
      updated,
    };
  }

  const now = new Date('2026-07-25T09:00:00.000Z');

  it('nudges each incomplete student through the guarded dispatch path', async () => {
    const { service, dispatched, updated } = makeService([
      { id: 'u1', preferredLanguage: 'fr', countryOfResidence: 'NE' },
      { id: 'u2', preferredLanguage: 'en', countryOfResidence: 'SN' },
    ]);

    const res = await service.run(now);

    expect(res).toEqual({ candidates: 2, nudgesSent: 2 });
    expect(updated.sort()).toEqual(['u1', 'u2']);
    expect(dispatched[0]).toMatchObject({
      userId: 'u1',
      kind: 'profile_nudge',
      // One key per user per month — a retried run cannot double-nudge.
      dedupeKey: 'profile-nudge:2026-07:u1',
      route: '/profile',
      preferredLanguage: 'fr',
      countryOfResidence: 'NE',
    });
    // Both locales travel with the reminder; dispatch picks by preference.
    expect(String((dispatched[0].title as { fr: string }).fr)).toContain(
      'Complète',
    );
    expect(String((dispatched[0].title as { en: string }).en)).toContain(
      'Complete',
    );
  });

  it('stamps the throttle even when the push is held back by quiet hours', async () => {
    const { service, updated } = makeService(
      [{ id: 'u1', preferredLanguage: 'fr' }],
      'quiet_hours',
    );

    const res = await service.run(now);

    // Not counted as sent — but stamped, so a student whose push was held back
    // is not re-queried (and eventually hammered) every single day. The nudge
    // is already waiting in their feed.
    expect(res).toEqual({ candidates: 1, nudgesSent: 0 });
    expect(updated).toEqual(['u1']);
  });

  it('does nothing when no profile is incomplete', async () => {
    const { service, dispatched } = makeService([]);
    expect(await service.run(now)).toEqual({ candidates: 0, nudgesSent: 0 });
    expect(dispatched).toHaveLength(0);
  });
});
