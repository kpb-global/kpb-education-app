// ─────────────────────────────────────────────────────────────────────────────
// L'import du catalogue « Études en France » — la moitié pure.
//
// DEUX RÈGLES, REPRISES DU PIPELINE DES BOURSES, POUR LA MÊME RAISON
//
// 1. CRÉATION SEULE. Une ligne dont l'id existe déjà n'est jamais mise à jour :
//    un administrateur a pu la corriger à la main, et un import ne doit pas
//    écraser une correction humaine. Le compteur s'appelle
//    `existingNotUpdated`, pas `skipped` — « sauté : 34 » se lit « rien à
//    faire » alors qu'il veut dire « 34 lignes potentiellement périmées »,
//    et c'est ce malentendu qui a laissé deux bourses servir une date fausse
//    pendant un mois.
//
// 2. LIGNES INACTIVES. Une formation importée n'est PAS publiée. Elle attend
//    la file de vérification. À 7 000 lignes, la relecture humaine intégrale
//    n'arrivera jamais : ce qui doit arriver, c'est que rien ne s'affiche
//    tant que personne n'a relu.
//
// Le plan est calculé ici, sans base de données, pour que `--dry-run` montre
// EXACTEMENT ce que `--apply` écrira. Un dry-run qui emprunte un autre chemin
// que l'apply ne prouve rien.
// ─────────────────────────────────────────────────────────────────────────────
import {
  INSTITUTION_LANGUAGE_REQUIREMENTS,
  LANGUAGE_NOTICE,
  TUITION_NOTICE,
  cycleLabel,
  durationLabel,
  institutionLocation,
  institutionOverview,
  levelLabel,
  programRequirements,
} from './eef-catalog.copy';
import type { EefCatalog, EefProgramRecord } from './eef-catalog.types';

/// Une ligne `Institution` prête à écrire. Les noms de champs sont ceux du
/// schéma : le writer ne doit avoir aucune traduction à faire.
export interface PlannedInstitution {
  readonly id: string;
  readonly countryId: string;
  readonly nameFr: string;
  readonly nameEn: string;
  readonly locationFr: string;
  readonly locationEn: string;
  readonly overviewFr: string;
  readonly overviewEn: string;
  readonly studyLevels: string[];
  readonly tuitionLabelFr: string;
  readonly tuitionLabelEn: string;
  readonly languageRequirementsFr: string;
  readonly languageRequirementsEn: string;
  readonly intakePeriods: string[];
  readonly programIds: string[];
  readonly isPartner: false;
  /// Comme les formations : un établissement importé attend la file de
  /// vérification. Sa fiche — texte de présentation, effectif daté — est une
  /// affirmation, et son `programIds` renvoie vers des lignes non relues.
  readonly isActive: false;
  readonly institutionType: string;
  readonly uaiCode: string;
  readonly websiteUrl: string;
  readonly sourceUrl: string;
}

export interface PlannedProgram {
  readonly id: string;
  readonly institutionId: string;
  readonly countryId: string;
  readonly fieldId: string;
  readonly nameFr: string;
  readonly nameEn: string;
  readonly levelFr: string;
  readonly levelEn: string;
  readonly durationFr: string;
  readonly durationEn: string;
  readonly tuitionFr: string;
  readonly tuitionEn: string;
  readonly languageFr: string;
  readonly languageEn: string;
  readonly requirementsFr: string[];
  readonly requirementsEn: string[];
  readonly teachingLanguages: string[];
  readonly procedureType: string;
  /// Le cycle exact, pour que la recherche filtre et facette dessus sans avoir
  /// à découper `levelFr`, qui est un libellé rédigé pour être lu.
  readonly cycle: string;
  readonly selectivity: string;
  readonly formationCode: string;
  readonly campusCity: string;
  /// Null assumé : aucun jeu ouvert ne publie le niveau de français exigé
  /// formation par formation. Écrire « B2 » partout serait inventer une
  /// exigence ; la phrase des `requirements` dit la règle et renvoie à la fiche.
  readonly frenchLevelRequired: null;
  /// Null assumé : les droits réellement payés par un étudiant extra-européen
  /// dépendent d'une exonération que les données ouvertes ne publient pas.
  readonly applicationFeeEur: null;
  readonly tuitionMinEur: null;
  readonly isActive: false;
  readonly sourceUrl: string;
}

export interface EefImportPlan {
  readonly catalogVersion: string;
  readonly countryId: string;
  readonly institutions: PlannedInstitution[];
  readonly programs: PlannedProgram[];
}

/// Le type d'établissement, tel qu'il s'affichera en facette. Tout ce
/// catalogue-ci en porte un seul : c'est un catalogue d'universités publiques.
export const INSTITUTION_TYPE_PUBLIC_UNIVERSITY = 'universite_publique';

/// L'ordre des niveaux servis sur la fiche d'un établissement. Fixé, pour que
/// deux imports successifs ne produisent pas un `studyLevels` différent —
/// un tableau réordonné est un faux changement en revue.
const LEVEL_ORDER = ['Bac+2', 'Bachelor', 'Master', 'Doctorat'] as const;

