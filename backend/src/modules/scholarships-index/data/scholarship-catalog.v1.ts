import type { VersionedScholarshipCatalog } from './scholarship-catalog.types';
import { VERIFIED_ADDITIONAL_MASTER_RECORDS_V1 } from './scholarship-catalog.records.additional-master.v1';
import { VERIFIED_BACHELOR_RECORDS_V1 } from './scholarship-catalog.records.bachelor.v1';
import { VERIFIED_MASTER_RECORDS_V1 } from './scholarship-catalog.records.master.v1';
import { VERIFIED_MULTI_LEVEL_RECORDS_V1 } from './scholarship-catalog.records.multi-level.v1';
import { VERIFIED_SCHOLARSHIP_RECORDS_V1 } from './scholarship-catalog.records.v1';

/**
 * The catalog is populated progressively from current official sources. Every
 * imported record still lands inactive and pending editorial moderation. The
 * inventory below mirrors level labels already present in
 * `src/common/data/mock-catalog.ts`; it remains a visible research backlog and
 * is never imported into the database.
 */
export const SCHOLARSHIP_CATALOG_V1: VersionedScholarshipCatalog = {
  schemaVersion: 1,
  catalogVersion: '1.2.0',
  volumeTargets: {
    uniqueRecords: 25,
    secondary: 3,
    bachelor: 12,
    master: 15,
  },
  records: [
    ...VERIFIED_SCHOLARSHIP_RECORDS_V1,
    ...VERIFIED_MULTI_LEVEL_RECORDS_V1,
    ...VERIFIED_BACHELOR_RECORDS_V1,
    ...VERIFIED_MASTER_RECORDS_V1,
    ...VERIFIED_ADDITIONAL_MASTER_RECORDS_V1,
  ],
  backlog: [
    {
      legacyId: 'mccall_macbain',
      intendedLevels: ['master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'canada_future',
      intendedLevels: ['bachelor', 'master'],
      reasons: [
        'legacy_record_incomplete',
        'legacy_record_requires_official_verification',
      ],
    },
    {
      legacyId: 'france_excellence',
      intendedLevels: ['master'],
      reasons: [
        'legacy_record_incomplete',
        'legacy_record_requires_official_verification',
      ],
    },
    {
      legacyId: 'rhodes_oxford',
      intendedLevels: ['master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'knight_hennessy_stanford',
      intendedLevels: ['master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'helmut_schmidt_daad',
      intendedLevels: ['master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'chevening_uk',
      intendedLevels: ['master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'turkiye_burslari',
      intendedLevels: ['bachelor', 'master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'fulbright_foreign',
      intendedLevels: ['master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'mext_japan',
      intendedLevels: ['bachelor', 'master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
    {
      legacyId: 'mastercard_foundation',
      intendedLevels: ['bachelor', 'master'],
      reasons: ['legacy_record_requires_official_verification'],
    },
  ],
};
