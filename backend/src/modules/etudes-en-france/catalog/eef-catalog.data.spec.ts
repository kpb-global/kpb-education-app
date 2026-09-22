// Le test qui juge les DONNÉES livrées, pas seulement le code qui les produit.
//
// Les deux modules voisins prouvent que la conversion est correcte sur des cas
// écrits à la main. Celui-ci ouvre les 70 fichiers réellement versionnés et
// leur applique les portes strictes : c'est lui qui échoue si une collecte
// rapporte un catalogue amputé, si une source disparaît, ou si un identifiant
// se met à doubler.
import { programRequirements } from './eef-catalog.copy';
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
    expect(result.stats.byLevel.Bachelor).toBeGreaterThanOrEqual(6000);
    expect(result.stats.byLevel.Master).toBeGreaterThanOrEqual(2500);
  });

  it('couvre les 2e et 3e années, dans toutes les universités', () => {
    // C'est le cas le plus courant du public visé : un candidat qui a déjà
    // commencé des études chez lui n'entre pas en L1. Parcoursup ne les décrit
    // pas, donc leur absence ne se verrait nulle part sans ce test.
    //
    // Les établissements ajoutés hors typologie (UTC, Sciences Po, INALCO…)
    // n'ont pas un cycle licence complet. Le « au plus une exception » ne
    // vise que les universités du filtre historique. PSL reste cette exception.
    const classic = catalog.universities.filter(
      (file) =>
        !file.institution.institutionKind
        || file.institution.institutionKind === 'universite_publique',
    );
    const withContinuation = classic.filter((file) =>
      file.programs.some(
        (program) =>
          program.cycle === 'licence2' || program.cycle === 'licence3',
      ),
    );
    // Toutes sauf une. PSL fait exception pour une raison réelle : son offre
    // de licence est portée par ses composantes — Dauphine et le CPES — qui
    // ont leur propre identifiant au référentiel et ne remontent pas sous
    // l'université. Le seuil dit « au plus une exception », pour qu'une
    // deuxième fasse échouer le test au lieu de passer inaperçue.
    expect(withContinuation.length).toBeGreaterThanOrEqual(
      classic.length - 1,
    );
    const total = catalog.universities.reduce(
      (sum, file) =>
        sum
        + file.programs.filter(
          (program) =>
            program.cycle === 'licence2' || program.cycle === 'licence3',
        ).length,
      0,
    );
    expect(total).toBeGreaterThanOrEqual(2500);
  });

  it("n'écrit aucun intitulé de licence amputé de ses accents", () => {
    // Le jeu source les publie sans accents ; servis tels quels ce serait une
    // faute d'orthographe sur 3 000 fiches.
    const unaccented = /(etrangeres|litteratures|geographie|societe|motricite|entrainement sportif)/;
    for (const file of catalog.universities) {
      for (const program of file.programs) {
        expect(program.nameFr.toLowerCase()).not.toMatch(unaccented);
      }
    }
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
        if (
          program.cycle === 'master'
          || program.cycle === 'licence2'
          || program.cycle === 'licence3'
        ) {
          // La DAP ne concerne que la PREMIÈRE année : une L2, une L3 et un
          // master se demandent par la procédure Études en France.
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

  it('décrit chaque formation et ne fabrique pas de moyenne', () => {
    let withCohort = 0;
    let withLogo = 0;
    for (const file of catalog.universities) {
      if (file.institution.logo) withLogo += 1;
      for (const program of file.programs) {
        if (program.admissionCohort) withCohort += 1;
        const lines = programRequirements(program);
        expect(lines[0].fr).toContain(program.nameFr);
        expect(lines.some((line) => line.fr.includes('Aucune moyenne minimale'))).toBe(
          true,
        );
        expect(lines[0].en.length).toBeGreaterThan(10);
      }
    }
    // Plancher, pas un compte exact : un logo Commons qui change de licence
    // ou une formation 2026 sans statistique 2025 ne doit pas casser la CI,
    // une collecte qui n'a plus rien joint, si.
    expect(withLogo).toBeGreaterThanOrEqual(20);
    expect(withCohort).toBeGreaterThanOrEqual(1000);
  });

  it('n’importe aucun logo SVG brut : Flutter ne les décode pas', () => {
    const plan = planEefImport(catalog, 'france');
    for (const row of plan.institutions) {
      if (!row.logoUrl) continue;
      expect(row.logoUrl.toLowerCase()).not.toMatch(/\.svg(\?|$)/);
      expect(row.logoUrl).toMatch(/wikimedia\.org/);
    }
  });

  it('n’accepte aucune licence non commerciale sur un logo versionné', () => {
    for (const file of catalog.universities) {
      const licence = file.institution.logo?.licence;
      if (!licence) continue;
      expect(licence.toLowerCase()).not.toMatch(/\bnc\b/);
      expect(licence.toLowerCase()).not.toContain('noncommercial');
    }
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
