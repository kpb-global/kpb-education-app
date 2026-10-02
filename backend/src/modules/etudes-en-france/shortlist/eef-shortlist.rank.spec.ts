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
    recommendedBachelors: [],
    recommendedFieldIds: [],
    admissionModes: [],
    ...over,
  };
}

/// La même ligne, avec la sélectivité que la base lui donne aussi. Ni `tierOf`
/// ni `reasonsFor` ne doivent la lire : les tests qui s'en servent la font
/// varier pour le prouver.
function rowWithSelectivity(
  selectivity: string | null,
  over: Partial<EefCandidateRow> = {},
): EefCandidateRow {
  return Object.assign(row(over), { selectivity });
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
    } else if ('startsWith' in op) {
      if (actual === null || actual === undefined) parts.push(null);
      else
        parts.push(
          typeof actual === 'string' && actual.startsWith(op.startsWith as string),
        );
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

  // La décision n° 5 du 02/10/2026 : « non sélective » est la catégorie
  // Parcoursup des élèves de terminale française. Pour un candidat en DAP — et
  // les 2 428 non sélectives du chemin le sont toutes —, l'université examine
  // le dossier et peut le refuser. « Sécurité » promettait le contraire, et
  // « ambition » pour les autres n'avait plus rien à quoi s'opposer.
  it('ne range plus une L1 non sélective en « sécurité » : le post-bac n’a pas d’étage',
    () => {
      for (const selectivity of ['non_selective', 'selective', null]) {
        for (const admissionModes of [[], ['Dossier'], ['Concours']]) {
          const candidate = rowWithSelectivity(selectivity, {
            cycle: 'licence1',
            admissionModes,
          });
          expect({
            selectivity,
            admissionModes,
            tier: tierOf(candidate, 'post_bac'),
          }).toEqual({ selectivity, admissionModes, tier: 'unranked' });
        }
      }
    });

  // Le constat qui a façonné toute la fonctionnalité : sur ce chemin, TOUTES
  // les lignes du catalogue sont `selective` et aucune ne publie de modalité.
  // Rendre trois étages y aurait été une invention pure.
  it('ne classe rien sur le chemin L2/L3, quelles que soient les données', () => {
    for (const modes of [[], ['Dossier'], ['Concours']]) {
      for (const selectivity of ['selective', 'non_selective', null]) {
        expect(
          tierOf(rowWithSelectivity(selectivity, { admissionModes: modes }),
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

  // Les étages classés sont interdits PAR LA REQUÊTE, pas par la confiance
  // dans l'appelant ; et « non classé » rend tout, sans quoi une ligne
  // disparaîtrait de la liste sans avoir été classée nulle part. Ni la
  // sélectivité — NULL comprise — ni les modalités n'y changent rien.
  it('met tout dans « non classé » sur les chemins sans axe', () => {
    for (const path of ['post_bac', 'licence_continuation'] as const) {
      for (const selectivity of ['selective', 'non_selective', 'inconnue', null]) {
        for (const admissionModes of [[], ['Dossier'], ['Entretien', 'Concours']]) {
          const candidate = rowWithSelectivity(selectivity, { admissionModes });
          const matched = EEF_SHORTLIST_TIERS.filter((tier) =>
            matchesWhere(
              tierWhere(tier, path),
              candidate as unknown as Record<string, unknown>,
            ),
          );
          expect({
            path,
            selectivity,
            admissionModes,
            matched,
            inMemory: tierOf(candidate, path),
          }).toEqual({
            path,
            selectivity,
            admissionModes,
            matched: ['unranked'],
            inMemory: 'unranked',
          });
        }
      }
    }
  });
});

describe('buildShortlistWhere', () => {
  /// L'établissement PUBLIÉ des lignes d'essai. Sans lui, aucune ligne ne
  /// satisfait la clause : la formation n'est recommandable que si son parent
  /// est publié.
  const PUBLISHED = 'eef-univ-0353074b';
  const base = {
    path: 'master' as EefEntryPath,
    countryId: 'france',
    declaredFieldIds: ['d02'],
    tier: 'securite' as EefShortlistTier,
    publishedInstitutionIds: [PUBLISHED],
  };

  it('ne sort jamais du relu ni du bon pays', () => {
    for (const stratum of ['linked', 'open', 'any'] as const) {
      const where = buildShortlistWhere({ ...base, stratum });
      expect(where.isActive).toBe(true);
      expect(where.countryId).toBe('france');
    }
  });

  // ── Le parent doit être publié ────────────────────────────────────────────
  //
  // `Program` n'a pas de relation vers `Institution` : une formation publiée
  // sous une université que personne n'a relue était RECOMMANDÉE nominativement,
  // avec pour établissement une fiche non vérifiée.
  describe('l’établissement doit être publié', () => {
    const eligible = {
      isActive: true,
      countryId: 'france',
      cycle: 'master',
      procedureType: 'eef',
      fieldId: 'd02',
      recommendedFieldIds: [],
      recommendedBachelors: ['Toutes licences'],
      admissionModes: ['Dossier'],
    };

    it('recommande une formation dont l’établissement est publié', () => {
      const where = buildShortlistWhere({ ...base, stratum: 'linked' });
      expect(
        matchesWhere(where, { ...eligible, institutionId: PUBLISHED }),
      ).toBe(true);
    });

    it('ne recommande pas une formation dont l’établissement ne l’est pas', () => {
      // Étage, strate et comptage : la clause vaut pour TOUTES les variantes,
      // le total compris — un total qui compterait ces lignes annoncerait des
      // formations que la liste ne montrera jamais.
      for (const tier of EEF_SHORTLIST_TIERS) {
        for (const stratum of ['linked', 'open', 'any'] as const) {
          const where = buildShortlistWhere({ ...base, tier, stratum });
          expect({
            tier,
            stratum,
            served: matchesWhere(where, {
              ...eligible,
              fieldId: 'd02',
              institutionId: 'eef-univ-non-publiee',
            }),
          }).toEqual({ tier, stratum, served: false });
        }
      }
    });

    // ── La provenance : une seule définition de « EEF » ─────────────────────
    //
    // `cycle` filtre sur des valeurs qu'une formation partenaire pourrait aussi
    // porter le jour où l'exploitation la qualifie. Seule la PROVENANCE dit
    // « cette ligne vient de l'import » — la même que celle que le catalogue
    // général exclut.
    describe('la formation vient de l’import', () => {
      const PARTNER = 'omnes-essec';
      const both = { ...base, publishedInstitutionIds: [PUBLISHED, PARTNER] };
      const servedBy = (row: Record<string, unknown>) => {
        const served: string[] = [];
        for (const tier of EEF_SHORTLIST_TIERS) {
          for (const stratum of ['linked', 'open', 'any'] as const) {
            const where = buildShortlistWhere({ ...both, tier, stratum });
            if (matchesWhere(where, { ...eligible, fieldId: 'd02', ...row })) {
              served.push(`${tier}/${stratum}`);
            }
          }
        }
        return served;
      };

      it('ne recommande pas la formation d’une école partenaire publiée, même qualifiée', () => {
        // Établissement actif (donc dans la liste des publiés), cycle et domaine
        // compatibles : seule la provenance l'écarte.
        expect(
          servedBy({ id: 'omnes-p-42', institutionId: PARTNER }),
        ).toEqual([]);
        // Un identifiant généré (saisie manuelle) sous un établissement
        // partenaire ne change rien.
        expect(
          servedBy({ id: 'cm1abcdef0000', institutionId: PARTNER }),
        ).toEqual([]);
      });

      it('recommande une formation de l’import', () => {
        expect(
          servedBy({ id: 'eef-prog-0387ffdcaab99c8a', institutionId: PUBLISHED })
            .length,
        ).toBeGreaterThan(0);
      });

      it('compte aussi une formation saisie à la main sous une université de l’import', () => {
        // Même règle que `notEefProgram` : le parent EEF fait la ligne EEF.
        expect(
          servedBy({ id: 'cm1abcdef0000', institutionId: PUBLISHED }).length,
        ).toBeGreaterThan(0);
      });

      it('exclut une ligne dont on ne sait rien', () => {
        expect(servedBy({ id: undefined, institutionId: null })).toEqual([]);
      });
    });

    it('ne recommande pas une formation sans établissement connu', () => {
      // `NULL IN (…)` vaut NULL, donc faux : une ligne sans parent ne passe pas.
      const where = buildShortlistWhere({ ...base, stratum: 'linked' });
      expect(matchesWhere(where, { ...eligible, institutionId: null })).toBe(
        false,
      );
      expect(matchesWhere(where, { ...eligible })).toBe(false);
    });

    it('sans aucun établissement publié, ne recommande rien', () => {
      // La liste vide reste dans la clause : l'omettre servirait tout.
      for (const stratum of ['linked', 'open', 'any'] as const) {
        const where = buildShortlistWhere({
          ...base,
          stratum,
          publishedInstitutionIds: [],
        });
        expect(where.AND).toContainEqual({ institutionId: { in: [] } });
        expect(
          matchesWhere(where, { ...eligible, institutionId: PUBLISHED }),
        ).toBe(false);
      }
    });

    it('copie la liste au lieu de la partager', () => {
      // Le service passe UNE liste à chaque requête d'étage et de total.
      const shared = [PUBLISHED];
      const where = buildShortlistWhere({
        ...base,
        stratum: 'linked',
        publishedInstitutionIds: shared,
      });
      const clause = (where.AND as { institutionId?: { in: string[] } }[]).find(
        (part) => part.institutionId !== undefined,
      )!;
      clause.institutionId!.in.push('intrus');
      expect(shared).toEqual([PUBLISHED]);
    });
  });

  it('restreint aux cycles du chemin, et à eux seuls', () => {
    expect(buildShortlistWhere({ ...base, stratum: 'linked' }).cycle)
      .toEqual({ in: ['master'] });
    expect(
      buildShortlistWhere({ ...base, path: 'post_bac', stratum: 'linked' })
        .cycle,
    ).toEqual({ in: ['licence1', 'but1', 'deust', 'sante'] });
  });

  // ── La procédure de l'espace ──────────────────────────────────────────────
  //
  // Le cycle ne dit pas la procédure. Depuis les décisions du 02/10/2026, la 1re
  // année de Sciences Po (Paris) est une `licence1` en `hors_eef`, le DCG une
  // `licence1` en `parcoursup` : sans clause de procédure, les deux entraient
  // dans le chemin post-bac, rangées parmi des formations qui se demandent par
  // la DAP.
  describe('la procédure de l’espace', () => {
    /// Une ligne que tout le reste de la clause laisse passer : publiée, en
    /// France, de l'import, sous un établissement publié, dans le domaine
    /// déclaré. Seule sa procédure varie.
    const candidate = {
      id: 'eef-prog-0387ffdcaab99c8a',
      isActive: true,
      countryId: 'france',
      institutionId: PUBLISHED,
      fieldId: 'd02',
      selectivity: 'selective',
      recommendedFieldIds: [],
      recommendedBachelors: [],
      admissionModes: [],
    };
    /// Un cycle de chaque chemin.
    const CYCLE_OF: Record<EefEntryPath, string> = {
      post_bac: 'licence1',
      licence_continuation: 'licence2',
      master: 'master',
    };
    const servedBy = (
      procedureType: unknown,
      path: EefEntryPath = 'post_bac',
    ) => {
      const served: string[] = [];
      for (const tier of EEF_SHORTLIST_TIERS) {
        for (const stratum of ['linked', 'open', 'any'] as const) {
          const where = buildShortlistWhere({ ...base, path, tier, stratum });
          if (
            matchesWhere(where, {
              ...candidate,
              cycle: CYCLE_OF[path],
              procedureType,
            })
          ) {
            served.push(`${tier}/${stratum}`);
          }
        }
      }
      return served;
    };

    it('pose la liste fermée sur chaque requête, chemin, étage et strate', () => {
      for (const path of Object.keys(CYCLE_OF) as EefEntryPath[]) {
        for (const tier of EEF_SHORTLIST_TIERS) {
          for (const stratum of ['linked', 'open', 'any'] as const) {
            expect(
              buildShortlistWhere({ ...base, path, tier, stratum })
                .procedureType,
            ).toEqual({ in: ['dap_blanche', 'dap_jaune', 'eef'] });
          }
        }
      }
    });

    it('sert les trois procédures de l’espace', () => {
      // Le témoin : sans lui, une clause qui n'écarterait rien passerait pour
      // une clause qui écarte bien. Le post-bac n'a pas d'étage, donc seule la
      // colonne « non classé » la rend — par la strate liée, et au total.
      for (const procedure of ['dap_blanche', 'dap_jaune', 'eef']) {
        expect({ procedure, served: servedBy(procedure) }).toEqual({
          procedure,
          served: ['unranked/linked', 'unranked/any'],
        });
      }
    });

    it('écarte la 1re année de Sciences Po (`hors_eef`) et le DCG (`parcoursup`)',
      () => {
        for (const procedure of ['hors_eef', 'parcoursup']) {
          expect({ procedure, served: servedBy(procedure) }).toEqual({
            procedure,
            served: [],
          });
        }
      });

    it('écarte une ligne sans procédure, comme la recherche', () => {
      // `NULL IN (…)` vaut NULL, donc faux : c'est la clause qui le dit, pas un
      // effet de bord d'une négation.
      expect(servedBy(null)).toEqual([]);
      expect(servedBy(undefined)).toEqual([]);
    });

    it('écarte une procédure que la liste ne connaît pas encore', () => {
      // Une valeur ajoutée demain au catalogue n'entre pas d'elle-même dans
      // une recommandation : il faut l'ajouter à la liste, donc le décider.
      expect(servedBy('campus_connecte')).toEqual([]);
    });

    it('applique la même règle sur chaque chemin', () => {
      for (const path of Object.keys(CYCLE_OF) as EefEntryPath[]) {
        expect({ path, served: servedBy('hors_eef', path) }).toEqual({
          path,
          served: [],
        });
        expect(servedBy('eef', path).length).toBeGreaterThan(0);
      }
    });
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
            institutionId: PUBLISHED,
            procedureType: 'eef',
            admissionModes: ['Dossier'],
          } as unknown as Record<string, unknown>),
        ).toBe(true);
      }
      expect(
        matchesWhere(where, {
          ...neither,
          isActive: true,
          countryId: 'france',
          institutionId: PUBLISHED,
          procedureType: 'eef',
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
      institutionId: PUBLISHED,
      cycle: 'master',
      procedureType: 'eef',
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
        institutionId: PUBLISHED,
        cycle: 'master',
        procedureType: 'eef',
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
          institutionId: PUBLISHED,
          cycle: 'master',
          procedureType: 'eef',
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
      institutionId: PUBLISHED,
      cycle: 'master',
      procedureType: 'eef',
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

  // Sur un master, la sélectivité vaut `selective` pour chaque ligne : c'est la
  // loi du 23 décembre 2016, pas une caractéristique de l'établissement. Sur le
  // chemin post-bac, « non sélective » est la catégorie Parcoursup des élèves
  // de terminale française, et ne dit rien d'un candidat en DAP. Dans les deux
  // cas, le motif justifierait ce qu'il ne justifie pas.
  it('n’émet aucun motif de sélectivité, sur aucun chemin', () => {
    for (const path of ['master', 'post_bac', 'licence_continuation'] as const) {
      for (const selectivity of ['selective', 'non_selective', null]) {
        expect({
          path,
          selectivity,
          reasons: reasonsFor(rowWithSelectivity(selectivity), [], path),
        }).toEqual({ path, selectivity, reasons: [] });
      }
    }
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
