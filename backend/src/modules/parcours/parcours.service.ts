import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';

import { PublicationStatus } from '../../common/enums/publication-status.enum';
import { PrismaService } from '../prisma/prisma.service';
import { PARCOURS_SEED, ParcoursSeedItem } from './data/parcours.seed';

// ─────────────────────────────────────────────────────────────────────────────
// Parcours & Témoignages KPB (Chantier C).
//
// Serves the curated career/education stories (YouTube videos + legacy written
// interviews) that feed the app's free "Parcours" section. DB-backed via
// Prisma with a graceful fallback to the seed data (PARCOURS_SEED) so the
// screen still works before the DB is provisioned — same pattern as
// ContentService. Payloads use the app-wide localized `{ fr, en }` shape.
// ─────────────────────────────────────────────────────────────────────────────

interface Qa {
  question: string;
  answer: string;
}

/// The public, localized shape the mobile app consumes.
export interface ParcoursDto {
  id: string;
  slug: string;
  kind: 'video' | 'text';
  fieldId: string | null;
  tags: string[];
  personName: string;
  role: { fr: string; en: string };
  title: { fr: string; en: string };
  hook: { fr: string; en: string };
  summary: { fr: string; en: string };
  thumbnailUrl: string;
  photoUrl: string;
  youtubeId: string | null;
  durationMinutes: number | null;
  // FR is authoritative; EN may be null (app falls back to FR).
  interview: { fr: Qa[] | null; en: Qa[] | null };
  status: PublicationStatus;
  featured: boolean;
  displayOrder: number;
  popularity: number;
}

// Minimal shape of a Prisma ParcoursStory row (kept local so the module does
// not hard-depend on generated types being present at edit time).
interface ParcoursRow {
  id: string;
  slug: string;
  kind: string;
  fieldId: string | null;
  tags: string[];
  personName: string;
  roleFr: string;
  roleEn: string;
  titleFr: string;
  titleEn: string;
  hookFr: string;
  hookEn: string;
  summaryFr: string;
  summaryEn: string;
  thumbnailUrl: string;
  photoUrl: string;
  youtubeId: string | null;
  durationMinutes: number | null;
  interviewFr: unknown;
  interviewEn: unknown;
  status: string;
  featured: boolean;
  displayOrder: number;
  popularity: number;
}

@Injectable()
export class ParcoursService {
  constructor(private readonly prismaService: PrismaService) {}

  // ── Public: only published + active stories ────────────────────────────────
  async listPublic(): Promise<{ items: ParcoursDto[] }> {
    const rows = await this.prismaService.execute((prisma) =>
      prisma.parcoursStory.findMany({
        where: {
          isActive: true,
          status: PublicationStatus.Published,
        },
        orderBy: [{ displayOrder: 'asc' }, { popularity: 'desc' }],
      }),
    );

    if (rows) {
      return { items: (rows as ParcoursRow[]).map((r) => this.toDto(r)) };
    }

    // Fallback to the seed (published + active) when the DB is unavailable.
    return {
      items: PARCOURS_SEED.filter(
        (s) => s.isActive && s.status === 'published',
      ).map((s) => this.seedToDto(s)),
    };
  }

  // ── Admin: every story, any status ─────────────────────────────────────────
  async listAdmin(): Promise<{ items: ParcoursDto[] }> {
    const rows = await this.prismaService.execute((prisma) =>
      prisma.parcoursStory.findMany({ orderBy: [{ displayOrder: 'asc' }] }),
    );

    if (rows) {
      return { items: (rows as ParcoursRow[]).map((r) => this.toDto(r)) };
    }
    return { items: PARCOURS_SEED.map((s) => this.seedToDto(s)) };
  }

  async create(input: Record<string, unknown>): Promise<ParcoursDto> {
    const data = this.inputToRow(input);
    const created = await this.prismaService.execute((prisma) =>
      prisma.parcoursStory.create({
        data: data as never,
      }),
    );
    if (created) return this.toDto(created as ParcoursRow);
    // No DB (mock mode): echo the payload back so the admin UI stays usable.
    return this.seedToDto({
      ...this.blankSeedItem(),
      ...(data as Partial<ParcoursSeedItem>),
      slug: data.slug,
    } as ParcoursSeedItem);
  }

