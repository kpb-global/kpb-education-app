// Contrôle que la page-source de chaque formation « page d'établissement » de
// l'import Études en France répond encore, et écrit le rapport que la
// publication déléguée lit pour laisser les pages mortes en attente.
// Voir `eef-source-check.ts` pour le pourquoi, et ce que le contrôle ne dit pas.
//
//   npx ts-node --transpile-only scripts/check-eef-source-pages.ts
//   npx ts-node --transpile-only scripts/check-eef-source-pages.ts --limit 40 --out /tmp/essai.json
//
// Lecture seule côté base (il n'y touche pas) : il lit les fichiers versionnés du
// catalogue et interroge les sites des établissements, deux passages espacés. À
// lancer depuis un poste ou la CI, pas depuis le conteneur de production : il n'a
// besoin ni de la base ni de ses secrets, et ses ~1 600 requêtes n'ont rien à y
// faire. Derrière un proxy d'entreprise : `NODE_USE_ENV_PROXY=1`.
import { writeFileSync } from 'node:fs';

import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';
import {
  assertSourceCheckUsable,
  checkedScope,
  EEF_SOURCE_CHECK_FILE,
  redirectedToHome,
  scopeDigest,
  sourceVerdict,
  type SourceCheckEntry,
  type SourceCheckReport,
  type SourceObservation,
} from '../src/modules/etudes-en-france/publication/eef-source-check';

const USER_AGENT = 'KPB-link-check/1.0 (+https://kpbeducation.cloud)';
const TIMEOUT_MS = 25_000;
const CONCURRENCY = 12;
// Un site d'université ne reçoit jamais plus de deux requêtes à la fois.
const PER_HOST = 2;

function option(name: string): string | undefined {
  const index = process.argv.indexOf(name);
  return index >= 0 ? process.argv[index + 1] : undefined;
}

const limit = Number(option('--limit') ?? '0');
const retryDelaySeconds = Number(option('--retry-delay-seconds') ?? '60');
if (!Number.isFinite(limit) || limit < 0 || !Number.isFinite(retryDelaySeconds) || retryDelaySeconds < 0) {
  console.error('--limit et --retry-delay-seconds doivent être des nombres positifs.');
  process.exit(2);
}
// Un essai partiel n'écrase JAMAIS le rapport versionné : celui-ci décide ce que la
// publication laisse en attente, et un rapport partiel en laisserait passer.
if (limit > 0 && option('--out') === undefined) {
  console.error('--limit (essai partiel) exige --out : le rapport versionné ne doit pas être écrasé par un essai.');
  process.exit(2);
}
const out = option('--out') ?? EEF_SOURCE_CHECK_FILE;

const sleep = (ms: number) => new Promise<void>((resolve) => setTimeout(resolve, ms));

async function probe(url: string): Promise<SourceObservation> {
  try {
    const response = await fetch(url, {
      redirect: 'follow',
      signal: AbortSignal.timeout(TIMEOUT_MS),
      headers: { 'user-agent': USER_AGENT, accept: 'text/html,*/*;q=0.8' },
    });
    // On ne lit pas la page : le statut suffit, et ne rien télécharger ménage le site.
    await response.body?.cancel();
    return {
      status: response.status,
      redirectedToHome: redirectedToHome(url, response.url),
    };
  } catch {
    return { status: 0, redirectedToHome: false };
  }
}

/** Parcourt `urls` avec au plus `CONCURRENCY` requêtes, `PER_HOST` par site. */
async function probeAll(urls: readonly string[]): Promise<Map<string, SourceObservation>> {
  const results = new Map<string, SourceObservation>();
  const pending = [...urls];
  const inFlight = new Map<string, number>();
  let running = 0;
  let done = 0;

  await new Promise<void>((resolve) => {
    const pump = () => {
      while (running < CONCURRENCY) {
        const index = pending.findIndex(
          (url) => (inFlight.get(new URL(url).hostname) ?? 0) < PER_HOST,
        );
        if (index < 0) break;
        const [url] = pending.splice(index, 1);
        const host = new URL(url).hostname;
        inFlight.set(host, (inFlight.get(host) ?? 0) + 1);
        running += 1;
        void probe(url).then((observation) => {
          results.set(url, observation);
          inFlight.set(host, (inFlight.get(host) ?? 1) - 1);
          running -= 1;
          done += 1;
          if (done % 200 === 0) console.log(`  … ${done}/${urls.length}`);
          pump();
        });
      }
      if (running === 0 && pending.length === 0) resolve();
    };
    pump();
  });
  return results;
}

