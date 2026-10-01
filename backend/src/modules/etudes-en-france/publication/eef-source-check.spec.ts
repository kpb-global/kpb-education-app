import { readFileSync } from 'node:fs';

import { loadEefCatalog } from '../catalog/eef-catalog.loader';
import { classifyProgramSource } from './eef-publication.plan';
import {
  assertSourceCheckUsable,
  checkedScope,
  deadProgramIds,
  EEF_SOURCE_CHECK_FILE,
  loadSourceCheckReport,
  MAX_UNCERTAIN_SHARE,
  MIN_OK_SHARE,
  parseSourceCheckReport,
  redirectedToHome,
  scopeDigest,
  sourceVerdict,
  type SourceCheckReport,
  type SourceObservation,
} from './eef-source-check';

const ok: SourceObservation = { status: 200, redirectedToHome: false };
const gone: SourceObservation = { status: 404, redirectedToHome: false };
const home: SourceObservation = { status: 200, redirectedToHome: true };

describe('sourceVerdict — une page n’est « morte » que sur deux constats concordants', () => {
  it('un seul passage ne condamne jamais', () => {
    expect(sourceVerdict([gone])).toBe('uncertain');
    expect(sourceVerdict([{ status: 410, redirectedToHome: false }])).toBe('uncertain');
  });

  it('deux 404/410 concordants condamnent', () => {
    expect(sourceVerdict([gone, gone])).toBe('dead');
    expect(sourceVerdict([gone, { status: 410, redirectedToHome: false }])).toBe('dead');
  });

  it('une page qui répond une fois existe : la panne de l’autre passage ne condamne pas', () => {
    expect(sourceVerdict([gone, ok])).toBe('ok');
    expect(sourceVerdict([ok, gone])).toBe('ok');
  });

  it('une redirection vers l’accueil compte comme une disparition, pas comme un succès', () => {
    expect(sourceVerdict([home])).toBe('uncertain');
    expect(sourceVerdict([home, home])).toBe('dead');
    expect(sourceVerdict([gone, home])).toBe('dead');
  });

  it.each([403, 429, 500, 503, 0])(
    'le statut %i ne prouve pas la disparition, même constaté deux fois',
    (status) => {
      const flaky: SourceObservation = { status, redirectedToHome: false };
      expect(sourceVerdict([flaky, flaky])).toBe('uncertain');
      expect(sourceVerdict([gone, flaky])).toBe('uncertain');
    },
  );

  it('aucune observation : incertaine, jamais morte', () => {
    expect(sourceVerdict([])).toBe('uncertain');
  });
});

describe('redirectedToHome', () => {
  it('reconnaît une fiche profonde renvoyée à la racine du même site', () => {
    expect(
      redirectedToHome('https://www.univ-x.fr/formations/master-y', 'https://www.univ-x.fr/'),
    ).toBe(true);
    expect(
      redirectedToHome('https://www.univ-x.fr/formations/master-y', 'https://www.univ-x.fr/fr/'),
    ).toBe(true);
    expect(
      redirectedToHome('https://univ-x.fr/a/b', 'https://www.univ-x.fr/index.html'),
    ).toBe(true);
  });

  it.each([
    ['https://www.univ-x.fr/formations/master-y', 'https://www.univ-x.fr/?lang=fr'],
    ['https://www.univ-x.fr/formations/master-y', 'https://www.univ-x.fr/accueil/'],
    ['https://www.univ-x.fr/formations/master-y', 'https://www.univ-x.fr/fr/home/'],
    ['https://www.univ-x.fr/formations/master-y', 'https://www.univ-x.fr/home'],
    // un sous-domaine de formations renvoyé à la racine du site principal
    ['https://formations.univ-x.fr/p/123', 'https://www.univ-x.fr/'],
  ])('reconnaît le renvoi à l’accueil : %s → %s', (from, to) => {
    expect(redirectedToHome(from, to)).toBe(true);
  });

  it('une requête qui ne choisit pas la langue n’est pas un accueil', () => {
    expect(
      redirectedToHome('https://www.univ-x.fr/a/b', 'https://www.univ-x.fr/?id=42'),
    ).toBe(false);
  });

  it('ne confond pas une page réelle avec l’accueil', () => {
    expect(
      redirectedToHome(
        'https://www.univ-x.fr/formations/master-y',
        'https://www.univ-x.fr/formations/master-y-2026',
      ),
    ).toBe(false);
    // Une page demandée avec une requête n'est pas « une racine » : on ne devine pas.
    expect(
      redirectedToHome('https://www.univ-x.fr/a?id=3', 'https://www.univ-x.fr/a?id=3'),
    ).toBe(false);
  });

  it('une redirection vers un AUTRE site n’est pas un retour à l’accueil', () => {
    expect(
      redirectedToHome('https://www.univ-x.fr/a/b', 'https://www.univ-y.fr/'),
    ).toBe(false);
  });

  it('une adresse qui demandait déjà la racine n’est pas « redirigée vers l’accueil »', () => {
    expect(redirectedToHome('https://www.univ-x.fr/', 'https://www.univ-x.fr/')).toBe(false);
  });

  it('une adresse illisible ne lève pas', () => {
    expect(redirectedToHome('pas une url', 'https://x.fr/')).toBe(false);
  });
});

