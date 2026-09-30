import {
  capFairly,
  compareVerificationItems,
  countryVerificationDueWhere,
  institutionVerificationDueWhere,
  programVerificationDueWhere,
  scholarshipVerificationDueWhere,
  verificationDueWhere,
  type VerificationQueueEntry,
} from './verification-due';

const DAY = 24 * 60 * 60 * 1000;
const NOW = new Date('2026-09-29T12:00:00.000Z');

describe('verification-due — les prédicats', () => {
  it('coupent à now − cadence, dans ce sens-là', () => {
    // Un `+` au lieu du `−` compterait comme « à revérifier » tout ce qui vient
    // d'être vérifié ; une cadence lue à 30 jours au lieu de 180 compterait les
    // trois quarts de la file. Aucun de ces deux défauts ne fait échouer un test
    // qui se contente d'une `Date` quelconque.
    expect(verificationDueWhere(180, NOW)).toEqual({
      OR: [
        { lastVerifiedAt: null },
        { lastVerifiedAt: { lt: new Date(NOW.getTime() - 180 * DAY) } },
      ],
    });
    expect(verificationDueWhere(30, NOW)).toEqual({
      OR: [
        { lastVerifiedAt: null },
        { lastVerifiedAt: { lt: new Date(NOW.getTime() - 30 * DAY) } },
      ],
    });
  });

  it('ne comptent que les pays ACTIFS', () => {
    expect(countryVerificationDueWhere(30, NOW)).toEqual({
      isActive: true,
      ...verificationDueWhere(30, NOW),
    });
  });

  it('ne comptent que les bourses ACTIVES et APPROUVÉES', () => {
    // Une bourse en attente de modération n'est pas publiée : la revérifier est
    // du travail pour rien, et la compter gonfle l'alerte.
    expect(scholarshipVerificationDueWhere(30, NOW)).toEqual({
      isActive: true,
      moderationStatus: 'approved',
      ...verificationDueWhere(30, NOW),
    });
  });

  it('retirent des établissements et des formations les seules lignes EEF EN ATTENTE', () => {
    expect(institutionVerificationDueWhere(180, NOW)).toEqual({
      AND: [
        verificationDueWhere(180, NOW),
        {
          NOT: {
            AND: [{ id: { startsWith: 'eef-univ-' } }, { isActive: false }],
          },
        },
      ],
    });
    expect(programVerificationDueWhere(180, NOW)).toEqual({
      AND: [
        verificationDueWhere(180, NOW),
        {
          NOT: {
            AND: [{ id: { startsWith: 'eef-prog-' } }, { isActive: false }],
          },
        },
      ],
    });
  });
});

// ─── L'ordre ─────────────────────────────────────────────────────────────────

function entry(
  overrides: Partial<VerificationQueueEntry> & { id: string },
): VerificationQueueEntry {
  const cadenceDays = overrides.cadenceDays ?? 180;
  const lastVerifiedAt =
    'lastVerifiedAt' in overrides ? overrides.lastVerifiedAt! : null;
  return {
    entityType: 'program',
    category: 'program_scolarite',
    cadenceDays,
    lastVerifiedAt,
    dueAt: lastVerifiedAt
      ? new Date(lastVerifiedAt.getTime() + cadenceDays * DAY)
      : null,
    ...overrides,
  };
}
const verifiedDaysAgo = (days: number) => new Date(NOW.getTime() - days * DAY);

