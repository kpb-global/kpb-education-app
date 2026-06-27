import { PrismaService } from '../prisma/prisma.service';
import { OneSignalSenderService } from './onesignal-sender.service';
import { ProfileNudgeCronService } from './profile-nudge-cron.service';

/** Guards KPB-76: incomplete students get a /profile-deep-linked nudge, and
 *  each candidate is stamped (throttle) regardless of push success. */
describe('ProfileNudgeCronService', () => {
  function makeService(
    candidates: Array<{ id: string; preferredLanguage: string }>,
  ) {
    const sent: Array<{
      userId: string;
      title: string;
      body: string;
      data?: Record<string, string>;
    }> = [];
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
    const push = {
      sendToUser: async (
        userId: string,
        title: string,
        body: string,
        data?: Record<string, string>,
      ) => {
        sent.push({ userId, title, body, data });
        return true;
      },
    } as unknown as OneSignalSenderService;
    return { service: new ProfileNudgeCronService(prisma, push), sent, updated };
  }

  it('nudges each incomplete student, deep-linking to /profile, and stamps them', async () => {
    const { service, sent, updated } = makeService([
      { id: 'u1', preferredLanguage: 'fr' },
      { id: 'u2', preferredLanguage: 'en' },
    ]);

    const res = await service.run();

    expect(res).toEqual({ candidates: 2, nudgesSent: 2 });
    expect(sent.every((s) => s.data?.route === '/profile')).toBe(true);
    expect(updated.sort()).toEqual(['u1', 'u2']);
    // Localized copy per preferredLanguage.
    expect(sent.find((s) => s.userId === 'u1')!.title).toContain('Complète');
    expect(sent.find((s) => s.userId === 'u2')!.title).toContain('Complete');
  });

  it('does nothing when no profile is incomplete', async () => {
    const { service, sent } = makeService([]);
    expect(await service.run()).toEqual({ candidates: 0, nudgesSent: 0 });
    expect(sent).toHaveLength(0);
  });
});