describe('parseSourceCheckReport — un rapport tronqué ne doit pas se lire « rien à écarter »', () => {
  const valid = {
    checkedAt: '2026-10-01T18:00:00.000Z',
    method: 'GET',
    scope: 'full',
    scopeDigest: 'a'.repeat(64),
    totals: { programsChecked: 3, urlsChecked: 2, ok: 1, dead: 1, uncertain: 0 },
    dead: [
      {
        programId: 'eef-prog-1',
        institutionId: 'eef-univ-1',
        url: 'https://u.fr/a',
        status: 404,
        passes: 2,
        redirectedToHome: false,
      },
    ],
    uncertain: [],
  };

  it('accepte un rapport complet', () => {
    expect(parseSourceCheckReport(valid).dead).toHaveLength(1);
    expect(deadProgramIds(parseSourceCheckReport(valid))).toEqual(new Set(['eef-prog-1']));
  });

  it.each([
    ['null', null],
    ['sans date', { ...valid, checkedAt: undefined }],
    ['date illisible', { ...valid, checkedAt: 'hier' }],
    ['sans totaux', { ...valid, totals: undefined }],
    ['totaux incomplets', { ...valid, totals: { programsChecked: 1 } }],
    ['liste morte absente', { ...valid, dead: undefined }],
    ['entrée sans identifiant', { ...valid, dead: [{ url: 'https://u.fr/a' }] }],
    ['morts annoncées, aucune listée', { ...valid, dead: [] }],
    ['portée inconnue', { ...valid, scope: 'tout' }],
    ['empreinte absente', { ...valid, scopeDigest: undefined }],
    ['empreinte illisible', { ...valid, scopeDigest: 'abc' }],
  ])('refuse : %s', (_label, raw) => {
    expect(() => parseSourceCheckReport(raw)).toThrow();
  });
});

