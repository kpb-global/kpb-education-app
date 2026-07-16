import type {
  VerifiedScholarshipCatalogRecord,
  VersionedScholarshipCatalog,
} from './scholarship-catalog.types';

export interface ScholarshipCatalogWriter {
  /**
   * Must be implemented as create-if-absent. It must never update a row whose
   * id already exists, because that row may have been edited in the admin.
   */
  createIfAbsent(
    record: VerifiedScholarshipCatalogRecord,
  ): Promise<'created' | 'existing'>;
}

export interface ScholarshipCatalogImportSummary {
  catalogVersion: string;
  attempted: number;
  created: number;
  skippedExisting: number;
}

export async function importScholarshipCatalog(
  catalog: VersionedScholarshipCatalog,
  writer: ScholarshipCatalogWriter,
): Promise<ScholarshipCatalogImportSummary> {
  let created = 0;
  let skippedExisting = 0;
  for (const record of catalog.records) {
    const result = await writer.createIfAbsent(record);
    if (result === 'created') created += 1;
    else skippedExisting += 1;
  }
  return {
    catalogVersion: catalog.catalogVersion,
    attempted: catalog.records.length,
    created,
    skippedExisting,
  };
}
