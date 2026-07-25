import { NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { ParcoursService } from './parcours.service';
import { PrismaService } from '../prisma/prisma.service';
import { PARCOURS_SEED } from './data/parcours.seed';

/**
 * ParcoursService serves the "Parcours & Témoignages" stories. Two things must
 * hold: (1) when the DB is unavailable (execute → null) it falls back to the
 * curated seed, exposing only published + active stories on the public
 * endpoint; (2) when the DB is available it maps flat columns to the app-wide
 * localized `{ fr, en }` shape, including the JSON interview.
 */
describe('ParcoursService', () => {
  // A PrismaService whose execute() always yields null → forces the mock path.
  const nullPrisma = {
    execute: async () => null,
  } as unknown as PrismaService;

  // A PrismaService backed by an in-memory fake `parcoursStory` delegate.
  function dbPrisma(rows: Record<string, unknown>[]) {
    const calls: { create: unknown[]; update: unknown[]; delete: unknown[] } = {
      create: [],
      update: [],
      delete: [],
    };
    const client = {
      parcoursStory: {
        findMany: async (_args: unknown) => rows,
        create: async ({ data }: { data: Record<string, unknown> }) => {
          calls.create.push(data);
          return { id: 'new-id', ...data };
        },
        update: async ({
          where,
          data,
        }: {
          where: { id: string };
          data: Record<string, unknown>;
        }) => {
          calls.update.push({ where, data });
          return { id: where.id, ...data };
        },
        delete: async ({ where }: { where: { id: string } }) => {
          calls.delete.push(where);
          return { id: where.id };
        },
      },
    };
    const prisma = {
      execute: async (fn: (c: typeof client) => unknown) => fn(client),
    } as unknown as PrismaService;
    return { prisma, calls };
  }

  describe('listPublic — mock fallback', () => {
    it('returns the seed when the DB is unavailable', async () => {
      const service = new ParcoursService(nullPrisma);
      const { items } = await service.listPublic();
      expect(items.length).toBeGreaterThan(0);
    });

    it('exposes only published + active stories', async () => {
      const service = new ParcoursService(nullPrisma);
      const { items } = await service.listPublic();
      const publishedActive = PARCOURS_SEED.filter(
        (s) => s.isActive && s.status === 'published',
      ).length;
      expect(items.length).toBe(publishedActive);
    });

    it('maps each seed story into the localized {fr,en} shape', async () => {
      const service = new ParcoursService(nullPrisma);
      const { items } = await service.listPublic();
      const first = items[0];
      expect(first.title).toHaveProperty('fr');
      expect(first.title).toHaveProperty('en');
      expect(['video', 'text']).toContain(first.kind);
    });

    it('includes both video and text stories from the seed', async () => {
      const service = new ParcoursService(nullPrisma);
      const { items } = await service.listPublic();
      expect(items.some((i) => i.kind === 'video')).toBe(true);
      expect(items.some((i) => i.kind === 'text')).toBe(true);
    });
  });

  describe('listPublic — DB path', () => {
    it('maps a DB row (flat columns + JSON interview) to the DTO', async () => {
      const { prisma } = dbPrisma([
        {
          id: 'row-1',
          slug: 's-1',
          kind: 'text',
          fieldId: 'd01',
          tags: ['Tech'],
          personName: 'Jane Doe',
          roleFr: 'Ingénieure',
          roleEn: 'Engineer',
          titleFr: 'Titre',
          titleEn: 'Title',
          hookFr: 'Accroche',
          hookEn: 'Hook',
          summaryFr: 'Résumé',
          summaryEn: 'Summary',
          thumbnailUrl: '',
          photoUrl: '',
          youtubeId: null,
          durationMinutes: null,
          interviewFr: [{ question: 'Q', answer: 'A' }],
          interviewEn: null,
          status: 'published',
          featured: false,
          displayOrder: 3,
          popularity: 12,
        },
      ]);
      const service = new ParcoursService(prisma);
      const { items } = await service.listPublic();
      expect(items).toHaveLength(1);
      expect(items[0].role).toEqual({ fr: 'Ingénieure', en: 'Engineer' });
      expect(items[0].interview.fr).toEqual([{ question: 'Q', answer: 'A' }]);
      expect(items[0].interview.en).toBeNull();
      expect(items[0].kind).toBe('text');
    });
  });

  describe('pickStoryOfWeek — "récit de la semaine" (KPB-169)', () => {
    const featured = (id: string, order: number) => ({
      id,
      slug: id,
      kind: 'video',
      fieldId: null,
      tags: [],
      personName: '',
      roleFr: '',
      roleEn: '',
      titleFr: id,
      titleEn: id,
      hookFr: '',
      hookEn: '',
      summaryFr: '',
      summaryEn: '',
      thumbnailUrl: '',
      photoUrl: '',
      youtubeId: 'yt',
      durationMinutes: null,
      interviewFr: null,
      interviewEn: null,
      status: 'published',
      featured: true,
      displayOrder: order,
      popularity: 0,
    });

    it('returns null when nothing is featured — the slot stays empty', async () => {
      const { prisma } = dbPrisma([]);
      const service = new ParcoursService(prisma);
      expect(await service.pickStoryOfWeek(new Date('2026-07-26'))).toBeNull();
    });

    it('is stable across a week and rotates the next one', async () => {
      const { prisma } = dbPrisma([featured('a', 1), featured('b', 2)]);
      const service = new ParcoursService(prisma);

      // Monday → Sunday of the same week: one and the same story.
      const week1 = await Promise.all(
        [
          '2026-07-20T00:00:00Z',
          '2026-07-23T12:00:00Z',
          '2026-07-26T23:59:00Z',
        ].map((d) => service.pickStoryOfWeek(new Date(d))),
      );
      expect(new Set(week1.map((s) => s?.slug)).size).toBe(1);

      // The following Monday is a different story.
      const week2 = await service.pickStoryOfWeek(
        new Date('2026-07-27T08:00:00Z'),
      );
      expect(week2?.slug).not.toBe(week1[0]?.slug);
    });

    it('keeps serving the only featured story rather than going empty', async () => {
      const { prisma } = dbPrisma([featured('solo', 1)]);
      const service = new ParcoursService(prisma);
      const a = await service.pickStoryOfWeek(new Date('2026-07-20'));
      const b = await service.pickStoryOfWeek(new Date('2026-08-10'));
      expect([a?.slug, b?.slug]).toEqual(['solo', 'solo']);
    });

    it('getStoryOfWeek stamps a week key alongside the pick', async () => {
      const { prisma } = dbPrisma([featured('a', 1)]);
      const service = new ParcoursService(prisma);
      const out = await service.getStoryOfWeek(new Date('2026-07-22T10:00:00Z'));
      expect(out.story?.slug).toBe('a');
      expect(out.week).toMatch(/^2026-W\d+$/);
      // Same key all week, new key the next.
      expect(service.weekKey(new Date('2026-07-26T10:00:00Z'))).toBe(out.week);
      expect(service.weekKey(new Date('2026-07-27T10:00:00Z'))).not.toBe(
        out.week,
      );
    });
  });

  describe('admin mutations', () => {
    it('create maps the localized input into flat columns', async () => {
      const { prisma, calls } = dbPrisma([]);
      const service = new ParcoursService(prisma);
      await service.create({
        slug: 'my-story',
        kind: 'video',
        title: { fr: 'FR', en: 'EN' },
        youtubeId: 'abc123',
      });
      const data = calls.create[0] as Record<string, unknown>;
      expect(data.slug).toBe('my-story');
      expect(data.titleFr).toBe('FR');
      expect(data.titleEn).toBe('EN');
      expect(data.youtubeId).toBe('abc123');
    });

    it('update sends only provided fields (partial)', async () => {
      const { prisma, calls } = dbPrisma([]);
      const service = new ParcoursService(prisma);
      await service.update('row-1', { title: { fr: 'Nouveau', en: 'New' } });
      const { data } = calls.update[0] as { data: Record<string, unknown> };
      expect(data.titleFr).toBe('Nouveau');
      // slug/kind not supplied → not written on a partial update
      expect(data).not.toHaveProperty('slug');
    });

    it('partial update of one locale does NOT blank the other (regression)', async () => {
      const { prisma, calls } = dbPrisma([]);
      const service = new ParcoursService(prisma);
      // Only the French title is sent — English must be left untouched.
      await service.update('row-1', { title: { fr: 'Seulement FR' } });
      const { data } = calls.update[0] as { data: Record<string, unknown> };
      expect(data.titleFr).toBe('Seulement FR');
      expect(data).not.toHaveProperty('titleEn');
    });

    it('create writes Prisma.JsonNull (not bare null) for absent interviews', async () => {
      const { prisma, calls } = dbPrisma([]);
      const service = new ParcoursService(prisma);
      await service.create({ slug: 'v', kind: 'video', title: { fr: 'x', en: 'x' } });
      const data = calls.create[0] as Record<string, unknown>;
      expect(data.interviewFr).toBe(Prisma.JsonNull);
      expect(data.interviewEn).toBe(Prisma.JsonNull);
    });

    it('partial update with only interview.fr leaves interviewEn untouched', async () => {
      const { prisma, calls } = dbPrisma([]);
      const service = new ParcoursService(prisma);
      await service.update('row-1', {
        interview: { fr: [{ question: 'Q', answer: 'A' }] },
      });
      const { data } = calls.update[0] as { data: Record<string, unknown> };
      expect(data.interviewFr).toEqual([{ question: 'Q', answer: 'A' }]);
      expect(data).not.toHaveProperty('interviewEn');
    });

    it('update throws NotFound when the DB is unavailable', async () => {
      const service = new ParcoursService(nullPrisma);
      await expect(
        service.update('missing', { title: { fr: 'x', en: 'x' } }),
      ).rejects.toBeInstanceOf(NotFoundException);
    });
  });
});
