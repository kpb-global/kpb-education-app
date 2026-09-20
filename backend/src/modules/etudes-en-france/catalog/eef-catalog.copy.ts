// ─────────────────────────────────────────────────────────────────────────────
// Catalogue « Études en France » — la prose, écrite UNE fois.
//
// Les fichiers de données ne contiennent aucune phrase. Tout ce qu'un étudiant
// lit — la présentation d'une université, les exigences d'admission d'une
// formation, le libellé d'un niveau ou d'une durée — est produit ici, à partir
// des faits de la ligne.
//
// CE QUE CE MODULE S'INTERDIT
//
// Inventer un fait que la source ne donne pas. Les données ouvertes du
// ministère ne publient ni les frais réels payés par un étudiant non
// européen, ni le niveau de français exigé formation par formation. Donc ce
// module ne les écrit pas : il dit que le montant dépend de l'établissement et
// renvoie à la fiche officielle. Une phrase prudente coûte un clic ; une
// phrase inventée coûte une candidature.
//
// Les droits d'inscription en particulier : depuis 2019 les universités
// peuvent appliquer des droits différenciés aux étudiants extra-européens OU
// en exonérer. Les deux pratiques coexistent, université par université, et
// aucun jeu ouvert ne dit laquelle s'applique où. Annoncer un montant serait
// donc faux pour une moitié du catalogue — on annonce la règle, pas le prix.
// ─────────────────────────────────────────────────────────────────────────────
import type {
  EefCycle,
  EefInstitutionRecord,
  EefLevel,
  EefProcedureType,
  EefProgramRecord,
  EefSelectivity,
} from './eef-catalog.types';

export interface Bilingual {
  readonly fr: string;
  readonly en: string;
}

/// Le repère « Bac+n » est identique dans les deux langues, et c'est
/// volontaire : c'est un marqueur du système français, pas une phrase. Le sens
/// est porté par le libellé de cycle, qui, lui, est traduit — sinon
/// « Master's level — Master's degree » répète deux fois la même chose.
const LEVEL_LABELS: Readonly<Record<EefLevel, Bilingual>> = {
  'Bac+2': { fr: 'Bac+2', en: 'Bac+2' },
  Bachelor: { fr: 'Bac+3', en: 'Bac+3' },
  Master: { fr: 'Bac+5', en: 'Bac+5' },
  Doctorat: { fr: 'Bac+8', en: 'Bac+8' },
};

export function levelLabel(level: EefLevel): Bilingual {
  return LEVEL_LABELS[level];
}

export function durationLabel(years: number): Bilingual {
  return years === 1
    ? { fr: '1 an', en: '1 year' }
    : { fr: `${years} ans`, en: `${years} years` };
}

const CYCLE_LABELS: Readonly<Record<EefCycle, Bilingual>> = {
  licence1: { fr: 'Licence, 1re année', en: 'Bachelor, first year' },
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

export function cycleLabel(cycle: EefCycle): Bilingual {
  return CYCLE_LABELS[cycle];
}

/// Le seul énoncé de prix que les données ouvertes autorisent. Il est
/// identique pour toutes les lignes, et c'est le point : il ne prétend pas
/// distinguer ce que la source ne distingue pas.
export const TUITION_NOTICE: Bilingual = {
  fr:
    "Droits d'inscription nationaux fixés chaque année par arrêté. Des droits "
    + "différenciés peuvent s'appliquer aux étudiants extra-européens, et "
    + "certaines universités en exonèrent : le montant exact se vérifie sur la "
    + "fiche officielle de la formation.",
  en:
    'National tuition fees are set by ministerial order each year. '
    + 'Differentiated fees may apply to non-European students, and some '
    + 'universities waive them: check the official programme page for the '
    + 'exact amount.',
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
 * Les exigences d'admission d'une formation, dans l'ordre où un candidat les
 * rencontre : par quelle procédure, avec quel diplôme, avec quel français,
 * puis ce que l'établissement ajoute.
 */
export function programRequirements(program: EefProgramRecord): Bilingual[] {
  const out: Bilingual[] = [
    PROCEDURE_STEP[program.procedureType],
    ENTRY_QUALIFICATION[program.cycle],
  ];
  const french = FRENCH_LEVEL[program.procedureType];
  if (french) out.push(french);
  out.push(SELECTIVITY_NOTE[program.selectivity]);
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

/**
 * La présentation d'une université. Uniquement des faits du référentiel du
 * ministère — typologie, ville, effectif daté. Pas d'adjectif : « prestigieuse »
 * n'est pas une donnée ouverte.
 */
export function institutionOverview(
  institution: EefInstitutionRecord,
): Bilingual {
  const typologyFr = institution.typology
    ? `${institution.typology}. `
    : 'Université publique française. ';
  const typologyEn = institution.typology
    ? `${institution.typology}. `
    : 'French public university. ';
  const enrolmentFr = institution.enrolment
    ? `${institution.enrolment.count.toLocaleString('fr-FR')} étudiants inscrits à la rentrée ${institution.enrolment.year}. `
    : '';
  const enrolmentEn = institution.enrolment
    ? `${institution.enrolment.count.toLocaleString('en-US')} students enrolled in ${institution.enrolment.year}. `
    : '';
  return {
    fr:
      `${typologyFr}Campus principal à ${institution.city} (${institution.department}, ${institution.region}). `
      + `${enrolmentFr}Établissement public : les droits d'inscription sont fixés par arrêté national.`,
    en:
      `${typologyEn}Main campus in ${institution.city} (${institution.department}, ${institution.region}). `
      + `${enrolmentEn}Public institution: tuition fees are set by national ministerial order.`,
  };
}

export function institutionLocation(
  institution: EefInstitutionRecord,
): Bilingual {
  return {
    fr: `${institution.city}, ${institution.region}`,
    en: `${institution.city}, ${institution.region}`,
  };
}

/// Ce que l'université enseigne, côté langue. Les universités publiques
/// enseignent en français ; les cursus anglophones existent mais ne sont pas
/// identifiables dans les jeux ouverts, donc on ne les annonce pas.
export const LANGUAGE_NOTICE: Bilingual = {
  fr: 'Français',
  en: 'French',
};

export const INSTITUTION_LANGUAGE_REQUIREMENTS: Bilingual = {
  fr:
    "Enseignement en français. Le niveau exigé dépend de la procédure et de la "
    + 'formation : TCF DAP pour une 1re année de licence, niveau fixé par '
    + "l'établissement (B2 le plus souvent) pour les autres cursus.",
  en:
    'Teaching is in French. The required level depends on the procedure and '
    + 'the programme: TCF DAP for a first-year bachelor, a level set by the '
    + 'institution (usually B2) for other programmes.',
};
