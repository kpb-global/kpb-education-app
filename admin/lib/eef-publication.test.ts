import { describe, expect, it } from 'vitest';

import {
  applyBody,
  canApply,
  genericSourceCount,
  plannedCount,
  readableApiError,
  refusalMessageKey,
  simulationBody,
  type PublicationPlan,
  type UnpublicationPlan,
} from './eef-publication';

const plan = (over: Partial<PublicationPlan> = {}): PublicationPlan => ({
  institutionId: 'eef-univ-1',
  institutionName: 'Université',
  institution: { alreadyActive: false, willActivate: true, refusals: [] },
  programs: {
    toPublish: ['a', 'b', 'c'],
    alreadyActive: 0,
    refused: [],
    genericSource: { ministryPortal: 0, ministryDataset: 0 },
  },
  publishable: true,
  nothingToDo: null,
  ...over,
});

const removal = (over: Partial<UnpublicationPlan> = {}): UnpublicationPlan => ({
  institutionId: 'eef-univ-1',
  institutionName: 'Université',
  deactivateInstitution: true,
  toDeactivate: ['a', 'b'],
  refused: [],
  savedByStudents: 0,
  refusals: [],
  nothingToDo: false,
  ...over,
});

describe('simulationBody', () => {
  it('n’écrit jamais : pas de `apply`', () => {
    expect(simulationBody()).toEqual({});
    expect(simulationBody([])).toEqual({});
    expect('apply' in simulationBody(['x'])).toBe(false);
  });

  it('transmet les formations choisies', () => {
    expect(simulationBody(['x', 'y'])).toEqual({ programIds: ['x', 'y'] });
  });
});

describe('applyBody', () => {
  it('confirme le nombre AFFICHÉ, pour une publication', () => {
    expect(applyBody('publish', plan())).toEqual({ apply: true, expectedPrograms: 3 });
  });

  it('confirme le nombre affiché, pour un retrait', () => {
    expect(applyBody('unpublish', removal())).toEqual({ apply: true, expectedPrograms: 2 });
  });

  it('garde la liste de formations de la simulation', () => {
    expect(applyBody('publish', plan(), ['a'])).toEqual({
      apply: true,
      expectedPrograms: 3,
      programIds: ['a'],
    });
  });
});

describe('canApply', () => {
  it('suit `publishable` pour une publication', () => {
    expect(canApply('publish', plan())).toBe(true);
    expect(canApply('publish', plan({ publishable: false }))).toBe(false);
  });

  it('refuse un retrait sans rien à retirer ou d’un établissement refusé', () => {
    expect(canApply('unpublish', removal())).toBe(true);
    expect(canApply('unpublish', removal({ nothingToDo: true }))).toBe(false);
    expect(canApply('unpublish', removal({ refusals: ['institution_not_from_import'] }))).toBe(false);
  });
});

describe('genericSourceCount', () => {
  it('additionne les deux familles de sources génériques', () => {
    const generic = plan({
      programs: {
        toPublish: ['a', 'b', 'c'],
        alreadyActive: 0,
        refused: [],
        genericSource: { ministryPortal: 2, ministryDataset: 1 },
      },
    });
    expect(genericSourceCount(generic)).toBe(3);
    expect(genericSourceCount(plan())).toBe(0);
  });
});

describe('plannedCount', () => {
  it('compte les formations du bon côté du plan', () => {
    expect(plannedCount('publish', plan())).toBe(3);
    expect(plannedCount('unpublish', removal())).toBe(2);
  });
});

describe('readableApiError', () => {
  it('extrait le message d’une erreur JSON du serveur', () => {
    const error = new Error(JSON.stringify({ message: 'Relancez la simulation.', statusCode: 409 }));
    expect(readableApiError(error, 'x')).toBe('Relancez la simulation.');
  });

  it('joint les erreurs de validation', () => {
    const error = new Error(JSON.stringify({ message: ['a est invalide', 'b est requis'] }));
    expect(readableApiError(error, 'x')).toBe('a est invalide b est requis');
  });

  it('rend un texte qui n’est pas du JSON tel quel', () => {
    expect(readableApiError(new Error('Unauthorized'), 'x')).toBe('Unauthorized');
  });

  it('retombe sur le repli sans message ou sans erreur', () => {
    expect(readableApiError(new Error(''), 'repli')).toBe('repli');
    expect(readableApiError('boom', 'repli')).toBe('repli');
    expect(readableApiError(undefined, 'repli')).toBe('repli');
  });
});

describe('refusalMessageKey', () => {
  it('range chaque motif sous eefPub.reason', () => {
    expect(refusalMessageKey('program_source_missing')).toBe('eefPub.reason.program_source_missing');
  });
});
