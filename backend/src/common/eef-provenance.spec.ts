// ─────────────────────────────────────────────────────────────────────────────
// La provenance « Études en France » : que l'import écrit ce que les surfaces
// excluent, et qu'aucune porte ne reste sans garde.
//
// POURQUOI CE FICHIER EXISTE
//
// Le défaut qu'il garde a la forme que ce dépôt a déjà connue : une règle
// énoncée et appliquée à une porte sur quatre. Le catalogue général, les
// recommandations, la file de revérification et le compteur du tableau de bord
// lisent tous `Program` et `Institution`. Les corriger un par un ne suffit pas —
// le cinquième lecteur, écrit dans six mois, ne saura pas qu'il existe une
// règle. Ce test le lui dit, à l'endroit où l'oubli se produit.
//
// Il fait donc deux choses :
//
//   1. il relie la CRÉATION à l'EXCLUSION : l'import doit produire des
//      identifiants que les clauses reconnaissent, sur les vrais fichiers de
//      données et non sur des exemples écrits à la main ;
//   2. il COMPTE LES PORTES : tout fichier qui lit ces deux tables doit porter
//      l'une des clauses, ou figurer dans une liste d'exceptions dont chaque
//      entrée dit POURQUOI.
// ─────────────────────────────────────────────────────────────────────────────
import { readFileSync, readdirSync } from 'node:fs';
import { join, relative, sep } from 'node:path';

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
    expect(notEefProgram()).toEqual({
      NOT: { id: { startsWith: 'eef-prog-' } },
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

// ─── Les portes ──────────────────────────────────────────────────────────────

const SRC_DIR = join(__dirname, '..');

/**
 * Le code, sans commentaires.
 *
 * Nécessaire aux deux sens : un commentaire qui CITE `notEefProgram` ne prouve
 * aucune garde (il suffirait d'écrire le mot), et du code commenté ne doit pas
 * compter comme une lecture. Les lignes de commentaire entières et les blocs
 * sont retirés ; on ne touche pas aux commentaires de fin de ligne pour ne pas
 * mutiler une chaîne contenant `//`.
 */
function stripComments(source: string): string {
  return source
    .replace(/\/\*[\s\S]*?\*\//g, '')
    .split('\n')
    .filter((line) => !line.trimStart().startsWith('//'))
    .join('\n');
}

/** Tous les `.ts` de production sous `src/`, spec exclus. */
function productionFiles(dir: string): string[] {
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    if (entry.isDirectory()) return productionFiles(path);
    return entry.name.endsWith('.ts') && !entry.name.endsWith('.spec.ts')
      ? [path]
      : [];
  });
}

/** Une lecture de `Program` ou `Institution` par le client Prisma. */
const READS_CATALOG_TABLES =
  /\.(program|institution)\.(findMany|findFirst|findFirstOrThrow|findUnique|findUniqueOrThrow|count|groupBy|aggregate)\s*\(/;

/** Le même accès en SQL brut : il contournerait toute clause Prisma. */
const RAW_SQL_ON_CATALOG_TABLES = /\b(?:FROM|JOIN)\s+"(?:Program|Institution)"/i;

/**
 * Ce qui prouve qu'un fichier a pensé à la frontière.
 *
 * Les deux dernières enveloppent `notPendingEef*` pour la file de revérification
 * et son compteur : un lecteur qui passe par elles porte la clause sans la
 * nommer.
 */
const SCOPE_TOKENS = [
  'notEefProgram',
  'notEefInstitution',
  'notPendingEefProgram',
  'notPendingEefInstitution',
  'loadPublishedInstitutionIds',
  'institutionVerificationDueWhere',
  'programVerificationDueWhere',
];

/**
 * Les fichiers qui lisent ces tables SANS clause, et pourquoi c'est voulu.
 *
 * Ajouter une entrée ici est une décision de périmètre, pas une commodité : la
 * raison doit dire pourquoi CE lecteur a le droit de voir des lignes EEF non
 * publiées, et qui l'appelle.
 */
const UNSCOPED_ON_PURPOSE: Record<string, string> = {
  'modules/admin-catalog/admin-catalog.service.ts':
    'L’administration édite le catalogue : elle doit voir TOUT ce qui est en '
    + 'base, publié ou non — c’est son travail. Le seul de ses lecteurs qui '
    + 'sert un compteur ou une alarme (la file de revérification et le SLA) '
    + 'porte notPendingEef*, et son test regarde la clause envoyée.',
  'modules/competition-readiness/admin/admin-partnerships.service.ts':
    'Lecture par identifiant d’un établissement par un administrateur qui '
    + 'gère un partenariat : il faut pouvoir le retrouver quel que soit son état.',
};

describe('provenance — aucune porte sans garde', () => {
  const files = productionFiles(SRC_DIR).map((path) => ({
    path,
    key: relative(SRC_DIR, path).split(sep).join('/'),
    text: stripComments(readFileSync(path, 'utf8')),
  }));
  const readers = files.filter((file) => READS_CATALOG_TABLES.test(file.text));

  it('trouve bien des lecteurs — garde morte, sinon', () => {
    // Si l'expression régulière se casse ou que le dossier change, la liste est
    // vide et le test suivant passe sans rien garder.
    expect(readers.length).toBeGreaterThanOrEqual(6);
  });

  it('exige une clause de provenance de tout fichier qui lit Program ou Institution', () => {
    const unguarded = readers
      .filter((file) => !(file.key in UNSCOPED_ON_PURPOSE))
      .filter((file) => !SCOPE_TOKENS.some((token) => file.text.includes(token)))
      .map((file) => file.key);

    expect({
      message:
        unguarded.length === 0
          ? 'ok'
          : 'Ces fichiers lisent Program ou Institution sans clause de '
            + 'provenance. Le catalogue général ne doit jamais servir de ligne '
            + 'de l’import « Études en France » (voir common/eef-provenance.ts) : '
            + 'ajoute notEefProgram()/notEefInstitution(), ou, pour une lecture '
            + 'qui doit vraiment tout voir, déclare-la dans UNSCOPED_ON_PURPOSE '
            + 'avec la raison.',
      unguarded,
    }).toEqual({ message: 'ok', unguarded: [] });
  });

  it('ne tolère aucun SQL brut sur ces tables', () => {
    // Le SQL brut ignore toute clause Prisma. S'il devient nécessaire, il faut
    // écrire la garde à la main ET l'ajouter à ce test.
    const raw = files
      .filter((file) => RAW_SQL_ON_CATALOG_TABLES.test(file.text))
      .map((file) => file.key);
    expect(raw).toEqual([]);
  });

  it('n’a aucune exception morte', () => {
    // Une exception qui ne correspond plus à un lecteur est un droit d'accès
    // oublié : le fichier a pu être supprimé, renommé, ou cesser de lire ces
    // tables, et la liste continuerait d'autoriser un nom vide.
    const readerKeys = new Set(readers.map((file) => file.key));
    const dead = Object.keys(UNSCOPED_ON_PURPOSE).filter(
      (key) => !readerKeys.has(key),
    );
    expect(dead).toEqual([]);
  });

  it('exige une raison de chaque exception', () => {
    for (const [key, reason] of Object.entries(UNSCOPED_ON_PURPOSE)) {
      expect({ key, longEnough: reason.length > 60 }).toEqual({
        key,
        longEnough: true,
      });
    }
  });

  it('ne compte que des jetons qui existent encore', () => {
    // Un jeton renommé rendrait la vérification ci-dessus fausse pour tout le
    // monde (ou vraie pour un fichier qui n'a rien gardé, par un commentaire
    // qui le cite) sans que personne ne le voie. Il doit être une FONCTION
    // définie quelque part, pas un mot dans un texte.
    for (const token of SCOPE_TOKENS) {
      const defined = files.some((file) =>
        new RegExp(`\\bfunction\\s+${token}\\b`).test(file.text),
      );
      expect({ token, defined }).toEqual({ token, defined: true });
    }
  });
});
