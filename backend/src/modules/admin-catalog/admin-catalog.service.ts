// ─────────────────────────────────────────────────────────────────────────────
// Admin catalogue CRUD (Chantier B).
//
// Lets the KPB team create / edit / delete formations (Program), universités
// (Institution), bourses (Scholarship), pays (Country) and filières (Field)
// from the web back-office — no more code deploys to change content.
//
// Follows the repo's established admin-content pattern (see notifications /
// admin-users services): bodies arrive as `Record<string, unknown>` and we map
// only the fields we recognise. The global ValidationPipe skips `Object`
// bodies, so this is safe and consistent.
//
// Program degree levels are normalised to clean canonical labels on write
// (mirror of Flutter `programLevelLabel`) so "B1"/"MSc · Bac+5" never re-enter
// the catalogue.
// ─────────────────────────────────────────────────────────────────────────────

import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';

import type { AdminSessionUser } from '../auth/auth.service';
import { PrismaService } from '../prisma/prisma.service';

/// Clean canonical degree label. Mirror of the Flutter referential.
function normalizeDegreeLevel(raw: string): string {
  const s = (raw ?? '').toLowerCase();
  if (s.includes('doctorat') || s.includes('phd') || s.includes('bac+8')) {
    return 'Doctorat';
  }
  if (s.includes('mba') || s.includes('dba')) return 'MBA / DBA';
  if (
    s.includes('bac+5') || s.includes('bac +5') || s.includes('master') ||
    s.includes('msc') || s.includes('pge') || s.includes('grande ecole') ||
    s.includes('grande école') || s.includes('mastere') || s.includes('visa')
  ) {
    return 'Master';
  }
  if (s.includes('bba') || s.includes('bac+4') || s.includes('bac +4')) {
    return 'BBA';
  }
  if (
    s.includes('bac+3') || s.includes('bac +3') || s.includes('bachelor') ||
    s.includes('licence')
  ) {
    return 'Bachelor';
  }
  if (s.includes('bac+2') || s.includes('bac +2')) return 'Bac+2';
  return (raw ?? '').trim();
}

const DAY_MS = 24 * 60 * 60 * 1000;

// Exported so the reports dashboard can count due items with the SAME
// cadences as the verification queue (single source of truth).
export const VERIFICATION_POLICIES = {
  countryVisa: {
    key: 'country_visa',
    label: 'Pays: visa, couts et difficulte admission',
    cadenceDays: 30,
    owner: 'Amina KPB',
  },
  institutionScolarite: {
    key: 'institution_scolarite',
    label: 'Etablissements: frais, niveaux et exigences',
    cadenceDays: 180,
    owner: 'Fatou Admin',
  },
  programScolarite: {
    key: 'program_scolarite',
    label: 'Formations: frais, duree, langue et prerequis',
    cadenceDays: 180,
    owner: 'Fatou Admin',
  },
  scholarshipDeadline: {
    key: 'scholarship_deadline',
    label: 'Bourses: deadlines, financement et eligibilite',
    cadenceDays: 30,
    owner: 'Amina KPB',
  },
} as const;

type VerificationPolicyName = keyof typeof VERIFICATION_POLICIES;
type VerificationEntity = 'country' | 'institution' | 'program' | 'scholarship';

interface VerificationSlaCategory {
  label: string;
  cadenceDays: number;
  overdue: number;
  neverVerified: number;
  oldestDays: number | null;
}

/// Aggregate freshness view over the verification queue (KPB-161).
export interface VerificationSlaSummary {
  generatedAt: Date;
  totalOverdue: number;
  neverVerified: number;
  byCategory: Record<string, VerificationSlaCategory>;
}

@Injectable()
export class AdminCatalogService {
  private readonly logger = new Logger(AdminCatalogService.name);

  constructor(private readonly prisma: PrismaService) {}

  private assertDb() {
    if (!this.prisma.isEnabled) {
      throw new ServiceUnavailableException(
        'Database is not configured. Set DATABASE_URL.',
      );
    }
  }

  // ── small typed pickers ───────────────────────────────────────────────────
  private str(v: unknown): string | undefined {
    return typeof v === 'string' ? v : undefined;
  }

  private nonEmptyStr(v: unknown): string | undefined {
    const value = this.str(v)?.trim();
    return value ? value : undefined;
  }

  private strArr(v: unknown): string[] | undefined {
    if (!Array.isArray(v)) return undefined;
    return v.filter((x): x is string => typeof x === 'string');
  }

