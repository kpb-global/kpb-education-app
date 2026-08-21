import { SCHOLARSHIP_CATALOG_V1 } from '../src/modules/scholarships-index/data/scholarship-catalog.v1';
import { validateScholarshipCatalog } from '../src/modules/scholarships-index/data/scholarship-catalog.validator';

const structureOnly = process.argv.includes('--structure-only');

/**
 * `--ignore-clock` : sortir sur le verdict qui ne dépend PAS du passage du
 * temps.
 *
 * Pourquoi ce drapeau existe. L'en-tête de `catalog-freshness.yml` promet, noir
 * sur blanc, que le pourrissement daté du catalogue est « délibérément SÉPARÉ de
 * la CI backend », parce qu'« une campagne close est une ligne de littéral à
 * rafraîchir, ce n'est pas une raison de bloquer une PR d'authentification ».
 * Cette séparation n'était pas implémentée : le même script servait les deux
 * consommateurs avec le même verdict, et `CATALOG_EXPIRED_CYCLE_CODES` — la
 * constante qui nomme précisément ces codes — n'était branchée à rien.
 *
 * Le 20/08/2026 la promesse a été démentie en production : la date limite de
 * McCall MacBain est passée pendant la nuit et la CI backend est devenue rouge
 * sur TOUTE PR ouverte ce jour-là, dont un correctif de fuite de données
 * personnelles. Personne n'avait touché au dépôt.
 *
 * Le drapeau ne CACHE rien : le rapport complet est imprimé, anomalies datées
 * comprises, et le contrôle planifié quotidien continue de sortir sur le verdict
 * strict. Il déplace seulement la responsabilité là où le geste correctif se
 * trouve.
 */
const ignoreClock = process.argv.includes('--ignore-clock');

const report = validateScholarshipCatalog(SCHOLARSHIP_CATALOG_V1, {
  includeVolumeTargets: !structureOnly,
});

console.log(JSON.stringify(report, null, 2));

// Les échéances proches ne sont pas des anomalies, elles ne pèsent sur aucun
// verdict — mais elles doivent être LUES. Les écrire en annotation GitHub les
// fait remonter dans le résumé du run, y compris quand tout est vert : c'est le
// seul moment où quelqu'un peut encore choisir QUAND agir.
for (const soon of report.closingSoon) {
  console.log(
    `::warning::${soon.scholarshipId} clôt dans ${soon.daysLeft} jour(s) ` +
      `(${soon.closesAt.slice(0, 10)}). Passez le cycle en « closed » ce jour-là, ` +
      `ou publiez les dates du cycle suivant si la source les donne. ` +
      `Sans geste, la validation datée deviendra rouge.`,
  );
}

const passed = ignoreClock ? report.validIgnoringClock : report.valid;
if (!passed) {
  process.exitCode = 1;
}
