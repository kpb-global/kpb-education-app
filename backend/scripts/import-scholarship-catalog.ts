/**
 * Wrapper de développement. La logique vit dans
 * `src/cli/scholarships-catalog.cli.ts`, seul endroit compilé dans `dist/` et
 * donc seul endroit exécutable dans le conteneur de production.
 *
 * Conservé pour que les commandes `scholarships:import*` déjà documentées et
 * utilisées en local continuent de fonctionner à l'identique.
 */
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

const args = process.argv.slice(2);
const mode = args.includes('--apply') ? '--apply' : '--dry-run';

const result = spawnSync(
  process.execPath,
  [
    require.resolve('ts-node/dist/bin'),
    resolve(__dirname, '../src/cli/scholarships-catalog.cli.ts'),
    'import',
    mode,
  ],
  { stdio: 'inherit' },
);

process.exitCode = result.status ?? 1;