  async update(id: string, input: Record<string, unknown>): Promise<ParcoursDto> {
    const data = this.inputToRow(input, true);
    const updated = await this.prismaService.execute((prisma) =>
      prisma.parcoursStory.update({
        where: { id },
        data: data as never,
      }),
    );
    if (updated) return this.toDto(updated as ParcoursRow);
    throw new NotFoundException(`Parcours story ${id} not found.`);
  }

  async remove(id: string): Promise<{ id: string; deleted: boolean }> {
    const deleted = await this.prismaService.execute((prisma) =>
      prisma.parcoursStory.delete({
        where: { id },
      }),
    );
    if (deleted) return { id, deleted: true };
    throw new NotFoundException(`Parcours story ${id} not found.`);
  }

  // ── Mapping helpers ─────────────────────────────────────────────────────────

  private asQa(value: unknown): Qa[] | null {
    if (!Array.isArray(value)) return null;
    const out = value
      .filter((v): v is Record<string, unknown> => !!v && typeof v === 'object')
      .map((v) => ({
        question: String(v['question'] ?? ''),
        answer: String(v['answer'] ?? ''),
      }))
      .filter((v) => v.answer.trim() !== '');
    return out.length ? out : null;
  }

  private toDto(r: ParcoursRow): ParcoursDto {
    return {
      id: r.id,
      slug: r.slug,
      kind: r.kind === 'text' ? 'text' : 'video',
      fieldId: r.fieldId ?? null,
      tags: r.tags ?? [],
      personName: r.personName ?? '',
      role: { fr: r.roleFr ?? '', en: r.roleEn ?? '' },
      title: { fr: r.titleFr ?? '', en: r.titleEn ?? '' },
      hook: { fr: r.hookFr ?? '', en: r.hookEn ?? '' },
      summary: { fr: r.summaryFr ?? '', en: r.summaryEn ?? '' },
      thumbnailUrl: r.thumbnailUrl ?? '',
      photoUrl: r.photoUrl ?? '',
      youtubeId: r.youtubeId ?? null,
      durationMinutes: r.durationMinutes ?? null,
      interview: {
        fr: this.asQa(r.interviewFr),
        en: this.asQa(r.interviewEn),
      },
      status: (r.status as PublicationStatus) ?? PublicationStatus.Published,
      featured: !!r.featured,
      displayOrder: r.displayOrder ?? 0,
      popularity: r.popularity ?? 0,
    };
  }

  private seedToDto(s: ParcoursSeedItem): ParcoursDto {
    return {
      id: s.slug,
      slug: s.slug,
      kind: s.kind,
      fieldId: s.fieldId ?? null,
      tags: s.tags ?? [],
      personName: s.personName ?? '',
      role: { fr: s.roleFr ?? '', en: s.roleEn ?? '' },
      title: { fr: s.titleFr ?? '', en: s.titleEn ?? '' },
      hook: { fr: s.hookFr ?? '', en: s.hookEn ?? '' },
      summary: { fr: s.summaryFr ?? '', en: s.summaryEn ?? '' },
      thumbnailUrl: s.thumbnailUrl ?? '',
      photoUrl: s.photoUrl ?? '',
      youtubeId: s.youtubeId ?? null,
      durationMinutes: s.durationMinutes ?? null,
      interview: {
        fr: this.asQa(s.interviewFr),
        en: this.asQa(s.interviewEn),
      },
      status: (s.status as PublicationStatus) ?? PublicationStatus.Published,
      featured: !!s.featured,
      displayOrder: s.displayOrder ?? 0,
      popularity: s.popularity ?? 0,
    };
  }

