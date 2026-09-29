import {
  planEefPublication,
  planEefUnpublication,
  type PublicationInstitution,
  type PublicationProgram,
} from './eef-publication.plan';

// Les règles de la publication, prouvées sur des lignes écrites à la main : pas de
// base, pas d'horloge. Chaque refus a son test, parce que chaque refus est une
// promesse faite à l'étudiant qui verra la fiche.

const INSTITUTION: PublicationInstitution = {
  id: 'eef-univ-0000001a',
  nameFr: 'Université d’Exemple',
  isActive: false,
  sourceUrl: 'https://exemple.fr/',
};

function program(
  n: number,
  overrides: Partial<PublicationProgram> = {},
): PublicationProgram {
  return {
    id: `eef-prog-${String(n).padStart(4, '0')}`,
    institutionId: INSTITUTION.id,
    nameFr: `Formation ${n}`,
    isActive: false,
    sourceUrl: `https://exemple.fr/formation/${n}`,
    procedureType: 'eef',
    fieldId: 'd01',
    ...overrides,
  };
}

const plan = (
  programs: PublicationProgram[],
  extra: {
    institution?: Partial<PublicationInstitution>;
    programIds?: string[];
  } = {},
) =>
  planEefPublication({
    institution: { ...INSTITUTION, ...extra.institution },
    programs,
    programIds: extra.programIds,
  });

describe('planEefPublication', () => {
  it('publie les formations inactives d’un établissement complet, et l’active', () => {
    const result = plan([program(2), program(1), program(3)]);

    expect(result.publishable).toBe(true);
    expect(result.programs.toPublish).toEqual([
      'eef-prog-0001',
      'eef-prog-0002',
      'eef-prog-0003',
    ]);
    expect(result.institution).toEqual({
      alreadyActive: false,
      willActivate: true,
      refusals: [],
    });
    expect(result.nothingToDo).toBeNull();
  });

  it('ne compte que les formations encore inactives, et compte les autres à part', () => {
    const result = plan([program(1), program(2, { isActive: true })]);

    expect(result.programs.toPublish).toEqual(['eef-prog-0001']);
    expect(result.programs.alreadyActive).toBe(1);
  });

  it('n’active pas un établissement déjà publié, mais publie ses nouvelles formations', () => {
    const result = plan([program(1)], { institution: { isActive: true } });

    expect(result.publishable).toBe(true);
    expect(result.institution.willActivate).toBe(false);
    expect(result.institution.alreadyActive).toBe(true);
  });

  describe('refuse l’établissement entier', () => {
    it.each([
      ['un identifiant qui ne vient pas de l’import', { id: 'omnes-1' }, 'institution_not_from_import'],
      ['une source absente', { sourceUrl: null }, 'institution_source_missing'],
      ['une source vide', { sourceUrl: '   ' }, 'institution_source_missing'],
      ['une source qui n’est pas HTTPS', { sourceUrl: 'http://exemple.fr/' }, 'institution_source_missing'],
      ['une source qui n’est pas une URL', { sourceUrl: 'exemple.fr' }, 'institution_source_missing'],
    ] as const)('pour %s', (_label, institution, refusal) => {
      const result = plan([program(1)], { institution });

      expect(result.publishable).toBe(false);
      expect(result.institution.willActivate).toBe(false);
      expect(result.institution.refusals).toContain(refusal);
      // Aucun refus d'établissement ne se traduit par une publication partielle.
      expect(result.programs.toPublish).toEqual([]);
      expect(result.nothingToDo).toBeNull();
    });
  });

  describe('refuse la formation, pas l’établissement', () => {
    it.each([
      ['sans source', { sourceUrl: null }, 'program_source_missing'],
      ['avec une source HTTP', { sourceUrl: 'http://exemple.fr/x' }, 'program_source_missing'],
      ['sans procédure', { procedureType: null }, 'program_procedure_missing'],
      ['avec une procédure vide', { procedureType: ' ' }, 'program_procedure_missing'],
      ['dans un domaine hors référentiel', { fieldId: 'computer_science' }, 'program_field_unknown'],
      ['qui ne vient pas de l’import', { id: 'partner-prog-1' }, 'program_not_from_import'],
      ['d’un autre établissement', { institutionId: 'eef-univ-autre' }, 'program_wrong_institution'],
    ] as const)('une formation %s', (_label, overrides, reason) => {
      const bad = program(2, overrides);
      const result = plan([program(1), bad]);

      expect(result.programs.toPublish).toEqual(['eef-prog-0001']);
      expect(result.programs.refused).toEqual([
        { id: bad.id, nameFr: bad.nameFr, reasons: [reason] },
      ]);
      expect(result.publishable).toBe(true);
    });

    it('cumule les raisons plutôt que de s’arrêter à la première', () => {
      const bad = program(2, { sourceUrl: null, procedureType: null, fieldId: 'zz' });
      const result = plan([bad]);

      expect(result.programs.refused[0].reasons).toEqual([
        'program_source_missing',
        'program_procedure_missing',
        'program_field_unknown',
      ]);
    });
  });

  it('ne publie pas un établissement dont aucune formation n’est publiable', () => {
    const result = plan([program(1, { procedureType: null })]);

    expect(result.publishable).toBe(false);
    expect(result.institution.willActivate).toBe(false);
    expect(result.nothingToDo).toBe('no_publishable_program');
  });

  it('ne publie pas un établissement sans aucune formation', () => {
    const result = plan([]);

    expect(result.publishable).toBe(false);
    expect(result.nothingToDo).toBe('no_publishable_program');
  });

  it('dit « déjà publié » quand tout l’est', () => {
    const result = plan([program(1, { isActive: true })], {
      institution: { isActive: true },
    });

    expect(result.publishable).toBe(false);
    expect(result.nothingToDo).toBe('already_published');
  });

  describe('avec une liste de formations demandée', () => {
    it('ne publie que celles-là', () => {
      const result = plan([program(1), program(2), program(3)], {
        programIds: ['eef-prog-0002'],
      });

      expect(result.programs.toPublish).toEqual(['eef-prog-0002']);
    });

    it('nomme un identifiant inconnu au lieu de l’ignorer', () => {
      const result = plan([program(1)], {
        programIds: ['eef-prog-0001', 'eef-prog-faute'],
      });

      expect(result.programs.toPublish).toEqual(['eef-prog-0001']);
      expect(result.programs.refused).toEqual([
        { id: 'eef-prog-faute', nameFr: null, reasons: ['program_unknown'] },
      ]);
    });

    it('refuse la formation d’un autre établissement, même demandée par son identifiant', () => {
      const other = program(9, { institutionId: 'eef-univ-autre' });
      const result = plan([other], { programIds: [other.id] });

      expect(result.programs.toPublish).toEqual([]);
      expect(result.programs.refused[0].reasons).toEqual(['program_wrong_institution']);
      expect(result.publishable).toBe(false);
    });

    it('ne compte pas deux fois un identifiant répété', () => {
      const result = plan([program(1)], {
        programIds: ['eef-prog-0001', 'eef-prog-0001'],
      });

      expect(result.programs.toPublish).toEqual(['eef-prog-0001']);
    });
  });
});

