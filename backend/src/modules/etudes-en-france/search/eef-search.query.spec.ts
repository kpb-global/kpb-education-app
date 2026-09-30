import { isDeepStrictEqual } from 'node:util';

import { eefProgramWhere } from '../../../common/eef-provenance';
import {
  EEF_SEARCH_DEFAULT_LIMIT,
  EEF_SEARCH_FACETS,
  EEF_SEARCH_MAX_FILTER_VALUES,
  EEF_SEARCH_MAX_LIMIT,
  EEF_SEARCH_MAX_TERMS,
  EefSearchCursorError,
  EefSearchParamError,
  buildEefSearchWhere,
  decodeEefCursor,
  encodeEefCursor,
  isRestricted,
  parseEefSearchInput,
  type EefSearchParams,
} from './eef-search.query';

describe('parseEefSearchInput', () => {
  it('borne la taille de page sans la laisser à zéro', () => {
    expect(parseEefSearchInput({}).limit).toBe(EEF_SEARCH_DEFAULT_LIMIT);
    expect(parseEefSearchInput({ limit: '500' }).limit).toBe(EEF_SEARCH_MAX_LIMIT);
    expect(parseEefSearchInput({ limit: '0' }).limit).toBe(EEF_SEARCH_DEFAULT_LIMIT);
    expect(parseEefSearchInput({ limit: '-5' }).limit).toBe(EEF_SEARCH_DEFAULT_LIMIT);
    expect(parseEefSearchInput({ limit: 'beaucoup' }).limit).toBe(
      EEF_SEARCH_DEFAULT_LIMIT,
    );
    expect(parseEefSearchInput({ limit: '5' }).limit).toBe(5);
  });

  it('découpe la recherche libre en mots, et en borne le nombre', () => {
    expect(parseEefSearchInput({ q: '  droit   rennes ' }).terms).toEqual([
      'droit',
      'rennes',
    ]);
    const many = Array.from({ length: 20 }, (_, i) => `m${i}`).join(' ');
    expect(parseEefSearchInput({ q: many }).terms).toHaveLength(
      EEF_SEARCH_MAX_TERMS,
    );
  });

  it('déduplique les valeurs d’une facette', () => {
    expect(
      parseEefSearchInput({ procedureType: 'eef,eef, dap_blanche ,eef' })
        .procedureTypes,
    ).toEqual(['eef', 'dap_blanche']);
  });

  it('refuse une valeur hors référentiel, en nommant les valeurs admises', () => {
    // Ignorer silencieusement ferait afficher au client des compteurs qui ne
    // correspondent pas à ce qu'il croit avoir demandé.
    expect(() => parseEefSearchInput({ procedureType: 'campusfrance' })).toThrow(
      EefSearchParamError,
    );
    try {
      parseEefSearchInput({ cycle: 'doctorat' });
      throw new Error('aurait dû lever');
    } catch (error) {
      expect((error as Error).message).toContain('cycle');
      expect((error as Error).message).toContain('master');
    }
    expect(() => parseEefSearchInput({ fieldId: 'd99' })).toThrow(
      EefSearchParamError,
    );
    expect(() => parseEefSearchInput({ selectivity: 'peut-être' })).toThrow(
      EefSearchParamError,
    );
  });

  it('refuse une liste `IN` sans borne', () => {
    // Fabricable avec une simple URL, et Postgres la planifierait.
    const tooMany = Array.from(
      { length: EEF_SEARCH_MAX_FILTER_VALUES + 1 },
      (_, i) => `inst-${i}`,
    ).join(',');
    expect(() => parseEefSearchInput({ institutionId: tooMany })).toThrow(
      EefSearchParamError,
    );
  });

  it('laisse passer un identifiant d’établissement inconnu', () => {
    // Il vient du catalogue, pas d'un référentiel fermé : zéro résultat est la
    // bonne réponse, pas une erreur.
    expect(
      parseEefSearchInput({ institutionId: 'eef-univ-inexistante' }).institutionIds,
    ).toEqual(['eef-univ-inexistante']);
  });
});

