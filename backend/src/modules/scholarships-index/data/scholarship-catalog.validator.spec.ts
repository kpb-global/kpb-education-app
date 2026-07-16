import { assessLegacyScholarshipSeed } from './legacy-scholarship-seed-safety';
import { mockCatalog } from '../../../common/data/mock-catalog';
import {
  importScholarshipCatalog,
  type ScholarshipCatalogWriter,
} from './scholarship-catalog.importer';
import type {
  VerifiedScholarshipCatalogRecord,
  VersionedScholarshipCatalog,
} from './scholarship-catalog.types';
import { SCHOLARSHIP_CATALOG_V1 } from './scholarship-catalog.v1';
import { validateScholarshipCatalog } from './scholarship-catalog.validator';

const NOW = new Date('2026-07-16T12:00:00.000Z');

function validRecord(): VerifiedScholarshipCatalogRecord {
  const checkedAt = '2026-07-15T12:00:00.000Z';
  return {
    catalogId: 'verified-test-record',
    levels: ['secondary', 'bachelor', 'master'],
    scholarship: {
      id: 'verified_test_record',
      nameFr: 'Bourse de test vérifiée',
      nameEn: 'Verified test scholarship',
      countryId: 'can',
      countryNameFr: 'Canada',
      countryNameEn: 'Canada',
      levelEligibleFr: 'Lycée / Licence / Master',
      levelEligibleEn: 'Secondary / Bachelor / Master',
      typeOfFundingFr: 'Complète',
      typeOfFundingEn: 'Full',
      fundingType: 'fully_funded',
      applicationRequirement: 'separate_application',
      deadlineLabelFr: 'Dates de test',
      deadlineLabelEn: 'Test dates',
      descriptionFr: 'Description française de test.',
      descriptionEn: 'English test description.',
      advantagesFr: ['Avantage vérifié'],
      advantagesEn: ['Verified benefit'],
      eligibilityFr: ['Critère vérifié'],
      eligibilityEn: ['Verified criterion'],
      keyRequirementsFr: ['Document vérifié'],
      keyRequirementsEn: ['Verified document'],
      relatedFieldIds: [],
      baseMatch: 30,
      applicationUrl: 'https://official.example/application',
      sourceUrl: 'https://official.example/overview',
      tags: ['test-only'],
    },
    applicationSteps: [
      {
        stepNumber: 1,
        titleFr: 'Postuler',
        titleEn: 'Apply',
        descriptionFr: 'Utiliser le formulaire officiel.',
        descriptionEn: 'Use the official form.',
      },
    ],
    cycle: {
      academicYear: '2026-2027',
      status: 'forecast',
      dateConfidence: 'estimated',
      estimatedOpenAt: '2026-08-01T00:00:00.000Z',
      estimatedCloseAt: '2026-10-01T00:00:00.000Z',
      sourceUrl: 'https://official.example/cycle',
    },
    officialSources: [
      'overview',
      'eligibility',
      'benefits',
      'application',
      'cycle',
    ].map((kind) => ({
      kind: kind as
        | 'overview'
        | 'eligibility'
        | 'benefits'
        | 'application'
        | 'cycle',
      url: `https://official.example/${kind}`,
      isOfficial: true,
      checkedAt,
      label: `Official ${kind}`,
    })),
    verifiedAt: checkedAt,
    verifiedBy: 'Test reviewer',
  };
}

