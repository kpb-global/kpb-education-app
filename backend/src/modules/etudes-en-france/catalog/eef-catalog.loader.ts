// ─────────────────────────────────────────────────────────────────────────────
// Lecture du catalogue versionné depuis le dépôt.
//
// Un fichier par université, plus un manifeste. Le découpage n'est pas un
// détail de rangement : 7 000 formations dans un seul JSON rendent toute revue
// impossible — on ne voit plus que « fichier modifié ». Par université, un lot
// d'import se relit université par université, et un `git diff` dit lequel a
// bougé.
// ─────────────────────────────────────────────────────────────────────────────
import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

import type {
  EefCatalog,
  EefCatalogManifest,
  EefUniversityFile,
} from './eef-catalog.types';

export const EEF_CATALOG_DATA_DIR = join(__dirname, 'data');
export const EEF_CATALOG_UNIVERSITIES_DIR = join(
  EEF_CATALOG_DATA_DIR,
  'universites',
);
export const EEF_CATALOG_MANIFEST_FILE = join(
  EEF_CATALOG_DATA_DIR,
  'manifest.json',
);

export function loadEefCatalog(dataDir = EEF_CATALOG_DATA_DIR): EefCatalog {
  const manifest = JSON.parse(
    readFileSync(join(dataDir, 'manifest.json'), 'utf8'),
  ) as EefCatalogManifest;
  const universitiesDir = join(dataDir, 'universites');
  const files = readdirSync(universitiesDir)
    .filter((name) => name.endsWith('.json'))
    // Tri explicite : `readdirSync` ne garantit pas l'ordre, et un import dont
    // l'ordre change d'une machine à l'autre produit un journal illisible.
    .sort();
  const universities = files.map(
    (name) =>
      JSON.parse(
        readFileSync(join(universitiesDir, name), 'utf8'),
      ) as EefUniversityFile,
  );
  return { manifest, universities };
}
