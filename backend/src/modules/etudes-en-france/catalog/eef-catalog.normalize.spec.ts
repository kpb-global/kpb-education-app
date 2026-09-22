import {
  FIELD_KEYWORD_RULES,
  PARCOURSUP_FAMILIES,
  normalizeCityName,
  normalizeLabel,
  refineParcoursupShape,
  resolveFieldId,
  resolveParcoursupShape,
  stableEefId,
} from './eef-catalog.normalize';

describe('normalizeLabel', () => {
  it('efface accents, casse, apostrophes et traits d’union', () => {
    expect(normalizeLabel("Réalisation d'applications")).toBe(
      'realisation d applications',
    );
    expect(normalizeLabel('Réalisation d’applications')).toBe(
      'realisation d applications',
    );
    expect(normalizeLabel('Génie civil - Construction durable')).toBe(
      'genie civil construction durable',
    );
  });

  // Régression : l'apostrophe non normalisée faisait rater 23 formations
  // d'informatique, classées nulle part et donc écartées du catalogue.
  it("classe « Réalisation d'applications » en informatique", () => {
    expect(resolveFieldId("BUT - Réalisation d'applications")?.fieldId).toBe(
      'd01',
    );
  });
});

describe('resolveFieldId', () => {
  it('classe par mot-clé sans marquer de repli', () => {
    expect(resolveFieldId('L1 - Droit')).toEqual({
      fieldId: 'd07',
      isFallback: false,
    });
    expect(resolveFieldId('Master — Monnaie, banque, finance')).toEqual({
      fieldId: 'd03',
      isFallback: false,
    });
  });

  it('fait primer la santé sur l’informatique quand les deux mots sont là', () => {
    // L'ordre des règles EST le classement : d04 passe avant d01.
    expect(resolveFieldId('Informatique médicale')?.fieldId).toBe('d04');
  });

  it('replie sur le grand domaine, et le dit', () => {
    expect(resolveFieldId('Mention inconnue au dictionnaire', 'ARTS, LETTRES, LANGUES')).toEqual({
      fieldId: 'd09',
      isFallback: true,
    });
  });

  it('ne lit que le premier grand domaine quand la source en cumule', () => {
    expect(
      resolveFieldId('Zzz', 'DROIT, ECONOMIE, GESTION|SCIENCES HUMAINES ET SOCIALES')
        ?.fieldId,
    ).toBe('d02');
  });

  it('refuse de ranger ce que la source ne décrit pas', () => {
    // « DU - Diplôme d'Université » ne dit pas ce qu'on y étudie. Le ranger
    // quelque part serait inventer l'information.
    expect(resolveFieldId("DU - Diplôme d'Université")).toBeNull();
    expect(resolveFieldId('')).toBeNull();
  });

  it('ne produit que des domaines du référentiel d01..d12', () => {
    const known = new Set([
      'd01', 'd02', 'd03', 'd04', 'd05', 'd06',
      'd07', 'd08', 'd09', 'd10', 'd11', 'd12',
    ]);
    for (const rule of FIELD_KEYWORD_RULES) {
      expect(known.has(rule.fieldId)).toBe(true);
    }
  });

  it('n’a aucune règle vide, qui capterait tout', () => {
    for (const rule of FIELD_KEYWORD_RULES) {
      for (const keyword of rule.keywords) {
        expect(keyword.trim()).not.toBe('');
      }
    }
  });
});

describe('resolveParcoursupShape', () => {
  it('garde la sélectivité quand la ligne porte les deux familles', () => {
    // Une ligne « Licence sélective » + « Licence » doit rester sélective :
    // prendre la première famille au hasard effacerait la seule information
    // qui distingue les deux.
    const shape = resolveParcoursupShape(['Licence sélective', 'Licence']);
    expect(shape?.selectivity).toBe('selective');
    expect(shape?.cycle).toBe('licence1');
    const reversed = resolveParcoursupShape(['Licence', 'Licence sélective']);
    expect(reversed?.selectivity).toBe('selective');
  });

  it('fait primer la famille la plus spécifique sur « Licence »', () => {
    expect(resolveParcoursupShape(['Licence', 'BUT'])?.cycle).toBe('but1');
  });

  it('rejette une famille hors table plutôt que de deviner', () => {
    expect(resolveParcoursupShape(['CPGE'])).toBeNull();
    expect(resolveParcoursupShape([])).toBeNull();
  });

  it('met la 1re année de licence en DAP blanche et le BUT en procédure EEF', () => {
    expect(PARCOURSUP_FAMILIES.Licence.procedureType).toBe('dap_blanche');
    expect(PARCOURSUP_FAMILIES.BUT.procedureType).toBe('eef');
    expect(
      PARCOURSUP_FAMILIES["Formations d'architecture, du paysage et du patrimoine"]
        .procedureType,
    ).toBe('dap_jaune');
  });

  it('range PASS en 1re année de licence, donc en DAP blanche', () => {
    expect(PARCOURSUP_FAMILIES['Etudes de santé'].procedureType).toBe(
      'dap_blanche',
    );
  });
});

describe('normalizeCityName', () => {
  it('retire le bureau distributeur et rend la ville lisible', () => {
    expect(normalizeCityName('RENNES CEDEX 7')).toBe('Rennes');
    expect(normalizeCityName('PARIS CEDEX 05')).toBe('Paris');
    expect(normalizeCityName('SAINT-MARTIN-D HERES')).toBe("Saint-Martin-d Heres");
  });

  it('laisse intacte une ville déjà correctement capitalisée', () => {
    expect(normalizeCityName("Saint-Martin-d'Hères")).toBe("Saint-Martin-d'Hères");
    expect(normalizeCityName('Le Havre')).toBe('Le Havre');
  });

  it('garde les particules en minuscules sauf en tête', () => {
    expect(normalizeCityName('AULNOY-LEZ-VALENCIENNES')).toBe(
      'Aulnoy-lez-Valenciennes',
    );
    expect(normalizeCityName('LE MANS')).toBe('Le Mans');
  });

  it('rend une chaîne vide quand il ne reste rien', () => {
    expect(normalizeCityName('   ')).toBe('');
    expect(normalizeCityName('CEDEX 12')).toBe('');
  });
});

describe('refineParcoursupShape', () => {
  it('laisse une licence Sciences Po en première année', () => {
    const shape = resolveParcoursupShape([
      "Sciences Po - Instituts d'études politiques",
    ]);
    expect(shape).not.toBeNull();
    expect(
      refineParcoursupShape(
        shape!,
        "Sciences Po / Instituts d'études politiques - Grade Licence",
      ).cycle,
    ).toBe('licence1');
  });

  it('ne classe pas un grade de master en DAP', () => {
    const shape = resolveParcoursupShape([
      "Sciences Po - Instituts d'études politiques",
    ]);
    const refined = refineParcoursupShape(
      shape!,
      'Sciences Po / Instituts d’études politiques - Sciences Humaines et Sociales - Grade Master',
    );
    expect(refined.cycle).toBe('master');
    expect(refined.procedureType).toBe('eef');
    expect(refined.level).toBe('Master');
  });
});

describe('stableEefId', () => {
  it('ne dépend que de la clé métier', () => {
    expect(stableEefId('eef-prog-', 'a')).toBe(stableEefId('eef-prog-', 'a'));
    expect(stableEefId('eef-prog-', 'a')).not.toBe(stableEefId('eef-prog-', 'b'));
    expect(stableEefId('eef-prog-', 'a')).toMatch(/^eef-prog-[0-9a-f]{16}$/);
  });
});