  private bool(v: unknown): boolean | undefined {
    return typeof v === 'boolean' ? v : undefined;
  }

  private int(v: unknown): number | undefined {
    return typeof v === 'number' && Number.isFinite(v) ? Math.trunc(v) : undefined;
  }

  private enumVal<T extends string>(v: unknown, allowed: readonly T[]): T | undefined {
    return typeof v === 'string' && (allowed as readonly string[]).includes(v)
      ? (v as T)
      : undefined;
  }

  private requireStr(input: Record<string, unknown>, key: string): string {
    const v = this.str(input[key]);
    if (v == null || v.trim() === '') {
      throw new BadRequestException(`Field "${key}" is required.`);
    }
    return v;
  }

  /// Drop undefined keys so we only update what was provided.
  private clean<T extends Record<string, unknown>>(obj: T): T {
    return Object.fromEntries(
      Object.entries(obj).filter(([, v]) => v !== undefined),
    ) as T;
  }

  private verificationDueWhere(cadenceDays: number, now = new Date()) {
    const cutoff = new Date(now.getTime() - cadenceDays * DAY_MS);
    return {
      OR: [{ lastVerifiedAt: null }, { lastVerifiedAt: { lt: cutoff } }],
    };
  }

  private verificationData(
    verified: boolean,
    sourceUrl?: unknown,
    verifier?: AdminSessionUser,
  ) {
    const srcStr = this.nonEmptyStr(sourceUrl);
    return this.clean({
      lastVerifiedAt: verified ? new Date() : null,
      verifiedById: verified ? (verifier?.id ?? 'system') : null,
      verifiedByName: verified
        ? (verifier?.fullName ?? verifier?.email ?? 'System verification')
        : null,
      ...(srcStr !== undefined ? { sourceUrl: srcStr } : {}),
    });
  }

  private buildVerificationItem(input: {
    policy: VerificationPolicyName;
    entityType: VerificationEntity;
    id: string;
    label: string;
    context?: string | null;
    lastVerifiedAt?: Date | null;
    verifiedByName?: string | null;
    sourceUrl?: string | null;
    now: Date;
  }) {
    const policy = VERIFICATION_POLICIES[input.policy];
    const dueAt = input.lastVerifiedAt
      ? new Date(input.lastVerifiedAt.getTime() + policy.cadenceDays * DAY_MS)
      : null;
    const daysSinceVerification = input.lastVerifiedAt
      ? Math.floor((input.now.getTime() - input.lastVerifiedAt.getTime()) / DAY_MS)
      : null;
    return {
      entityType: input.entityType,
      id: input.id,
      label: input.label,
      context: input.context ?? null,
      category: policy.key,
      categoryLabel: policy.label,
      cadenceDays: policy.cadenceDays,
      owner: policy.owner,
      lastVerifiedAt: input.lastVerifiedAt ?? null,
      verifiedByName: input.verifiedByName ?? null,
      sourceUrl: input.sourceUrl ?? null,
      dueAt,
      daysSinceVerification,
      isOverdue: dueAt == null || dueAt.getTime() <= input.now.getTime(),
    };
  }

  // ════════════════════════════════════════════════════════════════════════
  // VERIFICATION (data-trust signal)
  // ════════════════════════════════════════════════════════════════════════

