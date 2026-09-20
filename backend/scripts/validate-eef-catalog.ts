// Validateur du catalogue « Études en France ».
//
//   npx ts-node scripts/validate-eef-catalog.ts               # strict
//   npx ts-node scripts/validate-eef-catalog.ts --structure-only
//
// `--structure-only` laisse tomber les planchers de volume : c'est la porte
// rapide de CI, celle qu'un lot qui ne touche pas aux données doit franchir
// sans dépendre du millésime des jeux ouverts. Le mode strict, lui, est ce qui
// doit passer avant un import.
import {
  DEFAULT_EEF_GATES,
  validateEefCatalog,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.validator';
import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';

const structureOnly = process.argv.includes('--structure-only');
const catalog = loadEefCatalog();
const gates = structureOnly
  ? {
      ...DEFAULT_EEF_GATES,
      minInstitutions: 1,
      minPrograms: 1,
      minInstitutionsWithPrograms: 0,
    }
  : DEFAULT_EEF_GATES;

const result = validateEefCatalog(catalog, gates);
const { stats } = result;
console.log(
  `Catalogue ${catalog.manifest.catalogVersion} — `
  + `${stats.institutions} universités, ${stats.programs} formations, `
  + `${(stats.fallbackRatio * 100).toFixed(2)} % de domaines classés par repli.`,
);
console.log(`  par procédure : ${JSON.stringify(stats.byProcedure)}`);
console.log(`  par niveau    : ${JSON.stringify(stats.byLevel)}`);
for (const warning of result.warnings) console.warn(`  ⚠ ${warning}`);

if (result.errors.length > 0) {
  console.error(`\n${result.errors.length} erreur(s) :`);
  // Bornées à 50 : un jeu cassé en produit des milliers, et une console
  // saturée cache la première erreur, qui est la seule utile.
  for (const error of result.errors.slice(0, 50)) console.error(`  ✗ ${error}`);
  if (result.errors.length > 50) {
    console.error(`  … et ${result.errors.length - 50} autres.`);
  }
  process.exit(1);
}
console.log('\nCatalogue valide.');
