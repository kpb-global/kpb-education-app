// Le plan de `eef:reconcile`, sans base : ce qu'il réaligne, et surtout ce qu'il
// refuse de réécrire.
import { EEF_COPY_EDITION } from './eef-catalog.copy';
import { programRequirements1_2 } from './eef-catalog.copy-1.2';
import { planEefImport } from './eef-catalog.importer';
import { loadEefCatalog } from './eef-catalog.loader';
import { procedureExceptionOf } from './eef-catalog.normalize';
import {
  planProgramReconcile,
  RECONCILED_PROGRAM_FIELDS,
  reconciledValuesOf,
  reconcileTotals,
  type InstitutionReconcilePlan,
  type ReconcilableProgramRow,
} from './eef-catalog.reconcile';
import type { EefProgramRecord } from './eef-catalog.types';

const catalog = loadEefCatalog();

/// Ce que la simulation de production doit annoncer si personne n'a rien retouché
/// depuis l'import : 3 834 formations à réaligner dans 70 établissements, dont 57
/// changent de procédure. Mesuré le 02/10/2026 sur les fichiers versionnés.
const EXPECTED_PRODUCTION_UPDATES = 3834;
const files = catalog.universities;

/// Une ligne telle que l'import 1.2.0 l'a écrite, avant les corrections du 02/10.
function rowAsImported1_2(record: EefProgramRecord, isActive = true): ReconcilableProgramRow {
  const institution = institutionById.get(record.institutionId)!;
  const procedureType = procedureExceptionOf(record, institution) ? 'dap_blanche' : record.procedureType;
  const lines = programRequirements1_2({ ...record, procedureType });
  return {
    id: record.id,
    institutionId: record.institutionId,
    isActive,
    procedureType,
    selectivity: record.selectivity,
    requirementsFr: lines.map((line) => line.fr),
    requirementsEn: lines.map((line) => line.en),
  };
}

const all = files.flatMap((file) => file.programs);
const byId = new Map(all.map((program) => [program.id, program]));
const institutionById = new Map(files.map((file) => [file.institution.id, file.institution]));
const sciencesPoL1 = all.find(
  (p) => p.institutionId === 'eef-univ-0753431x' && p.cycle === 'licence1',
)!;
const dcg = all.find((p) => p.nameFr.startsWith('DCG - '))!;
const engineering = all.find((p) => p.cycle === 'ingenieur')!;
const master = all.find((p) => p.cycle === 'master' && !p.admissionCohort)!;

describe('eef:reconcile — le plan d’une formation', () => {
  it('suit la version du catalogue : une phrase changée est une nouvelle édition', () => {
    expect(EEF_COPY_EDITION).toBe(catalog.manifest.catalogVersion);
  });

  it('écrit exactement ce qu’`eef:import` écrirait aujourd’hui', () => {
    const plan = planEefImport(catalog, 'france');
    for (const planned of plan.programs) {
      const record = byId.get(planned.id)!;
      const values = reconciledValuesOf(record);
      expect(values.procedureType).toBe(planned.procedureType);
      expect(values.selectivity).toBe(planned.selectivity);
      expect(values.requirementsFr).toEqual(planned.requirementsFr);
      expect(values.requirementsEn).toEqual(planned.requirementsEn);
    }
  });

  it('réaligne une 1re année de Sciences Po restée telle que l’import 1.2.0 l’a écrite', () => {
    const plan = planProgramReconcile(rowAsImported1_2(sciencesPoL1), sciencesPoL1);
    expect(plan.outcome).toBe('update');
    expect(plan.edition).toBe('1.2.0');
    expect(plan.fields).toEqual(['procedureType', 'requirementsFr', 'requirementsEn']);
    expect(plan.write?.procedureType).toBe('hors_eef');
    expect(plan.write?.requirementsFr.join(' ')).toContain("Admission propre à l'établissement");
    expect(plan.write?.requirementsFr.join(' ')).not.toContain('DAP, dossier blanc');
  });

  it('réaligne le texte seul quand la procédure ne change pas', () => {
    const plan = planProgramReconcile(rowAsImported1_2(engineering), engineering);
    expect(plan.outcome).toBe('update');
    expect(plan.fields).toEqual(['requirementsFr', 'requirementsEn']);
    expect(plan.write?.procedureType).toBe('hors_eef');
  });

  it('laisse une formation déjà alignée', () => {
    const row = rowAsImported1_2(master);
    // Un master sans profil Parcoursup : aucune phrase n'a changé pour lui.
    const plan = planProgramReconcile(row, master);
    expect(plan.outcome).toBe('current');
    expect(plan.write).toBeNull();
  });

  it('ne réécrit PAS une formation retouchée dans l’admin : elle est signalée', () => {
    const row = rowAsImported1_2(dcg);
    const edited = { ...row, requirementsFr: [...row.requirementsFr.slice(0, -1), 'Ajouté à la main.'] };
    const plan = planProgramReconcile(edited, dcg);
    expect(plan.outcome).toBe('kept_edited');
    expect(plan.write).toBeNull();
    expect(plan.fields).toContain('procedureType');
  });

  it('protège aussi une procédure changée à la main sans le texte', () => {
    // La prose est celle de la DAP, la procédure dit autre chose : quelqu'un est passé.
    const row = { ...rowAsImported1_2(sciencesPoL1), procedureType: 'eef' };
    expect(planProgramReconcile(row, sciencesPoL1).outcome).toBe('kept_edited');
  });

  it('ne devine rien d’une procédure ou d’une sélectivité inconnue', () => {
    const row = rowAsImported1_2(engineering);
    expect(planProgramReconcile({ ...row, procedureType: null }, engineering).outcome).toBe('kept_edited');
    expect(planProgramReconcile({ ...row, selectivity: 'tres_selective' }, engineering).outcome).toBe(
      'kept_edited',
    );
  });

  it('signale une formation déplacée, ou absente des fichiers, sans l’écrire', () => {
    const row = rowAsImported1_2(engineering);
    expect(planProgramReconcile({ ...row, institutionId: 'eef-univ-ailleurs' }, engineering).outcome).toBe(
      'kept_moved',
    );
    expect(planProgramReconcile(row, undefined).outcome).toBe('absent_from_catalog');
  });

  it('reconnaît aussi la prose de l’édition courante écrite avec une autre procédure', () => {
    // Un import 1.3.0 d'une formation dont la règle changerait ensuite.
    const values = reconciledValuesOf({ ...dcg, procedureType: 'dap_blanche' });
    const row: ReconcilableProgramRow = {
      id: dcg.id,
      institutionId: dcg.institutionId,
      isActive: true,
      ...values,
    };
    const plan = planProgramReconcile(row, dcg);
    expect(plan.outcome).toBe('update');
    expect(plan.edition).toBe(EEF_COPY_EDITION);
  });

  it('n’écrit que les quatre champs des règles', () => {
    expect(RECONCILED_PROGRAM_FIELDS).toEqual([
      'procedureType',
      'selectivity',
      'requirementsFr',
      'requirementsEn',
    ]);
    const plan = planProgramReconcile(rowAsImported1_2(sciencesPoL1), sciencesPoL1);
    expect(Object.keys(plan.write!).sort()).toEqual([...RECONCILED_PROGRAM_FIELDS].sort());
  });
});

