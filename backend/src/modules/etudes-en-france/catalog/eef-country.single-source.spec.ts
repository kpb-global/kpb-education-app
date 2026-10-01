// La France se résout à UN seul endroit : `eef-country.ts`.
//
// Elle l'était en trois : l'import, la recherche et le rattrapage
// `backfill-eef-enrichment.ts`. La copie du rattrapage ne cherchait que le code
// « FR » alors que le référentiel M5 écrit « FRA » : en production, la dernière
// étape de l'action `eef-import` échouait après que l'import avait écrit. Ce garde
// lit les sources, parce qu'une copie ne se voit qu'à la lecture.

import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join, relative } from 'node:path';

const BACKEND = join(__dirname, '..', '..', '..', '..');
const RESOLVER = join(__dirname, 'eef-country.ts');

function sources(dir: string): string[] {
  const out: string[] = [];
  for (const name of readdirSync(dir)) {
    const path = join(dir, name);
    if (statSync(path).isDirectory()) {
      if (name === 'node_modules' || name === 'dist' || name === 'data')
        continue;
      out.push(...sources(path));
    } else if (name.endsWith('.ts') && !name.endsWith('.spec.ts')) {
      out.push(path);
    }
  }
  return out;
}

// Une définition locale de la résolution, ou une comparaison directe du code de
// pays à « FR » : les deux formes de la copie qui a mordu.
const LOCAL_DEFINITION = /function\s+resolveFranceCountryId\s*\(/;
const DIRECT_FR_COMPARISON =
  /\.code\b[^\n;]*\.toUpperCase\(\)\s*===\s*['"]FR['"]/;

describe('la France se résout à un seul endroit', () => {
  const files = [
    ...sources(join(BACKEND, 'scripts')),
    ...sources(join(BACKEND, 'src', 'modules', 'etudes-en-france')),
  ].filter((file) => file !== RESOLVER);

  it('lit bien les sources — sinon elle ne prouve rien', () => {
    expect(files.length).toBeGreaterThan(10);
    expect(
      files.some((file) => file.endsWith('backfill-eef-enrichment.ts')),
    ).toBe(true);
  });

  it('aucun fichier ne redéfinit la résolution de la France', () => {
    const offenders = files
      .filter((file) => LOCAL_DEFINITION.test(readFileSync(file, 'utf8')))
      .map((file) => relative(BACKEND, file));
    expect(offenders).toEqual([]);
  });

  it('aucun fichier ne compare le code de pays à « FR » seul', () => {
    const offenders = files
      .filter((file) => DIRECT_FR_COMPARISON.test(readFileSync(file, 'utf8')))
      .map((file) => relative(BACKEND, file));
    expect(offenders).toEqual([]);
  });

  it('le motif attrape bien la copie qui a mordu', () => {
    expect(
      DIRECT_FR_COMPARISON.test(
        "(country) => country.code.toUpperCase() === 'FR'",
      ),
    ).toBe(true);
    expect(
      LOCAL_DEFINITION.test('async function resolveFranceCountryId(): Promise'),
    ).toBe(true);
    expect(
      DIRECT_FR_COMPARISON.test('return resolveFranceCountryId(countries);'),
    ).toBe(false);
  });
});