describe('versioned scholarship catalog', () => {
  it('meets every target with official-source records while keeping unverified legacy rows in backlog', () => {
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      now: NOW,
    });

    expect(report.valid).toBe(true);
    expect(report.uniqueRecordCount).toBe(25);
    expect(report.uniqueRecordDeficit).toBe(0);
    expect(report.verifiedCounts).toEqual({
      secondary: 3,
      bachelor: 12,
      master: 19,
    });
    expect(report.backlogCounts).toEqual({
      secondary: 0,
      bachelor: 4,
      master: 11,
    });
    expect(report.volumeDeficits).toEqual({
      secondary: 0,
      bachelor: 0,
      master: 0,
    });
    expect(report.backlogDeficits).toEqual({
      secondary: 3,
      bachelor: 8,
      master: 4,
    });
    expect(report.issues.filter((issue) => issue.code === 'volume_target_not_met')).toHaveLength(0);
  });

  it('keeps the versioned backlog aligned with every legacy mock id', () => {
    const legacyIds = mockCatalog.scholarships
      .map((item) => item.id)
      .sort();
    const backlogIds = SCHOLARSHIP_CATALOG_V1.backlog
      .map((item) => item.legacyId)
      .sort();
    expect(backlogIds).toEqual(legacyIds);
  });

  it('passes structure-only validation for the progressive verified catalog', () => {
    const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
      includeVolumeTargets: false,
      now: NOW,
    });
    expect(report.valid).toBe(true);
  });

  it('accepts a complete bilingual record with fresh official HTTPS evidence', () => {
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [validRecord()],
      backlog: [],
    };
    expect(validateScholarshipCatalog(catalog, { now: NOW })).toMatchObject({
      valid: true,
      verifiedCounts: { secondary: 1, bachelor: 1, master: 1 },
    });
  });

  it('enforces the minimum number of distinct catalog records independently of level counts', () => {
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 2,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [validRecord()],
      backlog: [],
    };

    const report = validateScholarshipCatalog(catalog, { now: NOW });
    expect(report.uniqueRecordCount).toBe(1);
    expect(report.uniqueRecordDeficit).toBe(1);
    expect(report.issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ code: 'unique_record_target_not_met' }),
      ]),
    );
  });

  it('rejects unofficial HTTP evidence, missing translations, steps and cycle dates', () => {
    const record = validRecord();
    record.scholarship.descriptionEn = '';
    record.applicationSteps = [];
    record.cycle.estimatedCloseAt = undefined;
    record.officialSources[0] = {
      ...record.officialSources[0],
      url: 'http://aggregator.example/item',
      isOfficial: false as never,
    };
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [record],
      backlog: [],
    };
    const codes = validateScholarshipCatalog(catalog, { now: NOW }).issues.map(
      (issue) => issue.code,
    );
    expect(codes).toEqual(
      expect.arrayContaining([
        'missing_text',
        'missing_application_steps',
        'missing_cycle_dates',
        'unofficial_source',
        'invalid_https_url',
      ]),
    );
  });

  it('rejects payload URLs that are not the URLs declared by their official source kinds', () => {
    const record = validRecord();
    record.scholarship.applicationUrl = 'https://official.example/different-application';
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [record],
      backlog: [],
    };

    expect(validateScholarshipCatalog(catalog, { now: NOW }).issues).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          code: 'source_payload_url_mismatch',
          path: 'records[0].scholarship.applicationUrl',
        }),
      ]),
    );
  });

  it('uses a create-if-absent writer so a second import cannot overwrite an edited row', async () => {
    const catalog: VersionedScholarshipCatalog = {
      schemaVersion: 1,
      catalogVersion: '1.0.1',
      volumeTargets: {
        uniqueRecords: 1,
        secondary: 1,
        bachelor: 1,
        master: 1,
      },
      records: [validRecord()],
      backlog: [],
    };
    const stored = new Set<string>();
    const writer: ScholarshipCatalogWriter = {
      async createIfAbsent(record) {
        if (stored.has(record.scholarship.id)) return 'existing';
        stored.add(record.scholarship.id);
        return 'created';
      },
    };

    await expect(importScholarshipCatalog(catalog, writer)).resolves.toMatchObject({
      created: 1,
      skippedExisting: 0,
    });
    await expect(importScholarshipCatalog(catalog, writer)).resolves.toMatchObject({
      created: 0,
      skippedExisting: 1,
    });
  });

  it('identifies the sparse legacy placeholders without treating structure as verification', () => {
    const assessment = assessLegacyScholarshipSeed({
      name: { fr: 'Canada Future Leaders', en: 'Canada Future Leaders' },
      countryId: 'can',
      levelEligible: { fr: 'Licence / Master', en: 'Bachelor / Master' },
      typeOfFunding: { fr: 'Partielle', en: 'Partial' },
      deadlineLabel: { fr: 'Mai', en: 'May' },
    });
    expect(assessment.complete).toBe(false);
    expect(assessment.missing).toEqual(
      expect.arrayContaining([
        'description.fr/en',
        'advantages.fr/en',
        'eligibility.fr/en',
        'applicationUrl.https',
        'sourceUrl.https',
      ]),
    );
  });
});
