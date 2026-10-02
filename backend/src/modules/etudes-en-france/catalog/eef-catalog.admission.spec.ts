import { admissionGuidance } from './eef-catalog.copy';
import {
  cohortFromParcoursupRow,
  COMMONS_STANDARD_THUMB_WIDTHS,
  commonsRasterDisplayUrl,
  logoFromCommons,
} from './eef-catalog.admission';
import type { EefProgramRecord } from './eef-catalog.types';

const PROGRAM: EefProgramRecord = {
  id: 'eef-prog-1',
  institutionId: 'eef-univ-1',
  nameFr: 'L1 - Droit',
  level: 'Bachelor',
  cycle: 'licence1',
  fieldId: 'd07',
  fieldIsFallback: false,
  durationYears: 3,
  campusCity: 'Paris',
  procedureType: 'dap_blanche',
  selectivity: 'non_selective',
  formationCode: '47270',
  tracks: [],
  recommendedBachelors: [],
  admissionModes: [],
  dataset: 'parcoursup',
  sourceUrl: 'https://dossierappel.parcoursup.fr/x',
};

describe('cohortFromParcoursupRow', () => {
  it('accepte une ligne dont les mentions retombent sur les admis', () => {
    const cohort = cohortFromParcoursupRow({
      cod_aff_form: '47270',
      acc_neobac: 12,
      acc_sansmention: 6,
      acc_ab: 3,
      acc_b: 2,
      acc_tb: 1,
      acc_tbf: 0,
      taux_acces_ens: 36,
      ran_grp1: 43,
    });
    expect(cohort?.admittedNeobac).toBe(12);
    expect(cohort?.accessRatePct).toBe(36);
    expect(cohort?.lastCalledRank).toBe(43);
    expect(cohort?.session).toBe('2025');
  });

  it('écarte une ligne qui ne somme pas', () => {
    expect(
      cohortFromParcoursupRow({
        cod_aff_form: '1',
        acc_neobac: 10,
        acc_sansmention: 1,
        acc_ab: 1,
        acc_b: 1,
        acc_tb: 1,
        acc_tbf: 1,
      }),
    ).toBeNull();
  });
});

describe('admissionGuidance', () => {
  it('ne cite aucun seuil quand aucune statistique n’est jointe', () => {
    const text = admissionGuidance(PROGRAM).fr;
    expect(text).toContain('Aucune moyenne minimale');
    expect(text).not.toMatch(/\d{2}\/20/);
  });

  it('cite la mention la plus fréquente comme repère de concurrence, hors de la population du lecteur', () => {
    const text = admissionGuidance({
      ...PROGRAM,
      admissionCohort: {
        session: '2025',
        sourceUrl:
          'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/',
        admittedNeobac: 100,
        sansMention: 10,
        assezBien: 20,
        bien: 50,
        tresBien: 15,
        tresBienFelicitations: 5,
        accessRatePct: 40,
        lastCalledRank: 80,
      },
    }).fr;
    expect(text).toContain('Aucune moyenne minimale');
    expect(text).toContain('Repère de concurrence uniquement');
    expect(text).toContain('mention Bien (14 à moins de 16/20)');
    // Les chiffres ne décrivent que des élèves de terminale française, et le taux
    // d'accès ne compte que les candidats scolarisés en France ou européens.
    expect(text).toContain('admis issus de terminale française');
    expect(text).toContain("n'incluent pas les candidats à bac étranger");
    expect(text).toContain("n'est pas un seuil pour toi");
    expect(text).toContain('scolarisés en France ou européens : 40 %');
    // Plus aucune consigne tirée d'une population qui n'est pas celle du lecteur
    // (décision du 02/10/2026).
    expect(text).not.toMatch(/vise/i);
  });

  it('ne donne aucune consigne de note, quelle que soit la mention dominante', () => {
    for (const dominant of ['sansMention', 'assezBien', 'bien', 'tresBien', 'tresBienFelicitations'] as const) {
      const cohort = {
        session: '2025',
        sourceUrl:
          'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/',
        admittedNeobac: 40,
        sansMention: 0,
        assezBien: 0,
        bien: 0,
        tresBien: 0,
        tresBienFelicitations: 0,
        accessRatePct: null,
        lastCalledRank: null,
        [dominant]: 40,
      };
      const guidance = admissionGuidance({ ...PROGRAM, admissionCohort: cohort });
      expect(guidance.fr).not.toMatch(/vise|au moins \d+\/20/i);
      expect(guidance.en).not.toMatch(/aim for|at least \d+\/20/i);
      expect(guidance.en).toContain('not a threshold for you');
    }
  });

  it('ne tire pas d’objectif d’un effectif trop petit', () => {
    const text = admissionGuidance({
      ...PROGRAM,
      admissionCohort: {
        session: '2025',
        sourceUrl:
          'https://data.enseignementsup-recherche.gouv.fr/explore/dataset/fr-esr-parcoursup/',
        admittedNeobac: 4,
        sansMention: 0,
        assezBien: 0,
        bien: 4,
        tresBien: 0,
        tresBienFelicitations: 0,
        accessRatePct: null,
        lastCalledRank: null,
      },
    }).fr;
    expect(text).toContain('trop petit');
    expect(text).toContain('terminale française');
    expect(text).not.toMatch(/\d{2}\/20/);
  });
});

