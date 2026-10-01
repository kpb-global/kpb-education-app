import type { AdminSessionUser } from '../../auth/auth.service';
import {
  delegatedVerifier,
  pickVerifier,
  runDelegatedPublication,
  type AdminCandidate,
  type PublishingService,
} from './eef-delegated-publication';
import type {
  InstitutionRefusal,
  ProgramRefusal,
  PublicationPlan,
} from './eef-publication.plan';
import type { PublishResult } from './eef-publication.service';

const admin: AdminSessionUser = {
  id: 'adm-1',
  fullName: 'Aminou Test',
  email: 'owner@kpb.test',
  role: 'super_admin',
  languageScope: [],
};

function plan(over: {
  id: string;
  name?: string;
  toPublish?: string[];
  refused?: Array<{ id: string; reasons: ProgramRefusal[] }>;
  institutionRefusals?: InstitutionRefusal[];
  alreadyActive?: boolean;
}): PublicationPlan {
  const toPublish = over.toPublish ?? [];
  const institutionRefusals = over.institutionRefusals ?? [];
  const publishable = institutionRefusals.length === 0 && toPublish.length > 0;
  return {
    institutionId: over.id,
    institutionName: over.name ?? over.id,
    institution: {
      alreadyActive: over.alreadyActive ?? false,
      willActivate: publishable && !over.alreadyActive,
      refusals: institutionRefusals,
    },
    programs: {
      toPublish: institutionRefusals.length > 0 ? [] : toPublish,
      alreadyActive: 0,
      refused: (over.refused ?? []).map((r) => ({
        id: r.id,
        nameFr: r.id,
        reasons: r.reasons,
      })),
      activeInvalid: [],
      genericSource: { ministryPortal: 0, ministryDataset: 0 },
    },
    publishable,
    nothingToDo: publishable ? null : 'no_publishable_program',
  };
}

type Call = {
  id: string;
  apply: boolean;
  programIds?: readonly string[];
  expectedPrograms?: number;
  verifier: AdminSessionUser;
};

/** Un service qui rejoue des plans, et note tout ce qu'on lui demande. */
function fakeService(plans: Record<string, PublicationPlan>, fail: Set<string> = new Set()) {
  const calls: Call[] = [];
  const service: PublishingService = {
    publish: async (id, options): Promise<PublishResult> => {
      calls.push({
        id,
        apply: options.apply,
        programIds: options.programIds,
        expectedPrograms: options.expectedPrograms,
        verifier: options.verifier,
      });
      const base = plans[id];
      if (!base) throw new Error(`Établissement inconnu : ${id}.`);
      // Le plan RESTREINT aux formations demandées, comme le vrai service.
      const wanted = options.programIds
        ? base.programs.toPublish.filter((p) => options.programIds?.includes(p))
        : base.programs.toPublish;
      const restricted: PublicationPlan = {
        ...base,
        programs: { ...base.programs, toPublish: wanted },
        publishable: base.institution.refusals.length === 0 && wanted.length > 0,
        institution: {
          ...base.institution,
          willActivate: base.institution.refusals.length === 0 && wanted.length > 0 && !base.institution.alreadyActive,
        },
      };
      if (!options.apply) return { mode: 'dry-run', plan: restricted };
      if (fail.has(id)) throw new Error('Une formation a changé pendant la publication');
      return {
        mode: 'applied',
        plan: restricted,
        institutionActivated: restricted.institution.willActivate,
        programsPublished: wanted.length,
        verifiedBy: { id: options.verifier.id, name: options.verifier.fullName },
        verifiedAt: '2026-10-01T00:00:00.000Z',
      };
    },
  };
  return { service, calls };
}

