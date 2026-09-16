// ─────────────────────────────────────────────────────────────────────────────
// `Program.tuitionMinEur` — lire le plancher de frais depuis le libellé humain.
//
// Pourquoi ce module existe : les 628 programmes de production ont tous
// `tuitionMinEur` à `null`, alors que 350 d'entre eux portent déjà un montant
// en euros dans `tuitionFr`. matches.service.ts lit cette colonne pour le
// score budgétaire ; sans elle, chaque match est marqué `isEstimate`.
//
// `tuitionFr` reste le libellé d'origine, dans sa devise. Cette colonne-ci est
// une valeur MACHINE, utilisée pour classer, jamais affichée ni devisée.
// ─────────────────────────────────────────────────────────────────────────────

/// Parités FIXES. Le franc CFA est arrimé à l'euro par un accord monétaire :
/// ce n'est pas un cours de marché, il ne périme pas, et la conversion est
/// exacte. Aucune date de validité n'a donc de sens ici.
export const FIXED_PEGS: Record<string, number> = {
  XOF: 655.957,
  XAF: 655.957,
};

/// Taux SOURCÉS, à réviser. Chacun doit venir d'un document qu'on peut citer,
/// jamais d'une estimation : une valeur inventée ici biaiserait le classement
/// budgétaire de tout un pays sans que rien ne le signale.
///
/// MAD — taux appliqué par l'établissement lui-même sur ses fiches « Coût des
/// études » (Universiapolis, code FR2-1, année 2026-2027) : 1 € = 10 DH. C'est
/// le taux auquel l'étudiant est effectivement facturé, donc le bon pour un
/// classement par budget, même s'il s'écarte du cours de marché.
export const SOURCED_RATES: Record<string, { perEur: number; source: string }> = {
  MAD: { perEur: 10, source: 'Fiches Universiapolis « Coût des études » FR2-1, 2026-2027' },
};

/// Devises rencontrées en base pour lesquelles on n'a AUCUNE source. On ne
/// devine pas : `tuitionMinEur` reste `null` et le score budgétaire reste une
/// estimation, ce qui est honnête. Ajouter un taux ici demande un document.
export const UNSOURCED = ['USD', 'CAD', 'GBP', 'AED'] as const;

export type TuitionParse =
  | { ok: true; currency: string; amount: number; eur: number; exact: boolean }
  | {
      ok: false;
      reason:
        | 'no-amount'
        | 'unsourced-currency'
        | 'unknown-currency'
        | 'ambiguous-currency';
      currency?: string;
      currencies?: string[];
    };

/// Un motif par devise — invariant épinglé par un test. C'est lui qui garantit
/// que `detectCurrencies` ne peut pas rapporter deux fois le même code, donc
/// qu'une devise citée deux fois ne passe pas pour une ambiguïté.
export const CURRENCY_PATTERNS: [RegExp, string][] = [
  [/€|\bEUR\b/i, 'EUR'],
  [/\bXOF\b|\bFCFA\b/i, 'XOF'],
  [/\bXAF\b/i, 'XAF'],
  [/\bMAD\b|\bDH\b|\bDHS\b/i, 'MAD'],
  [/\bAED\b/i, 'AED'],
  [/\bUSD\b|\$/, 'USD'],
  [/\bCAD\b/i, 'CAD'],
  [/\bGBP\b|£/, 'GBP'],
];

/// Toutes les devises citées dans le libellé, dans l'ordre de la table.
export function detectCurrencies(label: string): string[] {
  const found: string[] = [];
  for (const [re, code] of CURRENCY_PATTERNS) {
    if (re.test(label)) found.push(code);
  }
  return found;
}

export function detectCurrency(label: string): string | null {
  const found = detectCurrencies(label);
  return found.length === 1 ? found[0] : null;
}

/// Premier nombre du libellé. « 6 690 € – 7 025 €/an » donne 6690 : on veut le
/// PLANCHER, et les fourchettes sont écrites du moins cher au plus cher.
/// Gère les séparateurs français (espace, espace insécable, espace fine) et
/// anglo-saxons (virgule). Un point n'est PAS traité comme séparateur décimal :
/// aucun montant de scolarité annuelle ne s'exprime en centimes, et « 18.500 »
/// est un séparateur de milliers dans plusieurs des libellés en base.
export function parseAmount(label: string): number | null {
  const m = /(\d[\d\s  .,]*)/.exec(label ?? '');
  if (!m) return null;
  const digits = m[1].replace(/[\s  .,]/g, '');
  if (!digits) return null;
  const n = Number.parseInt(digits, 10);
  return Number.isFinite(n) && n > 0 ? n : null;
}

export function tuitionToEur(label: string): TuitionParse {
  const text = (label ?? '').trim();
  if (!text) return { ok: false, reason: 'no-amount' };
  // Plusieurs devises dans un même libellé — « 34 500 DH · 2 259 750 FCFA »,
  // la forme exacte des fiches Universiapolis. `parseAmount` prendrait le
  // PREMIER nombre et la détection la PREMIÈRE devise de la table : les deux
  // peuvent désigner des colonnes différentes, et 34 500 dirhams deviendraient
  // 34 500 francs CFA, soit 53 € au lieu de 3 450. On refuse au lieu de
  // deviner : c'est la règle de tout ce module.
  const currencies = detectCurrencies(text);
  if (currencies.length > 1) {
    return { ok: false, reason: 'ambiguous-currency', currencies };
  }
  const currency = currencies[0] ?? null;
  if (!currency) return { ok: false, reason: 'unknown-currency' };
  const amount = parseAmount(text);
  if (amount == null) return { ok: false, reason: 'no-amount', currency };

  if (currency === 'EUR') {
    return { ok: true, currency, amount, eur: amount, exact: true };
  }
  const peg = FIXED_PEGS[currency];
  if (peg) {
    return { ok: true, currency, amount, eur: Math.round(amount / peg), exact: true };
  }
  const sourced = SOURCED_RATES[currency];
  if (sourced) {
    return {
      ok: true,
      currency,
      amount,
      eur: Math.round(amount / sourced.perEur),
      exact: false,
    };
  }
  return { ok: false, reason: 'unsourced-currency', currency };
}
