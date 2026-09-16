import {
  CURRENCY_PATTERNS,
  FIXED_PEGS,
  detectCurrencies,
  SOURCED_RATES,
  UNSOURCED,
  detectCurrency,
  parseAmount,
  tuitionToEur,
} from './tuition-eur';

/**
 * Les 628 programmes de production ont `tuitionMinEur` à `null`, donc chaque
 * match servi par l'app est marqué `isEstimate`. Ce module lit le plancher
 * depuis `tuitionFr`. Les libellés cités ici sont RÉELS, relevés en production
 * — c'est la seule façon de savoir que l'analyseur tient face aux formats
 * effectivement présents, et non face à ceux que j'imagine.
 */
describe('detectCurrency — libellés réellement présents en base', () => {
  it.each([
    ['15 420 €/an', 'EUR'],
    ['EUR 9 000/an', 'EUR'],
    ['8 850 €/an', 'EUR'],
    ['MAD 35,000/an', 'MAD'],
    ['57 900 DH/an', 'MAD'],
    ['XOF 1 300 000/an (est.)', 'XOF'],
    ['USD 18,000/an (approx.)', 'USD'],
    ['17 610 USD/an', 'USD'],
    ['CAD 18 000/an (indicatif)', 'CAD'],
    ['40 000 AED/an', 'AED'],
    ['8 000 - 18 500 AED', 'AED'],
  ])('reconnaît %s comme %s', (label, expected) => {
    expect(detectCurrency(label)).toBe(expected);
  });

  it("ne reconnaît rien dans un libellé sans devise", () => {
    expect(detectCurrency('À confirmer')).toBeNull();
  });

  // « DH » ne doit pas être attrapé à l'intérieur d'un mot.
  it('ne confond pas DH avec une sous-chaîne', () => {
    expect(detectCurrency('Programme DHEC sans montant')).toBeNull();
  });
});

describe('parseAmount', () => {
  it("prend la borne BASSE d'une fourchette", () => {
    expect(parseAmount('6 690 € – 7 025 €/an')).toBe(6690);
    expect(parseAmount('8 000 - 18 500 AED')).toBe(8000);
  });

  it('gère les séparateurs français', () => {
    expect(parseAmount('8 850 €/an')).toBe(8850);
    expect(parseAmount('15 420 €/an')).toBe(15420);
    expect(parseAmount('1 300 000 XOF')).toBe(1300000);
  });

  it('gère la virgule anglo-saxonne des milliers', () => {
    expect(parseAmount('MAD 35,000/an')).toBe(35000);
    expect(parseAmount('USD 18,000/an (approx.)')).toBe(18000);
  });

  // Un point est un séparateur de MILLIERS ici : aucune scolarité annuelle ne
  // s'exprime en centimes, et « 18.500 » vaut dix-huit mille cinq cents.
  it('traite le point comme un séparateur de milliers, pas une décimale', () => {
    expect(parseAmount('18.500 €/an')).toBe(18500);
  });

  it('renvoie null sans chiffre', () => {
    expect(parseAmount('À confirmer')).toBeNull();
    expect(parseAmount('')).toBeNull();
  });
});