describe('runDelegatedPublication', () => {
  const plans = {
    'eef-univ-a': plan({ id: 'eef-univ-a', name: 'Univ A', toPublish: ['eef-prog-1', 'eef-prog-2', 'eef-prog-3'] }),
    'eef-univ-b': plan({
      id: 'eef-univ-b',
      name: 'Univ B',
      toPublish: ['eef-prog-4'],
      refused: [{ id: 'eef-prog-9', reasons: ['program_source_missing', 'program_procedure_missing'] }],
    }),
    'eef-univ-c': plan({ id: 'eef-univ-c', name: 'Univ C', institutionRefusals: ['institution_source_missing'], toPublish: ['eef-prog-5'] }),
  };

  it('une simulation n’écrit jamais, même avec un relecteur et une liste complète', async () => {
    const { service, calls } = fakeService(plans);
    const report = await runDelegatedPublication({
      service,
      institutionIds: Object.keys(plans),
      holdback: new Set(),
      apply: false,
      verifier: admin,
    });
    expect(report.mode).toBe('dry-run');
    expect(calls.every((call) => call.apply === false)).toBe(true);
    expect(report.totals.programsPublished).toBe(4);
  });

  it('la liste d’attente n’est JAMAIS transmise au service, ni en simulation ni en écriture', async () => {
    const { service, calls } = fakeService(plans);
    await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-a'],
      holdback: new Set(['eef-prog-2']),
      apply: true,
      verifier: admin,
    });
    const asked = calls.flatMap((call) => call.programIds ?? []);
    expect(asked).toContain('eef-prog-1');
    expect(asked).toContain('eef-prog-3');
    expect(asked).not.toContain('eef-prog-2');
  });

  it('l’écriture demande au service exactement le nombre qu’elle vient de planifier', async () => {
    const { service, calls } = fakeService(plans);
    const report = await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-a'],
      holdback: new Set(['eef-prog-2']),
      apply: true,
      verifier: admin,
    });
    const write = calls.find((call) => call.apply);
    expect(write?.programIds).toEqual(['eef-prog-1', 'eef-prog-3']);
    expect(write?.expectedPrograms).toBe(2);
    expect(report.totals.programsPublished).toBe(2);
    expect(report.totals.programsHeldBack).toBe(1);
    expect(report.institutions[0].institutionActivated).toBe(true);
  });

  it('un établissement refusé par le plan n’est pas écrit, et son motif est dit', async () => {
    const { service, calls } = fakeService(plans);
    const report = await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-c'],
      holdback: new Set(),
      apply: true,
      verifier: admin,
    });
    expect(calls.some((call) => call.apply)).toBe(false);
    expect(report.institutions[0].outcome).toBe('refused');
    expect(report.institutions[0].refusals).toEqual(['institution_source_missing']);
    expect(report.totals.institutionsRefused).toBe(1);
  });

  it('compte les refus du plan par motif, sans les publier', async () => {
    const { service } = fakeService(plans);
    const report = await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-b'],
      holdback: new Set(),
      apply: false,
      verifier: admin,
    });
    expect(report.totals.refusedByReason).toEqual({
      program_source_missing: 1,
      program_procedure_missing: 1,
    });
    expect(report.totals.programsRefused).toBe(1);
  });

  it('si tout est en attente, rien n’est écrit pour cet établissement', async () => {
    const { service, calls } = fakeService(plans);
    const report = await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-b'],
      holdback: new Set(['eef-prog-4']),
      apply: true,
      verifier: admin,
    });
    expect(calls.some((call) => call.apply)).toBe(false);
    expect(report.institutions[0].outcome).toBe('nothing');
    expect(report.institutions[0].programsHeldBack).toBe(1);
  });

  it('l’échec d’un établissement n’arrête pas les autres, et se lit dans le code de sortie', async () => {
    const { service } = fakeService(plans, new Set(['eef-univ-a']));
    const report = await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-a', 'eef-univ-b'],
      holdback: new Set(),
      apply: true,
      verifier: admin,
    });
    expect(report.institutions.map((r) => r.outcome)).toEqual(['failed', 'published']);
    expect(report.institutions[0].error).toMatch(/a changé/);
    expect(report.hasFailures).toBe(true);
    expect(report.totals.programsPublished).toBe(1);
  });

  it('un établissement inconnu est un échec nommé, pas un oubli silencieux', async () => {
    const { service } = fakeService(plans);
    const report = await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-zzz'],
      holdback: new Set(),
      apply: false,
      verifier: admin,
    });
    expect(report.institutions[0].outcome).toBe('failed');
    expect(report.hasFailures).toBe(true);
  });

  it('transmet au service le relecteur annoté, pas un identifiant fabriqué', async () => {
    const { service, calls } = fakeService(plans);
    const verifier = delegatedVerifier(admin, 'aminou-gh');
    await runDelegatedPublication({
      service,
      institutionIds: ['eef-univ-a'],
      holdback: new Set(),
      apply: true,
      verifier,
    });
    expect(calls.every((call) => call.verifier.id === 'adm-1')).toBe(true);
  });

  it('journalise une ligne par établissement', async () => {
    const { service } = fakeService(plans);
    const lines: string[] = [];
    await runDelegatedPublication({
      service,
      institutionIds: Object.keys(plans),
      holdback: new Set(['eef-prog-2']),
      apply: false,
      verifier: admin,
      log: (line) => lines.push(line),
    });
    expect(lines).toHaveLength(3);
    expect(lines[0]).toContain('Univ A');
    expect(lines[0]).toContain('en attente');
    expect(lines[2]).toContain('refusé');
  });
});

