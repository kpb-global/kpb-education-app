// Ce que `vps-ops` lit APRÈS avoir recréé l'API, et ce qu'il en conclut.
//
// ## Les deux défauts que ce fichier empêche de revenir
//
// 1. La vérification lisait `/config/app` une demi-seconde après « Container kpb_api
//    Started » : Traefik répondait 404, et le job rougissait sur une trace Python
//    alors que l'opération avait réussi. Mesuré le 02/10/2026 sur `eef-space-on` ET
//    `eef-space-off` (runs 36995198501 et 36996234713).
// 2. « Prouver l'état de l'espace », la seule étape qui dit si l'espace est vraiment
//    ouvert ou fermé, n'avait JAMAIS pu tourner : bash reçoit son programme Python
//    entre apostrophes, et deux élisions dans un commentaire le coupaient —
//    `IndentationError` sur une valeur pourtant juste. Personne ne l'a vu : le
//    défaut 1 la faisait sauter à chaque fois. Encore un défaut caché par ce qui
//    devait le détecter.
//
// ## Pourquoi ce fichier JOUE les étapes
//
// Lire le workflow n'aurait pas vu le défaut 2 : le texte était juste, c'est bash qui
// le lisait autrement. Les deux étapes sont donc extraites telles quelles et jouées par
// `bash -e`, comme le runner, contre une API locale — jamais la production — qui sert
// la sortie du VRAI `AppConfigController`. Les assertions doivent passer sur une valeur
// juste et échouer sur une fausse : une vérification qu'on rend verte en la rendant
// aveugle ne vaut rien. Vu rouge par mutation : remettre une apostrophe dans le
// programme, lire `/config/app` sans attendre, ou desserrer une assertion.

import { execFile } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { createServer } from 'node:http';
import type { AddressInfo } from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

import { AppConfigController } from '../../config/app-config.controller';

const REPO = join(__dirname, '..', '..', '..', '..', '..');
const workflow = readFileSync(join(REPO, '.github', 'workflows', 'vps-ops.yml'), 'utf8');
const lines = workflow.split('\n');

const VERIFY = "Vérifier depuis l'extérieur ce que le serveur annonce vraiment";
const PROVE = "Prouver l'état de l'espace (eefSpace)";
// Les deux interrupteurs de la 56 (bulle, écoles privées) : relevé avant, preuve après.
const SPACE_BEFORE = "Relever l'espace avant (eefSpace ne doit pas bouger)";
const PROVE_SWITCH = "Prouver l'état de l'interrupteur (bulle, écoles privées)";

const stepIndex = (name: string) => lines.findIndex((l) => l.trim() === `- name: ${name}`);

/**
 * Une étape : son en-tête (`if:`, `env:`) et son script tel que le runner l'exécutera
 * — le bloc `run: |` sans son indentation YAML, et rien d'autre (pas les commentaires
 * posés au-dessus de l'étape suivante).
 */
function step(name: string): { header: string; script: string } {
  const at = stepIndex(name);
  expect(at).toBeGreaterThan(-1);
  const run = lines.findIndex((l, i) => i > at && /^ {8}run: \|$/.test(l));
  expect(run).toBeGreaterThan(at);
  const header = lines.slice(at, run).join('\n');
  // Le `run:` trouvé est bien celui de CETTE étape.
  expect(header).not.toMatch(/\n\s+- name: /);
  const body: string[] = [];
  for (const line of lines.slice(run + 1)) {
    if (line.trim() !== '' && !line.startsWith(' '.repeat(10))) break;
    body.push(line.slice(10));
  }
  return { header, script: body.join('\n') };
}

/** Une commande par ligne : les continuations `\` recollées. */
const commands = (script: string) => script.replace(/\\\n\s*/g, ' ').split('\n');

const isConfigFetch = (command: string) =>
  /\bcurl\b/.test(command) && command.includes('/api/config/app');

const verify = step(VERIFY);
const prove = step(PROVE);
const spaceBefore = step(SPACE_BEFORE);
const proveSwitch = step(PROVE_SWITCH);

