import { execFileSync } from 'node:child_process';
import { readdirSync } from 'node:fs';
import { join, resolve } from 'node:path';

const firstUpgradeMigration =
  '20260718142257_competition_08_partners_pilots_impact';

function psqlUrl(databaseUrl: string): string {
  const url = new URL(databaseUrl);
  // `schema` is a Prisma-only connection option and is rejected by libpq.
  url.searchParams.delete('schema');
  return url.toString();
}

function runPsql(
  url: string,
  args: string[],
  schema?: string,
): string {
  return execFileSync('psql', [url, '-v', 'ON_ERROR_STOP=1', ...args], {
    encoding: 'utf8',
    env: {
      ...process.env,
      ...(schema
        ? { PGOPTIONS: `-c search_path=${schema},public` }
        : undefined),
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
}

function quotedIdentifier(value: string): string {
  return `"${value.replaceAll('"', '""')}"`;
}

function main(): void {
  const databaseUrl = process.env.DATABASE_URL;
  if (!databaseUrl) {
    throw new Error('DATABASE_URL is required for the populated upgrade gate.');
  }

  const url = psqlUrl(databaseUrl);
  const schema = `competition_upgrade_${process.pid}_${Date.now()}`;
  const quotedSchema = quotedIdentifier(schema);
  const migrationsRoot = resolve('prisma/migrations');
  const migrations = readdirSync(migrationsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
  const targetIndex = migrations.indexOf(firstUpgradeMigration);
  if (targetIndex < 0) {
    throw new Error(
      `Upgrade migration ${firstUpgradeMigration} was not found.`,
    );
  }

  runPsql(url, ['-q', '-c', `CREATE SCHEMA ${quotedSchema}`]);
  try {
    for (const migration of migrations.slice(0, targetIndex)) {
      runPsql(
        url,
        ['-q', '-f', join(migrationsRoot, migration, 'migration.sql')],
        schema,
      );
    }

    runPsql(
      url,
      [
        '-q',
        '-c',
        `
          INSERT INTO "UserProfile"
            ("id", "accountType", "preferredLanguage", "fullName", "email",
             "phone", "countryOfResidence", "updatedAt")
          VALUES
            ('upgrade-user', 'student', 'fr', 'Utilisateur synthétique',
             'upgrade@example.invalid', '+22700000000', 'NE', NOW());

          INSERT INTO "Partner"
            ("id", "slug", "nameFr", "nameEn", "category", "countryCode",
             "updatedAt")
          VALUES
            ('upgrade-partner', 'upgrade-partner', 'Partenaire synthétique',
             'Synthetic partner', 'university', 'NE', NOW());

          INSERT INTO "Institution"
            ("id", "nameFr", "nameEn", "countryId", "locationFr",
             "locationEn", "overviewFr", "overviewEn", "studyLevels",
             "tuitionLabelFr", "tuitionLabelEn", "languageRequirementsFr",
             "languageRequirementsEn", "intakePeriods", "programIds",
             "updatedAt")
          VALUES
            ('upgrade-institution', 'Institution synthétique',
             'Synthetic institution', 'NE', 'Niamey', 'Niamey',
             'Test migration', 'Migration test', ARRAY['Master'], 'N/A', 'N/A',
             'N/A', 'N/A', ARRAY['2026'], ARRAY[]::TEXT[], NOW());
        `,
      ],
      schema,
    );

    for (const migration of migrations.slice(targetIndex)) {
      runPsql(
        url,
        ['-q', '-f', join(migrationsRoot, migration, 'migration.sql')],
        schema,
      );
    }

    const result = runPsql(
      url,
      [
        '-A',
        '-t',
        '-c',
        `
          SELECT
            (SELECT count(*) FROM "UserProfile"),
            (SELECT count(*) FROM "Partner"),
            (SELECT count(*) FROM "Institution"),
            (SELECT count(*) FROM information_schema.tables
             WHERE table_schema = '${schema}'
               AND table_name IN (
                 'PartnerAgreement', 'ImpactPilot', 'ImpactCohort',
                 'ImpactSnapshot', 'ImpactDataRoomExport'
               )),
            (SELECT count(*)
             FROM pg_trigger AS trigger
             INNER JOIN pg_class AS relation ON relation.oid = trigger.tgrelid
             INNER JOIN pg_namespace AS namespace
               ON namespace.oid = relation.relnamespace
             WHERE namespace.nspname = '${schema}'
               AND trigger.tgname IN (
               'ImpactSnapshot_append_only',
               'ImpactDataRoomExport_append_only',
               'PartnerAgreement_revision_only',
               'ImpactPilot_analysis_lock'
             ) AND NOT trigger.tgisinternal);
        `,
      ],
      schema,
    ).trim();

    if (result !== '1|1|1|5|4') {
      throw new Error(`Unexpected populated upgrade result: ${result}`);
    }
    process.stdout.write(
      `${firstUpgradeMigration} and later: populated additive upgrade verified (${result}).\n`,
    );
  } finally {
    runPsql(url, ['-q', '-c', `DROP SCHEMA ${quotedSchema} CASCADE`]);
  }
}

main();
