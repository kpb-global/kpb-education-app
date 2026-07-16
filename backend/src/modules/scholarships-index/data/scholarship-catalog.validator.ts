import {
  REQUIRED_OFFICIAL_SOURCE_KINDS,
  SCHOLARSHIP_STUDY_LEVELS,
  type ScholarshipStudyLevel,
  type VerifiedScholarshipCatalogRecord,
  type VersionedScholarshipCatalog,
} from './scholarship-catalog.types';

const DAY_MS = 24 * 60 * 60 * 1000;
const MAX_VERIFICATION_AGE_DAYS = 30;

export interface ScholarshipCatalogValidationIssue {
  code: string;
  path: string;
  message: string;
}

export interface ScholarshipCatalogValidationReport {
  valid: boolean;
  catalogVersion: string;
  uniqueRecordCount: number;
  uniqueRecordDeficit: number;
  verifiedCounts: Record<ScholarshipStudyLevel, number>;
  backlogCounts: Record<ScholarshipStudyLevel, number>;
  volumeDeficits: Record<ScholarshipStudyLevel, number>;
  backlogDeficits: Record<ScholarshipStudyLevel, number>;
  issues: ScholarshipCatalogValidationIssue[];
}

export interface ScholarshipCatalogValidationOptions {
  includeVolumeTargets?: boolean;
  now?: Date;
}