describe('planEefUnpublication', () => {
  const unplan = (
    programs: PublicationProgram[],
    extra: {
      institution?: Partial<PublicationInstitution>;
      programIds?: string[];
      saved?: number;
    } = {},
  ) =>
    planEefUnpublication({
      institution: { ...INSTITUTION, isActive: true, ...extra.institution },
      programs,
      programIds: extra.programIds,
      savedByStudents: extra.saved ?? 0,
    });

  it('retire l’établissement et toutes ses formations publiées', () => {
    const result = unplan([
      program(1, { isActive: true }),
      program(2, { isActive: true }),
      program(3, { isActive: false }),
    ]);

    expect(result.toDeactivate).toEqual(['eef-prog-0001', 'eef-prog-0002']);
    expect(result.deactivateInstitution).toBe(true);
    expect(result.nothingToDo).toBe(false);
  });

  it('avec une liste, retire ces formations et GARDE l’établissement', () => {
    const result = unplan(
      [program(1, { isActive: true }), program(2, { isActive: true })],
      { programIds: ['eef-prog-0001'] },
    );

    expect(result.toDeactivate).toEqual(['eef-prog-0001']);
    expect(result.deactivateInstitution).toBe(false);
  });

  it('annonce combien d’étudiants perdent la formation de leur liste', () => {
    expect(unplan([program(1, { isActive: true })], { saved: 7 }).savedByStudents).toBe(7);
  });

  it('refuse l’établissement qui ne vient pas de l’import, sans rien retirer', () => {
    const result = unplan([program(1, { isActive: true })], {
      institution: { id: 'omnes-1' },
    });

    expect(result.refusals).toEqual(['institution_not_from_import']);
    expect(result.toDeactivate).toEqual([]);
    expect(result.deactivateInstitution).toBe(false);
    expect(result.nothingToDo).toBe(false);
  });

  it('refuse une formation demandée qui n’est pas de l’import ou d’un autre établissement', () => {
    const foreign = program(2, { id: 'partner-prog-2', isActive: true });
    const other = program(3, { institutionId: 'eef-univ-autre', isActive: true });
    const result = unplan([foreign, other, program(1, { isActive: true })], {
      programIds: [foreign.id, other.id, 'eef-prog-0001', 'eef-prog-faute'],
    });

    expect(result.toDeactivate).toEqual(['eef-prog-0001']);
    expect(result.refused.map((r) => [r.id, r.reasons])).toEqual([
      ['eef-prog-0003', ['program_wrong_institution']],
      ['eef-prog-faute', ['program_unknown']],
      ['partner-prog-2', ['program_not_from_import']],
    ]);
  });

  it('dit qu’il n’y a rien à retirer quand rien n’est publié', () => {
    const result = unplan([program(1)], { institution: { isActive: false } });

    expect(result.toDeactivate).toEqual([]);
    expect(result.deactivateInstitution).toBe(false);
    expect(result.nothingToDo).toBe(true);
  });
});
