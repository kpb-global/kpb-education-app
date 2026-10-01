import { readFileSync } from 'node:fs';

import {
  EEF_ATTRIBUTION_SOURCE_NAMES,
  EEF_CATALOG_ATTRIBUTION,
} from './eef-catalog-attribution';
import { EEF_CATALOG_MANIFEST_FILE } from './eef-catalog.loader';
import type { EefCatalogManifest } from './eef-catalog.types';

// La mention servie à l'app doit rester vraie du catalogue importé. Ces tests
// échouent au premier réimport qui ne la met pas à jour — c'est leur seul
// travail, et la raison pour laquelle la mention peut être une simple constante.
describe('EEF_CATALOG_ATTRIBUTION', () => {
  const manifest = JSON.parse(
    readFileSync(EEF_CATALOG_MANIFEST_FILE, 'utf8'),
  ) as EefCatalogManifest;

  it('porte la version du catalogue importé', () => {
    expect(EEF_CATALOG_ATTRIBUTION.catalogVersion).toBe(
      manifest.catalogVersion,
    );
  });

  it('porte le jour de la dernière récupération des données', () => {
    const latest = manifest.sources
      .map((source) => source.fetchedAt)
      .sort()
      .pop();
    expect(EEF_CATALOG_ATTRIBUTION.updatedAt).toBe(latest?.slice(0, 10));
  });

  it('cite chaque famille de jeux réutilisée, et aucune autre', () => {
    const families = [...new Set(manifest.sources.map((s) => s.dataset))];
    const named = families.map((family) => {
      const name = EEF_ATTRIBUTION_SOURCE_NAMES[family];
      // Un jeu réutilisé sans nom lisible serait une source non citée.
      expect(name).toBeDefined();
      return name;
    });
    expect([...EEF_CATALOG_ATTRIBUTION.sources].sort()).toEqual(
      [...named].sort(),
    );
  });

  it('nomme la licence que le manifeste déclare', () => {
    const licences = new Set(manifest.sources.map((s) => s.licence));
    expect([...licences]).toEqual(['Licence Ouverte v2.0 (Etalab)']);
    expect(EEF_CATALOG_ATTRIBUTION.licence).toBe('Licence Ouverte 2.0');
  });

  it('le jour est un jour nu valide', () => {
    expect(EEF_CATALOG_ATTRIBUTION.updatedAt).toMatch(/^\d{4}-\d{2}-\d{2}$/);
    expect(
      Number.isNaN(
        Date.parse(`${EEF_CATALOG_ATTRIBUTION.updatedAt}T00:00:00Z`),
      ),
    ).toBe(false);
  });

  it('ne sert que des liens https', () => {
    expect(EEF_CATALOG_ATTRIBUTION.producerUrl).toMatch(/^https:\/\//);
    expect(EEF_CATALOG_ATTRIBUTION.licenceUrl).toMatch(/^https:\/\//);
  });
});
