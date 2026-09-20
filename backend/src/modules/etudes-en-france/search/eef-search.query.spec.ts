import {
  EEF_SEARCH_DEFAULT_LIMIT,
  EEF_SEARCH_MAX_FILTER_VALUES,
  EEF_SEARCH_MAX_LIMIT,
  EEF_SEARCH_MAX_TERMS,
  EefSearchCursorError,
  EefSearchParamError,
  buildEefSearchWhere,
  decodeEefCursor,
  encodeEefCursor,
  parseEefSearchInput,
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

  it('impose toujours la relecture et le pays', () => {
    const where = buildEefSearchWhere(params, 'france');
    expect(where.isActive).toBe(true);
    expect(where.countryId).toBe('france');
    // Les formations des écoles privées partenaires n'ont pas de procédure :
    // elles ont leur propre espace et n'ont rien à faire ici.
    expect(where.procedureType).toEqual({ in: ['eef'] });
    expect(buildEefSearchWhere(parseEefSearchInput({}), 'france').procedureType)
      .toEqual({ not: null });
  });

  it('exige chaque mot, dans l’intitulé OU dans la ville', () => {
    const where = buildEefSearchWhere(params, 'france');
    const and = where.AND as Record<string, unknown>[];
    const termClauses = and.filter((clause) => 'OR' in clause);
    expect(termClauses).toHaveLength(2);
    expect(termClauses[0]).toEqual({
      OR: [
        { nameFr: { contains: 'droit', mode: 'insensitive' } },
        { campusCity: { contains: 'droit', mode: 'insensitive' } },
      ],
    });
  });

  it('exclut le filtre de la facette qu’il compte', () => {
    // Sans cela, choisir « master » ferait tomber à zéro le compte de toutes
    // les autres valeurs du même sélecteur : l'étudiant ne pourrait plus voir
    // combien de licences existent sans défaire son filtre.
    const where = buildEefSearchWhere(params, 'france', {
      excludeFacet: 'cycle',
    });
    expect(where.cycle).toBeUndefined();
    expect(where.fieldId).toEqual({ in: ['d07'] });
  });

  it('n’applique le curseur qu’à la page', () => {
    const withCursor = parseEefSearchInput({
      cursor: encodeEefCursor({ nameFr: 'L1 - Droit', id: 'p-042' }),
    });
    const total = buildEefSearchWhere(withCursor, 'france');
    expect(total.AND).toBeUndefined();

    const page = buildEefSearchWhere(withCursor, 'france', { withCursor: true });
    expect(page.AND).toEqual([
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
