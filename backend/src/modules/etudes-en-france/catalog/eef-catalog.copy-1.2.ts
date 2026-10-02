// ─────────────────────────────────────────────────────────────────────────────
// Catalogue « Études en France » — la prose de l'édition 1.2.0, FIGÉE.
//
// À NE JAMAIS MODIFIER. Ce module recopie, octet pour octet, ce que
// `eef-catalog.copy.ts` écrivait dans `requirementsFr` / `requirementsEn` avant
// les corrections du 02/10/2026 (`docs/eef-dossier-relecture-procedures.md`,
// § « Réponses de recherche »). C'est la prose que portent les formations
// publiées le 01/10/2026.
//
// Il ne sert qu'à `eef:reconcile` (`eef-catalog.reconcile.ts`), pour répondre
// à une seule question : « cette ligne en base est-elle encore la prose machine
// d'un import, ou quelqu'un l'a-t-il retouchée dans l'admin ? ». Une ligne
// identique à ce que cette édition aurait produit est réalignée ; une ligne qui
// diffère est SIGNALÉE et laissée telle quelle.
//
// Le spec voisin prouve que ce module reproduit l'édition 1.2.0 : il recalcule
// les 10 502 formations versionnées et compare l'empreinte à celle mesurée sur
// le code d'origine, avant correction. Une retouche ici casse ce test.
// ─────────────────────────────────────────────────────────────────────────────
import type { Bilingual } from './eef-catalog.copy';
import type {
  EefAdmissionCohort,
  EefCycle,
  EefProcedureType,
  EefProgramRecord,
  EefSelectivity,
} from './eef-catalog.types';

/// L'édition dont ce module est la copie.
export const EEF_COPY_EDITION_1_2 = '1.2.0';

const CYCLE_LABELS: Readonly<Record<EefCycle, Bilingual>> = {
  licence1: { fr: 'Licence, 1re année', en: 'Bachelor, first year' },
  licence2: { fr: 'Licence, 2e année', en: 'Bachelor, second year' },
  licence3: { fr: 'Licence, 3e année', en: 'Bachelor, final year' },
  licence_pro: { fr: 'Licence professionnelle', en: 'Professional bachelor' },
  but1: {
    fr: 'Bachelor universitaire de technologie (BUT), 1re année',
    en: 'University Bachelor of Technology (BUT), first year',
  },
  deust: {
    fr: "Diplôme d'études universitaires scientifiques et techniques (DEUST)",
    en: 'Two-year scientific and technical university degree (DEUST)',
  },
  sante: {
    fr: 'Parcours d’accès aux études de santé, 1re année',
    en: 'Health studies access pathway, first year',
  },
  ingenieur: {
    fr: "Cycle d'ingénieur en cinq ans",
    en: 'Five-year engineering programme',
  },
  master: { fr: 'Master', en: "Master's degree" },
  // Ajouter un cycle ici sans lui donner de libellé casserait la compilation :
  // le Record est exhaustif sur `EefCycle`, exprès.
};

const PROCEDURE_STEP: Readonly<Record<EefProcedureType, Bilingual>> = {
  dap_blanche: {
    fr:
      "Candidature par Demande d'admission préalable (DAP, dossier blanc), "
      + "déposée auprès de l'espace Campus France de votre pays de résidence.",
    en:
      'Apply through the Preliminary Admission Application (DAP, white form), '
      + 'filed with the Campus France office in your country of residence.',
  },
  dap_jaune: {
    fr:
      "Candidature par Demande d'admission préalable (DAP, dossier jaune), "
      + "propre aux écoles nationales supérieures d'architecture.",
    en:
      'Apply through the Preliminary Admission Application (DAP, yellow form), '
      + 'specific to national schools of architecture.',
  },
  eef: {
    fr:
      'Candidature par la procédure « Études en France », sur la plateforme '
      + 'Campus France de votre pays de résidence.',
    en:
      'Apply through the "Études en France" procedure, on the Campus France '
      + 'platform of your country of residence.',
  },
  parcoursup: {
    fr:
      'Candidature sur Parcoursup — le chemin des candidats résidant en '
      + 'France.',
    en: 'Apply on Parcoursup — the route for applicants residing in France.',
  },
  hors_eef: {
    fr:
      "Admission gérée directement par l'établissement ou par un concours : "
      + 'cette formation ne se demande pas par la procédure Études en France.',
    en:
      'Admission is handled by the institution itself or through a competitive '
      + 'examination: this programme is not part of the Études en France '
      + 'procedure.',
  },
};