describe('compareVerificationItems — ce qui presse d’abord', () => {
  it('met les jamais-vérifiés devant les vérifiés', () => {
    const sorted = [
      entry({ id: 'old', lastVerifiedAt: verifiedDaysAgo(900) }),
      entry({ id: 'never' }),
    ].sort(compareVerificationItems);
    expect(sorted.map((e) => e.id)).toEqual(['never', 'old']);
  });

  it('parmi les jamais-vérifiés, met le plus PÉRISSABLE devant', () => {
    // Une bourse (30 jours) avant une formation (180), quel que soit l'ordre des
    // identifiants.
    const sorted = [
      entry({ id: 'a-program', cadenceDays: 180 }),
      entry({
        id: 'z-scholarship',
        entityType: 'scholarship',
        category: 'scholarship_deadline',
        cadenceDays: 30,
      }),
    ].sort(compareVerificationItems);
    expect(sorted.map((e) => e.id)).toEqual(['z-scholarship', 'a-program']);
  });

  it('parmi les vérifiés, trie sur le RETARD et non sur l’âge', () => {
    // Le défaut : une formation vérifiée il y a 181 jours est en retard d'UN jour ;
    // une bourse vérifiée il y a 100 jours l'est de 70. L'âge brut plaçait la
    // formation devant, et le plafond écartait la bourse.
    const program = entry({ id: 'program-181', lastVerifiedAt: verifiedDaysAgo(181) });
    const scholarship = entry({
      id: 'scholarship-100',
      entityType: 'scholarship',
      category: 'scholarship_deadline',
      cadenceDays: 30,
      lastVerifiedAt: verifiedDaysAgo(100),
    });

    const sorted = [program, scholarship].sort(compareVerificationItems);

    expect(sorted.map((e) => e.id)).toEqual(['scholarship-100', 'program-181']);
  });

  it('départage à la milliseconde, pas au jour', () => {
    // Deux fiches en retard de 200 jours, à quelques heures d'écart : le jour
    // entier ne les distingue pas, l'échéance si.
    const a = entry({ id: 'a', lastVerifiedAt: new Date(NOW.getTime() - 380 * DAY) });
    const b = entry({
      id: 'b',
      lastVerifiedAt: new Date(NOW.getTime() - 380 * DAY - 3 * 60 * 60 * 1000),
    });
    expect([a, b].sort(compareVerificationItems).map((e) => e.id)).toEqual([
      'b',
      'a',
    ]);
  });

  it('est un ordre TOTAL : le même résultat, quel que soit l’ordre d’entrée', () => {
    // Des milliers de formations partagent leur nom (jusqu'à 476 identiques) : sans
    // départage final, la page tronquée change d'un appel à l'autre.
    const items = Array.from({ length: 40 }, (_, i) =>
      entry({
        id: `p-${String(i).padStart(2, '0')}`,
        // Beaucoup d'égalités exprès.
        lastVerifiedAt: i % 4 === 0 ? null : verifiedDaysAgo(200 + (i % 3)),
      }),
    );
    const reference = [...items].sort(compareVerificationItems).map((e) => e.id);

    // Mélanges déterministes (générateur congruentiel), pas de hasard.
    let seed = 12345;
    const next = () => (seed = (seed * 1103515245 + 12345) % 2147483648);
    for (let round = 0; round < 25; round++) {
      const shuffled = [...items].sort(() => (next() % 3) - 1);
      expect(shuffled.sort(compareVerificationItems).map((e) => e.id)).toEqual(
        reference,
      );
    }
  });
});

// ─── La coupe ────────────────────────────────────────────────────────────────

