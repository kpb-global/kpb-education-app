// Le classement de la shortlist.
//
// LE TEST QUI COMPTE, ET POURQUOI IL EXISTE
//
// L'étage d'une formation est décidé DEUX FOIS : par `tierWhere`, qui va la
// chercher en base, et par `tierOf`, qui la relit en mémoire pour lui donner
// ses motifs. Deux lectures de la même règle, écrites dans deux langages —
// c'est la configuration exacte où une divergence s'installe sans bruit.
//
// Ce qu'une divergence produirait n'est pas une erreur visible : une formation
// rendue par la requête « sécurité » mais relue « ambition » s'afficherait
// sous un étage avec les justifications d'un autre. Personne ne le verrait, et
// la liste mentirait sur exactement ce qu'elle promet d'expliquer.
//
// `matchesWhere` ci-dessous rejoue la clause en mémoire, avec la logique à
// TROIS valeurs de SQL — c'est indispensable : `NOT (NULL IN (…))` vaut NULL,
// donc faux, et c'est par là qu'une ligne peut disparaître de tous les étages.
import {
  ADMISSION_MODE_EFFORT,
  EEF_SHORTLIST_DEFAULT_LIMIT,
  EEF_SHORTLIST_MAX_LIMIT,
  buildShortlistWhere,
  clampShortlistLimit,
  reasonsFor,
  tierOf,
  tierWhere,
  type EefCandidateRow,
} from './eef-shortlist.rank';
import {
  EEF_SHORTLIST_TIERS,
  type EefEntryPath,
  type EefShortlistTier,
} from './eef-shortlist.types';

function row(over: Partial<EefCandidateRow> = {}): EefCandidateRow {
  return {
    id: 'p-1',
    fieldId: 'd02',
    cycle: 'master',
    selectivity: 'selective',
    recommendedBachelors: [],
    recommendedFieldIds: [],
    admissionModes: [],
    ...over,
  };
}

// ─── Le ré-exécuteur de clause, à trois valeurs ──────────────────────────────

type Tri = true | false | null;

function and(values: Tri[]): Tri {
  if (values.some((v) => v === false)) return false;
  if (values.some((v) => v === null)) return null;
  return true;
}

function or(values: Tri[]): Tri {
  if (values.some((v) => v === true)) return true;
  if (values.some((v) => v === null)) return null;
  return false;
}

function evaluate(
  clause: Record<string, unknown>,
  target: Record<string, unknown>,
): Tri {
  const parts: Tri[] = [];
  for (const [key, expected] of Object.entries(clause)) {
    if (key === 'NOT') {
      const inner = evaluate(expected as Record<string, unknown>, target);
      // SQL : NOT(inconnu) reste inconnu, donc n'est pas vrai. C'est ce qui
      // fait disparaître les lignes `NULL` d'un `NOT IN`.
      parts.push(inner === null ? null : !inner);
      continue;
    }
    if (key === 'AND') {
      parts.push(
        and(
          (expected as Record<string, unknown>[]).map((branch) =>
            evaluate(branch, target),
          ),
        ),
      );
      continue;
    }
    if (key === 'OR') {
      parts.push(
        or(
          (expected as Record<string, unknown>[]).map((branch) =>
            evaluate(branch, target),
          ),
        ),
      );
      continue;
    }
    const actual = target[key];
    if (expected === null) {
      parts.push(actual === null || actual === undefined);
      continue;
    }
    if (typeof expected !== 'object') {
      if (actual === null || actual === undefined) parts.push(null);
      else parts.push(actual === expected);
      continue;
    }
    const op = expected as Record<string, unknown>;
    if ('in' in op) {
      if (actual === null || actual === undefined) parts.push(null);
      else parts.push((op.in as unknown[]).includes(actual));
    } else if ('hasSome' in op) {
      const list = (actual as unknown[]) ?? [];
      parts.push((op.hasSome as unknown[]).some((v) => list.includes(v)));
    } else if ('has' in op) {
      const list = (actual as unknown[]) ?? [];
      parts.push(list.includes(op.has));
    } else if ('isEmpty' in op) {
      const list = (actual as unknown[]) ?? [];
      parts.push((list.length === 0) === op.isEmpty);
    } else {
      throw new Error(`opérateur non pris en charge dans le test : ${
        JSON.stringify(op)}`);
    }
  }
  return and(parts);
}

