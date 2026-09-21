import {
  buildInstitution,
  buildLabelIndex,
  buildLicenceContinuationPrograms,
  diplomaSourceUrl,
  buildMasterPrograms,
  buildParcoursupPrograms,
  countRejections,
  institutionUaiCodes,
  type RawInstitution,
  type RawLicenceYearRow,
  type RawMasterMention,
  type RawMasterTrack,
  type RawParcoursupRow,
} from './eef-catalog.builder';
import type { EefInstitutionRecord } from './eef-catalog.types';

const RAW_UNIVERSITY: RawInstitution = {
  uai: '0353074B',
  uo_lib: 'Université de Rennes',
  uo_lib_en: 'University of Rennes',
  sigle: null,
  com_nom: 'Rennes',
  dep_nom: 'Ille-et-Vilaine',
  reg_nom: 'Bretagne',
  url: 'https://www.univ-rennes.fr/',
  typologie_d_universites_et_assimiles: 'Université scientifique et/ou médicale',
  etablissement_id_paysage: 'PAY1',
  inscrits_2024: 34926,
  inscrits_2023: 34000,
};

describe('buildInstitution', () => {
  it('dérive un identifiant stable de l’UAI, pas du nom', () => {
    const renamed = buildInstitution({
      ...RAW_UNIVERSITY,
      uo_lib: 'Université de Rennes (EPE)',
    });
    expect(buildInstitution(RAW_UNIVERSITY)?.id).toBe(renamed?.id);
    expect(renamed?.id).toBe('eef-univ-0353074b');
  });

  it('garde tous les UAI d’un établissement qui en déclare plusieurs', () => {
    // Université Paris 8 en déclare deux ; n'en garder qu'un perdrait la
    // moitié de ses formations à la jointure.
    expect(institutionUaiCodes({ uai: '0751724S;0931827F' })).toEqual([
      '0751724S',
      '0931827F',
    ]);
    const record = buildInstitution({
      ...RAW_UNIVERSITY,
      uai: '0751724S;0931827F',
    });
    expect(record?.uai).toBe('0751724S;0931827F');
    expect(record?.id).toBe('eef-univ-0751724s');
  });

  it('retombe sur le nom français quand le ministère ne publie pas d’anglais', () => {
    const record = buildInstitution({ ...RAW_UNIVERSITY, uo_lib_en: null });
    expect(record?.nameEn).toBe('Université de Rennes');
  });

  it('prend l’effectif le plus récent, avec son année', () => {
    expect(buildInstitution(RAW_UNIVERSITY)?.enrolment).toEqual({
      count: 34926,
      year: 2024,
    });
    expect(
      buildInstitution({ ...RAW_UNIVERSITY, inscrits_2024: null })?.enrolment,
    ).toEqual({ count: 34000, year: 2023 });
    expect(
      buildInstitution({
        ...RAW_UNIVERSITY,
        inscrits_2024: null,
        inscrits_2023: null,
      })?.enrolment,
    ).toBeNull();
  });

  it('refuse un établissement sans UAI, sans nom ou sans site HTTPS', () => {
    expect(buildInstitution({ ...RAW_UNIVERSITY, uai: '' })).toBeNull();
    expect(buildInstitution({ ...RAW_UNIVERSITY, uo_lib: '  ' })).toBeNull();
    expect(
      buildInstitution({ ...RAW_UNIVERSITY, url: 'http://univ-rennes.fr/' }),
    ).toBeNull();
  });
});

const INSTITUTION = buildInstitution(RAW_UNIVERSITY) as EefInstitutionRecord;
const BY_PAYSAGE = new Map<string, EefInstitutionRecord>([['PAY1', INSTITUTION]]);

const PARCOURSUP_ROW: RawParcoursupRow = {
  etablissement_id_paysage: 'PAY1',
  etab_nom: 'Université de Rennes (35)',
  tf: ['Licence'],
  fl: ['L1 - Droit'],
  nm: ['Licence - Droit - Parcours Excellence'],
  commune: 'RENNES CEDEX 7',
  fiche: 'https://dossierappel.parcoursup.fr/Candidats/public/fiches/x?g_ta_cod=9307',
  gta: 9307,
};

