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
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
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

const VERIFICATION_POLICIES = {
  countryVisa: {
    key: 'country_visa',
    label: 'Pays: visa, coûts et difficulté admission',
    cadenceDays: 30,
    owner: 'Amina KPB',
  },
  institutionScolarite: {
    key: 'institution_scolarite',
    label: 'Établissements: frais, niveaux et exigences',
    cadenceDays: 180,
    owner: 'Fatou Admin',
  },
  programScolarite: {
    key: 'program_scolarite',
    label: 'Formations: frais, durée, langue et prérequis',
    cadenceDays: 180,
    owner: 'Fatou Admin',
  },
  scholarshipDeadline: {
    key: 'scholarship_deadline',
    label: 'Bourses: deadlines, financement et éligibilité',
    cadenceDays: 30,
    owner: 'Amina KPB',
  },
} as const;

type VerificationPolicyName = keyof typeof VERIFICATION_POLICIES;

@Injectable()
export class AdminCatalogService {
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

  private verificationAudit(
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
    fallbackSourceUrl?: string,
  ) {
    const sourceUrl =
      this.nonEmptyStr(input.verificationSourceUrl) ?? fallbackSourceUrl;
    return this.clean({
      verificationSourceUrl: sourceUrl,
      lastVerifiedAt: new Date(),
      verifiedById: verifier?.id ?? 'system',
      verifiedByName:
        verifier?.fullName ?? verifier?.email ?? 'System verification',
    });
  }

  private verificationDueWhere(cadenceDays: number, now = new Date()) {
    const cutoff = new Date(now);
    cutoff.setDate(cutoff.getDate() - cadenceDays);
    return {
      OR: [{ lastVerifiedAt: null }, { lastVerifiedAt: { lt: cutoff } }],
    };
  }