function matchesWhere(
  clause: Record<string, unknown>,
  target: Record<string, unknown>,
): boolean {
  return evaluate(clause, target) === true;
}

/** Tous les sous-ensembles d'un vocabulaire, y compris le vide. */
function subsets<T>(values: readonly T[]): T[][] {
  return values.reduce<T[][]>(
    (acc, value) => [...acc, ...acc.map((subset) => [...subset, value])],
    [[]],
  );
}

// ─── Les épreuves ────────────────────────────────────────────────────────────

describe('tierOf — la lecture en mémoire', () => {
  it("garde l'épreuve la plus exigeante", () => {
    expect(tierOf(row({ admissionModes: ['Dossier'] }), 'master'))
      .toBe('securite');
    expect(tierOf(row({ admissionModes: ['Dossier', 'Entretien'] }), 'master'))
      .toBe('cible');
    expect(
      tierOf(row({ admissionModes: ['Dossier', 'Entretien', 'Concours'] }),
        'master'),
    ).toBe('ambition');
  });

  it('range sans modalité publiée dans « non classé », pas dans « sécurité »',
    () => {
      // 198 masters sont dans ce cas. Les glisser dans « sécurité » les ferait
      // passer pour évalués sur un dossier qu'aucun établissement n'a publié.
      expect(tierOf(row({ admissionModes: [] }), 'master')).toBe('unranked');
    });

  it("ignore une modalité hors table sans faire disparaître la ligne", () => {
    // Elle ne pèse pas sur l'effort — on ne sait pas la lire — mais la ligne
    // reste classée par ce qu'on sait lire, et une ligne dont RIEN n'est
    // lisible tombe dans « non classé » plutôt que nulle part.
    expect(tierOf(row({ admissionModes: ['Dossier', 'Tirage'] }), 'master'))
      .toBe('securite');
    expect(tierOf(row({ admissionModes: ['Tirage'] }), 'master'))
      .toBe('unranked');
  });

  it('lit la sélectivité sur le chemin post-bac, et rien d’autre', () => {
    expect(tierOf(row({ selectivity: 'non_selective' }), 'post_bac'))
      .toBe('securite');
    expect(tierOf(row({ selectivity: 'selective' }), 'post_bac'))
      .toBe('ambition');
    expect(tierOf(row({ selectivity: null }), 'post_bac')).toBe('unranked');
  });

  // Le constat qui a façonné toute la fonctionnalité : sur ce chemin, TOUTES
  // les lignes du catalogue sont `selective` et aucune ne publie de modalité.
  // Rendre trois étages y aurait été une invention pure.
  it('ne classe rien sur le chemin L2/L3, quelles que soient les données', () => {
    for (const modes of [[], ['Dossier'], ['Concours']]) {
      for (const selectivity of ['selective', 'non_selective', null]) {
        expect(
          tierOf(row({ admissionModes: modes, selectivity }),
            'licence_continuation'),
        ).toBe('unranked');
      }
    }
  });
});