describe('buildParcoursupPrograms', () => {
  it('rattache une composante à son université par l’identifiant Paysage', () => {
    // Les IUT portent leur propre UAI mais le Paysage de leur université :
    // se fier à l'UAI perdrait les 800 formations de BUT.
    const { records } = buildParcoursupPrograms(
      [{ ...PARCOURSUP_ROW, etab_uai: '0597266C', etab_nom: "IUT de Roubaix" }],
      BY_PAYSAGE,
    );
    expect(records).toHaveLength(1);
    expect(records[0].institutionId).toBe(INSTITUTION.id);
  });

  it('préfère la filière au libellé commercial de l’établissement', () => {
    const { records } = buildParcoursupPrograms([PARCOURSUP_ROW], BY_PAYSAGE);
    expect(records[0].nameFr).toBe('L1 - Droit');
    expect(records[0].fieldId).toBe('d07');
    expect(records[0].procedureType).toBe('dap_blanche');
    expect(records[0].campusCity).toBe('Rennes');
  });

  it('déduplique les lignes répétées par bac d’origine', () => {
    const { records } = buildParcoursupPrograms(
      [PARCOURSUP_ROW, { ...PARCOURSUP_ROW }, { ...PARCOURSUP_ROW }],
      BY_PAYSAGE,
    );
    expect(records).toHaveLength(1);
  });

  it('écarte, en le nommant, ce qu’il ne sait pas classer', () => {
    const { records, rejected } = buildParcoursupPrograms(
      [
        { ...PARCOURSUP_ROW, tf: ['CPGE'] },
        { ...PARCOURSUP_ROW, fl: ["DU - Diplôme d'Université"] },
        { ...PARCOURSUP_ROW, fiche: 'http://exemple.fr' },
        { ...PARCOURSUP_ROW, etablissement_id_paysage: 'INCONNU' },
        { ...PARCOURSUP_ROW, fl: [], nm: [] },
      ],
      BY_PAYSAGE,
    );
    expect(records).toHaveLength(0);
    expect(countRejections(rejected)).toEqual({
      'famille-inconnue': 1,
      'domaine-introuvable': 1,
      'source-manquante': 1,
      'etablissement-inconnu': 1,
      'intitule-vide': 1,
    });
  });
});

const MENTION: RawMasterMention = {
  etablissement_id_paysage: 'ANCIEN',
  etab_nom: 'Université Rennes-I',
  etab_ville: 'RENNES CEDEX',
  for_inm: '1702353J',
  for_intitule: 'Science politique',
  for_dom: 'DROIT, ECONOMIE, GESTION',
};

const TRACKS: RawMasterTrack[] = [
  {
    for_inm: '1702353J',
    parc_intitule: 'Théorie politique',
    parc_lic_conseille: ['Droit', 'Science politique'],
    for_candidature: ['Dossier'],
    for_lien_fiche: 'https://formations.univ-rennes.fr/master-science-politique',
  },
  {
    for_inm: '1702353J',
    parc_intitule: 'Théorie politique',
    parc_lic_conseille: ['Droit'],
    for_candidature: ['Dossier'],
    for_lien_fiche: null,
  },
];