const ENTRY_QUALIFICATION: Readonly<Record<EefCycle, Bilingual>> = {
  licence1: {
    fr:
      "Baccalauréat ou diplôme étranger donnant accès à l'enseignement "
      + "supérieur dans le pays d'obtention.",
    en:
      'Baccalauréat, or a foreign diploma granting access to higher education '
      + 'in the country where it was awarded.',
  },
  sante: {
    fr:
      "Baccalauréat ou diplôme étranger donnant accès à l'enseignement "
      + "supérieur dans le pays d'obtention.",
    en:
      'Baccalauréat, or a foreign diploma granting access to higher education '
      + 'in the country where it was awarded.',
  },
  licence2: {
    fr:
      "Une année validée après le baccalauréat dans une discipline compatible. "
      + "L'entrée en cours de cursus passe par une commission de validation des "
      + "études suivies à l'étranger.",
    en:
      'One completed year of higher education in a compatible field. Entry '
      + "mid-programme goes through a committee that validates studies completed "
      + 'abroad.',
  },
  licence3: {
    fr:
      'Deux années validées après le baccalauréat (Bac+2) dans une discipline '
      + "compatible. L'entrée en cours de cursus passe par une commission de "
      + "validation des études suivies à l'étranger.",
    en:
      'Two completed years of higher education (Bac+2) in a compatible field. '
      + 'Entry mid-programme goes through a committee that validates studies '
      + 'completed abroad.',
  },
  but1: {
    fr: 'Baccalauréat ou diplôme équivalent.',
    en: 'Baccalauréat or an equivalent diploma.',
  },
  deust: {
    fr: 'Baccalauréat ou diplôme équivalent.',
    en: 'Baccalauréat or an equivalent diploma.',
  },
  ingenieur: {
    fr: 'Baccalauréat scientifique ou diplôme équivalent.',
    en: 'Science baccalauréat or an equivalent diploma.',
  },
  licence_pro: {
    fr: 'Deux années validées après le baccalauréat (Bac+2) dans une discipline compatible.',
    en: 'Two completed years of higher education (Bac+2) in a compatible field.',
  },
  master: {
    fr: 'Licence ou diplôme équivalent (Bac+3) dans une discipline compatible.',
    en: "Bachelor's degree or equivalent (Bac+3) in a compatible field.",
  },
};

const FRENCH_LEVEL: Readonly<Record<EefProcedureType, Bilingual | null>> = {
  dap_blanche: {
    fr:
      'Test de langue française exigé pour la DAP (TCF DAP), sauf dispense '
      + "prévue par l'arrêté — par exemple un baccalauréat français.",
    en:
      'A French language test is required for the DAP (TCF DAP), unless you '
      + 'qualify for an exemption — for instance a French baccalauréat.',
  },
  dap_jaune: {
    fr:
      'Test de langue française exigé pour la DAP (TCF DAP), sauf dispense '
      + "prévue par l'arrêté.",
    en:
      'A French language test is required for the DAP (TCF DAP), unless you '
      + 'qualify for an exemption.',
  },
  eef: {
    fr:
      "Le niveau de français exigé est fixé par l'établissement ; B2 est le "
      + 'seuil le plus courant. À confirmer sur la fiche officielle.',
    en:
      'The required French level is set by the institution; B2 is the most '
      + 'common threshold. Confirm it on the official programme page.',
  },
  parcoursup: null,
  hors_eef: null,
};

