import * as fs from 'node:fs';
import * as path from 'node:path';

import { SEED_INSTITUTION_FILLS } from './seed-institution-fills';

/**
 * La table EST le correctif : elle écrit la description que des étudiants
 * liront pour choisir où engager des frais de scolarité. Un champ vide ici
 * n'échoue pas — il écrit du vide, c'est-à-dire exactement l'état qu'on
 * prétend réparer, en le faisant passer pour corrigé.
 */
describe('table de complétion des établissements seed', () => {
  it('couvre les 2 établissements antérieurs à l’import partenaire', () => {
    expect(SEED_INSTITUTION_FILLS.map((f) => f.id).sort()).toEqual([
      'essec',
      'uottawa',
    ]);
  });

  it('aucun identifiant en double', () => {
    const ids = SEED_INSTITUTION_FILLS.map((f) => f.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  // Le défaut central : écrire du vide par-dessus du vide. Le script ne
  // vérifie que la colonne EN BASE, pas ce qu'il s'apprête à y mettre.
  it('aucun champ écrit n’est vide', () => {
    for (const fill of SEED_INSTITUTION_FILLS) {
      for (const key of [
        'overviewFr',
        'overviewEn',
        'locationFr',
        'locationEn',
        'sourceUrl',
      ] as const) {
        expect(fill[key].trim()).not.toBe('');
      }
    }
  });

  // Une description d'une ligne ne dit rien d'utile : la fiche resterait aussi
  // vide qu'avant, mais sortie de tout contrôle puisque la colonne est remplie.
  it('chaque description dit quelque chose', () => {
    for (const fill of SEED_INSTITUTION_FILLS) {
      expect(fill.overviewFr.length).toBeGreaterThan(80);
      expect(fill.overviewEn.length).toBeGreaterThan(80);
    }
  });

  it('chaque source est une URL https de l’établissement', () => {
    for (const fill of SEED_INSTITUTION_FILLS) {
      expect(fill.sourceUrl).toMatch(/^https:\/\//);
    }
  });

  // Les deux langues doivent dire la même chose. Un copier-coller du français
  // dans le champ anglais passerait tous les tests ci-dessus.
  it('le texte anglais n’est pas le texte français', () => {
    for (const fill of SEED_INSTITUTION_FILLS) {
      expect(fill.overviewEn).not.toBe(fill.overviewFr);
    }
  });

  // ESSEC a un campus à Rabat. Une première rédaction ne citait que la France
  // et Singapour : pour un étudiant ouest-africain, c'est le campus le plus
  // accessible qui disparaissait de la fiche. Épinglé pour que la mention ne
  // soit pas perdue à la prochaine réécriture.
  it('la fiche ESSEC mentionne le campus de Rabat', () => {
    const essec = SEED_INSTITUTION_FILLS.find((f) => f.id === 'essec');
    expect(essec?.overviewFr).toContain('Rabat');
    expect(essec?.overviewEn).toContain('Rabat');
  });

  // Le script ne doit PAS poser lastVerifiedAt : la source est inscrite, mais
  // la vérification humaine reste due. Même raisonnement que pour les niveaux
  // Mundiapolis — une fiche qui se déclare vérifiée sort de la file de
  // contrôle sans que personne ne l'ait regardée.
  it('le script ne se déclare jamais vérifié', () => {
    const script = fs.readFileSync(
      path.join(__dirname, '../../../scripts/backfill-seed-institutions.ts'),
      'utf8',
    );
    expect(script).not.toContain('lastVerifiedAt');
  });

  // Chaque écriture doit porter SA condition dans le WHERE, réévaluée par la
  // base à l'instant de l'écriture. Une décision prise sur la lecture préalable
  // laisserait une fenêtre : un administrateur qui saisit la description
  // entre-temps la verrait écrasée, alors que le script promet l'inverse.
  it('chaque écriture est conditionnée à un champ vide', () => {
    const script = fs.readFileSync(
      path.join(__dirname, '../../../scripts/backfill-seed-institutions.ts'),
      'utf8',
    );
    expect(script).toContain("overviewFr: ''");
    expect(script).toContain("locationFr: ''");
    expect(script).toContain('sourceUrl: null');
    // Aucune écriture ne doit viser une ligne par son seul identifiant.
    expect(script).not.toMatch(/updateMany\(\{\s*where:\s*\{\s*id:[^,}]*\}\s*,/);
  });
});
