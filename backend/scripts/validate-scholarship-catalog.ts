import { SCHOLARSHIP_CATALOG_V1 } from '../src/modules/scholarships-index/data/scholarship-catalog.v1';
import { validateScholarshipCatalog } from '../src/modules/scholarships-index/data/scholarship-catalog.validator';

const structureOnly = process.argv.includes('--structure-only');
const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
  includeVolumeTargets: !structureOnly,
});

console.log(JSON.stringify(report, null, 2));

if (!report.valid) {
  process.exitCode = 1;
}