const SELECTIVITY_NOTE: Readonly<Record<EefSelectivity, Bilingual>> = {
  selective: {
    fr: "Formation sélective : l'établissement arbitre entre les dossiers.",
    en: 'Selective programme: the institution ranks applications.',
  },
  non_selective: {
    fr:
      "Formation non sélective : la capacité d'accueil est la limite, pas un "
      + 'classement des dossiers.',
    en:
      'Non-selective programme: intake capacity is the limit, not a ranking of '
      + 'applications.',
  },
};

/**
 * Une phrase, pas une fiche. Elle ne dit que ce que la ligne sait déjà :
 * l'intitulé, le cycle, le campus, et si l'établissement classe les dossiers.
 */
function programSummary(program: EefProgramRecord): Bilingual {
  const cycle = CYCLE_LABELS[program.cycle];
  const selective = program.selectivity === 'selective';
  return {
    fr:
      `${program.nameFr} — ${cycle.fr}, campus ${program.campusCity}. `
      + (selective
        ? "L'établissement classe les dossiers."
        : "La capacité d'accueil limite les places, pas un classement."),
    en:
      `${program.nameFr} — ${cycle.en}, ${program.campusCity} campus. `
      + (selective
        ? 'The institution ranks applications.'
        : 'Intake capacity limits places, not a ranking of files.'),
  };
}

/// En dessous de cet effectif, le profil des admis est un bruit, pas un repère.
const MIN_COHORT_FOR_TARGET = 15;

interface MentionBracket {
  readonly count: number;
  readonly floor: number;
  readonly fr: string;
  readonly en: string;
}

function mentionBrackets(cohort: EefAdmissionCohort): MentionBracket[] {
  // Les bornes sont celles que le jeu Parcoursup donne à ses propres colonnes
  // (mention au bac français). On ne les recalcule pas à partir d'une note
  // que le jeu ne publie pas.
  return [
    {
      count: cohort.tresBienFelicitations,
      floor: 18,
      fr: 'mention Très bien avec félicitations (18/20 et plus)',
      en: 'highest honours (18/20 and above)',
    },
    {
      count: cohort.tresBien,
      floor: 16,
      fr: 'mention Très bien (16 à moins de 18/20)',
      en: 'honours Très bien (16 to under 18/20)',
    },
    {
      count: cohort.bien,
      floor: 14,
      fr: 'mention Bien (14 à moins de 16/20)',
      en: 'honours Bien (14 to under 16/20)',
    },
    {
      count: cohort.assezBien,
      floor: 12,
      fr: 'mention Assez bien (12 à moins de 14/20)',
      en: 'honours Assez bien (12 to under 14/20)',
    },
    {
      count: cohort.sansMention,
      floor: 10,
      fr: 'bac sans mention (10 à moins de 12/20)',
      en: 'baccalauréat without honours (10 to under 12/20)',
    },
  ];
}

/**
 * Le repère de moyenne, ou l'aveu qu'il n'y en a pas.
 *
 * Règle unique : aucun chiffre qui ne sorte des effectifs publiés. Le plancher
 * cité est la borne basse de la mention la plus fréquente parmi les
 * néo-bacheliers qui ont accepté une place — pas un seuil d'admission, et pas
 * une exigence Campus France. En dessous de 15 admis, on donne les effectifs
 * sans en tirer un objectif.
 */
