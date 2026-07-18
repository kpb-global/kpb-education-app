import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

describe('CR-017 outcome migration contract', () => {
  const sql = readFileSync(
    resolve(
      process.cwd(),
      'prisma/migrations/20260717210000_competition_07_verified_outcomes/migration.sql',
    ),
    'utf8',
  );

  it('enforces append versioning and one current decision per workspace', () => {
    expect(sql).toContain(
      '"ApplicationSubmission_workspaceId_version_key"',
    );
    expect(sql).toMatch(
      /ApplicationDecisionRecord_one_current_per_workspace[\s\S]*WHERE "isCurrent" = true/,
    );
    expect(sql).toMatch(
      /FundingDecisionRecord_one_current_per_workspace[\s\S]*WHERE "isCurrent" = true/,
    );
  });

  it('keeps verifier identity immutable and verification timestamps coherent', () => {
    expect(sql.match(/_verification_check/g)).toHaveLength(3);
    expect(sql.match(/verifiedById_fkey[\s\S]*?ON DELETE RESTRICT/g)).toHaveLength(
      3,
    );
  });

  it('allows unknown funded amounts but never a half-filled amount/currency pair', () => {
    expect(sql).toContain(
      '("fundingAmountMinor" IS NULL AND "fundingCurrency" IS NULL)',
    );
    expect(sql).toContain('"fundingAmountMinor" IS NOT NULL');
    expect(sql).toContain('"fundingCurrency" IS NOT NULL');
    expect(sql).toContain('"fundingAmountMinor" > 0');
    expect(sql).toContain('"fundingCurrency" ~ \'^[A-Z]{3}$\'');
  });

  it('protects primary evidence and allows only one primary link per outcome', () => {
    expect(sql).toContain('OutcomeEvidenceLink_one_primary_per_entity');
    expect(sql).toMatch(
      /OutcomeEvidenceLink_one_primary_per_entity[\s\S]*WHERE "isPrimary" = true/,
    );
    expect(sql).toContain('ON DELETE RESTRICT ON UPDATE CASCADE');
  });
});