describe('buildMasterPrograms', () => {
  const merges = new Map([['ANCIEN', 'PAY1']]);

  it('recale une mention sur l’université issue de la fusion', () => {
    // Sans cette table, les fusions de 2022-2025 rendraient 430 mentions
    // orphelines : elles existent, leur établissement a changé de nom.
    const { records } = buildMasterPrograms([MENTION], TRACKS, BY_PAYSAGE, merges);
    expect(records).toHaveLength(1);
    expect(records[0].institutionId).toBe(INSTITUTION.id);
    expect(records[0].level).toBe('Master');
    expect(records[0].procedureType).toBe('eef');
    // Sélectif de droit depuis la loi du 23 décembre 2016.
    expect(records[0].selectivity).toBe('selective');
    expect(records[0].campusCity).toBe('Rennes');
  });

  it('agrège les parcours sans les répéter', () => {
    const { records } = buildMasterPrograms([MENTION], TRACKS, BY_PAYSAGE, merges);
    expect(records[0].tracks).toEqual(['Théorie politique']);
    expect(records[0].recommendedBachelors).toEqual(['Droit', 'Science politique']);
    expect(records[0].admissionModes).toEqual(['Dossier']);
  });

  // Le portail publie `for_lic_conseille` tantôt en tableau de mentions,
  // tantôt en UNE chaîne jointe par des barres verticales — les deux formes
  // dans le même jeu. Non découpée, elle produisait une « mention » du genre
  // « Droit|Economie|Gestion|Toutes licences » : un libellé que personne ne
  // publie, qu'aucun appariement ne reconnaît, et qui enterrait donc quatre
  // licences conseillées dans une case introuvable. 501 entrées du catalogue
  // étaient dans ce cas, dont les 302 qui portent « Toutes licences » —
  // c'est-à-dire l'information d'admission la plus favorable du jeu.
  it('découpe les valeurs jointes par des barres verticales', () => {
    const { records } = buildMasterPrograms(
      [MENTION],
      [
        {
          ...TRACKS[0],
          parc_intitule: 'Théorie politique|Politiques comparées',
          parc_lic_conseille: ['Droit|Economie|Toutes licences'],
          for_candidature: ['Dossier|Entretien'],
        },
      ],
      BY_PAYSAGE,
      merges,
    );
    expect(records[0].recommendedBachelors).toEqual([
      'Droit',
      'Economie',
      'Toutes licences',
    ]);
    expect(records[0].admissionModes).toEqual(['Dossier', 'Entretien']);
    expect(records[0].tracks).toEqual([
      'Théorie politique',
      'Politiques comparées',
    ]);
  });

  it('ne dédouble pas une mention servie sous les deux formes', () => {
    // Un même parcours peut publier « Droit » en tableau et « Droit|Economie »
    // en chaîne : le découpage précède le dédoublonnage, sinon « Droit »
    // apparaîtrait deux fois.
    const { records } = buildMasterPrograms(
      [MENTION],
      [
        {
          ...TRACKS[0],
          parc_lic_conseille: ['Droit', 'Droit|Economie'],
        },
      ],
      BY_PAYSAGE,
      merges,
    );
    expect(records[0].recommendedBachelors).toEqual(['Droit', 'Economie']);
  });

  it('prend le premier lien HTTPS publié, et le portail en dernier recours', () => {
    const { records } = buildMasterPrograms([MENTION], TRACKS, BY_PAYSAGE, merges);
    expect(records[0].sourceUrl).toBe(
      'https://formations.univ-rennes.fr/master-science-politique',
    );
    const withoutLink = buildMasterPrograms(
      [MENTION],
      [{ ...TRACKS[0], for_lien_fiche: null }],
      BY_PAYSAGE,
      merges,
    );
    expect(withoutLink.records[0].sourceUrl).toMatch(/^https:\/\//);
  });

  it('écarte les établissements qui ne sont pas des universités', () => {
    const { records, rejected } = buildMasterPrograms(
      [{ ...MENTION, etablissement_id_paysage: 'ECOLE', etab_nom: 'Institut mines télécom' }],
      TRACKS,
      BY_PAYSAGE,
      merges,
    );
    expect(records).toHaveLength(0);
    expect(rejected[0]).toEqual({
      reason: 'etablissement-inconnu',
      label: 'Institut mines télécom',
    });
  });
});

const LICENCE_YEAR: RawLicenceYearRow = {
  etablissement_id_paysage_actuel: 'PAY1',
  etablissement_actuel_lib: 'Université de Rennes',
  libelle_intitule_1: 'Langues, litteratures et civilisations etrangeres et regionales',
  niveau: '03',
  implantation_commune: 'Rennes',
  diplom: '2300027',
};

describe('buildLabelIndex', () => {
  it('indexe la mention sans son préfixe de filière', () => {
    const index = buildLabelIndex(
      buildParcoursupPrograms([PARCOURSUP_ROW], BY_PAYSAGE).records,
    );
    expect(index.get('droit')).toBe('Droit');
    expect(index.get('l1 droit')).toBe('L1 - Droit');
  });
});

describe('buildLicenceContinuationPrograms', () => {
  const index = buildLabelIndex([
    ...buildParcoursupPrograms(
      [
        {
          ...PARCOURSUP_ROW,
          fl: ['L1 - Langues, littératures et civilisations étrangères et régionales'],
          gta: 1111,
        },
      ],
      BY_PAYSAGE,
    ).records,
  ]);

  it('rétablit les accents depuis un intitulé déjà connu du catalogue', () => {
    // Le jeu source publie sans accents ; on RECONNAÎT plutôt que de deviner,
    // parce que replacer un accent par règle est impossible en français.
    const { records } = buildLicenceContinuationPrograms(
      [LICENCE_YEAR],
      BY_PAYSAGE,
      index,
      2024,
    );
    expect(records[0].nameFr).toBe(
      'L3 - Langues, littératures et civilisations étrangères et régionales',
    );
  });

  it('rétablit les accents depuis la table fermée quand rien ne les porte', () => {
    const { records } = buildLicenceContinuationPrograms(
      [{ ...LICENCE_YEAR, libelle_intitule_1: 'Staps : education et motricite' }],
      BY_PAYSAGE,
      new Map(),
      2024,
    );
    expect(records[0].nameFr).toBe('L3 - STAPS : éducation et motricité');
  });

  it('laisse l’intitulé brut plutôt que d’accentuer au hasard', () => {
    // Une fiche sans accent se repère et se corrige ; une fiche accentuée au
    // hasard ne se repère pas.
    const { records } = buildLicenceContinuationPrograms(
      [{ ...LICENCE_YEAR, libelle_intitule_1: 'Chimie des procedes inedite' }],
      BY_PAYSAGE,
      new Map(),
      2024,
    );
    expect(records[0].nameFr).toBe('L3 - Chimie des procedes inedite');
  });

  it('met la L2 et la L3 en procédure Études en France, jamais en DAP', () => {
    const { records } = buildLicenceContinuationPrograms(
      [LICENCE_YEAR, { ...LICENCE_YEAR, niveau: '02' }],
      BY_PAYSAGE,
      index,
      2024,
    );
    expect(records.map((row) => row.cycle)).toEqual(['licence3', 'licence2']);
    expect(records.every((row) => row.procedureType === 'eef')).toBe(true);
    // Durée = ce qu'il RESTE à faire, pas la durée du diplôme : on entre en
    // cours de cursus.
    expect(records.map((row) => row.durationYears)).toEqual([1, 2]);
  });

  it('distingue deux campus de la même licence', () => {
    // Poitiers et Niort sont deux offres pour un étudiant, qui ne déménagera
    // pas deux fois.
    const { records } = buildLicenceContinuationPrograms(
      [LICENCE_YEAR, { ...LICENCE_YEAR, implantation_commune: 'Niort' }],
      BY_PAYSAGE,
      index,
      2024,
    );
    expect(records).toHaveLength(2);
    expect(records.map((row) => row.campusCity).sort()).toEqual(['Niort', 'Rennes']);
  });

  it('pointe sur SA ligne du jeu de données, pas sur le jeu entier', () => {
    // Un sourceUrl partagé par 3 000 fiches ne se vérifie pas.
    const url = diplomaSourceUrl('PAY1', '2300027', 2024);
    expect(url).toContain('refine=diplom%3A2300027');
    expect(url).toContain('refine=etablissement_id_paysage_actuel%3APAY1');
    expect(url).toContain('refine=rentree%3A2024');
    expect(url.startsWith('https://')).toBe(true);
  });

  it('écarte les portails, qui ne sont pas des mentions', () => {
    // Un « portail » est une entrée pluridisciplinaire de 1re année, qui se
    // scinde ensuite : l'annoncer comme une L3 tromperait.
    const { records, rejected } = buildLicenceContinuationPrograms(
      [
        { ...LICENCE_YEAR, libelle_intitule_1: 'Portail convention cpge litteraires' },
        { ...LICENCE_YEAR, niveau: '01' },
        { ...LICENCE_YEAR, etablissement_id_paysage_actuel: 'INCONNU' },
        { ...LICENCE_YEAR, diplom: '' },
      ],
      BY_PAYSAGE,
      index,
      2024,
    );
    expect(records).toHaveLength(0);
    expect(countRejections(rejected)).toEqual({
      'domaine-introuvable': 1,
      'famille-inconnue': 1,
      'etablissement-inconnu': 1,
      'source-manquante': 1,
    });
  });
});
