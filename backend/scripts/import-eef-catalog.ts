// Import du catalogue « Études en France » en base.
//
//   npx ts-node scripts/import-eef-catalog.ts --dry-run
//   npx ts-node scripts/import-eef-catalog.ts --apply
//
// Aucun mode par défaut : la commande sans drapeau ne fait rien et le dit.
// C'est la règle du pipeline des bourses, et elle vient d'un accident réel —
// une commande qui écrit par défaut finit par écrire par accident.
import { existsSync } from 'node:fs';
import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

import {
  importEefCatalog,
  planEefImport,
  type EefCatalogWriter,
  type PlannedInstitution,
  type PlannedProgram,
} from '../src/modules/etudes-en-france/catalog/eef-catalog.importer';
import { loadEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.loader';
import { validateEefCatalog } from '../src/modules/etudes-en-france/catalog/eef-catalog.validator';

if (existsSync('.env')) loadEnvFile?.('.env');

const dryRun = process.argv.includes('--dry-run');
const apply = process.argv.includes('--apply');
if (dryRun === apply) {
  console.error('Choisir --dry-run OU --apply. Rien n\'a été fait.');
  process.exit(2);
}

const prisma = new PrismaClient();

/**
 * Le pays n'est pas écrit en dur, et ce n'est pas de la prudence gratuite :
 * `Institution.countryId` n'est pas une clé étrangère, et deux identifiants de
 * la France coexistent déjà dans le dépôt selon le semeur qui a écrit la ligne
 * (`france` côté M5, `fra` côté partenaires). Écrire le mauvais produirait
 * 7 000 formations orphelines qu'aucun filtre ne montrerait — et que
 * `verify:catalog` signalerait bien trop tard.
 *
 * On résout donc par le CODE pays, unique en base, et on refuse d'avancer si
 * la France n'est pas un pays actif.
 */
async function resolveFranceCountryId(): Promise<string> {
  const countries = await prisma.country.findMany({
    where: { isActive: true },
    select: { id: true, code: true },
  });
  const matches = countries.filter(
    (country) => country.code.toUpperCase() === 'FR',
  );
  if (matches.length === 0) {
    throw new Error(
      "Aucun pays actif de code « FR » en base : le catalogue n'a nulle part où "
      + "se rattacher. Exécuter le semeur des pays avant l'import.",
    );
  }
  if (matches.length > 1) {
    throw new Error(
      `Plusieurs pays actifs de code « FR » : ${matches.map((c) => c.id).join(', ')}. `
      + 'Trancher en base avant de réimporter.',
    );
  }
  return matches[0].id;
}

class PrismaEefWriter implements EefCatalogWriter {
  async createInstitutionIfAbsent(
    row: PlannedInstitution,
  ): Promise<'created' | 'existing'> {
    const existing = await prisma.institution.findUnique({
      where: { id: row.id },
      select: { id: true },
    });
    if (existing) return 'existing';
    await prisma.institution.create({ data: { ...row } });
    return 'created';
  }

  async createProgramIfAbsent(
    row: PlannedProgram,
  ): Promise<'created' | 'existing'> {
    const existing = await prisma.program.findUnique({
      where: { id: row.id },
      select: { id: true },
    });
    if (existing) return 'existing';
    await prisma.program.create({ data: { ...row } });
    return 'created';
  }
}

/// Le writer du dry-run : il LIT la base — sinon « ce qui serait créé » serait
/// une estimation — mais n'écrit rien.
class DryRunEefWriter implements EefCatalogWriter {
  async createInstitutionIfAbsent(
    row: PlannedInstitution,
  ): Promise<'created' | 'existing'> {
    const existing = await prisma.institution.findUnique({
      where: { id: row.id },
      select: { id: true },
    });
    return existing ? 'existing' : 'created';
  }

  async createProgramIfAbsent(
    row: PlannedProgram,
  ): Promise<'created' | 'existing'> {
    const existing = await prisma.program.findUnique({
      where: { id: row.id },
      select: { id: true },
    });
    return existing ? 'existing' : 'created';
  }
}

async function main(): Promise<void> {
  const catalog = loadEefCatalog();
  const validation = validateEefCatalog(catalog);
  if (validation.errors.length > 0) {
    console.error(
      `Catalogue invalide (${validation.errors.length} erreurs) : import refusé.`,
    );
    for (const error of validation.errors.slice(0, 20)) {
      console.error(`  ✗ ${error}`);
    }
    process.exit(1);
  }
  for (const warning of validation.warnings) console.warn(`  ⚠ ${warning}`);

  const countryId = await resolveFranceCountryId();
  if (countryId !== catalog.manifest.countryId) {
    console.warn(
      `  ⚠ Le manifeste vise « ${catalog.manifest.countryId} » ; la base sert `
      + `« ${countryId} » pour le code FR. C'est la base qui gagne.`,
    );
  }
  const plan = planEefImport(catalog, countryId);
  const writer = apply ? new PrismaEefWriter() : new DryRunEefWriter();
  const summary = await importEefCatalog(plan, writer);
  console.log(JSON.stringify({ mode: apply ? 'apply' : 'dry-run', ...summary }, null, 2));
  console.log(
    apply
      ? '\nLignes créées INACTIVES : elles attendent la file de vérification.'
      : '\nRien écrit.',
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
