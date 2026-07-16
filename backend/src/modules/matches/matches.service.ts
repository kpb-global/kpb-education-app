import { Injectable, NotFoundException } from '@nestjs/common';
import type { Institution, Program } from '@prisma/client';

import { PrismaService } from '../prisma/prisma.service';
import { mockCatalog } from '../../common/data/mock-catalog';
import {
  ALGORITHM_VERSION,
  MatchScore,
  ScoringProfile,
  ScoringProgram,
  scoreProgram,
} from './matching';

const MATCH_TTL_MS = 24 * 60 * 60 * 1000; // kit: Match rows expire after 24h
const AHA_DEFAULT_LIMIT = 3;
const AHA_MAX_LIMIT = 10;

export interface MatchDto {
  institutionId: string;
  institutionName: { fr: string; en: string };
  programId: string;
  programName: { fr: string; en: string };
  probability: number;
  zone: string;
  isEstimate: boolean;
  algorithmVersion: string;
  factors: Array<{
    name: string;
    weight: number;
    score: number;
    isEstimate: boolean;
  }>;
  narrative: { fr: string; en: string };
}

interface ScoringInstitution {
  id: string;
  nameFr: string;
  nameEn: string;
  studyLevels: string[];
}

type MockProgram = {
  id: string;
  institutionId: string;
  countryId: string;
  fieldId: string;
  name: { fr: string; en: string };
  level: { fr: string; en: string };
  minGpaRequired?: number;
  tuitionMinEur?: number;
  applicationDeadline?: string;
  teachingLanguages?: string[];
};

type MockInstitution = {
  id: string;
  name: { fr: string; en: string };
  countryId: string;
  levels: string[];
};

@Injectable()
export class MatchesService {
  constructor(private readonly prismaService: PrismaService) {}

  /** US-004 — best-scoring program of one institution for the caller. */
  async schoolMatch(userId: string, institutionId: string): Promise<MatchDto> {
    const profile = await this.loadProfile(userId);
    const institution = (await this.loadInstitutions([institutionId]))[0];
    if (!institution) {
      throw new NotFoundException('Institution not found.');
    }
    const programs = await this.loadPrograms({ institutionId });
    if (programs.length === 0) {
      throw new NotFoundException('No programs found for this institution.');
    }

    const scored = programs
      .map((program) => this.toDto(profile, program, institution))
      .sort((a, b) => b.probability - a.probability);
    const best = scored[0];
    await this.persist(userId, best);
    return best;
  }

  /** US-003 — top-N matches across the caller's target countries/fields. */
  async ahaMoment(
    userId: string,
    limit?: number,
  ): Promise<{ items: MatchDto[]; isEstimate: boolean }> {
    const profile = await this.loadProfile(userId);
    const take = Math.min(Math.max(limit ?? AHA_DEFAULT_LIMIT, 1), AHA_MAX_LIMIT);

    let programs = await this.loadPrograms({
      countryIds: profile.targetCountryIds,
      fieldIds: profile.fieldIds,
    });
    // Preference filters are progressive, not absolute: an empty result set
    // (e.g. no catalog rows for the chosen countries yet) falls back to the
    // whole catalog rather than an empty AHA moment.
    if (programs.length === 0) {
      programs = await this.loadPrograms({});
    }
    if (programs.length === 0) {
      return { items: [], isEstimate: false };
    }

    const institutions = await this.loadInstitutions([
      ...new Set(programs.map((p) => p.institutionId)),
    ]);
    const institutionById = new Map(institutions.map((i) => [i.id, i]));

    const scored = programs
      .map((program) =>
        this.toDto(profile, program, institutionById.get(program.institutionId)),
      )
      .sort((a, b) => b.probability - a.probability);

    // One entry per institution (the AHA moment presents schools, not a list
    // of near-duplicate programs from the same place).
    const items: MatchDto[] = [];
    const seenInstitutions = new Set<string>();
    for (const match of scored) {
      if (seenInstitutions.has(match.institutionId)) continue;
      seenInstitutions.add(match.institutionId);
      items.push(match);
      if (items.length >= take) break;
    }

    await Promise.all(items.map((item) => this.persist(userId, item)));
    return { items, isEstimate: items.some((i) => i.isEstimate) };
  }

  // ── Data loading (DB via tryExecute, mock catalog as fallback) ────────────

  private async loadProfile(userId: string): Promise<ScoringProfile> {
    const row = await this.prismaService.tryExecute((prisma) =>
      prisma.userProfile.findUnique({
        where: { id: userId },
        select: {
          gradeRange: true,
          languageLevel: true,
          targetLevel: true,
          annualTuitionBudgetEur: true,
          fieldIds: true,
          targetCountryIds: true,
        },
      }),
    );
    if (!row) {
      throw new NotFoundException('Profile not found.');
    }
    return row;
  }

  private async loadPrograms(filter: {
    institutionId?: string;
    countryIds?: string[];
    fieldIds?: string[];
  }): Promise<ScoringProgram[]> {
    const where: Record<string, unknown> = {};
    if (filter.institutionId) where.institutionId = filter.institutionId;
    if (filter.countryIds?.length) where.countryId = { in: filter.countryIds };
    if (filter.fieldIds?.length) where.fieldId = { in: filter.fieldIds };

    const rows = await this.prismaService.tryExecute((prisma) =>
      prisma.program.findMany({ where }),
    );
    if (Array.isArray(rows)) {
      return rows.map((row) => this.fromDbProgram(row));
    }

    return (mockCatalog.programs as MockProgram[])
      .filter((p) => !filter.institutionId || p.institutionId === filter.institutionId)
      .filter(
        (p) => !filter.countryIds?.length || filter.countryIds.includes(p.countryId),
      )
      .filter((p) => !filter.fieldIds?.length || filter.fieldIds.includes(p.fieldId))
      .map((p) => this.fromMockProgram(p));
  }

