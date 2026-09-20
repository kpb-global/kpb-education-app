// Le test qui juge les DONNÉES livrées, pas seulement le code qui les produit.
//
// Les deux modules voisins prouvent que la conversion est correcte sur des cas
// écrits à la main. Celui-ci ouvre les 70 fichiers réellement versionnés et
// leur applique les portes strictes : c'est lui qui échoue si une collecte
// rapporte un catalogue amputé, si une source disparaît, ou si un identifiant
// se met à doubler.
import { loadEefCatalog } from './eef-catalog.loader';
import { planEefImport } from './eef-catalog.importer';
import { validateEefCatalog } from './eef-catalog.validator';

describe('catalogue « Études en France » versionné', () => {
  const catalog = loadEefCatalog();
  const result = validateEefCatalog(catalog);

  it('passe le validateur strict', () => {
    expect(result.errors).toEqual([]);
  });

  it('couvre les universités publiques et leurs deux cycles', () => {
    expect(result.stats.institutions).toBeGreaterThanOrEqual(65);
    expect(result.stats.byLevel.Bachelor).toBeGreaterThanOrEqual(3000);
    expect(result.stats.byLevel.Master).toBeGreaterThanOrEqual(2500);
  });

  it('range chaque formation sous une procédure connue, et surtout la bonne', () => {
    // Le partage DAP / Études en France est la seule chose qui décide du
    // calendrier d'un candidat : une L1 classée « eef » lui ferait rater
    // l'échéance de la DAP.
    for (const file of catalog.universities) {
      for (const program of file.programs) {
        if (program.cycle === 'licence1' || program.cycle === 'sante') {
          expect(['dap_blanche', 'dap_jaune']).toContain(program.procedureType);
        }
        if (program.cycle === 'master') {
          expect(program.procedureType).toBe('eef');
        }
      }
    }
  });

  it('déclare une licence de réutilisation pour chaque source', () => {
    // Sans licence nommée, une donnée publique n'est pas réutilisable : c'est
    // une affirmation juridique, elle doit voyager avec la donnée.
    expect(catalog.manifest.sources.length).toBeGreaterThan(0);
    for (const source of catalog.manifest.sources) {
      expect(source.licence).toContain('Licence Ouverte');
      expect(source.portal).toMatch(/^https:\/\//);
    }
  });

  it('n’importerait que des lignes inactives', () => {
    const plan = planEefImport(catalog, 'france');
    expect(plan.programs.length).toBe(result.stats.programs);
    expect(plan.programs.some((row) => row.isActive)).toBe(false);
  });

  it('ne sert aucune fiche vers un agrégateur', () => {
    // Les sources autorisées sont les portails de l'État et les sites des
    // établissements. Un agrégateur ne prouve rien et meurt sans prévenir.
    const banned = /(letudiant|studyrama|diplomeo|thotis|orientation\.com)/i;
    for (const file of catalog.universities) {
      for (const program of file.programs) {
        expect(program.sourceUrl).not.toMatch(banned);
      }
    }
  });
});
