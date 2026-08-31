import type {
  VerifiedScholarshipCatalogRecord,
  VersionedScholarshipCatalog,
} from './scholarship-catalog.types';

export interface ScholarshipCatalogWriter {
  /**
   * Must be implemented as create-if-absent. It must never update a row whose
   * id already exists, because that row may have been edited in the admin.
   *
   * Le réalignement d'une ligne existante est un acte DISTINCT, avec ses
   * propres garde-fous : voir `scholarship-catalog.reconcile.ts` et la
   * sous-commande `catalog:reconcile`.
   */
  createIfAbsent(
    record: VerifiedScholarshipCatalogRecord,
  ): Promise<'created' | 'existing'>;
}

export interface ScholarshipCatalogImportSummary {
  catalogVersion: string;
  attempted: number;
  created: number;
  /**
   * Lignes déjà présentes, laissées TELLES QUELLES.
   *
   * Le nom compte. Ce compteur s'appelait `skippedExisting`, et
   * « skipped: 34 » se lisait « rien à faire » alors qu'il voulait dire
   * « 34 lignes non réalignées, donc potentiellement périmées » : c'est ce
   * malentendu qui a laissé deux fiches servir `dateConfidence: estimated`
   * pendant que le dépôt disait `confirmed`. Un compteur doit nommer ce qui
   * n'a PAS été fait.
   */
  existingNotUpdated: number;
}

export async function importScholarshipCatalog(
  catalog: VersionedScholarshipCatalog,
  writer: ScholarshipCatalogWriter,
): Promise<ScholarshipCatalogImportSummary> {
  let created = 0;
  let existingNotUpdated = 0;
  for (const record of catalog.records) {
    const result = await writer.createIfAbsent(record);
    if (result === 'created') created += 1;
    else existingNotUpdated += 1;
  }
  return {
    catalogVersion: catalog.catalogVersion,
    attempted: catalog.records.length,
    created,
    existingNotUpdated,
  };
}