describe('tuitionToEur', () => {
  it("n'applique aucun taux à un montant déjà en euros", () => {
    const r = tuitionToEur('15 420 €/an');
    expect(r).toEqual({ ok: true, currency: 'EUR', amount: 15420, eur: 15420, exact: true });
  });

  // Le franc CFA est arrimé à l'euro par accord monétaire : la conversion est
  // exacte et ne périmera pas. 1 300 000 / 655,957 = 1981,8 → 1982.
  it('convertit le XOF exactement, via la parité fixe', () => {
    const r = tuitionToEur('XOF 1 300 000/an (est.)');
    expect(r).toMatchObject({ ok: true, currency: 'XOF', eur: 1982, exact: true });
  });

  it('marque la conversion MAD comme NON exacte', () => {
    const r = tuitionToEur('MAD 35,000/an');
    expect(r).toMatchObject({ ok: true, currency: 'MAD', eur: 3500, exact: false });
  });

  it('convertit le libellé en dirhams du PDF Universiapolis', () => {
    // 34 500 DH, le moins cher des cinq écoles → 3 450 € au taux facturé.
    expect(tuitionToEur('34 500 DH/an')).toMatchObject({ eur: 3450, exact: false });
  });

  // Le point dur : pas de taux inventé. Une devise sans source documentée doit
  // laisser `tuitionMinEur` à null plutôt que biaiser le classement budgétaire
  // d'un pays entier sans que rien ne le signale.
  it.each([...UNSOURCED])('refuse de convertir %s faute de source', (code) => {
    const r = tuitionToEur(`${code} 18 000/an`);
    expect(r).toEqual({ ok: false, reason: 'unsourced-currency', currency: code });
  });

  it('refuse un libellé sans montant', () => {
    expect(tuitionToEur('À confirmer')).toMatchObject({ ok: false });
  });

  it('refuse un libellé sans devise reconnaissable', () => {
    expect(tuitionToEur('12 000 par an')).toEqual({ ok: false, reason: 'unknown-currency' });
  });
});

describe('libellés à plusieurs devises', () => {
  // La forme exacte des fiches Universiapolis : montant en dirhams, puis sa
  // conversion en FCFA. `parseAmount` prend le premier nombre (34 500, des
  // dirhams) et la détection prendrait la première devise de la table (XOF) —
  // 34 500 francs CFA valent 53 €, contre 3 450 € pour les dirhams. Un facteur
  // 65 sur le score budgétaire, sans aucun signal.
  it('refuse « 34 500 DH · 2 259 750 FCFA » au lieu de choisir', () => {
    const r = tuitionToEur('34 500 DH · 2 259 750 FCFA');
    expect(r.ok).toBe(false);
    expect(r).toMatchObject({ reason: 'ambiguous-currency' });
    expect((r as { currencies: string[] }).currencies.sort()).toEqual(['MAD', 'XOF']);
  });

  it('refuse un libellé mêlant euros et dollars', () => {
    expect(tuitionToEur('15 420 € (≈ 16 600 USD)')).toMatchObject({
      reason: 'ambiguous-currency',
    });
  });

  it('detectCurrencies les liste toutes', () => {
    expect(detectCurrencies('34 500 DH · 2 259 750 FCFA').sort()).toEqual([
      'MAD',
      'XOF',
    ]);
    expect(detectCurrencies('15 420 €/an')).toEqual(['EUR']);
  });

  it("une devise citée deux fois n'est pas une ambiguïté", () => {
    expect(tuitionToEur('6 690 € – 7 025 €/an')).toMatchObject({
      ok: true,
      currency: 'EUR',
      eur: 6690,
    });
  });
});

describe('les tables de taux', () => {
  // Ce qui garantit qu'une devise citée deux fois n'est pas prise pour une
  // ambiguïté, ce n'est pas une déduplication à l'exécution — c'est qu'un code
  // n'apparaît qu'une fois dans la table. L'invariant est ici, pas dans une
  // garde défensive que rien ne pourrait faire échouer.
  it('chaque devise n’a qu’un seul motif', () => {
    const codes = CURRENCY_PATTERNS.map(([, c]) => c);
    expect(new Set(codes).size).toBe(codes.length);
  });

  it('le CFA porte bien la parité officielle', () => {
    expect(FIXED_PEGS.XOF).toBe(655.957);
    expect(FIXED_PEGS.XAF).toBe(655.957);
  });

  it('chaque taux sourcé cite sa source', () => {
    for (const [code, r] of Object.entries(SOURCED_RATES)) {
      expect(r.perEur).toBeGreaterThan(0);
      expect(r.source.length).toBeGreaterThan(15);
      expect(UNSOURCED).not.toContain(code);
    }
  });

  it('aucune devise n’est à la fois ancrée et sourcée', () => {
    for (const code of Object.keys(FIXED_PEGS)) {
      expect(SOURCED_RATES[code]).toBeUndefined();
    }
  });
});