describe('tierWhere et tierOf disent la même chose', () => {
  // Le vocabulaire publié PLUS un mot que la table ne connaît pas : c'est le
  // cas que la source peut produire demain sans prévenir.
  const MODES = [...Object.keys(ADMISSION_MODE_EFFORT), 'Tirage'];

  it('range chaque combinaison de modalités dans exactement un étage', () => {
    for (const admissionModes of subsets(MODES)) {
      const candidate = row({ admissionModes });
      const matched = EEF_SHORTLIST_TIERS.filter((tier) =>
        matchesWhere(
          tierWhere(tier, 'master'),
          candidate as unknown as Record<string, unknown>,
        ),
      );
      expect({ admissionModes, matched }).toEqual({
        admissionModes,
        matched: [tierOf(candidate, 'master')],
      });
    }
  });

  it('range chaque sélectivité dans exactement un étage, NULL comprise', () => {
    for (const selectivity of ['selective', 'non_selective', 'inconnue', null]) {
      const candidate = row({ selectivity });
      const matched = EEF_SHORTLIST_TIERS.filter((tier) =>
        matchesWhere(
          tierWhere(tier, 'post_bac'),
          candidate as unknown as Record<string, unknown>,
        ),
      );
      expect({ selectivity, matched }).toEqual({
        selectivity,
        matched: [tierOf(candidate, 'post_bac')],
      });
    }
  });

  it('ne laisse tomber aucune ligne dans « cible » sur l’axe sélectivité', () => {
    // « cible » n'a pas de socle publié sur ce chemin : la requête doit le
    // garantir, pas la confiance dans l'appelant.
    for (const selectivity of ['selective', 'non_selective', null]) {
      expect(
        matchesWhere(
          tierWhere('cible', 'post_bac'),
          row({ selectivity }) as unknown as Record<string, unknown>,
        ),
      ).toBe(false);
    }
  });

  it('met tout dans « non classé » sur le chemin sans axe', () => {
    const candidate = row({ admissionModes: ['Dossier'] });
    const matched = EEF_SHORTLIST_TIERS.filter((tier) =>
      matchesWhere(
        tierWhere(tier, 'licence_continuation'),
        candidate as unknown as Record<string, unknown>,
      ),
    );
    expect(matched).toEqual(['unranked']);
  });
});

