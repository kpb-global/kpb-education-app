import {
  backfillEefCycles,
  planCycleBackfill,
  type CycleBackfillEntry,
  type CycleBackfillWriter,
} from './eef-cycle-backfill';
import { loadEefCatalog } from './eef-catalog.loader';

class FakeWriter implements CycleBackfillWriter {
  readonly written: CycleBackfillEntry[] = [];
  constructor(private readonly nullIds: ReadonlySet<string>) {}

  async fillIfNull(entry: CycleBackfillEntry): Promise<number> {
    if (!this.nullIds.has(entry.id)) return 0;
    this.written.push(entry);
    return 1;
  }
}

describe('rattrapage du cycle', () => {
  const catalog = loadEefCatalog();
  const entries = planCycleBackfill(catalog);

  it('couvre toutes les formations du catalogue versionné', () => {
    const total = catalog.universities.reduce(
      (sum, file) => sum + file.programs.length,
      0,
    );
    expect(entries).toHaveLength(total);
    expect(entries.every((entry) => entry.cycle !== '')).toBe(true);
  });

  it('écrit le cycle décidé par la collecte, jamais un cycle déduit', () => {
    // Cette colonne existe précisément pour ne pas avoir à découper `levelFr`.
    const sample = catalog.universities[0].programs[0];
    const planned = entries.find((entry) => entry.id === sample.id);
    expect(planned?.cycle).toBe(sample.cycle);
  });

  it('ne comble que les trous, et compte ce qu’il n’a pas touché', async () => {
    // Écraser une valeur existante ferait de ce script un second import, avec
    // le pouvoir d'écraser sans les garde-fous de l'import.
    const holes = new Set(entries.slice(0, 3).map((entry) => entry.id));
    const writer = new FakeWriter(holes);

    const summary = await backfillEefCycles(entries, writer);

    expect(summary.attempted).toBe(entries.length);
    expect(summary.filled).toBe(3);
    expect(summary.untouched).toBe(entries.length - 3);
    expect(writer.written.map((entry) => entry.id).sort()).toEqual(
      [...holes].sort(),
    );
  });

  it('est rejouable : une seconde passe ne comble plus rien', async () => {
    const writer = new FakeWriter(new Set());
    const summary = await backfillEefCycles(entries, writer);
    expect(summary.filled).toBe(0);
    expect(writer.written).toEqual([]);
  });
});