describe('le rapport versionné', () => {
  const report = loadSourceCheckReport();
  const catalog = loadEefCatalog();
  const byId = new Map(
    catalog.universities.flatMap((university) =>
      university.programs.map((program) => [program.id, program] as const),
    ),
  );

  it('est le fichier que la publication déléguée lira', () => {
    expect(EEF_SOURCE_CHECK_FILE.endsWith('publication/data/source-check.json')).toBe(true);
    expect(JSON.parse(readFileSync(EEF_SOURCE_CHECK_FILE, 'utf8'))).toBeTruthy();
  });

  it('ne cite que des formations qui existent encore dans le catalogue, avec la même source', () => {
    // Si le catalogue est régénéré (identifiants ou adresses qui changent), le
    // rapport devient faux : il faut le refaire, pas le publier tel quel.
    for (const entry of [...report.dead, ...report.uncertain]) {
      const program = byId.get(entry.programId);
      expect(program).toBeDefined();
      expect(program?.sourceUrl).toBe(entry.url);
      expect(program?.institutionId).toBe(entry.institutionId);
    }
  });

  it('ne contrôle que des pages d’établissement, jamais un portail qui répond toujours', () => {
    for (const entry of [...report.dead, ...report.uncertain]) {
      expect(classifyProgramSource(entry.url)).toBe('formation_page');
      expect(new URL(entry.url).hostname).not.toBe('dossierappel.parcoursup.fr');
    }
  });

  it('est un contrôle COMPLET, à l’empreinte du catalogue actuel, et digne de décider', () => {
    // Si le catalogue est régénéré (formation ajoutée, adresse changée), l'empreinte ne
    // correspond plus : le rapport est périmé même si chaque entrée citée existe.
    expect(report.scope).toBe('full');
    expect(report.scopeDigest).toBe(scopeDigest(checkedScope(catalog)));
    expect(report.totals.programsChecked).toBe(checkedScope(catalog).length);
    expect(() => assertSourceCheckUsable(report, catalog)).not.toThrow();
  });

  it('une formation n’est jamais à la fois morte et incertaine', () => {
    const dead = deadProgramIds(report);
    for (const entry of report.uncertain) expect(dead.has(entry.programId)).toBe(false);
  });

  it('le total des morts annoncé correspond à des formations listées', () => {
    expect(report.dead.length > 0).toBe(report.totals.dead > 0);
    expect(report.totals.programsChecked).toBeGreaterThan(0);
  });
});

describe('assertSourceCheckUsable — un rapport bien formé n’est pas forcément un rapport juste', () => {
  const catalog = loadEefCatalog();
  const base = loadSourceCheckReport();
  const with_ = (over: Omit<Partial<SourceCheckReport>, 'totals'> & { totals?: Partial<SourceCheckReport['totals']> }): SourceCheckReport => ({
    ...base,
    ...over,
    totals: { ...base.totals, ...(over.totals ?? {}) },
  });

  it('refuse un essai partiel, même récent', () => {
    expect(() => assertSourceCheckUsable(with_({ scope: 'partial' }), catalog)).toThrow(/partiel/);
  });

  it('refuse un rapport dont l’empreinte n’est plus celle du catalogue', () => {
    expect(() =>
      assertSourceCheckUsable(with_({ scopeDigest: '0'.repeat(64) }), catalog),
    ).toThrow(/catalogue a changé/);
  });

  it('refuse le rapport d’un sondage en panne : 0 valide, 0 morte, tout incertain', () => {
    // Le cas relevé en relecture : réseau coupé → fichier frais, valide, et qui n'écarte rien.
    const dead = with_({
      dead: [],
      uncertain: [],
      totals: { ok: 0, dead: 0, uncertain: base.totals.urlsChecked },
    });
    expect(() => assertSourceCheckUsable(dead, catalog)).toThrow(/en panne/);
  });

  it('refuse un sondage trop incomplet, même avec des pages valides', () => {
    const urls = base.totals.urlsChecked;
    const ok = Math.ceil(urls * MIN_OK_SHARE) + 5;
    const uncertain = Math.ceil(urls * MAX_UNCERTAIN_SHARE) + 5;
    expect(() =>
      assertSourceCheckUsable(with_({ totals: { ok, uncertain, dead: urls - ok - uncertain } }), catalog),
    ).toThrow(/incertaine/);
  });

  it('accepte le rapport versionné', () => {
    expect(() => assertSourceCheckUsable(base, catalog)).not.toThrow();
  });
});

describe('scopeDigest', () => {
  it('change dès qu’une adresse ou une formation change, pas avec l’ordre', () => {
    const a = { programId: 'eef-prog-1', institutionId: 'eef-univ-1', url: 'https://u.fr/a' };
    const b = { programId: 'eef-prog-2', institutionId: 'eef-univ-1', url: 'https://u.fr/b' };
    expect(scopeDigest([a, b])).toBe(scopeDigest([b, a]));
    expect(scopeDigest([a, b])).not.toBe(scopeDigest([a]));
    expect(scopeDigest([a, b])).not.toBe(scopeDigest([a, { ...b, url: 'https://u.fr/c' }]));
  });
});
