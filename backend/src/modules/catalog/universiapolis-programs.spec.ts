import * as fs from 'node:fs';
import * as path from 'node:path';

import { INSTITUTION_RATES, tuitionToEur } from './tuition-eur';
import {
  UNIVERSIAPOLIS_INSTITUTION as INST,
  UNIVERSIAPOLIS_PROGRAMS,
} from './universiapolis-programs';

const REFERENTIAL = ['Bac+2', 'Bachelor', 'BBA', 'Master', 'MBA / DBA', 'Doctorat'];
const PROD_FIELDS = ['d01', 'd02', 'd03', 'd04', 'd05', 'd06', 'd07', 'd08', 'd09', 'd10', 'd11', 'd12'];

/**
 * Universiapolis a été ÉCARTÉE de l'import du 16/09 : ses 15 lignes CSV étaient
 * des années d'entrée tarifées (« 1re année », « 2e année »…), pas des
 * formations. Cette table est le résultat du regroupement, et c'est elle le
 * livrable — une erreur dedans écrit un mauvais diplôme sur une fiche que des
 * étudiants consultent pour engager des frais de scolarité.
 */
describe('table Universiapolis', () => {
  it('regroupe les 15 années d’entrée en 6 formations', () => {
    expect(UNIVERSIAPOLIS_PROGRAMS).toHaveLength(6);
    const years = UNIVERSIAPOLIS_PROGRAMS.reduce(
      (n, p) => n + p.mergedYears.length,
      0,
    );
    expect(years).toBe(15);
  });

  it('aucun niveau n’est une année d’étude', () => {
    for (const p of UNIVERSIAPOLIS_PROGRAMS) {
      expect(REFERENTIAL).toContain(p.levelFr);
      expect(p.levelFr).not.toMatch(/année|Prépa|Spécialité/);
    }
  });

  it('les filières existent dans la taxonomie de production', () => {
    for (const p of UNIVERSIAPOLIS_PROGRAMS) {
      expect(PROD_FIELDS).toContain(p.fieldId);
    }
  });

  it('chaque formation cite une page de l’université', () => {
    for (const p of UNIVERSIAPOLIS_PROGRAMS) {
      expect(p.sourceUrl).toMatch(
        /^https:\/\/(universiapolis\.ma|e-polytechnique\.ma|suphcom\.ma|suphdroit\.ma)\//,
      );
    }
  });

  it('les clés et les noms sont distincts', () => {
    const keys = UNIVERSIAPOLIS_PROGRAMS.map((p) => p.key);
    const names = UNIVERSIAPOLIS_PROGRAMS.map((p) => p.nameFr);
    expect(new Set(keys).size).toBe(keys.length);
    expect(new Set(names).size).toBe(names.length);
  });

  // Le CSV attribuait le droit à Sup'H.Com. Ce sont deux établissements
  // distincts du groupe : Sup'H.Com fait communication, tourisme et hôtellerie.
  it("rectifie l'attribution du droit à Sup'H.Droit", () => {
    const droit = UNIVERSIAPOLIS_PROGRAMS.find((p) => p.fieldId === 'd07');
    expect(droit).toBeDefined();
    expect(droit!.nameFr).toContain("Sup'H.Droit");
    expect(droit!.nameFr).not.toContain("Sup'H.Com");
    // Les 2e, 3e et 4e années du CSV — deux libellés — sont fusionnées.
    expect(droit!.mergedYears).toHaveLength(3);
  });

  it('le cycle préparatoire ne prétend pas délivrer un diplôme d’ingénieur', () => {
    const prepa = UNIVERSIAPOLIS_PROGRAMS.find((p) => p.key === 'epp-tronc-commun');
    const inge = UNIVERSIAPOLIS_PROGRAMS.find((p) => p.key === 'epp-ingenierie');
    expect(prepa!.levelFr).toBe('Bac+2');
    expect(inge!.levelFr).toBe('Master');
  });

  it('chaque formation annonce une durée et un tarif', () => {
    for (const p of UNIVERSIAPOLIS_PROGRAMS) {
      expect(p.durationFr.trim().length).toBeGreaterThan(0);
      expect(p.tuitionFr).toMatch(/\d/);
      expect(p.tuitionFr).toContain('DH');
    }
  });
});