describe('eef:reconcile — le catalogue publié le 01/10, tel que la simulation le trouvera', () => {
  // Toutes les formations versionnées, telles que l'import 1.2.0 les a écrites. C'est
  // l'état de la production (10 029 publiées, 473 en attente) si personne n'a rien
  // retouché : la simulation de production doit annoncer ces nombres-là, et un écart
  // se lit dans ses lignes « signalées ».
  const plans: InstitutionReconcilePlan[] = files.map((file) => ({
    institutionId: file.institution.id,
    institutionName: file.institution.nameFr,
    programs: file.programs.map((record) => planProgramReconcile(rowAsImported1_2(record), record)),
  }));
  const totals = reconcileTotals(plans);

  it('ne signale rien quand rien n’a été retouché', () => {
    expect(totals.programsExamined).toBe(10502);
    expect(totals.programsKeptEdited).toBe(0);
    expect(totals.programsKeptMoved).toBe(0);
    expect(totals.programsAbsentFromCatalog).toBe(0);
    expect(totals.byEdition).toEqual({ '1.2.0': totals.programsToUpdate });
  });

  it('change la procédure des 57 formations décidées le 02/10, et d’elles seules', () => {
    expect(totals.procedureTransitions).toEqual({
      'dap_blanche→hors_eef': 39,
      'dap_blanche→parcoursup': 1,
      'dap_blanche→eef': 17,
    });
    expect(totals.byField.procedureType).toBe(57);
    expect(totals.institutionsToUpdate).toBe(70);
    expect(totals.byField.selectivity).toBe(0);
  });

  it('réécrit le texte des L1 non sélectives en DAP, des formations hors procédure et des repères', () => {
    const touched = new Set<string>();
    for (const file of files) {
      for (const record of file.programs) {
        const dapNonSelective =
          record.selectivity === 'non_selective'
          && (record.procedureType === 'dap_blanche' || record.procedureType === 'dap_jaune');
        if (
          dapNonSelective
          // Un profil à zéro admis garde la phrase « aucun seuil vérifiable », inchangée.
          || (record.admissionCohort?.admittedNeobac ?? 0) > 0
          || record.procedureType === 'hors_eef'
          || procedureExceptionOf(record, file.institution)
        ) {
          touched.add(record.id);
        }
      }
    }
    expect(totals.programsToUpdate).toBe(touched.size);
    expect(totals.byField.requirementsFr).toBe(touched.size);
    expect(totals.byField.requirementsEn).toBe(touched.size);
    // Le nombre que la simulation de production doit annoncer si rien n'a été retouché.
    expect(totals.programsToUpdate).toBe(EXPECTED_PRODUCTION_UPDATES);
  });

  it('est idempotente : une fois écrite, une seconde passe ne trouve plus rien', () => {
    const after: InstitutionReconcilePlan[] = plans.map((plan) => ({
      ...plan,
      programs: plan.programs.map((program) => {
        const record = byId.get(program.id)!;
        const row: ReconcilableProgramRow = program.write
          ? { ...program.before, ...program.write }
          : program.before;
        return planProgramReconcile(row, record);
      }),
    }));
    const second = reconcileTotals(after);
    expect(second.programsToUpdate).toBe(0);
    expect(second.programsCurrent).toBe(10502);
  });
});
