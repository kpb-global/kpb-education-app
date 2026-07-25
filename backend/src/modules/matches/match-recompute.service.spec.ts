import { NotificationDispatchService } from '../notifications/notification-dispatch.service';
import { PrismaService } from '../prisma/prisma.service';
import { MatchRecomputeService } from './match-recompute.service';
import { MatchesService } from './matches.service';

/**
 * Guards KPB-168. The acceptance criteria are two-sided, and the negative half
 * is the one that matters: a profile or catalog change must produce a relevant
 * notification the following week — and ZERO notifications when nothing moved.
 */
describe('MatchRecomputeService', () => {
  const ORIGINAL = process.env.KPB_MATCH_RECOMPUTE_ENABLED;
  afterEach(() => {
    if (ORIGINAL === undefined) {
      delete process.env.KPB_MATCH_RECOMPUTE_ENABLED;
    } else {
      process.env.KPB_MATCH_RECOMPUTE_ENABLED = ORIGINAL;
    }
  });

  type Stored = { programId: string; zone: string };
  type Computed = { programId: string; zone: string; institutionId?: string };

  function make(opts: {
    recipients?: Array<Record<string, unknown>>;
    stored?: Stored[];
    computed?: Computed[];
    enabled?: boolean;
    ahaThrows?: boolean;
  }) {
    if (opts.enabled ?? true) {
      process.env.KPB_MATCH_RECOMPUTE_ENABLED = 'true';
    } else {
      delete process.env.KPB_MATCH_RECOMPUTE_ENABLED;
    }

    const client = {
      userProfile: {
        findMany: async () =>
          opts.recipients ?? [
            {
              id: 'u1',
              preferredLanguage: 'fr',
              countryOfResidence: 'NE',
            },
          ],
      },
      match: { findMany: async () => opts.stored ?? [] },
    };
    const prisma = {
      isEnabled: true,
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;

    const matches = {
      ahaMoment: async () => {
        if (opts.ahaThrows) throw new Error('scoring exploded');
        return {
          isEstimate: false,
          items: (opts.computed ?? []).map((c) => ({
            institutionId: c.institutionId ?? `inst-${c.programId}`,
            institutionName: { fr: 'Université X', en: 'University X' },
            programId: c.programId,
            programName: { fr: 'Licence', en: 'Bachelor' },
            probability: 0.5,
            zone: c.zone,
            isEstimate: false,
            algorithmVersion: 'v1',
            factors: [],
            narrative: { fr: '', en: '' },
          })),
        };
      },
    } as unknown as MatchesService;

    const dispatched: Array<Record<string, unknown>> = [];
    const dispatch = {
      dispatch: async (input: Record<string, unknown>) => {
        dispatched.push(input);
        return 'pushed' as const;
      },
    } as unknown as NotificationDispatchService;

    return {
      service: new MatchRecomputeService(prisma, matches, dispatch),
      dispatched,
    };
  }

  const now = new Date('2026-07-29T09:00:00.000Z'); // a Wednesday

  it('does nothing when the flag is off', async () => {
    const { service, dispatched } = make({
      enabled: false,
      stored: [{ programId: 'p1', zone: 'green' }],
      computed: [{ programId: 'p2', zone: 'green' }],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toEqual([]);
  });

  it('sends nothing when the top matches are identical', async () => {
    const { service, dispatched } = make({
      stored: [
        { programId: 'p1', zone: 'green' },
        { programId: 'p2', zone: 'yellow' },
      ],
      computed: [
        { programId: 'p1', zone: 'green' },
        { programId: 'p2', zone: 'yellow' },
      ],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toEqual([]);
  });

  it('sends nothing when only the ordering changed inside the same zones', async () => {
    const { service, dispatched } = make({
      stored: [
        { programId: 'p1', zone: 'green' },
        { programId: 'p2', zone: 'green' },
      ],
      computed: [
        { programId: 'p2', zone: 'green' },
        { programId: 'p1', zone: 'green' },
      ],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toEqual([]);
  });

  it('sends nothing on a first computation (no stored matches yet)', async () => {
    const { service, dispatched } = make({
      stored: [],
      computed: [{ programId: 'p1', zone: 'green' }],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toEqual([]);
  });

  it('notifies when a new school enters the top matches', async () => {
    const { service, dispatched } = make({
      stored: [
        { programId: 'p1', zone: 'green' },
        { programId: 'p2', zone: 'yellow' },
      ],
      computed: [
        { programId: 'p9', zone: 'green', institutionId: 'inst-9' },
        { programId: 'p1', zone: 'green' },
      ],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toHaveLength(1);
    expect(dispatched[0]).toMatchObject({
      userId: 'u1',
      kind: 'match_moved',
      dedupeKey: 'match-moved:2026-07-29:u1',
      preferredLanguage: 'fr',
      countryOfResidence: 'NE',
      data: { type: 'match_moved', institutionId: 'inst-9' },
    });
  });

  it('notifies when a kept school changed zone', async () => {
    const { service, dispatched } = make({
      stored: [{ programId: 'p1', zone: 'blue' }],
      computed: [{ programId: 'p1', zone: 'green' }],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toHaveLength(1);
  });

  it('sends nothing when the recompute yields no matches at all', async () => {
    const { service, dispatched } = make({
      stored: [{ programId: 'p1', zone: 'green' }],
      computed: [],
    });
    await service.recomputeWeekly(now);
    expect(dispatched).toEqual([]);
  });

  it('one student failing does not abort the run', async () => {
    const { service, dispatched } = make({
      recipients: [
        { id: 'u1', preferredLanguage: 'fr', countryOfResidence: 'NE' },
        { id: 'u2', preferredLanguage: 'fr', countryOfResidence: 'NE' },
      ],
      ahaThrows: true,
    });
    await expect(service.recomputeWeekly(now)).resolves.toBeUndefined();
    expect(dispatched).toEqual([]);
  });
});
