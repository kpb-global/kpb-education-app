import type { VersionedScholarshipCatalog } from './scholarship-catalog.types';
import { VERIFIED_ADDITIONAL_MASTER_RECORDS_V1 } from './scholarship-catalog.records.additional-master.v1';
import { VERIFIED_AFRICA_BACHELOR_RECORDS_V1 } from './scholarship-catalog.records.africa-bachelor.v1';
import { VERIFIED_BACHELOR_RECORDS_V1 } from './scholarship-catalog.records.bachelor.v1';
import { VERIFIED_EUROPE_MASTER_RECORDS_V1 } from './scholarship-catalog.records.europe-master.v1';
import { VERIFIED_MASTER_RECORDS_V1 } from './scholarship-catalog.records.master.v1';
import { VERIFIED_MASTERCARD_SOUTHERN_AFRICA_RECORDS_V1 } from './scholarship-catalog.records.mastercard-southern-africa.v1';
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
  catalogVersion: '1.3.0',
  // Planchers, pas des plafonds : le validateur signale un déficit sous ces
  // seuils. Relevés avec la vague « Top 10 » (25 → 34 fiches).
  volumeTargets: {
    uniqueRecords: 34,
    secondary: 3,
    bachelor: 15,
    master: 15,
  },
  records: [
    ...VERIFIED_SCHOLARSHIP_RECORDS_V1,
    ...VERIFIED_MULTI_LEVEL_RECORDS_V1,
    ...VERIFIED_BACHELOR_RECORDS_V1,
    ...VERIFIED_MASTER_RECORDS_V1,
    ...VERIFIED_ADDITIONAL_MASTER_RECORDS_V1,
    // Vague « Top 10 » : les bourses du lead magnet KPB, vérifiées sur sources
    // officielles le 10/08/2026. Deux du dépliant sont absentes à dessein —
    // Commonwealth PhD et Vanier Canada sont doctorales, et l'énumération des
    // niveaux s'arrête au master.
    ...VERIFIED_AFRICA_BACHELOR_RECORDS_V1,
    ...VERIFIED_EUROPE_MASTER_RECORDS_V1,
    ...VERIFIED_MASTERCARD_SOUTHERN_AFRICA_RECORDS_V1,
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