function admissionGuidance(program: EefProgramRecord): Bilingual {
  const cohort = program.admissionCohort;
  if (!cohort || cohort.admittedNeobac <= 0) {
    return {
      fr:
        'Aucune moyenne minimale officielle n\'est publiée pour cette formation, '
        + 'ni par le ministère ni pour la procédure Études en France. '
        + 'Il n\'existe pas de seuil chiffré vérifiable.',
      en:
        'No official minimum grade is published for this programme, neither by '
        + 'the ministry nor for the Études en France procedure. There is no '
        + 'verifiable numeric cutoff.',
    };
  }

  const brackets = mentionBrackets(cohort);
  const dominant = brackets.reduce((best, bracket) =>
    bracket.count > best.count ? bracket : best,
  );
  const access =
    cohort.accessRatePct == null
      ? ''
      : ` Taux d'accès Parcoursup ${cohort.session} : ${cohort.accessRatePct} %.`;
  const accessEn =
    cohort.accessRatePct == null
      ? ''
      : ` Parcoursup ${cohort.session} access rate: ${cohort.accessRatePct}%.`;

  if (cohort.admittedNeobac < MIN_COHORT_FOR_TARGET) {
    return {
      fr:
        `Aucune moyenne minimale officielle n'est publiée. Parcoursup ${cohort.session} `
        + `ne compte que ${cohort.admittedNeobac} néo-bacheliers ayant accepté une place : `
        + 'l\'effectif est trop petit pour en tirer un objectif de moyenne.'
        + access,
      en:
        `No official minimum grade is published. Parcoursup ${cohort.session} records `
        + `only ${cohort.admittedNeobac} new baccalauréat holders who accepted a place: `
        + 'the cohort is too small to infer a grade target.'
        + accessEn,
    };
  }

  const share = Math.round((dominant.count / cohort.admittedNeobac) * 100);
  const targetFr =
    dominant.floor <= 10
      ? 'Ce profil est le plus ouvert de la session. Pour te situer au-dessus, vise au moins 12/20 (mention Assez bien). Ce n\'est pas un seuil d\'admission.'
      : `Pour te situer dans ce profil, vise au moins ${dominant.floor}/20. Ce n'est pas un seuil d'admission.`;
  const targetEn =
    dominant.floor <= 10
      ? 'This is the most open profile in the session. To sit above it, aim for at least 12/20 (Assez bien). That is not an admission cutoff.'
      : `To sit in this profile, aim for at least ${dominant.floor}/20. That is not an admission cutoff.`;

  return {
    fr:
      `Aucune moyenne minimale officielle n'est publiée pour Études en France. `
      + `Parmi les ${cohort.admittedNeobac} néo-bacheliers qui ont accepté une place `
      + `sur Parcoursup ${cohort.session}, le profil le plus fréquent est ${dominant.fr} `
      + `(${share} %). ${targetFr}${access}`,
    en:
      `No official minimum grade is published for Études en France. Among the `
      + `${cohort.admittedNeobac} new baccalauréat holders who accepted a place on `
      + `Parcoursup ${cohort.session}, the most common profile is ${dominant.en} `
      + `(${share}%). ${targetEn}${accessEn}`,
  };
}

/**
 * Ce que l'édition 1.2.0 écrivait dans `requirementsFr` / `requirementsEn` pour
 * cette formation, avec SA procédure et SA sélectivité. L'appelant passe celles
 * que la ligne porte en base : c'est ce qui permet de reconnaître la prose d'une
 * ligne dont la procédure a changé depuis.
 */
export function programRequirements1_2(program: EefProgramRecord): Bilingual[] {
  const out: Bilingual[] = [
    programSummary(program),
    PROCEDURE_STEP[program.procedureType],
    ENTRY_QUALIFICATION[program.cycle],
  ];
  const french = FRENCH_LEVEL[program.procedureType];
  if (french) out.push(french);
  out.push(SELECTIVITY_NOTE[program.selectivity]);
  out.push(admissionGuidance(program));
  if (program.recommendedBachelors.length > 0) {
    const list = program.recommendedBachelors.join(', ');
    out.push({
      fr: `Licences conseillées à l'entrée, telles que publiées par l'établissement : ${list}.`,
      en: `Recommended bachelor's degrees, as published by the institution: ${list}.`,
    });
  }
  if (program.admissionModes.length > 0) {
    const list = program.admissionModes.join(', ');
    out.push({
      fr: `Modalité de candidature publiée : ${list}.`,
      en: `Published application method: ${list}.`,
    });
  }
  if (program.tracks.length > 0) {
    const list = program.tracks.join(' · ');
    out.push({
      fr: `Parcours proposés : ${list}.`,
      en: `Available tracks: ${list}.`,
    });
  }
  return out;
}
