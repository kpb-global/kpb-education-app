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
  'EEF_EXCLUDE_PROCEDURE',
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
    for (const name of [
      'verifier_email',
      'expected_programs',
      'institution_id',
      'exclude_procedure',
      'github.triggering_actor',
    ]) {
      expect(workflow).toContain(`bounded ${name} `);
    }
  });

  it('borne aussi la longueur, et ne contrôle ces valeurs que pour eef-publish', () => {
    expect(workflow).toMatch(/\$\{#2\}" -gt 254/);
    // Un login GitHub atypique ne doit pas bloquer `eef-space-off`.
    expect(workflow).toMatch(/if \[ "\$ACTION" = "eef-publish" \]; then\s+bounded verifier_email/);
  });

  it('inscrit celui qui LANCE (triggering_actor), pas celui qui a lancé la première fois', () => {
    expect(workflow).toContain('EEF_ACTOR: ${{ github.triggering_actor }}');
    expect(workflow).not.toContain('EEF_ACTOR: ${{ github.actor }}');
  });

  it('exclure une procédure est un choix FERMÉ, pas un texte libre', () => {
    expect(workflow).toMatch(/exclude_procedure:[\s\S]*?type: choice[\s\S]*?- aucune[\s\S]*?- hors_eef[\s\S]*?- dap_jaune[\s\S]*?- parcoursup/);
  });

  it.each(FREE_VALUES)('%s est transmis au VPS', (name) => {
    expect(workflow).toContain(`${name}='\${${name}}'`);
  });

  it('MESURE depuis l’extérieur que le catalogue général n’a pas bougé, et échoue sinon', () => {
    expect(workflow).toMatch(/inputs\.action == 'eef-publish'/);
    // Le relevé AVANT, puis la comparaison APRÈS qui fait échouer le job.
    expect(workflow).toContain('GENERAL_BEFORE=${inst}/${prog}');
    const proof = workflow.slice(workflow.indexOf("name: Prouver l'isolation"));
    expect(proof).toMatch(/"\$\{inst\}\/\$\{prog\}" != "\$\{GENERAL_BEFORE\}"[\s\S]*?exit 1/);
    expect(proof).toContain('etudes-en-france/search');
  });
});

describe('action eef-publish — script du VPS', () => {
  it('revalide chaque valeur libre à sa réception', () => {
    for (const name of FREE_VALUES) {
      expect(branch).toMatch(new RegExp(`check_shape ${name} `));
    }
    expect(branch).toMatch(/\[\[ "\$2" =~ \$3 \]\]/);
  });

  it('n’écrit que sur un « false » explicite : toute autre valeur reste en simulation', () => {
    expect(branch).toContain('if [ "$DRY_RUN" != "false" ]; then');
    expect(branch).not.toContain('if [ "$DRY_RUN" = "true" ]');
  });

  it('transmet la famille de procédure écartée', () => {
    expect(branch).toContain('--exclude-procedure "$EEF_EXCLUDE_PROCEDURE"');
  });

  it('la simulation ne contient jamais --apply', () => {
    const start = branch.indexOf('if [ "$DRY_RUN" != "false" ]');
    const dry = branch.slice(start, branch.indexOf('else', start));
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
