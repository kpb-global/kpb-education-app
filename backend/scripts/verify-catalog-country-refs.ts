import { loadEnvFile } from 'node:process';

import { PrismaClient } from '@prisma/client';

loadEnvFile?.('.env');

const prisma = new PrismaClient();

/**
 * Data-integrity check: every country reference that designates a KPB
 * *destination* must point to an *active* Country (these are plain indexed
 * columns, not FKs, so nothing enforces this at the DB level):
 *   - Institution.countryId
 *   - Program.countryId
 *   - SupportDestination.countryId
 *   - ServiceOffer.destinationIds[]
 *
 * Scholarships are intentionally excluded: a scholarship may legitimately point
 * to a country KPB does not actively place students in (e.g. Japan), so its
 * countryId is treated as a display label rather than a destination reference.
 *
 * Exits non-zero when any orphan is found, so it can be used as a CI gate.
 */
async function main() {
  const activeCountries = await prisma.country.findMany({
    where: { isActive: true },
    select: { id: true },
  });
  const activeIds = new Set(activeCountries.map((c) => c.id));

  const [institutions, programs, supportDestinations, serviceOffers] = await Promise.all([
    prisma.institution.groupBy({ by: ['countryId'], _count: { _all: true } }),
    prisma.program.groupBy({ by: ['countryId'], _count: { _all: true } }),
    prisma.supportDestination.groupBy({ by: ['countryId'], _count: { _all: true } }),
    prisma.serviceOffer.findMany({ select: { id: true, destinationIds: true } }),
  ]);

  const orphans: { table: string; countryId: string; count: number }[] = [];
  for (const row of institutions) {
    if (!activeIds.has(row.countryId)) {
      orphans.push({ table: 'Institution', countryId: row.countryId, count: row._count._all });
    }
  }
  for (const row of programs) {
    if (!activeIds.has(row.countryId)) {
      orphans.push({ table: 'Program', countryId: row.countryId, count: row._count._all });
    }
  }
  for (const row of supportDestinations) {
    if (!activeIds.has(row.countryId)) {
      orphans.push({ table: 'SupportDestination', countryId: row.countryId, count: row._count._all });
    }
  }
  const offerDestCounts = new Map<string, number>();
  for (const offer of serviceOffers) {
    for (const id of offer.destinationIds) {
      if (!activeIds.has(id)) offerDestCounts.set(id, (offerDestCounts.get(id) ?? 0) + 1);
    }
  }
  for (const [countryId, count] of offerDestCounts) {
    orphans.push({ table: 'ServiceOffer.destinationIds', countryId, count });
  }

  // eslint-disable-next-line no-console
  console.log(`Active countries (${activeIds.size}): ${[...activeIds].sort().join(', ')}`);

  if (orphans.length === 0) {
    // eslint-disable-next-line no-console
    console.log('OK — every Institution/Program countryId references an active Country.');
    return;
  }

  // eslint-disable-next-line no-console
  console.error('FAIL — found rows referencing inactive/unknown countries:');
  for (const o of orphans) {
    // eslint-disable-next-line no-console
    console.error(`  ${o.table}: countryId="${o.countryId}" (${o.count} row(s))`);
  }
  process.exitCode = 1;
}

main()
  .then(async () => prisma.$disconnect())
  .catch(async (error) => {
    console.error(error);
    await prisma.$disconnect();
    process.exit(1);
  });
