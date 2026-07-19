import { PrismaService } from '../prisma/prisma.service';
import { MauticService } from './mautic.service';
import { NewsletterSyncService } from './newsletter-sync.service';

const PROFILE = {
  id: 'user-1',
  email: 'aissatou@example.test',
  fullName: 'Aissatou Ibrahim',
  phone: '+22790000000',
  whatsApp: null,
  countryOfResidence: 'Niger',
  preferredLanguage: 'fr',
  newsletterOptIn: true,
  newsletterSyncedOptIn: null as boolean | null,
};

function makePrisma(profile: typeof PROFILE | null) {
  const updates: unknown[] = [];
  const client = {
    userProfile: {
      findUnique: async () => profile,
      findMany: async () => (profile ? [{ id: profile.id }] : []),
      update: async (args: unknown) => {
        updates.push(args);
        return profile;
      },
    },
  };
  const prisma = {
    isEnabled: true,
    execute: async (fn: (c: unknown) => unknown) => fn(client),
  } as unknown as PrismaService;
  return { prisma, updates };
}

function makeMautic(options: { configured?: boolean; fail?: boolean } = {}) {
  const syncCalls: Array<{ email: string; optIn: boolean }> = [];
  const mautic = {
    isConfigured: options.configured ?? true,
    syncContact: async (input: { email: string }, optIn: boolean) => {
      if (options.fail) throw new Error('Mautic down');
      syncCalls.push({ email: input.email, optIn });
    },
  } as unknown as MauticService;
  return { mautic, syncCalls };
}

describe('NewsletterSyncService', () => {
  it('does nothing when Mautic is not configured', async () => {
    const { prisma, updates } = makePrisma({ ...PROFILE });
    const { mautic, syncCalls } = makeMautic({ configured: false });

    const synced = await new NewsletterSyncService(
      prisma,
      mautic,
    ).syncProfile('user-1');

    expect(synced).toBe(false);
    expect(syncCalls).toHaveLength(0);
    expect(updates).toHaveLength(0);
  });

  it('pushes a pending opt-in to Mautic and records the synced state', async () => {
    const { prisma, updates } = makePrisma({ ...PROFILE });
    const { mautic, syncCalls } = makeMautic();

    const synced = await new NewsletterSyncService(
      prisma,
      mautic,
    ).syncProfile('user-1');

    expect(synced).toBe(true);
    expect(syncCalls).toEqual([
      { email: 'aissatou@example.test', optIn: true },
    ]);
    expect(updates).toHaveLength(1);
    expect(updates[0]).toMatchObject({
      where: { id: 'user-1' },
      data: { newsletterSyncedOptIn: true },
    });
  });

  it('skips a profile already in sync without calling Mautic', async () => {
    const { prisma, updates } = makePrisma({
      ...PROFILE,
      newsletterSyncedOptIn: true,
    });
    const { mautic, syncCalls } = makeMautic();

    const synced = await new NewsletterSyncService(
      prisma,
      mautic,
    ).syncProfile('user-1');

    expect(synced).toBe(true);
    expect(syncCalls).toHaveLength(0);
    expect(updates).toHaveLength(0);
  });

  it('leaves the profile pending when Mautic fails (cron retries later)', async () => {
    const { prisma, updates } = makePrisma({ ...PROFILE });
    const { mautic } = makeMautic({ fail: true });

    const synced = await new NewsletterSyncService(
      prisma,
      mautic,
    ).syncProfile('user-1');

    expect(synced).toBe(false);
    expect(updates).toHaveLength(0);
  });

  it('syncPending sweeps pending profiles', async () => {
    const { prisma } = makePrisma({ ...PROFILE });
    const { mautic, syncCalls } = makeMautic();

    const result = await new NewsletterSyncService(
      prisma,
      mautic,
    ).syncPending();

    expect(result).toEqual({ pending: 1, synced: 1 });
    expect(syncCalls).toHaveLength(1);
  });
});