function isNonBlank(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isHttpsUrl(value: unknown): value is string {
  if (!isNonBlank(value)) return false;
  try {
    return new URL(value).protocol === 'https:';
  } catch {
    return false;
  }
}

function parseDate(value: unknown): Date | null {
  if (!isNonBlank(value)) return null;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function push(
  issues: ScholarshipCatalogValidationIssue[],
  code: string,
  path: string,
  message: string,
) {
  issues.push({ code, path, message });
}

function requireBilingualList(
  issues: ScholarshipCatalogValidationIssue[],
  path: string,
  fr: string[],
  en: string[],
) {
  if (!Array.isArray(fr) || fr.length === 0 || fr.some((item) => !isNonBlank(item))) {
    push(issues, 'missing_fr_list', `${path}Fr`, 'A non-empty French list is required.');
  }
  if (!Array.isArray(en) || en.length === 0 || en.some((item) => !isNonBlank(item))) {
    push(issues, 'missing_en_list', `${path}En`, 'A non-empty English list is required.');
  }
  if (Array.isArray(fr) && Array.isArray(en) && fr.length !== en.length) {
    push(
      issues,
      'bilingual_list_length_mismatch',
      path,
      'French and English lists must describe the same number of items.',
    );
  }
}

function validateRecord(
  record: VerifiedScholarshipCatalogRecord,
  index: number,
  issues: ScholarshipCatalogValidationIssue[],
  now: Date,
) {
  const root = `records[${index}]`;
  const scholarship = record.scholarship;
  const requiredText: Array<[string, unknown]> = [
    ['catalogId', record.catalogId],
    ['scholarship.id', scholarship.id],
    ['scholarship.nameFr', scholarship.nameFr],
    ['scholarship.nameEn', scholarship.nameEn],
    ['scholarship.countryNameFr', scholarship.countryNameFr],
    ['scholarship.countryNameEn', scholarship.countryNameEn],
    ['scholarship.levelEligibleFr', scholarship.levelEligibleFr],
    ['scholarship.levelEligibleEn', scholarship.levelEligibleEn],
    ['scholarship.typeOfFundingFr', scholarship.typeOfFundingFr],
    ['scholarship.typeOfFundingEn', scholarship.typeOfFundingEn],
    ['scholarship.deadlineLabelFr', scholarship.deadlineLabelFr],
    ['scholarship.deadlineLabelEn', scholarship.deadlineLabelEn],
    ['scholarship.descriptionFr', scholarship.descriptionFr],
    ['scholarship.descriptionEn', scholarship.descriptionEn],
    ['verifiedBy', record.verifiedBy],
  ];
  for (const [path, value] of requiredText) {
    if (!isNonBlank(value)) {
      push(issues, 'missing_text', `${root}.${path}`, 'A non-empty value is required.');
    }
  }

  if (!/^[a-z0-9]+(?:[_-][a-z0-9]+)*$/.test(scholarship.id)) {
    push(issues, 'invalid_id', `${root}.scholarship.id`, 'Use a stable lowercase slug-like id.');
  }
  if (!/^[a-z]{3}$/.test(scholarship.countryId)) {
    push(
      issues,
      'invalid_country_id',
      `${root}.scholarship.countryId`,
      'Use the canonical three-letter lowercase country id.',
    );
  }

  if (!Array.isArray(record.levels) || record.levels.length === 0) {
    push(issues, 'missing_levels', `${root}.levels`, 'At least one structured study level is required.');
  } else if (record.levels.some((level) => !SCHOLARSHIP_STUDY_LEVELS.includes(level))) {
    push(issues, 'invalid_level', `${root}.levels`, 'An unsupported study level was provided.');
  }

  requireBilingualList(
    issues,
    `${root}.scholarship.advantages`,
    scholarship.advantagesFr,
    scholarship.advantagesEn,
  );
  requireBilingualList(
    issues,
    `${root}.scholarship.eligibility`,
    scholarship.eligibilityFr,
    scholarship.eligibilityEn,
  );
  requireBilingualList(
    issues,
    `${root}.scholarship.keyRequirements`,
    scholarship.keyRequirementsFr,
    scholarship.keyRequirementsEn,
  );

  for (const [path, url] of [
    ['scholarship.applicationUrl', scholarship.applicationUrl],
    ['scholarship.sourceUrl', scholarship.sourceUrl],
    ['cycle.sourceUrl', record.cycle.sourceUrl],
  ] as const) {
    if (!isHttpsUrl(url)) {
      push(issues, 'invalid_https_url', `${root}.${path}`, 'An HTTPS URL is required.');
    }
  }

  if (!Array.isArray(record.applicationSteps) || record.applicationSteps.length === 0) {
    push(
      issues,
      'missing_application_steps',
      `${root}.applicationSteps`,
      'At least one complete application step is required.',
    );
  } else {
    const seenStepNumbers = new Set<number>();
    for (const [stepIndex, step] of record.applicationSteps.entries()) {
      const stepPath = `${root}.applicationSteps[${stepIndex}]`;
      if (!Number.isInteger(step.stepNumber) || step.stepNumber < 1) {
        push(issues, 'invalid_step_number', `${stepPath}.stepNumber`, 'Step numbers start at 1.');
      } else if (seenStepNumbers.has(step.stepNumber)) {
        push(issues, 'duplicate_step_number', `${stepPath}.stepNumber`, 'Step numbers must be unique.');
      }
      seenStepNumbers.add(step.stepNumber);
      for (const [field, value] of [
        ['titleFr', step.titleFr],
        ['titleEn', step.titleEn],
        ['descriptionFr', step.descriptionFr],
        ['descriptionEn', step.descriptionEn],
      ]) {
        if (!isNonBlank(value)) {
          push(issues, 'missing_step_translation', `${stepPath}.${field}`, 'FR and EN step copy is required.');
        }
      }
    }
  }

  const sourceKinds = new Set<string>();
  for (const [sourceIndex, source] of record.officialSources.entries()) {
    const sourcePath = `${root}.officialSources[${sourceIndex}]`;
    sourceKinds.add(source.kind);
    if (source.isOfficial !== true) {
      push(issues, 'unofficial_source', `${sourcePath}.isOfficial`, 'Only declared official sources are importable.');
    }
    if (!isHttpsUrl(source.url)) {
      push(issues, 'invalid_https_url', `${sourcePath}.url`, 'Official sources must use HTTPS.');
    }
    if (!isNonBlank(source.label)) {
      push(issues, 'missing_source_label', `${sourcePath}.label`, 'Describe the official authority/page.');
    }
    const checkedAt = parseDate(source.checkedAt);
    if (!checkedAt) {
      push(issues, 'invalid_source_check_date', `${sourcePath}.checkedAt`, 'A valid check timestamp is required.');
    } else {
      const ageDays = Math.floor((now.getTime() - checkedAt.getTime()) / DAY_MS);
      if (ageDays < 0 || ageDays > MAX_VERIFICATION_AGE_DAYS) {
        push(
          issues,
          'stale_source_check',
          `${sourcePath}.checkedAt`,
          `Official sources must have been checked within ${MAX_VERIFICATION_AGE_DAYS} days.`,
        );
      }
    }
  }
  for (const kind of REQUIRED_OFFICIAL_SOURCE_KINDS) {
    if (!sourceKinds.has(kind)) {
      push(
        issues,
        'missing_official_source_kind',
        `${root}.officialSources`,
        `Missing official source evidence for "${kind}".`,
      );
    }
  }

  const sourceUrlsByKind = new Map(
    record.officialSources.map((source) => [source.kind, source.url]),
  );
  for (const [kind, payloadPath, payloadUrl] of [
    ['overview', 'scholarship.sourceUrl', scholarship.sourceUrl],
    ['application', 'scholarship.applicationUrl', scholarship.applicationUrl],
    ['cycle', 'cycle.sourceUrl', record.cycle.sourceUrl],
  ] as const) {
    const evidenceUrl = sourceUrlsByKind.get(kind);
    if (evidenceUrl && evidenceUrl !== payloadUrl) {
      push(
        issues,
        'source_payload_url_mismatch',
        `${root}.${payloadPath}`,
        `The payload URL must exactly match the declared official ${kind} source.`,
      );
    }
  }

  const verifiedAt = parseDate(record.verifiedAt);
  if (!verifiedAt) {
    push(issues, 'invalid_verification_date', `${root}.verifiedAt`, 'A valid verification timestamp is required.');
  } else {
    const ageDays = Math.floor((now.getTime() - verifiedAt.getTime()) / DAY_MS);
    if (ageDays < 0 || ageDays > MAX_VERIFICATION_AGE_DAYS) {
      push(
        issues,
        'stale_verification',
        `${root}.verifiedAt`,
        `The record must have been verified within ${MAX_VERIFICATION_AGE_DAYS} days.`,
      );
    }
  }

  const cycle = record.cycle;
  if (!/^\d{4}-\d{4}$/.test(cycle.academicYear)) {
    push(issues, 'invalid_academic_year', `${root}.cycle.academicYear`, 'Use YYYY-YYYY.');
  }
  const startRaw =
    cycle.dateConfidence === 'confirmed' ? cycle.opensAt : cycle.estimatedOpenAt;
  const closeRaw =
    cycle.dateConfidence === 'confirmed' ? cycle.closesAt : cycle.estimatedCloseAt;
  const start = parseDate(startRaw);
  const close = parseDate(closeRaw);
  if (!start || !close) {
    push(
      issues,
      'missing_cycle_dates',
      `${root}.cycle`,
      cycle.dateConfidence === 'confirmed'
        ? 'Confirmed cycles require opensAt and closesAt.'
        : 'Estimated cycles require estimatedOpenAt and estimatedCloseAt.',
    );
  } else if (close <= start) {
    push(issues, 'invalid_cycle_order', `${root}.cycle`, 'The closing date must be after the opening date.');
  }
  if (cycle.status === 'open' && cycle.dateConfidence !== 'confirmed') {
    push(issues, 'open_cycle_not_confirmed', `${root}.cycle`, 'An open cycle must use confirmed dates.');
  }
}

export function validateScholarshipCatalog(
  catalog: VersionedScholarshipCatalog,
  options: ScholarshipCatalogValidationOptions = {},
): ScholarshipCatalogValidationReport {
  const issues: ScholarshipCatalogValidationIssue[] = [];
  const now = options.now ?? new Date();
  const includeVolumeTargets = options.includeVolumeTargets ?? true;
  const verifiedCounts = { secondary: 0, bachelor: 0, master: 0 };
  const backlogCounts = { secondary: 0, bachelor: 0, master: 0 };

  if (catalog.schemaVersion !== 1) {
    push(issues, 'unsupported_schema_version', 'schemaVersion', 'Only catalog schema version 1 is supported.');
  }
  if (!/^\d+\.\d+\.\d+$/.test(catalog.catalogVersion)) {
    push(issues, 'invalid_catalog_version', 'catalogVersion', 'Use a semantic version such as 1.0.0.');
  }
  if (!Number.isInteger(catalog.volumeTargets.uniqueRecords) || catalog.volumeTargets.uniqueRecords < 1) {
    push(
      issues,
      'invalid_unique_record_target',
      'volumeTargets.uniqueRecords',
      'The unique-record target must be a positive integer.',
    );
  }

  const recordIds = new Set<string>();
  for (const [index, record] of catalog.records.entries()) {
    if (recordIds.has(record.catalogId) || recordIds.has(record.scholarship.id)) {
      push(issues, 'duplicate_record_id', `records[${index}]`, 'Catalog and scholarship ids must be unique.');
    }
    recordIds.add(record.catalogId);
    recordIds.add(record.scholarship.id);
    for (const level of new Set(record.levels)) verifiedCounts[level] += 1;
    validateRecord(record, index, issues, now);
  }

  const backlogIds = new Set<string>();
  for (const [index, item] of catalog.backlog.entries()) {
    if (!isNonBlank(item.legacyId) || backlogIds.has(item.legacyId)) {
      push(issues, 'invalid_backlog_id', `backlog[${index}].legacyId`, 'Backlog ids must be non-empty and unique.');
    }
    backlogIds.add(item.legacyId);
    if (!item.reasons.length) {
      push(issues, 'missing_backlog_reason', `backlog[${index}].reasons`, 'At least one visible deficit is required.');
    }
    for (const level of new Set(item.intendedLevels)) backlogCounts[level] += 1;
  }

  const volumeDeficits = {
    secondary: Math.max(0, catalog.volumeTargets.secondary - verifiedCounts.secondary),
    bachelor: Math.max(0, catalog.volumeTargets.bachelor - verifiedCounts.bachelor),
    master: Math.max(0, catalog.volumeTargets.master - verifiedCounts.master),
  };
  const uniqueRecordCount = catalog.records.length;
  const uniqueRecordDeficit = Math.max(
    0,
    catalog.volumeTargets.uniqueRecords - uniqueRecordCount,
  );
  const backlogDeficits = {
    secondary: Math.max(0, catalog.volumeTargets.secondary - backlogCounts.secondary),
    bachelor: Math.max(0, catalog.volumeTargets.bachelor - backlogCounts.bachelor),
    master: Math.max(0, catalog.volumeTargets.master - backlogCounts.master),
  };
  if (includeVolumeTargets) {
    if (uniqueRecordDeficit > 0) {
      push(
        issues,
        'unique_record_target_not_met',
        'volumeTargets.uniqueRecords',
        `Missing ${uniqueRecordDeficit} unique scholarship record(s).`,
      );
    }
    for (const level of SCHOLARSHIP_STUDY_LEVELS) {
      if (volumeDeficits[level] > 0) {
        push(
          issues,
          'volume_target_not_met',
          `volumeTargets.${level}`,
          `Missing ${volumeDeficits[level]} verified ${level} scholarship record(s).`,
        );
      }
    }
  }

  return {
    valid: issues.length === 0,
    catalogVersion: catalog.catalogVersion,
    uniqueRecordCount,
    uniqueRecordDeficit,
    verifiedCounts,
    backlogCounts,
    volumeDeficits,
    backlogDeficits,
    issues,
  };
}