describe('delegatedVerifier — le tampon ne laisse pas croire à une relecture une à une', () => {
  it('nomme la délégation et la personne qui a lancé l’opération', () => {
    const verifier = delegatedVerifier(admin, 'aminou-gh');
    expect(verifier.fullName).toBe('Aminou Test (publication déléguée · lancée par aminou-gh)');
    expect(verifier.id).toBe(admin.id);
  });

  it('sans lanceur connu, garde la mention de délégation', () => {
    expect(delegatedVerifier(admin, null).fullName).toBe('Aminou Test (publication déléguée)');
    expect(delegatedVerifier(admin, '  ').fullName).toBe('Aminou Test (publication déléguée)');
  });

  it('retombe sur l’e-mail quand le nom est vide', () => {
    expect(delegatedVerifier({ ...admin, fullName: '  ' }, null).fullName).toBe(
      'owner@kpb.test (publication déléguée)',
    );
  });
});

describe('pickVerifier', () => {
  const candidate = (over: Partial<AdminCandidate>): AdminCandidate => ({
    id: 'x',
    fullName: 'X',
    email: 'x@kpb.test',
    role: 'admin',
    isActive: true,
    languageScope: [],
    ...over,
  });

  it('avec un e-mail : ce compte, sans tenir compte de la casse', () => {
    const picked = pickVerifier(
      [candidate({ id: 'a', email: 'A@kpb.test' }), candidate({ id: 'b', email: 'b@kpb.test' })],
      '  a@KPB.test ',
    );
    expect(picked.id).toBe('a');
  });

  it('refuse un compte inactif, ou un rôle qui ne signe pas la publication', () => {
    expect(() => pickVerifier([candidate({ isActive: false })], 'x@kpb.test')).toThrow();
    expect(() => pickVerifier([candidate({ role: 'content_manager' })], 'x@kpb.test')).toThrow();
    expect(() => pickVerifier([candidate({ role: 'counselor' })], 'x@kpb.test')).toThrow();
  });

  it('refuse un e-mail inconnu sans le recopier, et liste les comptes éligibles masqués', () => {
    try {
      pickVerifier([candidate({ email: 'prenom@kpb.test' })], 'inconnu@kpb.test');
      throw new Error('devait refuser');
    } catch (error) {
      const message = (error as Error).message;
      expect(message).not.toContain('inconnu@kpb.test');
      expect(message).not.toContain('prenom@kpb.test');
      expect(message).toContain('p***@kpb.test (admin)');
    }
  });

  it('sans e-mail : le seul super_admin actif', () => {
    const picked = pickVerifier(
      [candidate({ id: 'adm', role: 'admin' }), candidate({ id: 'boss', role: 'super_admin', email: 'boss@kpb.test' })],
      null,
    );
    expect(picked.id).toBe('boss');
  });

  it('sans e-mail, sans super_admin : le seul compte admin actif', () => {
    const picked = pickVerifier(
      [candidate({ id: 'solo', role: 'admin' }), candidate({ id: 'off', isActive: false, email: 'off@kpb.test' }), candidate({ id: 'cm', role: 'content_manager', email: 'cm@kpb.test' })],
      null,
    );
    expect(picked.id).toBe('solo');
  });

  it('sans e-mail et deux super_admin : refuse de deviner', () => {
    expect(() =>
      pickVerifier(
        [candidate({ id: 'a', role: 'super_admin' }), candidate({ id: 'b', role: 'super_admin', email: 'b@kpb.test' })],
        null,
      ),
    ).toThrow(/précisez/);
  });

  it('sans e-mail, sans super_admin et deux admin : refuse, et nomme les deux masqués', () => {
    try {
      pickVerifier(
        [candidate({ id: 'a', email: 'alice@kpb.test' }), candidate({ id: 'b', email: 'bob@kpb.test' })],
        null,
      );
      throw new Error('devait refuser');
    } catch (error) {
      const message = (error as Error).message;
      expect(message).toContain('a***@kpb.test (admin)');
      expect(message).toContain('b***@kpb.test (admin)');
      expect(message).not.toContain('alice@');
    }
  });

  it('sans e-mail et aucun compte éligible : refuse', () => {
    expect(() => pickVerifier([candidate({ role: 'content_manager' })], null)).toThrow();
    expect(() => pickVerifier([], null)).toThrow();
  });

  it('un e-mail porté par deux comptes éligibles est refusé, pas choisi au hasard', () => {
    expect(() =>
      pickVerifier([candidate({ id: 'a' }), candidate({ id: 'b' })], 'x@kpb.test'),
    ).toThrow();
  });
});
