// Le câblage de l'action `eef-publish` (workflow `vps-ops` et script du VPS).
//
// Ce garde lit les sources : le comportement du script est prouvé ailleurs
// (`eef-delegated-publication.postgres.spec.ts`), mais personne ne le verrait si une
// retouche du workflow retirait la simulation par défaut, ressaisissait le total à
// côté, ou laissait passer une valeur libre non bornée vers une ligne de commande
// envoyée par SSH — la seule porte d'entrée de ce workflow vers un shell.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const REPO = join(__dirname, '..', '..', '..', '..', '..');
const workflow = readFileSync(join(REPO, '.github', 'workflows', 'vps-ops.yml'), 'utf8');
const script = readFileSync(join(REPO, '.github', 'scripts', 'vps-ops.sh'), 'utf8');

const branch = (() => {
  const start = script.indexOf('  eef-publish)');
  const end = script.indexOf('  reviews-purge-orphans)', start);
  expect(start).toBeGreaterThan(-1);
  expect(end).toBeGreaterThan(start);
  return script.slice(start, end);
})();

const FREE_VALUES = [
  'EEF_VERIFIER_EMAIL',
  'EEF_EXPECTED_PROGRAMS',
  'EEF_INSTITUTION_ID',
  'EEF_ACTOR',
] as const;

describe('action eef-publish — workflow vps-ops', () => {
  it('est dans la liste fermée des actions, et la simulation reste le défaut', () => {
    expect(workflow).toMatch(/^\s+- eef-publish$/m);
    expect(workflow).toMatch(/dry_run:[\s\S]*?default:\s*true/);
  });

  it('borne chaque valeur libre sur la valeur ENTIÈRE, sans grep', () => {
    // `grep` ne teste que ses lignes : « adresse valide ⏎ commande » le franchit.
    expect(workflow).toMatch(/bounded\(\)[\s\S]*?\[\[ "\$2" =~ \$3 \]\]/);
    const bounded = workflow.slice(workflow.indexOf('bounded() {'), workflow.indexOf('bounded verifier_email'));
    expect(bounded).not.toMatch(/\bgrep\b\s+-q/);
    for (const name of ['verifier_email', 'expected_programs', 'institution_id', 'github.actor']) {
      expect(workflow).toContain(`bounded ${name} `);
    }
  });

  it.each(FREE_VALUES)('%s est transmis au VPS', (name) => {
    expect(workflow).toContain(`${name}='\${${name}}'`);
  });

  it('prouve depuis l’extérieur que le catalogue général n’a pas bougé', () => {
    expect(workflow).toMatch(/inputs\.action == 'eef-publish'/);
    expect(workflow).toContain('catalog/institutions');
    expect(workflow).toContain('catalog/programs');
    expect(workflow).toContain('etudes-en-france/search');
  });
});

describe('action eef-publish — script du VPS', () => {
  it('revalide chaque valeur libre à sa réception', () => {
    for (const name of FREE_VALUES) {
      expect(branch).toMatch(new RegExp(`check_shape ${name} `));
    }
    expect(branch).toMatch(/\[\[ "\$2" =~ \$3 \]\]/);
  });

  it('la simulation ne contient jamais --apply', () => {
    const dry = branch.slice(
      branch.indexOf('if [ "$DRY_RUN" = "true" ]'),
      branch.indexOf('else', branch.indexOf('if [ "$DRY_RUN" = "true" ]')),
    );
    expect(dry).toContain('--dry-run');
    expect(dry).not.toContain('--apply');
  });

  it('écrire exige le total saisi, et le passe au script', () => {
    const write = branch.slice(branch.lastIndexOf('else'));
    expect(write).toMatch(/EEF_EXPECTED_PROGRAMS:-\}" \]/);
    expect(write).toContain('--apply --expect-programs "$EEF_EXPECTED_PROGRAMS"');
  });

  it('refuse d’écrire sur un backend sans la frontière de l’import', () => {
    expect(branch).toContain('dist/common/eef-provenance.js');
  });

  it('lance le script en --transpile-only (voir eef-scripts.memory.spec.ts)', () => {
    const packageScripts: Record<string, string> = JSON.parse(
      readFileSync(join(REPO, 'backend', 'package.json'), 'utf8'),
    ).scripts;
    expect(packageScripts['eef:publish']).toMatch(/ts-node --transpile-only scripts\/publish-eef-catalog\.ts/);
    expect(packageScripts['eef:check-sources']).toMatch(/ts-node --transpile-only/);
  });
});
