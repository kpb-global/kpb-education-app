import { normalizeSearchText, programSearchText } from './eef-search-text';

describe('normalizeSearchText', () => {
  it('ramène casse, accents et ponctuation à une seule écriture', () => {
    expect(normalizeSearchText('Génie civil')).toBe('genie civil');
    expect(normalizeSearchText('GENIE-CIVIL')).toBe('genie civil');
    expect(normalizeSearchText('  Économie   &  gestion ')).toBe('economie gestion');
    expect(normalizeSearchText("Saint-Martin-d'Hères")).toBe('saint martin d heres');
    expect(normalizeSearchText('L1 - Droit')).toBe('l1 droit');
  });

  it('réécrit les ligatures que NFD ne décompose pas', () => {
    expect(normalizeSearchText('Cœur')).toBe('coeur');
    expect(normalizeSearchText('Œuvres')).toBe('oeuvres');
    expect(normalizeSearchText('Æsthétique')).toBe('aesthetique');
    expect(normalizeSearchText('Straße')).toBe('strasse');
  });

  it('est idempotente : une chaîne déjà normalisée ne bouge plus', () => {
    for (const sample of ['Génie civil', "L'économie", 'Œuvres & œuvres', 'Besançon']) {
      const once = normalizeSearchText(sample);
      expect(normalizeSearchText(once)).toBe(once);
    }
  });

  it('tient pour nul, vide ou fait de ponctuation seule', () => {
    expect(normalizeSearchText(null)).toBe('');
    expect(normalizeSearchText(undefined)).toBe('');
    expect(normalizeSearchText('')).toBe('');
    expect(normalizeSearchText(' - — ')).toBe('');
  });

  it('les deux moitiés se rencontrent : ce qui est tapé sans accent trouve ce qui est écrit avec', () => {
    const row = programSearchText('Master — Génie civil', 'Besançon');
    for (const typed of ['genie', 'GÉNIE', 'besancon', 'Besançon', 'civil', 'master genie']) {
      expect(row).toContain(normalizeSearchText(typed));
    }
    expect(row).not.toContain(normalizeSearchText('droit'));
  });
});

describe('programSearchText', () => {
  it('joint l’intitulé et la ville, et tolère une ville absente', () => {
    expect(programSearchText('L1 - Droit', 'Rennes')).toBe('l1 droit rennes');
    expect(programSearchText('L1 - Droit', null)).toBe('l1 droit');
    expect(programSearchText('L1 - Droit', undefined)).toBe('l1 droit');
  });
});