describe('capFairly — un plafond qui n’affame aucune catégorie', () => {
  function queue(spec: Array<[category: string, count: number, cadenceDays: number]>) {
    return spec
      .flatMap(([category, count, cadenceDays]) =>
        Array.from({ length: count }, (_, i) =>
          entry({
            id: `${category}-${String(i).padStart(4, '0')}`,
            entityType: category,
            category,
            cadenceDays,
          }),
        ),
      )
      .sort(compareVerificationItems);
  }

  it('rend la file telle quelle sous le plafond, et à égalité avec lui', () => {
    const sorted = queue([['program_scolarite', 500, 180]]);
    expect(capFairly(sorted, 500)).toEqual(sorted);
    expect(capFairly(sorted.slice(0, 3), 500)).toEqual(sorted.slice(0, 3));
  });

  /**
   * Deux universités publiées d'un coup : plus de 800 formations « jamais
   * vérifiées ». Les bourses — la seule catégorie qui périme en 30 jours — sont
   * vérifiées, en retard de 15 jours : elles passent APRÈS les jamais-vérifiés.
   */
  function pileUp() {
    const programs = queue([['program_scolarite', 830, 180]]);
    const overdue = [
      ...['s1', 's2', 's3'].map((id) =>
        entry({
          id,
          entityType: 'scholarship',
          category: 'scholarship_deadline',
          cadenceDays: 30,
          lastVerifiedAt: verifiedDaysAgo(45),
        }),
      ),
      ...['c1', 'c2'].map((id) =>
        entry({
          id,
          entityType: 'country',
          category: 'country_visa',
          cadenceDays: 30,
          lastVerifiedAt: verifiedDaysAgo(60),
        }),
      ),
    ];
    return [...programs, ...overdue].sort(compareVerificationItems);
  }

  it('garde les bourses et les pays en retard quand 800 formations les précèdent', () => {
    const sorted = pileUp();

    // Sans la coupe équitable, les 500 premiers sont 500 formations.
    expect(sorted.slice(0, 500).some((e) => e.category === 'scholarship_deadline')).toBe(false);

    const capped = capFairly(sorted, 500);

    expect(capped).toHaveLength(500);
    expect(capped.filter((e) => e.category === 'scholarship_deadline')).toHaveLength(3);
    expect(capped.filter((e) => e.category === 'country_visa')).toHaveLength(2);
    expect(capped.filter((e) => e.category === 'program_scolarite')).toHaveLength(495);
  });

  it('garde l’ordre global : les places réservées ne passent pas devant le pot commun', () => {
    // Le défaut visé : réserver d'abord (formations 0–165, puis les bourses et les
    // pays), COMPLÉTER ensuite (formations 166–494), et rendre les lignes dans
    // l'ordre où on les a choisies. Les bourses se retrouveraient alors avant 329
    // formations qui les précèdent dans la file. Un scénario où la catégorie
    // réservée n'arrive qu'après le pot commun est le seul qui distingue les deux
    // ordres : sur trois catégories dont les grosses viennent en dernier, le
    // résultat est identique dans les deux.
    const sorted = pileUp();
    const capped = capFairly(sorted, 500);

    // Exactement : les 495 premières formations, puis les cinq lignes en retard,
    // dans l'ordre de la file.
    expect(capped).toEqual([...sorted.slice(0, 495), ...sorted.slice(830)]);

    const positions = capped.map((item) => sorted.indexOf(item));
    expect(positions).toEqual([...positions].sort((a, b) => a - b));
    expect(new Set(positions).size).toBe(capped.length);
  });

  it('réserve au moins limite ÷ catégories à chacune, quand elles ont de quoi', () => {
    const sorted = queue([
      ['country_visa', 1000, 30],
      ['institution_scolarite', 1000, 180],
      ['program_scolarite', 1000, 180],
      ['scholarship_deadline', 1000, 30],
    ]);
    const capped = capFairly(sorted, 500);
    for (const category of [
      'country_visa',
      'institution_scolarite',
      'program_scolarite',
      'scholarship_deadline',
    ]) {
      expect(capped.filter((e) => e.category === category).length).toBeGreaterThanOrEqual(125);
    }
    expect(capped).toHaveLength(500);
  });

  it('rend à la file commune les places qu’une catégorie n’utilise pas', () => {
    // Quatre catégories, 125 places réservées chacune : trois formations et deux
    // pays n'en utilisent que cinq. Les 120 restantes ne doivent pas rester vides.
    const sorted = queue([
      ['country_visa', 2, 30],
      ['scholarship_deadline', 3, 30],
      ['institution_scolarite', 1000, 180],
      ['program_scolarite', 1000, 180],
    ]);
    const capped = capFairly(sorted, 500);
    expect(capped).toHaveLength(500);
    expect(capped.filter((e) => e.category === 'country_visa')).toHaveLength(2);
    expect(capped.filter((e) => e.category === 'scholarship_deadline')).toHaveLength(3);
  });
});