describe('buildShortlistWhere', () => {
  const base = {
    path: 'master' as EefEntryPath,
    countryId: 'france',
    declaredFieldIds: ['d02'],
    tier: 'securite' as EefShortlistTier,
  };

  it('ne sort jamais du relu ni du bon pays', () => {
    for (const stratum of ['linked', 'open', 'any'] as const) {
      const where = buildShortlistWhere({ ...base, stratum });
      expect(where.isActive).toBe(true);
      expect(where.countryId).toBe('france');
    }
  });

  it('restreint aux cycles du chemin, et à eux seuls', () => {
    expect(buildShortlistWhere({ ...base, stratum: 'linked' }).cycle)
      .toEqual({ in: ['master'] });
    expect(
      buildShortlistWhere({ ...base, path: 'post_bac', stratum: 'linked' })
        .cycle,
    ).toEqual({ in: ['licence1', 'but1', 'deust', 'sante'] });
  });

  // La branche qui fait l'intérêt de la fonctionnalité : un master dont le
  // domaine n'est PAS celui déclaré, mais qui conseille une licence qui l'est.
  it('accepte le lien par le domaine de la formation OU par ses licences conseillées',
    () => {
      const where = buildShortlistWhere({ ...base, stratum: 'linked' });
      const own = row({ fieldId: 'd02', recommendedFieldIds: [] });
      const viaRecommended = row({
        fieldId: 'd11',
        recommendedFieldIds: ['d02'],
      });
      const neither = row({ fieldId: 'd11', recommendedFieldIds: ['d09'] });

      for (const candidate of [own, viaRecommended]) {
        expect(
          matchesWhere(where, {
            ...candidate,
            isActive: true,
            countryId: 'france',
            admissionModes: ['Dossier'],
          } as unknown as Record<string, unknown>),
        ).toBe(true);
      }
      expect(
        matchesWhere(where, {
          ...neither,
          isActive: true,
          countryId: 'france',
          admissionModes: ['Dossier'],
        } as unknown as Record<string, unknown>),
      ).toBe(false);
    });

  it('exclut de la strate « ouverte » ce que la première a déjà servi', () => {
    // Sans cette exclusion, un master « Toutes licences » du bon domaine
    // occuperait deux places de l'étage avec la même fiche.
    const open = buildShortlistWhere({ ...base, stratum: 'open' });
    const target = {
      isActive: true,
      countryId: 'france',
      cycle: 'master',
      fieldId: 'd02',
      recommendedFieldIds: [],
      recommendedBachelors: ['Toutes licences'],
      admissionModes: ['Dossier'],
    };
    expect(matchesWhere(open, target)).toBe(false);
    expect(
      matchesWhere(open, { ...target, fieldId: 'd11' }),
    ).toBe(true);
  });

  it('ne resserre rien quand aucun domaine n’est déclaré', () => {
    // Poser `fieldId: { in: [] }` aurait rendu zéro résultat, donc une liste
    // vide indiscernable d'un catalogue vide.
    const where = buildShortlistWhere({
      ...base,
      declaredFieldIds: [],
      stratum: 'linked',
    });
    const [, stratumClause] = where.AND as Record<string, unknown>[];
    expect(stratumClause).toEqual({});
  });

  // La contre-épreuve du défaut qui a existé : l'étage et la strate emploient
  // tous deux `OR` et `NOT`. Fusionnés à plat, le second écrasait le premier,
  // et la strate « ouverte » effaçait l'exclusion de l'étage « sécurité » —
  // des masters à entretien étaient alors servis comme « dossier seul ».
  //
  // Ce test rejoue la clause COMPOSÉE, seule forme où la collision se voit :
  // les tests de `tierWhere` seul l'avaient laissée passer.
  it("compose l'étage et la strate sans qu'aucune condition n'en efface une autre",
    () => {
      const interviewed = {
        isActive: true,
        countryId: 'france',
        cycle: 'master',
        fieldId: 'd11',
        recommendedFieldIds: [],
        recommendedBachelors: ['Toutes licences'],
        admissionModes: ['Dossier', 'Entretien'],
      };
      // Il relève de « cible » : aucune strate ne doit le faire entrer dans
      // « sécurité ».
      for (const stratum of ['linked', 'open', 'any'] as const) {
        expect(
          matchesWhere(
            buildShortlistWhere({ ...base, tier: 'securite', stratum }),
            interviewed,
          ),
        ).toBe(false);
      }
      expect(
        matchesWhere(
          buildShortlistWhere({ ...base, tier: 'cible', stratum: 'open' }),
          interviewed,
        ),
      ).toBe(true);
    });

  it('range chaque formation dans exactement un étage, strate par strate', () => {
    const MODES = [...Object.keys(ADMISSION_MODE_EFFORT), 'Tirage'];
    for (const admissionModes of subsets(MODES)) {
      for (const stratum of ['linked', 'open'] as const) {
        const candidate = {
          isActive: true,
          countryId: 'france',
          cycle: 'master',
          fieldId: 'd02',
          recommendedFieldIds: [],
          recommendedBachelors: ['Toutes licences'],
          admissionModes,
        };
        const matched = EEF_SHORTLIST_TIERS.filter((tier) =>
          matchesWhere(buildShortlistWhere({ ...base, tier, stratum }),
            candidate),
        );
        // La strate « ouverte » exclut cette fiche (son domaine est déclaré),
        // donc zéro étage ; la strate « liée » la range dans l'étage que
        // `tierOf` calcule. Dans les deux cas : jamais deux étages.
        expect({ admissionModes, stratum, matched }).toEqual({
          admissionModes,
          stratum,
          matched: stratum === 'open'
            ? []
            : [tierOf(row({ admissionModes }), 'master')],
        });
      }
    }
  });

  it('compte l’étage entier sur « any », réunion des deux strates', () => {
    const any = buildShortlistWhere({ ...base, stratum: 'any' });
    const target = {
      isActive: true,
      countryId: 'france',
      cycle: 'master',
      fieldId: 'd11',
      recommendedFieldIds: [],
      recommendedBachelors: ['Toutes licences'],
      admissionModes: ['Dossier'],
    };
    // Servie par la strate « ouverte », donc elle DOIT être comptée : sinon
    // l'étage annoncerait « 3 formations » en en montrant cinq.
    expect(matchesWhere(any, target)).toBe(true);
    expect(
      matchesWhere(any, { ...target, recommendedFieldIds: ['d02'],
        recommendedBachelors: [] }),
    ).toBe(true);
  });
});

