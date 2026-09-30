// ─────────────────────────────────────────────────────────────────────────────
// La provenance « Études en France » : que l'import écrit ce que les surfaces
// excluent.
//
// POURQUOI CE FICHIER EXISTE
//
// Le défaut qu'il garde a la forme que ce dépôt a déjà connue : une règle
// énoncée et appliquée à une porte sur quatre. Le catalogue général, les
// recommandations, la file de revérification et le compteur du tableau de bord
// lisent tous `Program` et `Institution`.
//
// Il relie la CRÉATION à l'EXCLUSION : l'import doit produire des identifiants que
// les clauses reconnaissent, sur les vrais fichiers de données et non sur des
// exemples écrits à la main.
//
// Le COMPTE DES PORTES — aucun lecteur sans garde déclarée — vit dans
// `eef-provenance.doors.spec.ts`, qui lit le code par son arbre syntaxique.
// ─────────────────────────────────────────────────────────────────────────────
import { planEefImport } from '../modules/etudes-en-france/catalog/eef-catalog.importer';
import { loadEefCatalog } from '../modules/etudes-en-france/catalog/eef-catalog.loader';
import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
  isEefInstitutionId,
  isEefProgramId,
  notEefInstitution,
  notEefProgram,
  notPendingEefInstitution,
  notPendingEefProgram,
} from './eef-provenance';

describe('provenance — l’import écrit ce que les surfaces excluent', () => {
  // Les 70+ fichiers réellement versionnés, pas trois lignes d'exemple : c'est
  // ce que l'import écrira en production.
  const plan = planEefImport(loadEefCatalog(), 'france');

  it('lit bien un catalogue — garde morte, sinon', () => {
    // Si le chargeur ne rend rien, tous les tests ci-dessous passent en ne
    // prouvant rien. C'est le mode d'échec habituel d'un cliquet qui lit des
    // fichiers.
    expect(plan.institutions.length).toBeGreaterThan(50);
    expect(plan.programs.length).toBeGreaterThan(5000);
  });

  it('préfixe chaque établissement importé', () => {
    const strays = plan.institutions
      .filter((row) => !row.id.startsWith(EEF_INSTITUTION_ID_PREFIX))
      .map((row) => row.id);
    expect(strays).toEqual([]);
  });

  it('préfixe chaque formation importée', () => {
    // Une seule formation hors préfixe serait servie par le catalogue général
    // une fois publiée : elle chasserait une fiche partenaire de l'instantané
    // de 1 000 lignes, sans une erreur.
    const strays = plan.programs
      .filter((row) => !row.id.startsWith(EEF_PROGRAM_ID_PREFIX))
      .map((row) => row.id);
    expect(strays).toEqual([]);
  });

  it('ne rattache jamais une formation importée à un établissement non importé', () => {
    // La recherche exige que l'établissement d'une formation soit publié ; un
    // parent hors du périmètre EEF ne serait jamais exclu du catalogue général
    // avec ses enfants.
    const strays = plan.programs
      .filter((row) => !row.institutionId.startsWith(EEF_INSTITUTION_ID_PREFIX))
      .map((row) => row.id);
    expect(strays).toEqual([]);
  });

  it('reconnaît ses propres identifiants, et seulement eux', () => {
    expect(isEefProgramId('eef-prog-0387ffdcaab99c8a')).toBe(true);
    expect(isEefInstitutionId('eef-univ-0353074b')).toBe(true);
    // Les lignes partenaires existantes ne sont pas concernées.
    expect(isEefProgramId('omnes-p-abc')).toBe(false);
    expect(isEefInstitutionId('omnes-essec')).toBe(false);
    // Un établissement n'est pas une formation : les deux préfixes ne se
    // confondent pas.
    expect(isEefProgramId('eef-univ-0353074b')).toBe(false);
    expect(isEefInstitutionId('eef-prog-0387ffdcaab99c8a')).toBe(false);
  });
});

describe('provenance — les clauses', () => {
  it('excluent par préfixe, et ne mentionnent aucune colonne de procédure', () => {
    // Le critère est la PROVENANCE. `procedureType` a un sens (le schéma prévoit
    // déjà `hors_eef`) et `uaiCode` existe aussi pour les écoles privées : les
    // utiliser ferait disparaître d'Explore des fiches partenaires le jour où
    // l'exploitation les qualifie.
    // Une formation est de l'import si SON identifiant OU celui de son
    // établissement porte le préfixe : une formation créée à la main sous une
    // université de l'import (identifiant généré, actif par défaut) en est aussi.
    expect(notEefProgram()).toEqual({
      NOT: {
        OR: [
          { id: { startsWith: 'eef-prog-' } },
          { institutionId: { startsWith: 'eef-univ-' } },
        ],
      },
    });
    expect(notEefInstitution()).toEqual({
      NOT: { id: { startsWith: 'eef-univ-' } },
    });
    for (const clause of [
      notEefProgram(),
      notEefInstitution(),
      notPendingEefProgram(),
      notPendingEefInstitution(),
    ]) {
      expect(JSON.stringify(clause)).not.toMatch(
        /procedureType|uaiCode|institutionType|cycle/,
      );
    }
  });

  it('rendent un objet neuf à chaque appel', () => {
    // Les appelants complètent leurs clauses ; un objet partagé entre deux
    // requêtes est un aliasing qu'on ne relit jamais.
    expect(notEefProgram()).not.toBe(notEefProgram());
    const mine = notEefProgram();
    (mine as Record<string, unknown>).intrus = true;
    expect(notEefProgram()).not.toHaveProperty('intrus');
  });

  it('retirent des files de revérification les seules lignes EEF INACTIVES', () => {
    // « importée par l'EEF ET pas encore publiée » — rien d'autre. Une ligne EEF
    // publiée reste dans la file : c'est exactement le cas où elle doit être
    // revérifiée. Une ligne inactive qui n'est PAS de l'EEF garde son
    // comportement d'avant.
    expect(notPendingEefProgram()).toEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-prog-' } }, { isActive: false }],
      },
    });
    expect(notPendingEefInstitution()).toEqual({
      NOT: {
        AND: [{ id: { startsWith: 'eef-univ-' } }, { isActive: false }],
      },
    });
  });
});