  private async loadInstitutions(ids: string[]): Promise<ScoringInstitution[]> {
    if (ids.length === 0) return [];
    const rows = await this.prismaService.tryExecute((prisma) =>
      prisma.institution.findMany({ where: { id: { in: ids } } }),
    );
    if (Array.isArray(rows)) {
      return rows.map((row: Institution) => ({
        id: row.id,
        nameFr: row.nameFr,
        nameEn: row.nameEn,
        studyLevels: row.studyLevels,
      }));
    }
    return (mockCatalog.institutions as MockInstitution[])
      .filter((i) => ids.includes(i.id))
      .map((i) => ({
        id: i.id,
        nameFr: i.name.fr,
        nameEn: i.name.en,
        studyLevels: i.levels,
      }));
  }

  private fromDbProgram(row: Program): ScoringProgram {
    return {
      id: row.id,
      institutionId: row.institutionId,
      countryId: row.countryId,
      fieldId: row.fieldId,
      nameFr: row.nameFr,
      nameEn: row.nameEn,
      levelFr: row.levelFr,
      levelEn: row.levelEn,
      minGpaRequired: row.minGpaRequired,
      tuitionMinEur: row.tuitionMinEur,
      applicationDeadline: row.applicationDeadline,
      teachingLanguages: row.teachingLanguages,
    };
  }

  private fromMockProgram(p: MockProgram): ScoringProgram {
    return {
      id: p.id,
      institutionId: p.institutionId,
      countryId: p.countryId,
      fieldId: p.fieldId,
      nameFr: p.name.fr,
      nameEn: p.name.en,
      levelFr: p.level.fr,
      levelEn: p.level.en,
      minGpaRequired: p.minGpaRequired ?? null,
      tuitionMinEur: p.tuitionMinEur ?? null,
      applicationDeadline: p.applicationDeadline
        ? new Date(p.applicationDeadline)
        : null,
      teachingLanguages: p.teachingLanguages ?? [],
    };
  }

  // ── Scoring → DTO → persistence ───────────────────────────────────────────

  private toDto(
    profile: ScoringProfile,
    program: ScoringProgram,
    institution: ScoringInstitution | undefined,
  ): MatchDto {
    const score = scoreProgram(profile, program, {
      institutionStudyLevels: institution?.studyLevels,
    });
    return {
      institutionId: program.institutionId,
      institutionName: {
        fr: institution?.nameFr ?? '',
        en: institution?.nameEn ?? '',
      },
      programId: program.id,
      programName: { fr: program.nameFr, en: program.nameEn },
      probability: score.probability,
      zone: score.zone,
      isEstimate: score.isEstimate,
      algorithmVersion: ALGORITHM_VERSION,
      factors: score.factors,
      narrative: this.narrative(program, score),
    };
  }

  // Static bilingual narrative (v1 — an LLM narrative is deliberately out of
  // scope so the score path stays deterministic and free).
  private narrative(
    program: ScoringProgram,
    score: MatchScore,
  ): { fr: string; en: string } {
    const pct = Math.round(score.probability * 100);
    const byZone = {
      green: {
        fr: `Ton profil correspond très bien à ${program.nameFr} (${pct}% de compatibilité). Fonce, tes chances sont réelles.`,
        en: `Your profile is a strong match for ${program.nameEn} (${pct}% compatibility). Go for it — your chances are real.`,
      },
      yellow: {
        fr: `Ton profil est compatible avec ${program.nameFr} (${pct}%). Un dossier soigné ou une bourse peut faire la différence.`,
        en: `Your profile is compatible with ${program.nameEn} (${pct}%). A polished application or a scholarship can make the difference.`,
      },
      blue: {
        fr: `${program.nameFr} est ambitieux pour ton profil actuel (${pct}%). Garde-le en objectif et renforce ton dossier.`,
        en: `${program.nameEn} is a reach for your current profile (${pct}%). Keep it as a goal and strengthen your application.`,
      },
    } as const;
    const base = byZone[score.zone];
    if (!score.isEstimate) return { fr: base.fr, en: base.en };
    return {
      fr: `${base.fr} Estimation — complète ton profil pour plus de précision.`,
      en: `${base.en} Estimate — complete your profile for more precision.`,
    };
  }

  /** Best-effort 24h cache write; failures never break the response. */
  private async persist(userId: string, dto: MatchDto): Promise<void> {
    const expiresAt = new Date(Date.now() + MATCH_TTL_MS);
    await this.prismaService.tryExecute(async (prisma) => {
      const match = await prisma.match.upsert({
        where: {
          userProfileId_programId: {
            userProfileId: userId,
            programId: dto.programId,
          },
        },
        create: {
          userProfileId: userId,
          programId: dto.programId,
          institutionId: dto.institutionId,
          probability: dto.probability,
          zone: dto.zone as 'green' | 'yellow' | 'blue',
          algorithmVersion: dto.algorithmVersion,
          isEstimate: dto.isEstimate,
          expiresAt,
        },
        update: {
          probability: dto.probability,
          zone: dto.zone as 'green' | 'yellow' | 'blue',
          algorithmVersion: dto.algorithmVersion,
          isEstimate: dto.isEstimate,
          expiresAt,
        },
      });
      await prisma.matchExplanation.upsert({
        where: { matchId: match.id },
        create: {
          matchId: match.id,
          factors: dto.factors,
          narrativeFr: dto.narrative.fr,
          narrativeEn: dto.narrative.en,
        },
        update: {
          factors: dto.factors,
          narrativeFr: dto.narrative.fr,
          narrativeEn: dto.narrative.en,
        },
      });
      return match;
    });
  }
}