describe('paramètres répétés — la forme qu\u2019Express livre vraiment', () => {
  // Régression : `?cycle=master&cycle=licence1` arrive en TABLEAU, `.split()`
  // levait un TypeError non attrapé, et une requête publique parfaitement
  // licite rendait 500 au lieu de 400.
  it('aplatit un paramètre de liste répété', () => {
    expect(
      parseEefSearchInput({ cycle: ['master', 'licence1'] }).cycles,
    ).toEqual(['master', 'licence1']);
  });

  it('accepte le mélange des deux formes', () => {
    expect(
      parseEefSearchInput({ cycle: ['master,licence1', 'but1'] }).cycles,
    ).toEqual(['master', 'licence1', 'but1']);
  });

  it('valide chaque valeur d\u2019un tableau comme celles d\u2019une liste', () => {
    expect(() => parseEefSearchInput({ cycle: ['master', 'doctorat'] })).toThrow(
      EefSearchParamError,
    );
  });

  it('retient la première valeur d\u2019un paramètre scalaire répété', () => {
    expect(parseEefSearchInput({ limit: ['5', '50'] }).limit).toBe(5);
    expect(parseEefSearchInput({ q: ['droit', 'ignoré'] }).terms).toEqual([
      'droit',
    ]);
    const cursor = encodeEefCursor({ nameFr: 'L1 - Droit', id: 'p-1' });
    expect(parseEefSearchInput({ cursor: [cursor, 'bruit'] }).cursor).toEqual({
      nameFr: 'L1 - Droit',
      id: 'p-1',
    });
  });
});

describe('curseur', () => {
  it('fait l’aller-retour, y compris sur un intitulé à accents et virgules', () => {
    const cursor = {
      nameFr: 'L3 - Langues, littératures et civilisations étrangères',
      id: 'eef-prog-0387ffdcaab99c8a',
    };
    expect(decodeEefCursor(encodeEefCursor(cursor))).toEqual(cursor);
  });

  it('refuse un curseur illisible plutôt que de repartir du début', () => {
    // Repartir du début renverrait l'étudiant en haut de liste sans rien dire.
    for (const bad of ['', 'pas-un-curseur', encodeEefCursor({ nameFr: '', id: 'x' })]) {
      expect(() => decodeEefCursor(bad)).toThrow(EefSearchCursorError);
    }
  });
});