async function main(): Promise<void> {
  const catalog = loadEefCatalog();
  // Les formations dont la source est une PAGE D'ÉTABLISSEMENT (voir `checkedScope`).
  const fullScope = checkedScope(catalog);
  const programs = fullScope;

  // Ordre déterministe mais mélangé : les sites ne reçoivent pas leurs adresses
  // d'affilée, ce qui ménage les petits serveurs d'université.
  let seed = 11;
  const random = () => {
    seed = (seed * 1_103_515_245 + 12_345) & 0x7fffffff;
    return seed / 0x7fffffff;
  };
  const urls = [...new Set(programs.map((program) => program.url))].sort();
  for (let i = urls.length - 1; i > 0; i -= 1) {
    const j = Math.floor(random() * (i + 1));
    [urls[i], urls[j]] = [urls[j], urls[i]];
  }
  const selected = limit > 0 ? urls.slice(0, limit) : urls;
  const selectedSet = new Set(selected);
  const scoped = programs.filter((program) => selectedSet.has(program.url));

  console.log(`${scoped.length} formation(s), ${selected.length} adresse(s) à contrôler.`);
  const observations = new Map<string, SourceObservation[]>();
  const record = (results: Map<string, SourceObservation>) => {
    for (const [url, observation] of results) {
      observations.set(url, [...(observations.get(url) ?? []), observation]);
    }
  };

  console.log('Premier passage…');
  record(await probeAll(selected));
  const toRetry = selected.filter((url) => sourceVerdict(observations.get(url) ?? []) !== 'ok');
  console.log(`${toRetry.length} adresse(s) sans réponse valide : second passage dans ${retryDelaySeconds} s.`);
  if (toRetry.length > 0) {
    await sleep(retryDelaySeconds * 1000);
    record(await probeAll(toRetry));
  }

  const dead: SourceCheckEntry[] = [];
  const uncertain: SourceCheckEntry[] = [];
  const verdictByUrl = new Map<string, ReturnType<typeof sourceVerdict>>();
  for (const url of selected) {
    verdictByUrl.set(url, sourceVerdict(observations.get(url) ?? []));
  }
  for (const program of scoped) {
    const verdict = verdictByUrl.get(program.url);
    if (verdict === 'ok') continue;
    const seen = observations.get(program.url) ?? [];
    const last = seen[seen.length - 1];
    const entry: SourceCheckEntry = {
      programId: program.programId,
      institutionId: program.institutionId,
      url: program.url,
      status: last?.status ?? 0,
      passes: seen.length,
      redirectedToHome: last?.redirectedToHome ?? false,
    };
    (verdict === 'dead' ? dead : uncertain).push(entry);
  }
  const byProgram = (a: SourceCheckEntry, b: SourceCheckEntry) => a.programId.localeCompare(b.programId);
  dead.sort(byProgram);
  uncertain.sort(byProgram);

  const count = (verdict: string) => [...verdictByUrl.values()].filter((v) => v === verdict).length;
  const report: SourceCheckReport = {
    checkedAt: new Date().toISOString(),
    scope: limit > 0 ? 'partial' : 'full',
    scopeDigest: scopeDigest(fullScope),
    method:
      `GET suivi des redirections, délai ${TIMEOUT_MS / 1000} s, ${PER_HOST} requêtes simultanées par site, `
      + `deux passages espacés de ${retryDelaySeconds} s pour toute adresse sans réponse valide. `
      + '« morte » = deux constats 404/410/redirigée vers l’accueil ; 403, 5xx, délai et certificat '
      + 'incomplet restent « incertains » et n’écartent rien.',
    totals: {
      programsChecked: scoped.length,
      urlsChecked: selected.length,
      ok: count('ok'),
      dead: count('dead'),
      uncertain: count('uncertain'),
    },
    dead,
    uncertain,
  };
  // Un rapport « frais et bien formé » n'est pas un rapport juste : réseau coupé, le
  // sondage sort 0 valide, 0 morte, N incertaines — un fichier valide qui n'écarte
  // rien. Un essai complet doit passer les mêmes garde-fous que la publication.
  if (report.scope === 'full') {
    try {
      assertSourceCheckUsable(report, catalog);
    } catch (error) {
      const rejected = `${out}.rejected.json`;
      writeFileSync(rejected, `${JSON.stringify(report, null, 1)}\n`);
      console.error(`Rapport REFUSÉ, non écrit à ${out} : ${error instanceof Error ? error.message : String(error)}`);
      console.error(`Copie de diagnostic : ${rejected}`);
      process.exit(1);
    }
  }
  writeFileSync(out, `${JSON.stringify(report, null, 1)}\n`);
  console.log(`Adresses : ${report.totals.ok} valides, ${report.totals.dead} mortes, ${report.totals.uncertain} incertaines.`);
  console.log(`Formations écartées (page morte) : ${dead.length} ; incertaines : ${uncertain.length}.`);
  console.log(`Rapport écrit : ${out}`);
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