describe('vps-ops — lire l’API quand elle répond, pas pendant sa recréation', () => {
  it('lit bien les deux étapes — sinon ce garde ne prouve rien', () => {
    expect(commands(verify.script).some(isConfigFetch)).toBe(true);
    expect(commands(prove.script).some(isConfigFetch)).toBe(true);
    expect(prove.script).toContain('assert got is want');
  });

  it('attend un 200 portant du JSON, en boucle bornée, AVANT la première lecture de /config/app', () => {
    const before = verify.script.slice(0, verify.script.indexOf('/api/config/app'));
    expect(before).toContain('/api/health/version');
    // Seul un 200 dont le corps se lit en JSON compte : le 404 de Traefik ne passe pas.
    expect(before).toMatch(/"\$code" = "200"/);
    expect(before).toMatch(/json\.load/);
    // Bornée, et assez longue : l'API répond 5 à 10 s après « Started » (barrière de
    // santé de deploy.yml, même URL publique).
    const attempts = before.match(/for attempt in \$\(seq 1 (\d+)\); do/);
    const pause = before.match(/\bsleep (\d+)\b/);
    expect(attempts).not.toBeNull();
    expect(pause).not.toBeNull();
    expect(Number(attempts![1]) * Number(pause![1])).toBeGreaterThanOrEqual(30);
    // Et si elle ne répond jamais, le job le DIT, au lieu d'une trace Python.
    expect(before).toMatch(/if \[ "\$ready" != "1" \]; then\s+echo "::error::[\s\S]*?exit 1/);
  });

  it.each([
    { name: VERIFY, s: verify },
    { name: PROVE, s: prove },
  ])('« $name » : chaque lecture de /config/app reprend sur erreur, dans un fichier relu ensuite', ({ s }) => {
    const cmds = commands(s.script);
    const fetches = cmds.flatMap((c, i) => (isConfigFetch(c) ? [i] : []));
    expect(fetches.length).toBeGreaterThan(0);
    for (const i of fetches) {
      const fetch = cmds[i];
      expect(fetch).toMatch(/--retry \d+/);
      // Sans lui, curl ne reprend pas un 404 : c'est exactement la réponse de Traefik.
      expect(fetch).toContain('--retry-all-errors');
      expect(fetch).toMatch(/--max-time \d+/);
      // Un tube n'est pas remis à zéro entre deux tentatives (man curl) : le parseur
      // pourrait lire un corps partiel suivi du corps complet.
      expect(fetch).not.toContain('|');
      const out = fetch.match(/ -o "\$(\w+)"/);
      expect(out).not.toBeNull();
      const parse = cmds.findIndex((c, j) => j > i && c.includes(`< "$${out![1]}"`));
      expect(parse).toBeGreaterThan(i);
    }
  });

  it('les assertions sur la valeur servie sont intactes, et jugées une seule fois', () => {
    for (const assertion of [
      'want = os.environ["WANT_OPEN"] == "true"',
      'assert "eefSpace" in features',
      'assert got is want',
      'assert features.get("eef") is False',
      'assert d.get("eefCatalog")',
      'assert (d.get("eefCampaign") or {}).get("platformUrl")',
    ]) {
      expect(prove.script).toContain(assertion);
    }
    // Reprendre la LECTURE est voulu ; rejouer le JUGEMENT jusqu'à ce qu'il passe ne
    // l'est pas : aucune attente ni boucle dans cette étape.
    expect(prove.script).not.toMatch(/\bsleep\b|(^|;)\s*do\b/m);
  });

  it('« Prouver l’état » vient après la vérification, et seulement si elle a réussi', () => {
    expect(stepIndex(VERIFY)).toBeLessThan(stepIndex(PROVE));
    expect(prove.header).toMatch(/\n\s+if: \$\{\{ success\(\) && /);
  });
});

// ── Les étapes JOUÉES ────────────────────────────────────────────────────────

type Reply = { status: number; body: string; type?: string };
type Outcome = { code: number; stdout: string; stderr: string };

const TRAEFIK_404: Reply = { status: 404, body: '404 page not found\n', type: 'text/plain; charset=utf-8' };
const json = (value: unknown): Reply => ({ status: 200, body: JSON.stringify(value) });

/** La production du 02/10 : vitrine allumée, ancien commutateur éteint, espace fermé. */
const PRODUCTION = {
  KPB_EEF_ENABLED: 'false',
  KPB_EEF_TEASER_ENABLED: 'true',
  KPB_EEF_SPACE_ENABLED: 'false',
};

/** Ce que le VRAI contrôleur sert sous ces variables — pas une maquette du format. */
function served(overrides: Record<string, string> = {}): unknown {
  const env = { ...PRODUCTION, ...overrides };
  const saved: Record<string, string | undefined> = Object.fromEntries(
    Object.keys(env).map((k) => [k, process.env[k]]),
  );
  Object.assign(process.env, env);
  try {
    return new AppConfigController().getAppConfig();
  } finally {
    for (const [k, v] of Object.entries(saved)) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
  }
}

/**
 * Une API locale qui se comporte comme la production juste après la recréation :
 * Traefik répond 404 sur TOUT chemin tant qu'il n'a pas de conteneur vers qui router
 * (ici, pour les `unrouted` premières requêtes), puis l'API sert ses routes.
 */
async function withApi(
  routes: Record<string, Reply>,
  unrouted: number,
  run: (url: string, hits: Record<string, number>) => Promise<void>,
): Promise<void> {
  let seen = 0;
  const hits: Record<string, number> = {};
  const server = createServer((req, res) => {
    const path = req.url ?? '';
    hits[path] = (hits[path] ?? 0) + 1;
    const reply = seen++ < unrouted ? TRAEFIK_404 : (routes[path] ?? TRAEFIK_404);
    res.writeHead(reply.status, { 'content-type': reply.type ?? 'application/json' });
    res.end(reply.body);
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', () => resolve()));
  try {
    const { port } = server.address() as AddressInfo;
    await run(`http://127.0.0.1:${port}`, hits);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  }
}

describe('vps-ops — les deux étapes JOUÉES par bash, contre une API locale', () => {
  let tmp: string;
  beforeAll(() => {
    tmp = mkdtempSync(join(tmpdir(), 'vps-ops-'));
  });
  afterAll(() => rmSync(tmp, { recursive: true, force: true }));

  /** Le script d'une étape, comme le runner le lance : `bash -e`. */
  const play = (script: string, env: Record<string, string>) =>
    new Promise<Outcome>((resolve) => {
      execFile(
        'bash',
        ['-e', '-c', script],
        { env: { ...process.env, TMPDIR: tmp, ...env }, timeout: 60_000 },
        (error, stdout, stderr) =>
          resolve({ code: error ? (typeof error.code === 'number' ? error.code : -1) : 0, stdout, stderr }),
      );
    });

  it('« Vérifier » attend que Traefik route, puis lit /config/app UNE fois', async () => {
    const routes = {
      '/api/health/version': json({ sha: '47a1295fd71c', startedAt: '2026-10-02T10:23:49.550Z' }),
      '/api/config/app': json(served({ KPB_EEF_SPACE_ENABLED: 'true' })),
    };
    await withApi(routes, 1, async (url, hits) => {
      const r = await play(verify.script, { HEALTH_URL: url });
      expect(r.stderr).not.toMatch(/Error|Traceback/);
      expect(r.code).toBe(0);
      expect(r.stdout).toContain('API pas encore prête (tentative 1, HTTP 404)');
      expect(r.stdout).toContain('API prête à la tentative 2 | sha 47a1295fd71c');
      expect(r.stdout).toContain('"eefSpace": true');
      expect(hits['/api/config/app']).toBe(1);
    });
  }, 30_000);

  it.each<{ action: string; open: 'true' | 'false'; shown: string }>([
    { action: 'eef-space-on', open: 'true', shown: 'eefSpace = True | eef = False' },
    { action: 'eef-space-off', open: 'false', shown: 'eefSpace = False | eef = False' },
  ])('« Prouver l’état » passe quand $action a pris effet — il ne le pouvait pas avant le 02/10', async ({ open, shown }) => {
    const routes = { '/api/config/app': json(served({ KPB_EEF_SPACE_ENABLED: open })) };
    await withApi(routes, 0, async (url) => {
      const r = await play(prove.script, { HEALTH_URL: url, WANT_OPEN: open });
      expect(r.stderr).not.toMatch(/Error|Traceback/);
      expect(r.code).toBe(0);
      expect(r.stdout).toContain(shown);
    });
  }, 30_000);

  it.each<{ cas: string; payload: unknown; open: 'true' | 'false'; message: string }>([
    {
      cas: 'eef-space-on n’a pas pris',
      payload: served({ KPB_EEF_SPACE_ENABLED: 'false' }),
      open: 'true',
      message: 'features.eefSpace=False, attendu True',
    },
    {
      cas: 'eef-space-off n’a pas pris',
      payload: served({ KPB_EEF_SPACE_ENABLED: 'true' }),
      open: 'false',
      message: 'features.eefSpace=True, attendu False',
    },
    {
      cas: 'KPB_EEF_ENABLED est posé : la vitrine des builds 49 à 53 disparaît',
      payload: served({ KPB_EEF_ENABLED: 'true' }),
      open: 'true',
      message: 'features.eef est vrai',
    },
    {
      cas: 'la production tourne une image sans eefSpace',
      payload: { features: { eefTeaser: true, eef: false } },
      open: 'false',
      message: 'features.eefSpace absent',
    },
  ])('« Prouver l’état » échoue quand $cas', async ({ payload, open, message }) => {
    await withApi({ '/api/config/app': json(payload) }, 0, async (url) => {
      const r = await play(prove.script, { HEALTH_URL: url, WANT_OPEN: open });
      expect(r.code).not.toBe(0);
      expect(r.stderr).toContain(`AssertionError: ${message}`);
    });
  }, 30_000);
  // ── Les interrupteurs de la 56, contre la sortie du VRAI contrôleur ────────────
  //
  // `eefHelpBubble` / `eefPrivateSchools` sont écrites dans le contrôleur, dans le
  // client Flutter, dans l'argument du script et dans le workflow. Les tests Dart
  // jouent ces deux étapes sur des réponses fabriquées ; ici, c'est la réponse de
  // `AppConfigController` qui est servie. Renommer la clé d'un seul côté fait rougir
  // CE test, au lieu de rougir en production après l'écriture du `.env`.
  const SWITCHES = [
    { action: 'eef-bubble-on', env: 'KPB_EEF_HELP_BUBBLE_ENABLED', key: 'eefHelpBubble', open: true },
    { action: 'eef-bubble-off', env: 'KPB_EEF_HELP_BUBBLE_ENABLED', key: 'eefHelpBubble', open: false },
    { action: 'eef-private-schools-on', env: 'KPB_EEF_PRIVATE_SCHOOLS_ENABLED', key: 'eefPrivateSchools', open: true },
    { action: 'eef-private-schools-off', env: 'KPB_EEF_PRIVATE_SCHOOLS_ENABLED', key: 'eefPrivateSchools', open: false },
  ] as const;

  /** Le relevé « avant », puis la preuve, enchaînés par un vrai fichier $GITHUB_ENV. */
  async function beforeThenProve(
    s: (typeof SWITCHES)[number],
    afterPayload: unknown,
    beforePayload: unknown = served({ KPB_EEF_SPACE_ENABLED: 'true' }),
  ): Promise<{ before: Outcome; proof: Outcome; githubEnv: string }> {
    const githubEnv = join(tmp, `github_env_${s.action}_${Math.random().toString(36).slice(2)}`);
    writeFileSync(githubEnv, '');
    let before!: Outcome;
    await withApi({ '/api/config/app': json(beforePayload) }, 0, async (url) => {
      before = await play(spaceBefore.script, { HEALTH_URL: url, ACTION: s.action, GITHUB_ENV: githubEnv });
    });
    const written = readFileSync(githubEnv, 'utf8');
    const spaceBeforeValue = /^SPACE_BEFORE=(.*)$/m.exec(written)?.[1];
    let proof!: Outcome;
    await withApi({ '/api/config/app': json(afterPayload) }, 0, async (url) => {
      proof = await play(proveSwitch.script, {
        HEALTH_URL: url,
        ACTION: s.action,
        GITHUB_ENV: githubEnv,
        ...(spaceBeforeValue === undefined ? {} : { SPACE_BEFORE: spaceBeforeValue }),
      });
    });
    return { before, proof, githubEnv: written };
  }

  it.each(SWITCHES)(
    '$action : relevé puis preuve passent sur ce que sert le vrai contrôleur',
    async (s) => {
      const after = served({ KPB_EEF_SPACE_ENABLED: 'true', [s.env]: String(s.open) });
      const r = await beforeThenProve(s, after);

      expect(r.before.stderr).not.toMatch(/Error|Traceback/);
      expect(r.before.code).toBe(0);
      expect(r.githubEnv).toContain('SPACE_BEFORE=true');
      expect(r.proof.stderr).not.toMatch(/Error|Traceback/);
      expect(r.proof.code).toBe(0);
      expect(r.proof.stdout).toContain(`${s.key} = ${s.open ? 'True' : 'False'}`);
      expect(r.proof.stdout).toContain('(avant : true)');
    },
    30_000,
  );

  it.each(SWITCHES)(
    '$action : la preuve rougit si le contrôleur sert l’inverse de la valeur voulue',
    async (s) => {
      const after = served({ KPB_EEF_SPACE_ENABLED: 'true', [s.env]: String(!s.open) });
      const r = await beforeThenProve(s, after);

      expect(r.proof.code).not.toBe(0);
      expect(r.proof.stderr).toContain(`AssertionError: features.${s.key}=`);
    },
    30_000,
  );

  it.each(SWITCHES)(
    '$action : la preuve rougit sur l’image d’AVANT la 56 (clé absente)',
    async (s) => {
      const payload = served({ KPB_EEF_SPACE_ENABLED: 'true', [s.env]: String(s.open) }) as {
        features: Record<string, unknown>;
      };
      delete payload.features[s.key];
      const r = await beforeThenProve(s, payload);

      expect(r.proof.code).not.toBe(0);
      expect(r.proof.stderr).toContain(`AssertionError: features.${s.key} absent`);
    },
    30_000,
  );

  it.each(SWITCHES)(
    '$action : la preuve rougit si eefSpace a bougé entre le relevé et la preuve',
    async (s) => {
      const after = served({ KPB_EEF_SPACE_ENABLED: 'false', [s.env]: String(s.open) });
      const r = await beforeThenProve(s, after);

      expect(r.proof.code).not.toBe(0);
      expect(r.proof.stderr).toContain('features.eefSpace=');
    },
    30_000,
  );

  it('les clés des interrupteurs sont les mêmes dans le contrôleur, le client Flutter, le script et le workflow', () => {
    const controller = readFileSync(join(REPO, 'backend/src/modules/config/app-config.controller.ts'), 'utf8');
    const featuresBlock = /features:\s*\{([\s\S]*?)\}/.exec(controller)![1];
    const client = readFileSync(join(REPO, 'lib/app/core/services/remote_feature_flags.dart'), 'utf8');
    const ops = readFileSync(join(REPO, '.github/scripts/vps-ops.sh'), 'utf8');

    for (const s of SWITCHES.filter((x) => x.open)) {
      expect(featuresBlock).toMatch(new RegExp(`^\\s*${s.key},\\s*$`, 'm'));
      expect(client).toContain(`_flag('${s.key}'`);
      expect(ops).toContain(`eef_flag_on ${s.env} ${s.key} ${s.action}`);
      expect(proveSwitch.script).toContain(`=${s.key}`);
    }
  });
});