describe('buildEefSearchWhere', () => {
  const params = parseEefSearchInput({
    q: 'droit rennes',
    procedureType: 'eef',
    cycle: 'master',
    fieldId: 'd07',
    selectivity: 'selective',
    campusCity: 'Rennes',
    institutionId: 'eef-univ-0353074b',
  });

  /// Les établissements PUBLIÉS que le service a lus. Toute clause construite
  /// ici doit en dépendre : la formation n'est publique que si son parent l'est.
  const PUBLISHED = ['eef-univ-0353074b', 'eef-univ-0751724s'];
  const PUBLISHED_CLAUSE = { institutionId: { in: PUBLISHED } };
  /// La PROVENANCE : cet espace ne sert que les lignes de l'import.
  const PROVENANCE_CLAUSE = eefProgramWhere();

  /// Chaque variante qu'un appel construit : la page, le total, chaque facette.
  const variants = (): [string, (p: EefSearchParams) => Record<string, unknown>][] => [
    ['la page', (p) => buildEefSearchWhere(p, 'france', PUBLISHED, { withCursor: true })],
    ['le total', (p) => buildEefSearchWhere(p, 'france', PUBLISHED)],
    ...EEF_SEARCH_FACETS.map((facet): [string, (p: EefSearchParams) => Record<string, unknown>] => [
      `la facette ${facet}`,
      (p) => buildEefSearchWhere(p, 'france', PUBLISHED, { excludeFacet: facet }),
    ]),
  ];

  /// Ce qui reste de `AND` une fois les clauses de PORTÉE retirées (établissement
  /// publié, provenance) : les mots et le curseur. Les tests du curseur et des
  /// mots regardent CELA, pas la forme complète du tableau — la portée n'a rien à
  /// voir avec eux et ne doit pas les rendre fragiles.
  ///
  /// On retire EXACTEMENT ces clauses — égalité profonde —, pas « tout ce qui
  /// porte la clé `institutionId` » ni « tout ce qui porte un `OR` » : ces
  /// filtres auraient aussi avalé une clause de curseur, de mot ou de facette
  /// qui se tromperait de clé, et les tests n'auraient rien vu.
  const withoutScope = (where: Record<string, unknown>) =>
    ((where.AND as Record<string, unknown>[] | undefined) ?? []).filter(
      (clause) =>
        !isDeepStrictEqual(clause, PUBLISHED_CLAUSE) &&
        !isDeepStrictEqual(clause, PROVENANCE_CLAUSE),
    );

  it('impose toujours la relecture et le pays', () => {
    const where = buildEefSearchWhere(params, 'france', PUBLISHED);
    expect(where.isActive).toBe(true);
    expect(where.countryId).toBe('france');
    // Les formations des écoles privées partenaires n'ont pas de procédure :
    // elles ont leur propre espace et n'ont rien à faire ici.
    expect(where.procedureType).toEqual({ in: ['eef'] });
    expect(
      buildEefSearchWhere(parseEefSearchInput({}), 'france', PUBLISHED)
        .procedureType,
    ).toEqual({ not: null });
  });

  // ── Le parent doit être publié ────────────────────────────────────────────
  //
  // `Program` n'a pas de relation vers `Institution` : rien en base n'impose
  // que l'établissement d'une formation publiée le soit aussi. Une formation
  // publiée sous une université que personne n'a relue était servie, avec pour
  // parent une fiche non vérifiée. Ces tests regardent la clause, dans CHAQUE
  // variante qu'un appel construit — page, total, chaque facette.
  describe('l’établissement doit être publié', () => {
    it.each(variants())('accompagne %s', (_label, build) => {
      for (const input of [{}, { q: 'droit' }, { institutionId: 'eef-univ-0353074b' }]) {
        const where = build(parseEefSearchInput(input));
        expect(where.AND).toContainEqual(PUBLISHED_CLAUSE);
      }
    });

    it('ne se laisse pas remplacer par la facette « établissement »', () => {
      // Le défaut qu'a connu la shortlist : deux conditions sur la même clé,
      // fusionnées à plat, dont la seconde efface la première. La facette du
      // même nom écrit `institutionId` à plat ; la clause de publication doit
      // donc vivre AILLEURS, dans `AND`.
      const asked = parseEefSearchInput({ institutionId: 'eef-univ-inconnue' });
      const where = buildEefSearchWhere(asked, 'france', PUBLISHED);
      expect(where.institutionId).toEqual({ in: ['eef-univ-inconnue'] });
      expect(where.AND).toContainEqual(PUBLISHED_CLAUSE);

      // Et la facette qui compte les établissements garde la publication même
      // sans son propre filtre.
      const counting = buildEefSearchWhere(asked, 'france', PUBLISHED, {
        excludeFacet: 'institutionId',
      });
      expect(counting.institutionId).toBeUndefined();
      expect(counting.AND).toContainEqual(PUBLISHED_CLAUSE);
    });

    it('sans aucun établissement publié, aucune formation ne peut sortir', () => {
      // `IN ()` ne rend rien : c'est l'état d'aujourd'hui en production, et le
      // bon. La liste vide ne doit surtout pas DISPARAÎTRE de la clause —
      // l'omettre servirait tout le catalogue.
      const where = buildEefSearchWhere(parseEefSearchInput({}), 'france', []);
      expect(where.AND).toContainEqual({ institutionId: { in: [] } });
    });

    it('copie la liste au lieu de la partager', () => {
      // Le service passe UNE liste à huit clauses : si l'une d'elles la
      // modifiait, les sept autres décriraient un autre ensemble.
      const shared = [...PUBLISHED];
      const where = buildEefSearchWhere(parseEefSearchInput({}), 'france', shared);
      const clause = (where.AND as { institutionId: { in: string[] } }[])[0];
      clause.institutionId.in.push('intrus');
      expect(shared).toEqual(PUBLISHED);
    });
  });

  // ── La provenance : une seule définition de « EEF » ───────────────────────
  //
  // Le catalogue général EXCLUT les lignes de l'import par leur identifiant ;
  // cet espace les INCLUAIT par `procedureType`. Deux définitions : le jour où
  // l'exploitation qualifie une formation partenaire d'une procédure, elle
  // entrait ici ET restait dans le catalogue général. L'espace exige désormais la
  // même provenance que celle que le catalogue général exclut.
  describe('la formation vient de l’import', () => {
    it.each(variants())('accompagne %s', (_label, build) => {
      for (const input of [{}, { q: 'droit' }, { procedureType: 'eef' }]) {
        expect(build(parseEefSearchInput(input)).AND).toContainEqual(PROVENANCE_CLAUSE);
      }
    });

    it('est la même clause que celle que le catalogue général exclut', () => {
      // Identité de valeur, pas de ressemblance : les deux surfaces partent de
      // `eefProgramWhere`.
      expect(PROVENANCE_CLAUSE).toEqual({
        OR: [
          { id: { startsWith: 'eef-prog-' } },
          { institutionId: { startsWith: 'eef-univ-' } },
        ],
      });
    });

    it('ne se laisse pas remplacer par la procédure', () => {
      // `procedureType` reste un garde-fou de données, mais aucune valeur qu'on
      // lui donne ne dispense de la provenance.
      for (const procedure of ['eef', 'dap_blanche', 'hors_eef']) {
        const where = buildEefSearchWhere(
          parseEefSearchInput({ procedureType: procedure }),
          'france',
          PUBLISHED,
        );
        expect(where.AND).toContainEqual(PROVENANCE_CLAUSE);
      }
    });
  });

  it('exige chaque mot, dans le texte normalisé OU l’intitulé OU la ville', () => {
    const where = buildEefSearchWhere(params, 'france', PUBLISHED);
    const and = where.AND as Record<string, unknown>[];
    const termClauses = and.filter(
      (clause) => 'OR' in clause && !isDeepStrictEqual(clause, PROVENANCE_CLAUSE),
    );
    expect(termClauses).toHaveLength(2);
    expect(termClauses[0]).toEqual({
      OR: [
        // Sans accents ni casse : c'est lui qui fait trouver « Génie » à « genie ».
        { searchText: { contains: 'droit' } },
        // Le repli brut : jamais moins de résultats qu'avant sur une ligne dont
        // le texte normalisé n'est pas encore rattrapé.
        { nameFr: { contains: 'droit', mode: 'insensitive' } },
        { campusCity: { contains: 'droit', mode: 'insensitive' } },
      ],
    });
  });

  describe('les mots qui désignent un établissement ou un niveau', () => {
    const termClausesOf = (where: Record<string, unknown>) =>
      (where.AND as Record<string, unknown>[]).filter(
        (clause) => 'OR' in clause && !isDeepStrictEqual(clause, PROVENANCE_CLAUSE),
      ) as { OR: Record<string, unknown>[] }[];

    it('ajoute l’établissement désigné par le mot, et seulement pour ce mot', () => {
      const input = parseEefSearchInput({ q: 'sorbonne droit' });
      const where = buildEefSearchWhere(input, 'france', PUBLISHED, {
        termInstitutionIds: new Map([['sorbonne', ['eef-univ-sorbonne']]]),
      });
      const [sorbonne, droit] = termClausesOf(where);
      expect(sorbonne.OR).toContainEqual({
        institutionId: { in: ['eef-univ-sorbonne'] },
      });
      expect(droit.OR.some((alt) => 'institutionId' in alt)).toBe(false);
    });

    it('ne fabrique pas de clause d’établissement sans correspondance', () => {
      const where = buildEefSearchWhere(
        parseEefSearchInput({ q: 'xyz' }),
        'france',
        PUBLISHED,
        { termInstitutionIds: new Map([['xyz', []]]) },
      );
      expect(termClausesOf(where)[0].OR.some((alt) => 'institutionId' in alt)).toBe(
        false,
      );
    });

    it('traduit un mot de niveau en cycles', () => {
      const where = buildEefSearchWhere(
        parseEefSearchInput({ q: 'licence droit' }),
        'france',
        PUBLISHED,
      );
      const [licence, droit] = termClausesOf(where);
      expect(licence.OR).toContainEqual({
        cycle: {
          in: ['licence1', 'licence2', 'licence3', 'licence_pro'],
        },
      });
      expect(droit.OR.some((alt) => 'cycle' in alt)).toBe(false);
    });

    it('ignore les mots vides et découpe les composés', () => {
      const where = buildEefSearchWhere(
        parseEefSearchInput({ q: 'licence de droit l\'économie' }),
        'france',
        PUBLISHED,
      );
      const words = termClausesOf(where).map(
        (clause) => (clause.OR[0] as { searchText: { contains: string } }).searchText.contains,
      );
      expect(words).toEqual(['licence', 'droit', 'economie']);
    });

    it('garde les mots vides quand il n’y a rien d’autre', () => {
      const where = buildEefSearchWhere(
        parseEefSearchInput({ q: 'de' }),
        'france',
        PUBLISHED,
      );
      expect(termClausesOf(where)).toHaveLength(1);
    });

    it('un mot fait de ponctuation seule ne restreint rien', () => {
      const where = buildEefSearchWhere(
        parseEefSearchInput({ q: '- —' }),
        'france',
        PUBLISHED,
      );
      expect(termClausesOf(where)).toHaveLength(0);
    });

    it('les clauses d’établissement restent DANS le mot : l’établissement publié tient toujours', () => {
      const where = buildEefSearchWhere(
        parseEefSearchInput({ q: 'sorbonne' }),
        'france',
        ['eef-univ-publie'],
        { termInstitutionIds: new Map([['sorbonne', ['eef-univ-non-publie']]]) },
      );
      // Même si un identifiant non publié passait dans la table des mots, la
      // clause des établissements publiés reste un `AND` de plus haut niveau.
      expect(where.AND).toContainEqual({
        institutionId: { in: ['eef-univ-publie'] },
      });
    });
  });

  describe('isRestricted', () => {
    it('dit si la requête restreint quoi que ce soit', () => {
      expect(isRestricted(parseEefSearchInput({}))).toBe(false);
      expect(isRestricted(parseEefSearchInput({ limit: '5', cursor: undefined }))).toBe(false);
      for (const input of [
        { q: 'droit' },
        { procedureType: 'eef' },
        { cycle: 'master' },
        { fieldId: 'd07' },
        { institutionId: 'eef-univ-1' },
        { campusCity: 'Rennes' },
        { selectivity: 'selective' },
      ]) {
        expect(isRestricted(parseEefSearchInput(input))).toBe(true);
      }
    });
  });

  it('exclut le filtre de la facette qu’il compte', () => {
    // Sans cela, choisir « master » ferait tomber à zéro le compte de toutes
    // les autres valeurs du même sélecteur : l'étudiant ne pourrait plus voir
    // combien de licences existent sans défaire son filtre.
    const where = buildEefSearchWhere(params, 'france', PUBLISHED, {
      excludeFacet: 'cycle',
    });
    expect(where.cycle).toBeUndefined();
    expect(where.fieldId).toEqual({ in: ['d07'] });
  });

  it('n’applique le curseur qu’à la page', () => {
    const withCursor = parseEefSearchInput({
      cursor: encodeEefCursor({ nameFr: 'L1 - Droit', id: 'p-042' }),
    });
    // Le total ne porte AUCUN morceau de curseur : il décrit « ce qu'il y a »,
    // pas « ce qui reste ».
    const total = buildEefSearchWhere(withCursor, 'france', PUBLISHED);
    expect(withoutScope(total)).toEqual([]);

    const page = buildEefSearchWhere(withCursor, 'france', PUBLISHED, {
      withCursor: true,
    });
    expect(withoutScope(page)).toEqual([
      {
        OR: [
          { nameFr: { gt: 'L1 - Droit' } },
          { AND: [{ nameFr: 'L1 - Droit' }, { id: { gt: 'p-042' } }] },
        ],
      },
    ]);
  });

  it('départage les homonymes par identifiant', () => {
    // « L1 - Droit » est servi par quarante universités : sans le second
    // critère, le curseur sauterait les trente-neuf autres.
    const page = buildEefSearchWhere(
      parseEefSearchInput({
        cursor: encodeEefCursor({ nameFr: 'L1 - Droit', id: 'p-010' }),
      }),
      'france',
      PUBLISHED,
      { withCursor: true },
    );
    const clause = (page.AND as Record<string, unknown>[])[0].OR as Record<
      string,
      unknown
    >[];
    expect(clause[1]).toEqual({
      AND: [{ nameFr: 'L1 - Droit' }, { id: { gt: 'p-010' } }],
    });
  });
});