describe('l’identifiant de l’établissement porte le taux dirham', () => {
  // `INSTITUTION_RATES` rattache le taux 1 € = 10 DH à cet identifiant précis.
  // Le changer couperait la conversion en euros SANS erreur : les six fiches
  // arriveraient avec `tuitionMinEur` à null et un score budgétaire neutralisé.
  it('l’identifiant figure dans la portée du taux MAD', () => {
    const mad = INSTITUTION_RATES.find((r) => r.currency === 'MAD');
    expect(mad).toBeDefined();
    expect(mad!.institutionIds).toContain(INST.id);
  });

  it('les six tarifs se convertissent réellement', () => {
    for (const p of UNIVERSIAPOLIS_PROGRAMS) {
      const parsed = tuitionToEur(p.tuitionFr, INST.id);
      expect(parsed.ok).toBe(true);
      if (parsed.ok) {
        expect(parsed.eur).toBeGreaterThan(0);
        // Taux sourcé, pas une parité fixe : la conversion n'est pas exacte.
        expect(parsed.exact).toBe(false);
      }
    }
  });

  it('sans l’établissement, le dirham resterait non converti', () => {
    expect(tuitionToEur(UNIVERSIAPOLIS_PROGRAMS[0].tuitionFr)).toMatchObject({
      ok: false,
      reason: 'unsourced-currency',
    });
  });
});

describe('le script est prudent', () => {
  const SCRIPT = path.join(
    __dirname, '..', '..', '..', 'scripts', 'import-universiapolis.ts',
  );
  const src = fs.readFileSync(SCRIPT, 'utf8');

  it('n’écrase jamais une fiche existante', () => {
    expect(src).toMatch(/update:\s*\{\}/);
    expect(src).not.toMatch(/update:\s*\{[^}]/);
  });

  it('la simulation est le mode par défaut', () => {
    expect(src).toMatch(/const apply = process\.argv\.includes\('--apply'\)/);
    expect(src).toMatch(/SIMULATION/);
  });

  it('ne crée que les formations absentes', () => {
    expect(src).toMatch(/filter\(\(p\) => !present\.has\(p\.nameFr\)\)/);
  });

  // L'appel figure DEUX fois — rapport et écriture — et une assertion de simple
  // présence était satisfaite par l'une quand l'autre perdait `INST.id`. Le
  // rapport aurait alors annoncé un montant en euros que l'écriture n'aurait
  // pas posé : `tuitionToEur` ne convertit le dirham que pour les
  // établissements citant le taux en source. On compte les occurrences.
  // Revue #277 (P1) : `Institution.programIds` est LUE par six écrans de l'app
  // — nombre affiché, aperçu des trois premières, navigation depuis la fiche
  // pays (désactivée si vide), comparateur, profil, recherche. Créer les
  // formations sans la renseigner les rend inatteignables, sans aucune erreur.
  // C'est ce qui est arrivé aux 46 formations de Mundiapolis.
  it('renseigne programIds après avoir créé les formations', () => {
    expect(src).toMatch(/data:\s*\{\s*programIds:\s*ids\s*\}/);
  });

  it('reconstruit la liste depuis la base, pas depuis la table en dur', () => {
    expect(src).toMatch(/prisma\.program\.findMany\(\{[\s\S]{0,160}institutionId:\s*INST\.id/);
    expect(src).not.toMatch(/programIds:\s*UNIVERSIAPOLIS_PROGRAMS/);
  });

  it('passe l’établissement à la conversion dans LES DEUX phases', () => {
    const calls = src.match(/tuitionToEur\(p\.tuitionFr, INST\.id\)/g) ?? [];
    expect(calls).toHaveLength(2);
    expect(src).not.toMatch(/tuitionToEur\(p\.tuitionFr\)/);
  });
});
