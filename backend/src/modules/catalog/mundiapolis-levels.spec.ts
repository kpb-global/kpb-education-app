import * as fs from 'node:fs';
import * as path from 'node:path';

import {
  MUNDIAPOLIS_LEVEL_CORRECTIONS,
  REFERENTIAL_LEVELS,
} from './mundiapolis-levels';

/**
 * Correction de données en production : la table est le correctif, et une
 * erreur dedans écrit un mauvais niveau sur une fiche que des étudiants
 * consultent pour engager des frais de scolarité. Ces tests épinglent ce qui
 * peut silencieusement déraper — une cible hors référentiel, un identifiant
 * dupliqué, un niveau posé sans source.
 */
describe('table de corrections Mundiapolis', () => {
  it('corrige exactement les 4 fiches hors référentiel', () => {
    expect(MUNDIAPOLIS_LEVEL_CORRECTIONS).toHaveLength(4);
  });

  it('chaque cible appartient au référentiel', () => {
    for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
      expect(REFERENTIAL_LEVELS).toContain(fix.to);
    }
  });

  // La valeur de départ doit être HORS référentiel : si elle y était, la fiche
  // n'avait pas besoin d'être corrigée et on toucherait à une donnée valide.
  it('chaque valeur de départ est hors référentiel', () => {
    for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
      expect(REFERENTIAL_LEVELS).not.toContain(fix.from as never);
    }
  });

  it('ne corrige jamais une valeur vers elle-même', () => {
    for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
      expect(fix.to).not.toBe(fix.from);
    }
  });

  it('les identifiants sont distincts et suivent la dérivation de l’import', () => {
    const ids = MUNDIAPOLIS_LEVEL_CORRECTIONS.map((f) => f.id);
    expect(new Set(ids).size).toBe(ids.length);
    for (const id of ids) expect(id).toMatch(/^partner-p-[0-9a-f]{16}$/);
  });

  // Le point dur : aucun niveau ne doit reposer sur une déduction. Le CSV
  // disait « Spécialité » ; c'est l'université qui dit « Licence Bac+3 ».
  it('chaque correction cite une page de l’université', () => {
    for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
      expect(fix.sourceUrl).toMatch(/^https:\/\/www\.mundiapolis\.ma\//);
    }
  });

  it('les trois licences infirmières pointent une URL « bac3 »', () => {
    const licences = MUNDIAPOLIS_LEVEL_CORRECTIONS.filter(
      (f) => f.to === 'Bachelor',
    );
    expect(licences).toHaveLength(3);
    for (const fix of licences) {
      expect(fix.sourceUrl).toContain('bac3');
      expect(fix.durationFr).toBe('3 ans (Bac+3)');
    }
  });

  it('la prépa est un Bac+2 de deux ans, pas un diplôme', () => {
    const prepa = MUNDIAPOLIS_LEVEL_CORRECTIONS.find((f) => f.from === 'Prépa');
    expect(prepa).toBeDefined();
    expect(prepa!.to).toBe('Bac+2');
    expect(prepa!.durationFr).toBe('2 ans');
  });

  it('chaque correction annonce une durée', () => {
    for (const fix of MUNDIAPOLIS_LEVEL_CORRECTIONS) {
      expect(fix.durationFr.trim().length).toBeGreaterThan(0);
    }
  });
});

/**
 * L'écriture est conditionnée à la valeur actuelle, et c'est ce qui la rend
 * rejouable. Le script est le seul endroit où cette forme existe : une
 * réécriture vers un `update` nu la ferait disparaître sans qu'aucun test
 * unitaire ne bronche.
 */
describe('le script écrit de façon conditionnelle', () => {
  const SCRIPT = path.join(
    __dirname,
    '..',
    '..',
    '..',
    'scripts',
    'fix-mundiapolis-levels.ts',
  );
  const src = fs.readFileSync(SCRIPT, 'utf8');

  it('passe par updateMany avec le niveau actuel en condition', () => {
    expect(src).toMatch(/program\.updateMany/);
    expect(src).toMatch(/where:\s*\{\s*id:\s*fix\.id,\s*levelFr:\s*fix\.from\s*\}/);
  });

  it('n’utilise pas un update inconditionnel', () => {
    expect(src).not.toMatch(/program\.update\(\{/);
  });

  it('ne comble la durée que si elle est vide', () => {
    expect(src).toMatch(/current\.durationFr \? \{\} :/);
  });

  it('ne pose PAS lastVerifiedAt — la vérification humaine reste due', () => {
    expect(src).not.toMatch(/lastVerifiedAt:/);
  });

  // Le contrôle croisé existe DEUX fois — phase de rapport et phase d'écriture.
  // Une assertion générique sur « nameFr !== fix.nameFr » était satisfaite par
  // l'une quand l'autre était neutralisée : elle épinglait la présence du mot,
  // pas celle de la garde. Les deux sont donc nommées séparément.
  it('contrôle le nom dans la phase de RAPPORT', () => {
    expect(src).toMatch(/row\.nameFr !== fix\.nameFr/);
  });

  it('contrôle le nom de nouveau au moment d’ÉCRIRE', () => {
    expect(src).toMatch(/current\.nameFr !== fix\.nameFr/);
  });

  it('la simulation est le mode par défaut', () => {
    expect(src).toMatch(/const apply = process\.argv\.includes\('--apply'\)/);
    expect(src).toMatch(/SIMULATION/);
  });
});