  // Build a Prisma-shaped write payload from a loose admin input object.
  private inputToRow(
    input: Record<string, unknown>,
    partial = false,
  ): Record<string, unknown> {
    const pick = <T>(key: string, fallback: T): T =>
      (input[key] as T | undefined) ?? fallback;

    const row: Record<string, unknown> = {};
    // Write each locale column independently so a partial PATCH that carries
    // only `{ fr }` never blanks the existing `en` value (and vice-versa). On
    // a full create (!partial) both columns default to ''.
    const setLoc = (key: string, frCol: string, enCol: string) => {
      const v = input[key] as { fr?: string; en?: string } | undefined;
      if (v === undefined) {
        if (!partial) {
          row[frCol] = '';
          row[enCol] = '';
        }
        return;
      }
      if (v.fr !== undefined || !partial) row[frCol] = v.fr ?? '';
      if (v.en !== undefined || !partial) row[enCol] = v.en ?? '';
    };

    if (input['slug'] !== undefined || !partial) {
      row.slug = pick('slug', `parcours-${Date.now()}`);
    }
    if (input['kind'] !== undefined || !partial) {
      row.kind = pick('kind', 'video');
    }
    if (input['fieldId'] !== undefined) row.fieldId = input['fieldId'] ?? null;
    if (input['tags'] !== undefined) row.tags = pick<string[]>('tags', []);
    if (input['personName'] !== undefined || !partial) {
      row.personName = pick('personName', '');
    }
    setLoc('role', 'roleFr', 'roleEn');
    setLoc('title', 'titleFr', 'titleEn');
    setLoc('hook', 'hookFr', 'hookEn');
    setLoc('summary', 'summaryFr', 'summaryEn');
    if (input['thumbnailUrl'] !== undefined || !partial) {
      row.thumbnailUrl = pick('thumbnailUrl', '');
    }
    if (input['photoUrl'] !== undefined || !partial) {
      row.photoUrl = pick('photoUrl', '');
    }
    if (input['youtubeId'] !== undefined) row.youtubeId = input['youtubeId'] ?? null;
    if (input['durationMinutes'] !== undefined) {
      row.durationMinutes = input['durationMinutes'] ?? null;
    }
    // Prisma requires `Prisma.JsonNull` (not a bare JS null) to clear a
    // nullable Json column. Mirror the locale-independent partial semantics so
    // a `{ fr }`-only PATCH does not wipe the EN interview.
    const interview = input['interview'] as
      | { fr?: unknown; en?: unknown }
      | undefined;
    const jsonOrNull = (v: unknown): Prisma.InputJsonValue | typeof Prisma.JsonNull =>
      v == null ? Prisma.JsonNull : (v as Prisma.InputJsonValue);
    if (interview !== undefined) {
      if (interview.fr !== undefined || !partial) {
        row.interviewFr = jsonOrNull(interview.fr);
      }
      if (interview.en !== undefined || !partial) {
        row.interviewEn = jsonOrNull(interview.en);
      }
    } else if (!partial) {
      row.interviewFr = Prisma.JsonNull;
      row.interviewEn = Prisma.JsonNull;
    }
    if (input['status'] !== undefined || !partial) {
      row.status = pick('status', PublicationStatus.Draft);
    }
    if (input['featured'] !== undefined) row.featured = !!input['featured'];
    if (input['isActive'] !== undefined || !partial) {
      row.isActive = input['isActive'] === undefined ? true : !!input['isActive'];
    }
    if (input['displayOrder'] !== undefined) {
      row.displayOrder = input['displayOrder'] ?? 0;
    }
    if (input['popularity'] !== undefined) row.popularity = input['popularity'] ?? 0;
    if (input['source'] !== undefined || !partial) {
      row.source = pick('source', 'manual');
    }
    return row;
  }

  private blankSeedItem(): ParcoursSeedItem {
    return {
      slug: '',
      kind: 'video',
      fieldId: null,
      tags: [],
      personName: '',
      roleFr: '',
      roleEn: '',
      titleFr: '',
      titleEn: '',
      hookFr: '',
      hookEn: '',
      summaryFr: '',
      summaryEn: '',
      thumbnailUrl: '',
      photoUrl: '',
      youtubeId: null,
      durationMinutes: null,
      interviewFr: null,
      interviewEn: null,
      status: 'draft',
      isActive: true,
      featured: false,
      displayOrder: 0,
      popularity: 0,
      source: 'manual',
    };
  }
}