describe('reasonsFor', () => {
  it('nomme le domaine déclaré et la licence conseillée séparément', () => {
    const reasons = reasonsFor(
      row({ fieldId: 'd02', recommendedFieldIds: ['d02', 'd09'] }),
      ['d02'],
      'master',
    );
    expect(reasons).toContainEqual({ code: 'field_declared', value: 'd02' });
    expect(reasons).toContainEqual({
      code: 'bachelor_domain_recommended',
      value: 'd02',
    });
    // Un domaine conseillé mais NON déclaré ne justifie rien auprès de cet
    // étudiant : il n'a pas à figurer dans sa justification.
    expect(reasons).not.toContainEqual({
      code: 'bachelor_domain_recommended',
      value: 'd09',
    });
  });

  it('signale « Toutes licences » comme l’information qu’elle est', () => {
    const reasons = reasonsFor(
      row({ recommendedBachelors: ['Toutes licences'] }),
      [],
      'master',
    );
    expect(reasons).toContainEqual({
      code: 'bachelor_any_accepted',
      value: 'Toutes licences',
    });
  });

  it('ne sert aucun motif pour une modalité qu’il ne sait pas lire', () => {
    // Inventer un libellé donnerait à l'écran une phrase qu'il ne sait pas
    // traduire, et à l'étudiant une justification que rien n'atteste.
    const reasons = reasonsFor(row({ admissionModes: ['Tirage'] }), [],
      'master');
    expect(reasons).toEqual([]);
  });

  // La sélectivité vaut `selective` pour les 3 112 masters : c'est la loi du
  // 23 décembre 2016, pas une caractéristique de l'établissement. L'émettre
  // partout ajouterait à chaque fiche une justification qui ne justifie rien.
  it('n’émet la sélectivité que là où elle distingue', () => {
    const candidate = row({ selectivity: 'selective', admissionModes: [] });
    expect(reasonsFor(candidate, [], 'master')).toEqual([]);
    expect(reasonsFor(candidate, [], 'post_bac')).toEqual([
      { code: 'selectivity_arbitrated', value: 'selective' },
    ]);
  });

  it('rend deux fois la même liste pour la même formation', () => {
    const candidate = row({
      fieldId: 'd02',
      recommendedFieldIds: ['d09', 'd02', 'd05'],
      admissionModes: ['Dossier', 'Entretien'],
    });
    const first = reasonsFor(candidate, ['d05', 'd02'], 'master');
    const second = reasonsFor(candidate, ['d05', 'd02'], 'master');
    expect(first).toEqual(second);
    // Et dans un ordre stable : une justification qui clignote d'un appel à
    // l'autre se lit comme une liste qui change d'avis.
    expect(first.filter((r) => r.code === 'bachelor_domain_recommended'))
      .toEqual([
        { code: 'bachelor_domain_recommended', value: 'd02' },
        { code: 'bachelor_domain_recommended', value: 'd05' },
      ]);
  });
});

describe('clampShortlistLimit', () => {
  it('retombe sur la valeur par défaut plutôt que de refuser la liste', () => {
    for (const raw of [undefined, '', 'beaucoup', '0', '-3']) {
      expect(clampShortlistLimit(raw)).toBe(EEF_SHORTLIST_DEFAULT_LIMIT);
    }
  });

  it('borne par le haut', () => {
    expect(clampShortlistLimit('3')).toBe(3);
    expect(clampShortlistLimit('999')).toBe(EEF_SHORTLIST_MAX_LIMIT);
  });
});
