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

// ─────────────────────────────────────────────────────────────────────────────
// Consent gate. The three states of (newsletterOptIn, newsletterSyncedOptIn),
// and the promise that only a consented profile reaches Mautic.
//
// These tests wire the REAL MauticService and spy on `fetch` instead of using
// the makeMautic() double above. That is deliberate: the leak being guarded
// against happens inside MauticService.syncContact, whose upsert step ships
// the profile fields BEFORE it branches on the opt-in flag. A double asserting
// "syncContact was not called" would go green on a build that still leaks, and
// on this repo the harness hiding the bug is the recurring failure mode.
// `fetch` is the single exit to the network, so it is the only honest witness.
// ─────────────────────────────────────────────────────────────────────────────
describe('NewsletterSyncService consent gate', () => {
  const previousFetch = global.fetch;
  const previousEnv = { ...process.env };

  beforeEach(() => {
    // Mautic is unconfigured in every environment today, which is what makes
    // the leak inert; configure it so the guard tests the post-activation
    // world the fix has to survive.
    process.env.MAUTIC_BASE_URL = 'https://mautic.example.test';
    process.env.MAUTIC_USERNAME = 'api-user';
    process.env.MAUTIC_PASSWORD = 'api-pass';
    process.env.MAUTIC_SEGMENT_ID = '7';
  });

  afterEach(() => {
    global.fetch = previousFetch;
    process.env = { ...previousEnv };
  });

  function spyOnNetwork() {
    const fetchSpy = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ contact: { id: 42 } }),
    });
    global.fetch = fetchSpy as unknown as typeof fetch;
    return fetchSpy;
  }

  /// Every URL the run touched, so a test can assert on the whole traffic
  /// rather than on one indexed call.
  const urlsOf = (fetchSpy: jest.Mock): string[] =>
    fetchSpy.mock.calls.map((call) => call[0] as string);

  const bodyOf = (fetchSpy: jest.Mock, index: number): Record<string, string> =>
    JSON.parse(
      (fetchSpy.mock.calls[index][1] as RequestInit).body as string,
    ) as Record<string, string>;

  it('state 1 — never consented: not a single request leaves the server', async () => {
    const fetchSpy = spyOnNetwork();
    const { prisma, updates } = makePrisma({
      ...PROFILE,
      newsletterOptIn: false,
      newsletterSyncedOptIn: null,
    });

    const synced = await new NewsletterSyncService(
      prisma,
      new MauticService(),
    ).syncProfile('user-1');

    // The whole point of the correctif: no HTTP call at all — not even the
    // "harmless" upsert that used to carry name, phone, WhatsApp and country.
    expect(fetchSpy).not.toHaveBeenCalled();
    // Nothing pending: this row is a legitimate resting state, not a failure.
    expect(synced).toBe(true);
    // `null` must survive. It is the only record that Mautic holds nothing,
    // hence the only thing telling state 1 apart from state 2 next time.
    expect(updates).toHaveLength(0);
  });

  it('state 2 — consent withdrawn after a push: Mautic IS contacted to unsubscribe', async () => {
    const fetchSpy = spyOnNetwork();
    const { prisma, updates } = makePrisma({
      ...PROFILE,
      newsletterOptIn: false,
      newsletterSyncedOptIn: true,
    });

    const synced = await new NewsletterSyncService(
      prisma,
      new MauticService(),
    ).syncProfile('user-1');

    expect(synced).toBe(true);
    // Silence here would be the mirror-image bug: we would keep mailing
    // someone who explicitly said no.
    expect(urlsOf(fetchSpy)).toEqual([
      'https://mautic.example.test/api/contacts/new',
      'https://mautic.example.test/api/segments/7/contact/42/remove',
      'https://mautic.example.test/api/contacts/42/dnc/email/add',
    ]);
    // Unsubscribing identifies the contact and nothing more.
    expect(bodyOf(fetchSpy, 0)).toEqual({ email: PROFILE.email });
    expect(updates[0]).toMatchObject({
      data: { newsletterSyncedOptIn: false },
    });
  });

  it('state 3 — consent given: Mautic is contacted to subscribe', async () => {
    const fetchSpy = spyOnNetwork();
    const { prisma, updates } = makePrisma({
      ...PROFILE,
      newsletterOptIn: true,
      newsletterSyncedOptIn: null,
    });

    const synced = await new NewsletterSyncService(
      prisma,
      new MauticService(),
    ).syncProfile('user-1');

    expect(synced).toBe(true);
    expect(urlsOf(fetchSpy)).toEqual([
      'https://mautic.example.test/api/contacts/new',
      'https://mautic.example.test/api/contacts/42/dnc/email/remove',
      'https://mautic.example.test/api/segments/7/contact/42/add',
    ]);
    // Only the consented profile gets enriched.
    expect(bodyOf(fetchSpy, 0)).toMatchObject({
      email: PROFILE.email,
      firstname: 'Aissatou',
      lastname: 'Ibrahim',
      phone: PROFILE.phone,
      country: PROFILE.countryOfResidence,
    });
    expect(updates[0]).toMatchObject({
      data: { newsletterSyncedOptIn: true },
    });
  });

  it('the gate holds even if the sweep hands it a never-consented profile', async () => {
    // syncPending's WHERE clause already excludes (null, false), but a query
    // is easy to "complete" by mistake. Assert the per-profile gate is what
    // stops the leak, so the guard does not depend on the query staying right.
    const fetchSpy = spyOnNetwork();
    const { prisma, updates } = makePrisma({
      ...PROFILE,
      newsletterOptIn: false,
      newsletterSyncedOptIn: null,
    });

    const result = await new NewsletterSyncService(
      prisma,
      new MauticService(),
    ).syncPending();

    expect(fetchSpy).not.toHaveBeenCalled();
    expect(updates).toHaveLength(0);
    expect(result.pending).toBe(1);
  });
});