  /// Stamp (or clear) the data-trust signal on a catalog entity. When
  /// `verified` is true, `lastVerifiedAt` is set server-side to now; an optional
  /// `sourceUrl` records where the facts were confirmed. `verified: false`
  /// clears the stamp (back to "À confirmer").
  async setVerification(
    entity: string,
    id: string,
    verified: boolean,
    sourceUrl?: unknown,
    verifier?: AdminSessionUser,
  ) {
    this.assertDb();
    const data = this.verificationData(verified, sourceUrl, verifier);
    switch (entity) {
      case 'program':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.program.update({ where: { id }, data })),
          'Program',
          id,
        );
      case 'institution':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.institution.update({ where: { id }, data })),
          'Institution',
          id,
        );
      case 'country':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.country.update({ where: { id }, data })),
          'Country',
          id,
        );
      case 'scholarship':
        return this.runUpdate(
          () => this.prisma.execute((db) => db.scholarship.update({ where: { id }, data })),
          'Scholarship',
          id,
        );
      default:
        throw new BadRequestException(`Unknown catalog entity "${entity}".`);
    }
  }

  async listVerificationDue() {
    this.assertDb();
    const now = new Date();
    const result = await this.prisma.execute((db) =>
      db.$transaction([
        db.country.findMany({
          where: {
            isActive: true,
            ...this.verificationDueWhere(
              VERIFICATION_POLICIES.countryVisa.cadenceDays,
              now,
            ),
          } as Prisma.CountryWhereInput,
          orderBy: [{ lastVerifiedAt: 'asc' }, { displayOrder: 'asc' }],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
        db.institution.findMany({
          where: this.verificationDueWhere(
            VERIFICATION_POLICIES.institutionScolarite.cadenceDays,
            now,
          ) as Prisma.InstitutionWhereInput,
          orderBy: [{ lastVerifiedAt: 'asc' }, { nameFr: 'asc' }],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            countryId: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
        db.program.findMany({
          where: this.verificationDueWhere(
            VERIFICATION_POLICIES.programScolarite.cadenceDays,
            now,
          ) as Prisma.ProgramWhereInput,
          orderBy: [{ lastVerifiedAt: 'asc' }, { nameFr: 'asc' }],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            countryId: true,
            institutionId: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
        db.scholarship.findMany({
          where: {
            isActive: true,
            moderationStatus: 'approved',
            ...this.verificationDueWhere(
              VERIFICATION_POLICIES.scholarshipDeadline.cadenceDays,
              now,
            ),
          } as Prisma.ScholarshipWhereInput,
          orderBy: [{ lastVerifiedAt: 'asc' }, { deadlineAt: 'asc' }],
          select: {
            id: true,
            nameFr: true,
            nameEn: true,
            countryId: true,
            deadlineLabelFr: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            sourceUrl: true,
          },
        }),
      ]),
    );

    const [countries, institutions, programs, scholarships] =
      result ?? [[], [], [], []];
    const items = [
      ...countries.map((row) =>
        this.buildVerificationItem({
          policy: 'countryVisa',
          entityType: 'country',
          id: row.id,
          label: row.nameFr || row.nameEn,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
      ...institutions.map((row) =>
        this.buildVerificationItem({
          policy: 'institutionScolarite',
          entityType: 'institution',
          id: row.id,
          label: row.nameFr || row.nameEn,
          context: row.countryId,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
      ...programs.map((row) =>
        this.buildVerificationItem({
          policy: 'programScolarite',
          entityType: 'program',
          id: row.id,
          label: row.nameFr || row.nameEn,
          context: `${row.countryId} / ${row.institutionId}`,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
      ...scholarships.map((row) =>
        this.buildVerificationItem({
          policy: 'scholarshipDeadline',
          entityType: 'scholarship',
          id: row.id,
          label: row.nameFr || row.nameEn,
          context: row.deadlineLabelFr || row.countryId,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          sourceUrl: row.sourceUrl,
          now,
        }),
      ),
    ].sort((a, b) => {
      if (a.lastVerifiedAt == null && b.lastVerifiedAt != null) return -1;
      if (a.lastVerifiedAt != null && b.lastVerifiedAt == null) return 1;
      return (
        (b.daysSinceVerification ?? Number.MAX_SAFE_INTEGER) -
        (a.daysSinceVerification ?? Number.MAX_SAFE_INTEGER)
      );
    });

    return {
      items,
      total: items.length,
      policies: Object.values(VERIFICATION_POLICIES),
    };
  }

  /// Aggregate the verification queue into an SLA view: how many catalog items
  /// are overdue (past their per-category cadence), split by category, with the
  /// oldest age and the count never verified. Derived from the same source as
  /// the admin queue, so counts always match what admins see.
  async verificationSlaSummary(now = new Date()): Promise<VerificationSlaSummary> {
    const { items } = await this.listVerificationDue();
    const byCategory: Record<string, VerificationSlaCategory> = {};
    for (const policy of Object.values(VERIFICATION_POLICIES)) {
      byCategory[policy.key] = {
        label: policy.label,
        cadenceDays: policy.cadenceDays,
        overdue: 0,
        neverVerified: 0,
        oldestDays: null,
      };
    }
    for (const item of items) {
      const cat = byCategory[item.category];
      if (!cat) continue;
      cat.overdue += 1;
      if (item.lastVerifiedAt == null) {
        cat.neverVerified += 1;
      } else if (item.daysSinceVerification != null) {
        cat.oldestDays = Math.max(
          cat.oldestDays ?? 0,
          item.daysSinceVerification,
        );
      }
    }
    return {
      generatedAt: now,
      totalOverdue: items.length,
      neverVerified: Object.values(byCategory).reduce(
        (n, c) => n + c.neverVerified,
        0,
      ),
      byCategory,
    };
  }

  /// Daily ops signal (KPB-161): a WARN when catalog data has drifted past its
  /// freshness cadence, so stale deadlines / costs get re-verified before they
  /// mislead a student. Stdout is the only alert channel today; wiring it to a
  /// real alerting sink is a follow-up (KPB-167 observability).
  @Cron('0 7 * * *')
  async checkVerificationSla(): Promise<void> {
    if (!this.prisma.isEnabled) return;
    try {
      const sla = await this.verificationSlaSummary();
      if (sla.totalOverdue === 0) {
        this.logger.log('Catalog freshness OK — nothing past its cadence.');
        return;
      }
      const breakdown = Object.entries(sla.byCategory)
        .filter(([, c]) => c.overdue > 0)
        .map(([key, c]) => {
          const never = c.neverVerified
            ? ` (${c.neverVerified} never verified)`
            : '';
          const oldest = c.oldestDays != null ? `, +${c.oldestDays}d` : '';
          return `${key}=${c.overdue}${never}${oldest}`;
        })
        .join('; ');
      this.logger.warn(
        `Catalog freshness SLA breach: ${sla.totalOverdue} item(s) overdue — ${breakdown}. Re-verify in the admin queue.`,
      );
    } catch (error) {
      this.logger.error(
        `Verification SLA check failed (${error instanceof Error ? error.message : 'unknown'}).`,
      );
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROGRAMS (formations)
  // ════════════════════════════════════════════════════════════════════════
  async createProgram(input: Record<string, unknown>) {
    this.assertDb();
    const data: Prisma.ProgramCreateInput = {
      institutionId: this.requireStr(input, 'institutionId'),
      countryId: this.requireStr(input, 'countryId'),
      fieldId: this.requireStr(input, 'fieldId'),
      nameFr: this.requireStr(input, 'nameFr'),
      nameEn: this.str(input.nameEn) ?? this.requireStr(input, 'nameFr'),
      levelFr: normalizeDegreeLevel(this.str(input.levelFr) ?? ''),
      levelEn: normalizeDegreeLevel(
        this.str(input.levelEn) ?? this.str(input.levelFr) ?? '',
      ),
      durationFr: this.str(input.durationFr) ?? '',
      durationEn: this.str(input.durationEn) ?? this.str(input.durationFr) ?? '',
      tuitionFr: this.str(input.tuitionFr) ?? '',
      tuitionEn: this.str(input.tuitionEn) ?? this.str(input.tuitionFr) ?? '',
      languageFr: this.str(input.languageFr) ?? '',
      languageEn: this.str(input.languageEn) ?? this.str(input.languageFr) ?? '',
      requirementsFr: this.strArr(input.requirementsFr) ?? [],
      requirementsEn: this.strArr(input.requirementsEn) ?? [],
    };
    const created = await this.prisma.execute((db) =>
      db.program.create({ data }),
    );
    return created;
  }

  async updateProgram(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const rawLevelFr = this.str(input.levelFr);
    const rawLevelEn = this.str(input.levelEn);
    const data = this.clean<Prisma.ProgramUpdateInput>({
      institutionId: this.str(input.institutionId),
      countryId: this.str(input.countryId),
      fieldId: this.str(input.fieldId),
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      levelFr: rawLevelFr != null ? normalizeDegreeLevel(rawLevelFr) : undefined,
      levelEn: rawLevelEn != null ? normalizeDegreeLevel(rawLevelEn) : undefined,
      durationFr: this.str(input.durationFr),
      durationEn: this.str(input.durationEn),
      tuitionFr: this.str(input.tuitionFr),
      tuitionEn: this.str(input.tuitionEn),
      languageFr: this.str(input.languageFr),
      languageEn: this.str(input.languageEn),
      requirementsFr: this.strArr(input.requirementsFr),
      requirementsEn: this.strArr(input.requirementsEn),
    });
    return this.runUpdate(() =>
      this.prisma.execute((db) => db.program.update({ where: { id }, data })),
      'Program',
      id,
    );
  }

  async deleteProgram(id: string) {
    this.assertDb();
    await this.runUpdate(
      () => this.prisma.execute((db) => db.program.delete({ where: { id } })),
      'Program',
      id,
    );
    return { id, deleted: true };
  }

  // ════════════════════════════════════════════════════════════════════════
  // INSTITUTIONS (universités)
  // ════════════════════════════════════════════════════════════════════════
  async createInstitution(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.InstitutionCreateInput = {
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      countryId: this.requireStr(input, 'countryId'),
      locationFr: this.str(input.locationFr) ?? '',
      locationEn: this.str(input.locationEn) ?? this.str(input.locationFr) ?? '',
      overviewFr: this.str(input.overviewFr) ?? '',
      overviewEn: this.str(input.overviewEn) ?? this.str(input.overviewFr) ?? '',
      studyLevels: (this.strArr(input.studyLevels) ?? []).map(normalizeDegreeLevel),
      tuitionLabelFr: this.str(input.tuitionLabelFr) ?? '',
      tuitionLabelEn:
        this.str(input.tuitionLabelEn) ?? this.str(input.tuitionLabelFr) ?? '',
      languageRequirementsFr: this.str(input.languageRequirementsFr) ?? '',
      languageRequirementsEn:
        this.str(input.languageRequirementsEn) ??
        this.str(input.languageRequirementsFr) ??
        '',
      intakePeriods: this.strArr(input.intakePeriods) ?? [],
      programIds: this.strArr(input.programIds) ?? [],
      isPartner: this.bool(input.isPartner) ?? false,
    };
    return this.prisma.execute((db) => db.institution.create({ data }));
  }

  async updateInstitution(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const levels = this.strArr(input.studyLevels);
    const data = this.clean<Prisma.InstitutionUpdateInput>({
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      countryId: this.str(input.countryId),
      locationFr: this.str(input.locationFr),
      locationEn: this.str(input.locationEn),
      overviewFr: this.str(input.overviewFr),
      overviewEn: this.str(input.overviewEn),
      studyLevels: levels ? levels.map(normalizeDegreeLevel) : undefined,
      tuitionLabelFr: this.str(input.tuitionLabelFr),
      tuitionLabelEn: this.str(input.tuitionLabelEn),
      languageRequirementsFr: this.str(input.languageRequirementsFr),
      languageRequirementsEn: this.str(input.languageRequirementsEn),
      intakePeriods: this.strArr(input.intakePeriods),
      programIds: this.strArr(input.programIds),
      isPartner: this.bool(input.isPartner),
    });
    return this.runUpdate(
      () =>
        this.prisma.execute((db) =>
          db.institution.update({ where: { id }, data }),
        ),
      'Institution',
      id,
    );
  }

  async deleteInstitution(id: string) {
    this.assertDb();
    // Guard: refuse to delete an institution that still has programs.
    const programCount = await this.prisma.execute((db) =>
      db.program.count({ where: { institutionId: id } }),
    );
    if ((programCount ?? 0) > 0) {
      throw new BadRequestException(
        `Cannot delete institution ${id}: ${programCount} program(s) still reference it. Reassign or delete them first.`,
      );
    }
    await this.runUpdate(
      () =>
        this.prisma.execute((db) => db.institution.delete({ where: { id } })),
      'Institution',
      id,
    );
    return { id, deleted: true };
  }

  // ════════════════════════════════════════════════════════════════════════
  // SCHOLARSHIPS (bourses) — manual entries keep sourceKey null so the scraper
  // refresh (which upserts by prefixed sourceKey) never touches them.
  // ════════════════════════════════════════════════════════════════════════
  async createScholarship(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.ScholarshipCreateInput = {
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      countryId: this.requireStr(input, 'countryId'),
      countryNameFr: this.str(input.countryNameFr) ?? '',
      countryNameEn: this.str(input.countryNameEn) ?? '',
      levelEligibleFr: this.str(input.levelEligibleFr) ?? '',
      levelEligibleEn: this.str(input.levelEligibleEn) ?? '',
      typeOfFundingFr: this.str(input.typeOfFundingFr) ?? '',
      typeOfFundingEn: this.str(input.typeOfFundingEn) ?? '',
      applicationRequirement:
        this.enumVal(input.applicationRequirement, [
          'automatic',
          'separate_application',
        ] as const) ?? 'separate_application',
      deadlineLabelFr: this.str(input.deadlineLabelFr) ?? '',
      deadlineLabelEn: this.str(input.deadlineLabelEn) ?? '',
      descriptionFr: this.str(input.descriptionFr) ?? '',
      descriptionEn: this.str(input.descriptionEn) ?? '',
      advantagesFr: this.strArr(input.advantagesFr) ?? [],
      advantagesEn: this.strArr(input.advantagesEn) ?? [],
      eligibilityFr: this.strArr(input.eligibilityFr) ?? [],
      eligibilityEn: this.strArr(input.eligibilityEn) ?? [],
      keyRequirementsFr: this.strArr(input.keyRequirementsFr) ?? [],
      keyRequirementsEn: this.strArr(input.keyRequirementsEn) ?? [],
      relatedFieldIds: this.strArr(input.relatedFieldIds) ?? [],
      baseMatch: this.int(input.baseMatch) ?? 30,
      applicationUrl: this.str(input.applicationUrl) ?? null,
      sourceUrl: this.str(input.sourceUrl) ?? null,
      isActive: this.bool(input.isActive) ?? true,
      // Every manual entry passes through the same completeness gate as an
      // imported candidate. Approval is an explicit, audited admin action.
      moderationStatus: 'pending',
      tags: this.strArr(input.tags) ?? [],
      // sourceKey intentionally left null → flags this as a manual entry.
    };
    return this.prisma.execute((db) => db.scholarship.create({ data }));
  }

  async updateScholarship(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const data = this.clean<Prisma.ScholarshipUpdateInput>({
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      countryId: this.str(input.countryId),
      countryNameFr: this.str(input.countryNameFr),
      countryNameEn: this.str(input.countryNameEn),
      levelEligibleFr: this.str(input.levelEligibleFr),
      levelEligibleEn: this.str(input.levelEligibleEn),
      typeOfFundingFr: this.str(input.typeOfFundingFr),
      typeOfFundingEn: this.str(input.typeOfFundingEn),
      applicationRequirement: this.enumVal(input.applicationRequirement, [
        'automatic',
        'separate_application',
      ] as const),
      deadlineLabelFr: this.str(input.deadlineLabelFr),
      deadlineLabelEn: this.str(input.deadlineLabelEn),
      descriptionFr: this.str(input.descriptionFr),
      descriptionEn: this.str(input.descriptionEn),
      advantagesFr: this.strArr(input.advantagesFr),
      advantagesEn: this.strArr(input.advantagesEn),
      eligibilityFr: this.strArr(input.eligibilityFr),
      eligibilityEn: this.strArr(input.eligibilityEn),
      keyRequirementsFr: this.strArr(input.keyRequirementsFr),
      keyRequirementsEn: this.strArr(input.keyRequirementsEn),
      relatedFieldIds: this.strArr(input.relatedFieldIds),
      baseMatch: this.int(input.baseMatch),
      applicationUrl: this.str(input.applicationUrl),
      sourceUrl: this.str(input.sourceUrl),
      isActive: this.bool(input.isActive),
      tags: this.strArr(input.tags),
    });
    return this.runUpdate(
      () =>
        this.prisma.execute((db) =>
          db.scholarship.update({ where: { id }, data }),
        ),
      'Scholarship',
      id,
    );
  }

  async deleteScholarship(id: string) {
    this.assertDb();
    await this.runUpdate(
      () =>
        this.prisma.execute((db) => db.scholarship.delete({ where: { id } })),
      'Scholarship',
      id,
    );
    return { id, deleted: true };
  }

  // ── Scholarship application steps ("comment postuler") ────────────────────
  // Ordered, admin-authored steps distinct per scholarship — never scraped.
  async listApplicationSteps(scholarshipId: string) {
    this.assertDb();
    return this.prisma.execute((db) =>
      db.scholarshipApplicationStep.findMany({
        where: { scholarshipId },
        orderBy: { stepNumber: 'asc' },
      }),
    );
  }

  async createApplicationStep(
    scholarshipId: string,
    input: Record<string, unknown>,
  ) {
    this.assertDb();
    const titleFr = this.requireStr(input, 'titleFr');
    const stepNumber = this.int(input.stepNumber);
    if (stepNumber == null) {
      throw new BadRequestException('Field "stepNumber" is required.');
    }
    const data: Prisma.ScholarshipApplicationStepCreateInput = {
      scholarship: { connect: { id: scholarshipId } },
      stepNumber,
      titleFr,
      titleEn: this.str(input.titleEn) ?? titleFr,
      descriptionFr: this.str(input.descriptionFr) ?? '',
      descriptionEn: this.str(input.descriptionEn) ?? '',
      estimatedDurationDays: this.int(input.estimatedDurationDays) ?? null,
    };
    try {
      return await this.prisma.execute((db) =>
        db.scholarshipApplicationStep.create({ data }),
      );
    } catch (error) {
      throw this.mapStepUniqueError(error, scholarshipId, stepNumber);
    }
  }

  async updateApplicationStep(
    scholarshipId: string,
    stepId: string,
    input: Record<string, unknown>,
  ) {
    this.assertDb();
    const data = this.clean<Prisma.ScholarshipApplicationStepUpdateInput>({
      stepNumber: this.int(input.stepNumber),
      titleFr: this.str(input.titleFr),
      titleEn: this.str(input.titleEn),
      descriptionFr: this.str(input.descriptionFr),
      descriptionEn: this.str(input.descriptionEn),
      estimatedDurationDays: this.int(input.estimatedDurationDays),
    });
    try {
      return await this.runUpdate(
        () =>
          this.prisma.execute((db) =>
            db.scholarshipApplicationStep.update({
              where: { id: stepId },
              data,
            }),
          ),
        'ScholarshipApplicationStep',
        stepId,
      );
    } catch (error) {
      throw this.mapStepUniqueError(error, scholarshipId, data.stepNumber);
    }
  }

  async deleteApplicationStep(scholarshipId: string, stepId: string) {
    this.assertDb();
    await this.runUpdate(
      () =>
        this.prisma.execute((db) =>
          db.scholarshipApplicationStep.delete({ where: { id: stepId } }),
        ),
      'ScholarshipApplicationStep',
      stepId,
    );
    return { id: stepId, deleted: true };
  }

  /// Turns a unique-constraint violation on [scholarshipId, stepNumber] into a
  /// readable 400 instead of a raw Prisma P2002.
  private mapStepUniqueError(
    error: unknown,
    scholarshipId: string,
    stepNumber: unknown,
  ) {
    if (
      error &&
      typeof error === 'object' &&
      'code' in error &&
      (error as { code: string }).code === 'P2002'
    ) {
      return new BadRequestException(
        `A step numbered ${String(stepNumber)} already exists for scholarship ${scholarshipId}.`,
      );
    }
    return error as Error;
  }

  // ════════════════════════════════════════════════════════════════════════
  // COUNTRIES (pays)
  // ════════════════════════════════════════════════════════════════════════
  async createCountry(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.CountryCreateInput = {
      code: this.requireStr(input, 'code'),
      flagEmoji: this.str(input.flagEmoji) ?? '🌍',
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      whyStudyFr: this.str(input.whyStudyFr) ?? '',
      whyStudyEn: this.str(input.whyStudyEn) ?? '',
      tuitionRangeFr: this.str(input.tuitionRangeFr) ?? '',
      tuitionRangeEn: this.str(input.tuitionRangeEn) ?? '',
      livingCostRangeFr: this.str(input.livingCostRangeFr) ?? '',
      livingCostRangeEn: this.str(input.livingCostRangeEn) ?? '',
      visaOverviewFr: this.str(input.visaOverviewFr) ?? '',
      visaOverviewEn: this.str(input.visaOverviewEn) ?? '',
      admissionDifficultyFr: this.str(input.admissionDifficultyFr) ?? '',
      admissionDifficultyEn: this.str(input.admissionDifficultyEn) ?? '',
      taglineFr: this.str(input.taglineFr) ?? '',
      taglineEn: this.str(input.taglineEn) ?? '',
      popularFieldIds: this.strArr(input.popularFieldIds) ?? [],
      displayOrder: this.int(input.displayOrder) ?? 0,
      isActive: this.bool(input.isActive) ?? true,
    };
    return this.prisma.execute((db) => db.country.create({ data }));
  }

  async updateCountry(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const data = this.clean<Prisma.CountryUpdateInput>({
      code: this.str(input.code),
      flagEmoji: this.str(input.flagEmoji),
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      whyStudyFr: this.str(input.whyStudyFr),
      whyStudyEn: this.str(input.whyStudyEn),
      tuitionRangeFr: this.str(input.tuitionRangeFr),
      tuitionRangeEn: this.str(input.tuitionRangeEn),
      livingCostRangeFr: this.str(input.livingCostRangeFr),
      livingCostRangeEn: this.str(input.livingCostRangeEn),
      visaOverviewFr: this.str(input.visaOverviewFr),
      visaOverviewEn: this.str(input.visaOverviewEn),
      admissionDifficultyFr: this.str(input.admissionDifficultyFr),
      admissionDifficultyEn: this.str(input.admissionDifficultyEn),
      taglineFr: this.str(input.taglineFr),
      taglineEn: this.str(input.taglineEn),
      popularFieldIds: this.strArr(input.popularFieldIds),
      displayOrder: this.int(input.displayOrder),
      isActive: this.bool(input.isActive),
    });
    return this.runUpdate(
      () => this.prisma.execute((db) => db.country.update({ where: { id }, data })),
      'Country',
      id,
    );
  }

  async deleteCountry(id: string) {
    this.assertDb();
    const [programCount, institutionCount] = await Promise.all([
      this.prisma.execute((db) => db.program.count({ where: { countryId: id } })),
      this.prisma.execute((db) =>
        db.institution.count({ where: { countryId: id } }),
      ),
    ]);
    if ((programCount ?? 0) > 0 || (institutionCount ?? 0) > 0) {
      throw new BadRequestException(
        `Cannot delete country ${id}: ${programCount ?? 0} program(s) and ${institutionCount ?? 0} institution(s) still reference it. Consider deactivating (isActive=false) instead.`,
      );
    }
    await this.runUpdate(
      () => this.prisma.execute((db) => db.country.delete({ where: { id } })),
      'Country',
      id,
    );
    return { id, deleted: true };
  }

  // ════════════════════════════════════════════════════════════════════════
  // FIELDS (filières)
  // ════════════════════════════════════════════════════════════════════════
  async createField(input: Record<string, unknown>) {
    this.assertDb();
    const nameFr = this.requireStr(input, 'nameFr');
    const data: Prisma.FieldCreateInput = {
      nameFr,
      nameEn: this.str(input.nameEn) ?? nameFr,
      descriptionFr: this.str(input.descriptionFr) ?? '',
      descriptionEn: this.str(input.descriptionEn) ?? '',
      subjectsFr: this.strArr(input.subjectsFr) ?? [],
      subjectsEn: this.strArr(input.subjectsEn) ?? [],
      careersFr: this.strArr(input.careersFr) ?? [],
      careersEn: this.strArr(input.careersEn) ?? [],
      dailyLifeFr: this.strArr(input.dailyLifeFr) ?? [],
      dailyLifeEn: this.strArr(input.dailyLifeEn) ?? [],
      skillsFr: this.strArr(input.skillsFr) ?? [],
      skillsEn: this.strArr(input.skillsEn) ?? [],
      personalityTraitsFr: this.strArr(input.personalityTraitsFr) ?? [],
      personalityTraitsEn: this.strArr(input.personalityTraitsEn) ?? [],
      relatedCountryIds: this.strArr(input.relatedCountryIds) ?? [],
      relatedScholarshipIds: this.strArr(input.relatedScholarshipIds) ?? [],
      accentColorHex: this.str(input.accentColorHex) ?? null,
    };
    return this.prisma.execute((db) => db.field.create({ data }));
  }

  async updateField(id: string, input: Record<string, unknown>) {
    this.assertDb();
    const data = this.clean<Prisma.FieldUpdateInput>({
      nameFr: this.str(input.nameFr),
      nameEn: this.str(input.nameEn),
      descriptionFr: this.str(input.descriptionFr),
      descriptionEn: this.str(input.descriptionEn),
      subjectsFr: this.strArr(input.subjectsFr),
      subjectsEn: this.strArr(input.subjectsEn),
      careersFr: this.strArr(input.careersFr),
      careersEn: this.strArr(input.careersEn),
      dailyLifeFr: this.strArr(input.dailyLifeFr),
      dailyLifeEn: this.strArr(input.dailyLifeEn),
      skillsFr: this.strArr(input.skillsFr),
      skillsEn: this.strArr(input.skillsEn),
      personalityTraitsFr: this.strArr(input.personalityTraitsFr),
      personalityTraitsEn: this.strArr(input.personalityTraitsEn),
      relatedCountryIds: this.strArr(input.relatedCountryIds),
      relatedScholarshipIds: this.strArr(input.relatedScholarshipIds),
      accentColorHex: this.str(input.accentColorHex),
    });
    return this.runUpdate(
      () => this.prisma.execute((db) => db.field.update({ where: { id }, data })),
      'Field',
      id,
    );
  }

  async deleteField(id: string) {
    this.assertDb();
    await this.runUpdate(
      () => this.prisma.execute((db) => db.field.delete({ where: { id } })),
      'Field',
      id,
    );
    return { id, deleted: true };
  }

  // ── shared: translate Prisma "record not found" (P2025) → 404 ──────────────
  private async runUpdate<T>(
    op: () => Promise<T>,
    entity: string,
    id: string,
  ): Promise<T> {
    try {
      return await op();
    } catch (error) {
      if (
        error &&
        typeof error === 'object' &&
        'code' in error &&
        (error as { code: string }).code === 'P2025'
      ) {
        throw new NotFoundException(`${entity} ${id} not found.`);
      }
      throw error;
    }
  }
}