  private buildVerificationItem(input: {
    policy: VerificationPolicyName;
    entityType: 'country' | 'institution' | 'program' | 'scholarship';
    id: string;
    label: string;
    context?: string | null;
    lastVerifiedAt?: Date | null;
    verifiedByName?: string | null;
    verificationSourceUrl?: string | null;
    now: Date;
  }) {
    const policy = VERIFICATION_POLICIES[input.policy];
    const dueAt = input.lastVerifiedAt
      ? new Date(
          input.lastVerifiedAt.getTime() +
            policy.cadenceDays * 24 * 60 * 60 * 1000,
        )
      : null;
    const daysSinceVerification = input.lastVerifiedAt
      ? Math.floor(
          (input.now.getTime() - input.lastVerifiedAt.getTime()) /
            (24 * 60 * 60 * 1000),
        )
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
      verificationSourceUrl: input.verificationSourceUrl ?? null,
      dueAt,
      daysSinceVerification,
      isOverdue: dueAt == null || dueAt.getTime() <= input.now.getTime(),
    };
  }

  // ════════════════════════════════════════════════════════════════════════
  // READ / LIST (admin full-fidelity)
  //
  // Returns raw Prisma rows — not the mobile-mapped catalogue shape. The
  // back-office needs every writable column (incl. inactive rows and the
  // scholarship fields the public mapper drops) to round-trip edits without
  // data loss.
  // ════════════════════════════════════════════════════════════════════════
  async listPrograms(
    query: {
      q?: string;
      countryId?: string;
      fieldId?: string;
      institutionId?: string;
      limit?: number;
      offset?: number;
    } = {},
  ) {
    this.assertDb();
    const where: Prisma.ProgramWhereInput = {};
    if (query.countryId) where.countryId = query.countryId;
    if (query.fieldId) where.fieldId = query.fieldId;
    if (query.institutionId) where.institutionId = query.institutionId;
    const q = query.q?.trim();
    if (q) {
      where.OR = [
        { nameFr: { contains: q, mode: 'insensitive' } },
        { nameEn: { contains: q, mode: 'insensitive' } },
        { levelFr: { contains: q, mode: 'insensitive' } },
      ];
    }
    const limit = Math.min(Math.max(query.limit ?? 100, 1), 500);
    const offset = Math.max(query.offset ?? 0, 0);
    const result = await this.prisma.execute((db) =>
      db.$transaction([
        db.program.findMany({
          where,
          orderBy: { nameFr: 'asc' },
          take: limit,
          skip: offset,
        }),
        db.program.count({ where }),
      ]),
    );
    const [items, total] = result ?? [[], 0];
    return { items, total, limit, offset };
  }

  async listInstitutions(countryId?: string) {
    this.assertDb();
    const where: Prisma.InstitutionWhereInput = {};
    if (countryId) where.countryId = countryId;
    const items =
      (await this.prisma.execute((db) =>
        db.institution.findMany({ where, orderBy: { nameFr: 'asc' } }),
      )) ?? [];
    return { items, total: items.length };
  }

  async listScholarships() {
    this.assertDb();
    const items =
      (await this.prisma.execute((db) =>
        db.scholarship.findMany({ orderBy: { nameFr: 'asc' } }),
      )) ?? [];
    return { items, total: items.length };
  }

  async listCountries() {
    this.assertDb();
    const items =
      (await this.prisma.execute((db) =>
        db.country.findMany({ orderBy: { displayOrder: 'asc' } }),
      )) ?? [];
    return { items, total: items.length };
  }

  async listFields() {
    this.assertDb();
    const items =
      (await this.prisma.execute((db) =>
        db.field.findMany({ orderBy: { nameFr: 'asc' } }),
      )) ?? [];
    return { items, total: items.length };
  }

  async listVerificationDue(now = new Date()) {
    this.assertDb();
    const [
      countries,
      institutions,
      programs,
      scholarships,
    ] = await Promise.all([
      this.prisma.execute((db) =>
        db.country.findMany({
          where: this.verificationDueWhere(
            VERIFICATION_POLICIES.countryVisa.cadenceDays,
            now,
          ),
          select: {
            id: true,
            code: true,
            nameFr: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            verificationSourceUrl: true,
          },
          orderBy: [{ lastVerifiedAt: 'asc' }, { displayOrder: 'asc' }],
          take: 250,
        }),
      ),
      this.prisma.execute((db) =>
        db.institution.findMany({
          where: this.verificationDueWhere(
            VERIFICATION_POLICIES.institutionScolarite.cadenceDays,
            now,
          ),
          select: {
            id: true,
            countryId: true,
            nameFr: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            verificationSourceUrl: true,
          },
          orderBy: [{ lastVerifiedAt: 'asc' }, { nameFr: 'asc' }],
          take: 250,
        }),
      ),
      this.prisma.execute((db) =>
        db.program.findMany({
          where: this.verificationDueWhere(
            VERIFICATION_POLICIES.programScolarite.cadenceDays,
            now,
          ),
          select: {
            id: true,
            countryId: true,
            institutionId: true,
            nameFr: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            verificationSourceUrl: true,
          },
          orderBy: [{ lastVerifiedAt: 'asc' }, { nameFr: 'asc' }],
          take: 250,
        }),
      ),
      this.prisma.execute((db) =>
        db.scholarship.findMany({
          where: this.verificationDueWhere(
            VERIFICATION_POLICIES.scholarshipDeadline.cadenceDays,
            now,
          ),
          select: {
            id: true,
            countryId: true,
            nameFr: true,
            lastVerifiedAt: true,
            verifiedByName: true,
            verificationSourceUrl: true,
            sourceUrl: true,
          },
          orderBy: [{ lastVerifiedAt: 'asc' }, { nameFr: 'asc' }],
          take: 250,
        }),
      ),
    ]);

    const items = [
      ...((countries ?? []).map((row) =>
        this.buildVerificationItem({
          policy: 'countryVisa',
          entityType: 'country',
          id: row.id,
          label: row.nameFr,
          context: row.code,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          verificationSourceUrl: row.verificationSourceUrl,
          now,
        }),
      )),
      ...((institutions ?? []).map((row) =>
        this.buildVerificationItem({
          policy: 'institutionScolarite',
          entityType: 'institution',
          id: row.id,
          label: row.nameFr,
          context: row.countryId,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          verificationSourceUrl: row.verificationSourceUrl,
          now,
        }),
      )),
      ...((programs ?? []).map((row) =>
        this.buildVerificationItem({
          policy: 'programScolarite',
          entityType: 'program',
          id: row.id,
          label: row.nameFr,
          context: `${row.countryId} · ${row.institutionId}`,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          verificationSourceUrl: row.verificationSourceUrl,
          now,
        }),
      )),
      ...((scholarships ?? []).map((row) =>
        this.buildVerificationItem({
          policy: 'scholarshipDeadline',
          entityType: 'scholarship',
          id: row.id,
          label: row.nameFr,
          context: row.countryId,
          lastVerifiedAt: row.lastVerifiedAt,
          verifiedByName: row.verifiedByName,
          verificationSourceUrl: row.verificationSourceUrl ?? row.sourceUrl,
          now,
        }),
      )),
    ].sort((a, b) => {
      if (a.dueAt == null && b.dueAt == null) return a.label.localeCompare(b.label);
      if (a.dueAt == null) return -1;
      if (b.dueAt == null) return 1;
      return a.dueAt.getTime() - b.dueAt.getTime();
    });

    return {
      policies: Object.values(VERIFICATION_POLICIES),
      items,
      total: items.length,
    };
  }

  // ════════════════════════════════════════════════════════════════════════
  // PROGRAMS (formations)
  // ════════════════════════════════════════════════════════════════════════
  async createProgram(
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(input, verifier),
    };
    const created = await this.prisma.execute((db) =>
      db.program.create({ data }),
    );
    return created;
  }

  async updateProgram(
    id: string,
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(input, verifier),
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
  async createInstitution(
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(input, verifier),
    };
    return this.prisma.execute((db) => db.institution.create({ data }));
  }

  async updateInstitution(
    id: string,
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(input, verifier),
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
  async createScholarship(
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      tags: this.strArr(input.tags) ?? [],
      ...this.verificationAudit(
        input,
        verifier,
        this.nonEmptyStr(input.sourceUrl),
      ),
      // sourceKey intentionally left null → flags this as a manual entry.
    };
    return this.prisma.execute((db) => db.scholarship.create({ data }));
  }

  async updateScholarship(
    id: string,
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(
        input,
        verifier,
        this.nonEmptyStr(input.sourceUrl),
      ),
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

  // ════════════════════════════════════════════════════════════════════════
  // COUNTRIES (pays)
  // ════════════════════════════════════════════════════════════════════════
  async createCountry(
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(input, verifier),
    };
    return this.prisma.execute((db) => db.country.create({ data }));
  }

  async updateCountry(
    id: string,
    input: Record<string, unknown>,
    verifier?: AdminSessionUser,
  ) {
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
      ...this.verificationAudit(input, verifier),
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
