// Les scripts « Études en France » que `vps-ops` lance dans le conteneur `api`
// doivent tourner en `ts-node --transpile-only`.
//
// POURQUOI. `ts-node` seul garde le compilateur TypeScript en mémoire pour
// vérifier les types : mesuré à 369 Mo de tas AVANT la première ligne du script,
// contre 34 Mo en `--transpile-only`. Le conteneur `api` est plafonné à 768 Mo,
// partagé avec l'API en production ; le tas de Node y plafonne vers 400 Mo. Il
// restait 30 Mo pour le catalogue (10 502 formations) : l'import passait de
// justesse, et le rattrapage des logos et des exigences, qui relit en plus les
// lignes de la base, a fini en « JavaScript heap out of memory » en production,
// après que l'import avait écrit. Avec le drapeau, le même rattrapage culmine à
// 125 Mo de tas (336 Mo de mémoire du processus au lieu de 705).
//
// Les types sont vérifiés par la CI (`tsc`, `eslint`), pas au lancement.
//
// Ce garde lit les sources : un script ajouté à `vps-ops.sh` sans le drapeau
// recréerait la panne, et rien d'autre ne le verrait avant la production.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const BACKEND = join(__dirname, '..', '..', '..', '..');
const REPO = join(BACKEND, '..');

const packageScripts: Record<string, string> = JSON.parse(
  readFileSync(join(BACKEND, 'package.json'), 'utf8'),
).scripts;

const opsScript = readFileSync(
  join(REPO, '.github', 'scripts', 'vps-ops.sh'),
  'utf8',
);

// `npm run eef:xxx` tel qu'écrit dans vps-ops.sh (ces commandes s'exécutent dans
// le conteneur de production).
const opsNames = [
  ...new Set(
    [...opsScript.matchAll(/npm run (eef:[A-Za-z0-9:-]+)/g)].map(
      (match) => match[1],
    ),
  ),
];

const TS_NODE_WITHOUT_FLAG = /\bts-node\b(?!\s+(?:-T\b|--transpile-only\b))/;

describe('les scripts EEF lancés par vps-ops tournent en --transpile-only', () => {
  it('lit bien vps-ops.sh — sinon il ne prouve rien', () => {
    expect(opsNames).toEqual(
      expect.arrayContaining([
        'eef:import',
        'eef:backfill',
        'eef:backfill:search',
      ]),
    );
  });

  it.each(opsNames)('%s est défini dans package.json', (name) => {
    expect(packageScripts[name]).toBeDefined();
  });

  it.each(opsNames)(
    '%s ne lance pas ts-node avec vérification de types',
    (name) => {
      const command = packageScripts[name] ?? '';
      if (!/\bts-node\b/.test(command)) return; // un script compilé n'est pas concerné
      expect(command).toMatch(/\bts-node\s+(?:-T|--transpile-only)\b/);
    },
  );

  it('le motif attrape bien la commande qui a mordu', () => {
    expect(
      TS_NODE_WITHOUT_FLAG.test('ts-node scripts/backfill-eef-enrichment.ts'),
    ).toBe(true);
    expect(
      TS_NODE_WITHOUT_FLAG.test(
        'ts-node --transpile-only scripts/backfill-eef-enrichment.ts',
      ),
    ).toBe(false);
  });
});