function programName(program: EefProgramRecord): string {
  // L'intitulé Parcoursup porte déjà son préfixe (« L1 - Droit ») ; la mention
  // de master, non. On le préfixe pour que « Droit des affaires » ne se lise
  // pas comme une licence dans une liste mélangée.
  return program.cycle === 'master' ? `Master — ${program.nameFr}` : program.nameFr;
}

export function planEefImport(
  catalog: EefCatalog,
  countryId: string,
): EefImportPlan {
  const institutions: PlannedInstitution[] = [];
  const programs: PlannedProgram[] = [];

  for (const file of catalog.universities) {
    const institution = file.institution;
    const overview = institutionOverview(institution);
    const location = institutionLocation(institution);
    const levels = LEVEL_ORDER.filter((level) =>
      file.programs.some((program) => program.level === level),
    );
    institutions.push({
      id: institution.id,
      countryId,
      nameFr: institution.nameFr,
      nameEn: institution.nameEn,
      locationFr: location.fr,
      locationEn: location.en,
      overviewFr: overview.fr,
      overviewEn: overview.en,
      studyLevels: [...levels],
      tuitionLabelFr: TUITION_NOTICE.fr,
      tuitionLabelEn: TUITION_NOTICE.en,
      languageRequirementsFr: INSTITUTION_LANGUAGE_REQUIREMENTS.fr,
      languageRequirementsEn: INSTITUTION_LANGUAGE_REQUIREMENTS.en,
      // Vide, et volontairement : les dates de campagne varient par pays et
      // par procédure, elles sont SERVIES par `/config/app`, jamais figées
      // dans une ligne de catalogue qu'on ne peut plus corriger.
      intakePeriods: [],
      programIds: file.programs.map((program) => program.id),
      isPartner: false,
      isActive: false,
      institutionType: INSTITUTION_TYPE_PUBLIC_UNIVERSITY,
      uaiCode: institution.uai,
      websiteUrl: institution.websiteUrl,
      sourceUrl: institution.sourceUrl,
    });

    for (const program of file.programs) {
      const level = levelLabel(program.level);
      const duration = durationLabel(program.durationYears);
      const requirements = programRequirements(program);
      const cycle = cycleLabel(program.cycle);
      const name = programName(program);
      programs.push({
        id: program.id,
        institutionId: institution.id,
        countryId,
        fieldId: program.fieldId,
        nameFr: name,
        // Un intitulé de diplôme français est un nom propre. Le traduire
        // produirait un diplôme qui n'existe pas ; le cycle, lui, est traduit
        // et c'est lui qui porte le sens pour un lecteur anglophone.
        nameEn: name,
        levelFr: `${level.fr} — ${cycle.fr}`,
        levelEn: `${level.en} — ${cycle.en}`,
        durationFr: duration.fr,
        durationEn: duration.en,
        tuitionFr: TUITION_NOTICE.fr,
        tuitionEn: TUITION_NOTICE.en,
        languageFr: LANGUAGE_NOTICE.fr,
        languageEn: LANGUAGE_NOTICE.en,
        requirementsFr: requirements.map((line) => line.fr),
        requirementsEn: requirements.map((line) => line.en),
        teachingLanguages: ['fr'],
        procedureType: program.procedureType,
        cycle: program.cycle,
        selectivity: program.selectivity,
        formationCode: program.formationCode,
        campusCity: program.campusCity,
        frenchLevelRequired: null,
        applicationFeeEur: null,
        tuitionMinEur: null,
        isActive: false,
        sourceUrl: program.sourceUrl,
      });
    }
  }

  return {
    catalogVersion: catalog.manifest.catalogVersion,
    countryId,
    institutions,
    programs,
  };
}

export interface EefCatalogWriter {
  /**
   * Création seule. Doit renvoyer `existing` sans rien écrire quand l'id est
   * déjà pris — y compris quand la ligne existante diffère du plan.
   */
  createInstitutionIfAbsent(
    row: PlannedInstitution,
  ): Promise<'created' | 'existing'>;
  createProgramIfAbsent(row: PlannedProgram): Promise<'created' | 'existing'>;
}

export interface EefImportSummary {
  readonly catalogVersion: string;
  readonly institutionsAttempted: number;
  readonly institutionsCreated: number;
  readonly institutionsExistingNotUpdated: number;
  readonly programsAttempted: number;
  readonly programsCreated: number;
  readonly programsExistingNotUpdated: number;
}

export async function importEefCatalog(
  plan: EefImportPlan,
  writer: EefCatalogWriter,
): Promise<EefImportSummary> {
  let institutionsCreated = 0;
  let institutionsExisting = 0;
  for (const row of plan.institutions) {
    const result = await writer.createInstitutionIfAbsent(row);
    if (result === 'created') institutionsCreated += 1;
    else institutionsExisting += 1;
  }
  let programsCreated = 0;
  let programsExisting = 0;
  for (const row of plan.programs) {
    const result = await writer.createProgramIfAbsent(row);
    if (result === 'created') programsCreated += 1;
    else programsExisting += 1;
  }
  return {
    catalogVersion: plan.catalogVersion,
    institutionsAttempted: plan.institutions.length,
    institutionsCreated,
    institutionsExistingNotUpdated: institutionsExisting,
    programsAttempted: plan.programs.length,
    programsCreated,
    programsExistingNotUpdated: programsExisting,
  };
}
