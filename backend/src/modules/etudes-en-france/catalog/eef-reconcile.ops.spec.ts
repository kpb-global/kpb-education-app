// Le câblage de l'action `eef-reconcile` (workflow `vps-ops` et script du VPS).
//
// Ce garde lit les sources : le comportement de l'outil est prouvé ailleurs
// (`eef-catalog.reconcile.postgres.spec.ts`), mais personne ne verrait une retouche
// du workflow qui retirerait la simulation par défaut, oublierait le total à saisir,
// laisserait passer une valeur libre non bornée vers la ligne de commande envoyée par
// SSH, ou cesserait de prouver depuis l'extérieur que rien n'a été publié.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';

const REPO = join(__dirname, '..', '..', '..', '..', '..');
const workflow = readFileSync(join(REPO, '.github', 'workflows', 'vps-ops.yml'), 'utf8');
const script = readFileSync(join(REPO, '.github', 'scripts', 'vps-ops.sh'), 'utf8');

const branch = (() => {
  const start = script.indexOf('  eef-reconcile)');
  const end = script.indexOf('\n  *)', start);
  expect(start).toBeGreaterThan(-1);
  expect(end).toBeGreaterThan(start);
  return script.slice(start, end);
})();

const FREE_VALUES = ['EEF_EXPECTED_PROGRAMS', 'EEF_INSTITUTION_ID', 'EEF_ACTOR'] as const;

describe('action eef-reconcile — workflow vps-ops', () => {
  it('est dans la liste fermée des actions, et la simulation reste le défaut', () => {
    expect(workflow).toMatch(/^\s+- eef-reconcile$/m);
    expect(workflow).toMatch(/dry_run:[\s\S]*?default:\s*true/);
  });

  it('borne ses trois valeurs libres sur la valeur ENTIÈRE, avant le serveur', () => {
    // Le `fi` du bloc lui-même (indenté de 10), pas celui d'un test imbriqué.
    const block = workflow.match(/if \[ "\$ACTION" = "eef-reconcile" \]; then([\s\S]*?)\n {10}fi\n/);
    expect(block).not.toBeNull();
    for (const name of ['expected_programs', 'institution_id', 'github.triggering_actor']) {
      expect(block![1]).toContain(`bounded ${name} `);
    }
    // L'outil ne publie rien : un e-mail de relecteur est REFUSÉ, jamais transmis.
    expect(block![1]).toMatch(/if \[ -n "\$EEF_VERIFIER_EMAIL" \]; then[\s\S]*?exit 1/);
    expect(block![1]).not.toContain('bounded verifier_email');
  });

  it('relève le catalogue général ET la recherche Études en France avant', () => {
    const before = workflow.slice(
      workflow.indexOf('name: Relever le catalogue général'),
      workflow.indexOf("name: Exécuter l'opération"),
    );
    expect(before).toMatch(/inputs\.action == 'eef-reconcile'/);
    expect(before).toContain('GENERAL_BEFORE=${inst}/${prog}');
    expect(before).toContain('EEF_SEARCH_BEFORE=${eef}');
  });

  it('PROUVE depuis l’extérieur que rien n’a été publié ni dépublié, et échoue sinon', () => {
    const proof = workflow.slice(
      workflow.indexOf("name: Prouver l'isolation"),
      workflow.indexOf("name: Vérifier depuis l'extérieur"),
    );
    expect(proof).toMatch(/inputs\.action == 'eef-reconcile'/);
    expect(proof).toContain('ACTION: ${{ inputs.action }}');
    expect(proof).toMatch(/"\$\{eef\}" != "\$\{EEF_SEARCH_BEFORE\}"[\s\S]*?exit 1/);
    expect(proof).toMatch(/"\$\{inst\}\/\$\{prog\}" != "\$\{GENERAL_BEFORE\}"[\s\S]*?exit 1/);
    // Et ce que l'app lira, procédure par procédure.
    expect(proof).toContain('procedureType=${procedure}');
  });
});

describe('action eef-reconcile — script du VPS', () => {
  it('revalide chaque valeur libre à sa réception', () => {
    for (const name of FREE_VALUES) {
      expect(branch).toMatch(new RegExp(`check_shape ${name} `));
    }
    expect(branch).toMatch(/\[\[ "\$2" =~ \$3 \]\]/);
  });

  it('refuse de tourner sur un backend qui ne porte pas l’outil', () => {
    expect(branch).toContain('test -f scripts/reconcile-eef-catalog.ts');
  });

  it('n’écrit que sur un « false » explicite : toute autre valeur reste en simulation', () => {
    expect(branch).toContain('if [ "$DRY_RUN" != "false" ]; then');
    expect(branch).not.toContain('if [ "$DRY_RUN" = "true" ]');
  });

  it('la simulation ne contient jamais --apply', () => {
    const start = branch.indexOf('if [ "$DRY_RUN" != "false" ]');
    const dry = branch.slice(start, branch.indexOf('else', start));
    expect(dry).toContain('npm run eef:reconcile -- --dry-run');
    expect(dry).not.toContain('--apply');
  });

  it('écrire exige le total saisi, et le passe au script', () => {
    const write = branch.slice(branch.lastIndexOf('else'));
    expect(write).toMatch(/EEF_EXPECTED_PROGRAMS:-\}" \]/);
    expect(write).toContain('npm run eef:reconcile -- --apply --expect-programs "$EEF_EXPECTED_PROGRAMS"');
  });

  it('transmet l’établissement et l’opérateur', () => {
    expect(branch).toContain('--institution "$EEF_INSTITUTION_ID"');
    expect(branch).toContain('--actor "$EEF_ACTOR"');
  });

  it('lance le script en --transpile-only (voir eef-scripts.memory.spec.ts)', () => {
    const packageScripts: Record<string, string> = JSON.parse(
      readFileSync(join(REPO, 'backend', 'package.json'), 'utf8'),
    ).scripts;
    expect(packageScripts['eef:reconcile']).toMatch(
      /ts-node --transpile-only scripts\/reconcile-eef-catalog\.ts/,
    );
  });
});