describe('logoFromCommons', () => {
  const base = {
    wikidataId: 'Q42',
    fileUrl: 'https://upload.wikimedia.org/wikipedia/commons/a/a.png',
    filePage: 'https://commons.wikimedia.org/wiki/File:A.png',
    restrictions: '',
  };

  it('garde un logo en domaine public et note la marque', () => {
    const logo = logoFromCommons({
      ...base,
      licence: 'Public domain',
      restrictions: 'trademarked',
    });
    expect(logo?.trademarked).toBe(true);
    expect(logo?.licence).toBe('Public domain');
  });

  it('refuse un logo sous copyright', () => {
    expect(
      logoFromCommons({ ...base, licence: 'Copyrighted', restrictions: '' }),
    ).toBeNull();
  });

  it('refuse CC BY-NC même si la chaîne commence par CC BY', () => {
    expect(
      logoFromCommons({ ...base, licence: 'CC BY-NC 4.0', restrictions: '' }),
    ).toBeNull();
    expect(
      logoFromCommons({
        ...base,
        licence: 'CC BY-NC-SA 4.0',
        restrictions: '',
      }),
    ).toBeNull();
    expect(
      logoFromCommons({
        ...base,
        licence: 'Creative Commons Attribution-NonCommercial 4.0',
        restrictions: '',
      }),
    ).toBeNull();
  });

  it('garde CC BY et CC BY-SA', () => {
    expect(
      logoFromCommons({ ...base, licence: 'CC BY 4.0', restrictions: '' })?.licence,
    ).toBe('CC BY 4.0');
    expect(
      logoFromCommons({ ...base, licence: 'CC BY-SA 3.0', restrictions: '' })
        ?.licence,
    ).toBe('CC BY-SA 3.0');
  });
});

describe('commonsRasterDisplayUrl', () => {
  const SVG =
    'https://upload.wikimedia.org/wikipedia/commons/c/c6/Universit%C3%A4t_Artois_Logo.svg';
  const THUMB = (width: number) =>
    `https://upload.wikimedia.org/wikipedia/commons/thumb/c/c6/Universit%C3%A4t_Artois_Logo.svg/${width}px-Universit%C3%A4t_Artois_Logo.svg.png`;

  it('laisse un PNG ou un JPEG inchangé', () => {
    const png =
      'https://upload.wikimedia.org/wikipedia/commons/6/6d/Logo_Reims_University.png';
    expect(commonsRasterDisplayUrl(png)).toBe(png);
  });

  it('pointe le PNG miniature Commons d’un SVG, à une largeur que Wikimedia accepte', () => {
    expect(commonsRasterDisplayUrl(SVG)).toBe(THUMB(330));
  });

  it('ne demande jamais une largeur que Wikimedia refuse', () => {
    // 320 px répondait HTTP 400 : aucun logo ne s'affichait. Une largeur demandée
    // hors liste est ramenée à la standard qui la contient.
    for (const asked of [1, 20, 200, 300, 320, 330, 331, 400, 640, 2000, 9999]) {
      const url = commonsRasterDisplayUrl(SVG, asked);
      const width = Number(url.match(/\/(\d+)px-/)?.[1]);
      expect(COMMONS_STANDARD_THUMB_WIDTHS).toContain(width);
    }
    expect(commonsRasterDisplayUrl(SVG, 320)).toBe(THUMB(330));
    expect(commonsRasterDisplayUrl(SVG, 400)).toBe(THUMB(500));
    expect(commonsRasterDisplayUrl(SVG, 9999)).toBe(THUMB(3840));
  });

  it('ramène à une largeur acceptée une miniature déjà stockée en 320 px', () => {
    // Les lignes importées avant le correctif portent `/320px-…` en base.
    expect(commonsRasterDisplayUrl(THUMB(320))).toBe(THUMB(330));
    expect(commonsRasterDisplayUrl(THUMB(200))).toBe(THUMB(250));
  });

  it('laisse une miniature déjà à une largeur standard exactement telle quelle', () => {
    for (const width of COMMONS_STANDARD_THUMB_WIDTHS) {
      expect(commonsRasterDisplayUrl(THUMB(width))).toBe(THUMB(width));
    }
  });

  it('ne touche pas une miniature qui n’est pas sur Wikimedia', () => {
    const foreign = 'https://cdn.example.org/wikipedia/commons/thumb/c/c6/Logo.svg/320px-Logo.svg.png';
    expect(commonsRasterDisplayUrl(foreign)).toBe(foreign);
  });

  it('garde une URL à paramètres intacte quand elle est déjà standard', () => {
    expect(commonsRasterDisplayUrl(`${THUMB(330)}?utm=1`)).toBe(`${THUMB(330)}?utm=1`);
  });
});
