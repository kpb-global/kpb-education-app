import { randomUUID } from 'node:crypto';

import { Prisma, PrismaClient } from '@prisma/client';

import {
  EEF_INSTITUTION_ID_PREFIX,
  EEF_PROGRAM_ID_PREFIX,
} from '../../../common/eef-provenance';
import type { PrismaService } from '../../prisma/prisma.service';
import {
  FRANCE_COUNTRY_CODES,
  resolveFranceCountryId,
} from '../catalog/eef-country';
import { buildShortlistWhere } from './eef-shortlist.rank';
import { EefShortlistService } from './eef-shortlist.service';

/**
 * La shortlist du chemin post-bac, prouvée contre un vrai Postgres.
 *
 * Les doubles de `eef-shortlist.service.spec.ts` prouvent QUELLE question est
 * posée, et l'évaluateur de `eef-shortlist.rank.spec.ts` la rejoue avec la
 * logique à trois valeurs de SQL. Aucun des deux ne dit ce que Postgres répond
 * à un `IN` sur une colonne qui peut être NULL : c'est le contrat de la base,
 * pas celui d'un double.
 *
 * ## Les lignes, et ce que chacune prouve
 *
 * Toutes sous un même établissement PUBLIÉ de l'import, dans le domaine déclaré :
 * seules leur procédure et leur cycle les distinguent.
 *
 *   L1 en DAP blanche, non sélective   le cas de la décision n° 5 du 02/10/2026 :
 *                                      servie, mais « non classée », jamais
 *                                      « sécurité ».
 *   L1 en DAP blanche, sélective       servie, non classée : « ambition » n'a
 *                                      plus rien à quoi s'opposer.
 *   L1 en DAP jaune                    servie : c'est une DAP.
 *   BUT en procédure EEF               servi : la procédure de l'espace, hors DAP.
 *   L1 de Sciences Po, `hors_eef`      écartée : admission propre à
 *                                      l'établissement.
 *   DCG, `parcoursup`                  écarté : autre plateforme, autre
 *                                      calendrier.
 *   L1 sans procédure, saisie à la main
 *                                      écartée, comme par la recherche.
 *   cycle d'ingénieur, `hors_eef`      écarté, mais par le cycle : il est hors
 *                                      du chemin, quelle que soit sa procédure.
 *
 * Les comptes sont des ÉCARTS (avant / après l'insertion), et le domaine
 * (`FIELD`) est propre à l'exécution : une base qui porte déjà le catalogue
 * n'invalide pas les lectures. Les restes d'une exécution interrompue sont
 * purgés au démarrage par des motifs qu'aucun identifiant d'import réel ne peut
 * satisfaire (`eef-prog-<hex>`, `eef-univ-<uai>` : ni « -sl- », ni « -sl »).
 */
const describePostgres =
  process.env.KPB_RUN_POSTGRES_INTEGRATION === 'true'
    ? describe
    : describe.skip;

describePostgres('Shortlist EEF, chemin post-bac — intégration PostgreSQL', () => {
  jest.setTimeout(60_000);

  const prisma = new PrismaClient();
  const sfx = randomUUID().replace(/-/g, '').slice(0, 12);

  /// Un domaine que personne d'autre n'utilise : il isole la shortlist de tout
  /// ce que la base contient déjà.
  const FIELD = `zz${sfx}`;
  const USER_ID = `it-eef-sl-${sfx}`;

  const ids = {
    institution: `${EEF_INSTITUTION_ID_PREFIX}${sfx}-sl`,
    dapOpen: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-dap-open`,
    dapSelective: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-dap-sel`,
    dapJaune: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-dap-jaune`,
    but: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-but`,
    sciencesPo: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-scpo`,
    dcg: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-dcg`,
    engineering: `${EEF_PROGRAM_ID_PREFIX}${sfx}-sl-inge`,
    // Saisie à la main : identifiant généré, sans le préfixe de l'import. C'est
    // son établissement qui la rattache à l'import.
    manual: `it-eef-sl-manual-${sfx}`,
  };
  const SERVED = [ids.dapOpen, ids.dapSelective, ids.dapJaune, ids.but];
  /// Écartées par la procédure, et par elle seule : le témoin les retrouve.
  const OUT_OF_PROCEDURE = [ids.sciencesPo, ids.dcg, ids.manual];
  const programIds = [...SERVED, ...OUT_OF_PROCEDURE, ids.engineering];

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (client: PrismaClient) => Promise<T>) =>
      operation(prisma),
  } as unknown as PrismaService;
  const shortlist = new EefShortlistService(prismaService);

  let franceId = '';
  /// Renseigné seulement si CE test a créé la France : c'est alors à lui de la
  /// retirer. Une base déjà semée garde la sienne.
  let createdCountryId: string | null = null;
  let totalBefore = 0;

  function program(
    id: string,
    nameFr: string,
    overrides: Partial<Prisma.ProgramUncheckedCreateInput>,
  ): Prisma.ProgramUncheckedCreateInput {
    return {
      id,
      institutionId: ids.institution,
      countryId: franceId,
      fieldId: FIELD,
      nameFr: `${nameFr} ${sfx}`,
      nameEn: `${nameFr} ${sfx}`,
      levelFr: 'Licence',
      levelEn: "Bachelor's",
      durationFr: '3 ans',
      durationEn: '3 years',
      tuitionFr: 'Test',
      tuitionEn: 'Test',
      languageFr: 'Français',
      languageEn: 'French',
      requirementsFr: [],
      requirementsEn: [],
      cycle: 'licence1',
      selectivity: 'selective',
      campusCity: 'Rennes',
      isActive: true,
      lastVerifiedAt: new Date(),
      ...overrides,
    };
  }

  async function shortlistOf() {
    const result = await shortlist.getShortlist(USER_ID, '10');
    const items = result.tiers.flatMap((tier) => tier.items);
    return {
      result,
      // Nos lignes seulement : sur une base semée, la strate « Toutes licences »
      // pourrait compléter l'étage avec des formations réelles.
      mine: items.filter((item) =>
        programIds.includes((item.program as { id: string }).id),
      ),
      total: result.tiers.reduce((sum, tier) => sum + tier.total, 0),
    };
  }

  const sorted = (list: readonly string[]) => [...list].sort();

  async function purgeLeftovers() {
    await prisma.eefInterest.deleteMany({
      where: { userId: { startsWith: 'it-eef-sl-' } },
    });
    await prisma.userProfile.deleteMany({
      where: { id: { startsWith: 'it-eef-sl-' } },
    });
    await prisma.program.deleteMany({
      where: {
        OR: [
          {
            AND: [
              { id: { startsWith: EEF_PROGRAM_ID_PREFIX } },
              { id: { contains: '-sl-' } },
            ],
          },
          { id: { startsWith: 'it-eef-sl-manual-' } },
        ],
      },
    });
    await prisma.institution.deleteMany({
      where: {
        AND: [
          { id: { startsWith: EEF_INSTITUTION_ID_PREFIX } },
          { id: { endsWith: '-sl' } },
        ],
      },
    });
  }

  beforeAll(async () => {
    await purgeLeftovers();

    // ── La France : réutilisée si la base est semée, créée sinon ────────────
    // Même règle que le service (`eef-country.ts`) : les pays ACTIFS dont le
    // code, normalisé, est FR ou FRA.
    const activeCountries = await prisma.country.findMany({
      where: { isActive: true },
      select: { id: true, code: true },
    });
    const frances = activeCountries.filter((country) =>
      (FRANCE_COUNTRY_CODES as readonly string[]).includes(
        (country.code ?? '').trim().toUpperCase(),
      ),
    );
    if (frances.length === 1) {
      franceId = resolveFranceCountryId(activeCountries);
    } else if (frances.length === 0) {
      createdCountryId = `it-fra-${sfx}`;
      await prisma.country.create({
        data: {
          id: createdCountryId,
          code: 'FRA',
          nameFr: 'France (test)',
          nameEn: 'France (test)',
          whyStudyFr: 'Test.',
          whyStudyEn: 'Test.',
          tuitionRangeFr: 'Test.',
          tuitionRangeEn: 'Test.',
          livingCostRangeFr: 'Test.',
          livingCostRangeEn: 'Test.',
          visaOverviewFr: 'Test.',
          visaOverviewEn: 'Test.',
          admissionDifficultyFr: 'Test.',
          admissionDifficultyEn: 'Test.',
          popularFieldIds: [],
          lastVerifiedAt: new Date(),
        },
      });
      franceId = createdCountryId;
    } else {
      throw new Error(
        `Base inutilisable pour ce test : ${frances.length} pays actifs de code `
          + 'FR/FRA. La résolution de la France en exige exactement un.',
      );
    }

    // ── L'élève de terminale qui vise une licence : le chemin post-bac ──────
    await prisma.userProfile.create({
      data: {
        id: USER_ID,
        accountType: 'student',
        preferredLanguage: 'fr',
        fullName: 'Élève de test',
        email: `${USER_ID}@example.test`,
        phone: '+22900000000',
        countryOfResidence: 'SN',
        fieldIds: [FIELD],
        targetCountryIds: [franceId],
      },
    });
    await prisma.eefInterest.create({
      data: {
        userId: USER_ID,
        currentLevel: 'terminale',
        targetLevel: 'licence',
        fieldIds: [FIELD],
        consentVersion: 'integration-test',
        consentedAt: new Date(),
      },
    });

    totalBefore = (await shortlistOf()).total;

    // ── Les lignes ──────────────────────────────────────────────────────────
    await prisma.institution.create({
      data: {
        id: ids.institution,
        nameFr: `Université ${sfx}`,
        nameEn: `University ${sfx}`,
        countryId: franceId,
        locationFr: 'Rennes',
        locationEn: 'Rennes',
        overviewFr: 'Test.',
        overviewEn: 'Test.',
        studyLevels: ['licence'],
        tuitionLabelFr: 'Test',
        tuitionLabelEn: 'Test',
        languageRequirementsFr: 'Test',
        languageRequirementsEn: 'Test',
        intakePeriods: [],
        programIds: [],
        institutionType: 'universite_publique',
        isActive: true,
        lastVerifiedAt: new Date(),
      },
    });
    await prisma.program.createMany({
      data: [
        program(ids.dapOpen, 'L1 - Droit', {
          procedureType: 'dap_blanche',
          selectivity: 'non_selective',
        }),
        program(ids.dapSelective, 'L1 - Économie, sélective', {
          procedureType: 'dap_blanche',
        }),
        program(ids.dapJaune, 'L1 - Architecture', {
          procedureType: 'dap_jaune',
        }),
        program(ids.but, 'BUT - Informatique', {
          procedureType: 'eef',
          cycle: 'but1',
        }),
        program(ids.sciencesPo, 'L1 - Histoire (Sciences Po)', {
          procedureType: 'hors_eef',
        }),
        program(ids.dcg, 'DCG - Diplôme de Comptabilité et de Gestion', {
          procedureType: 'parcoursup',
        }),
        program(ids.manual, 'L1 - Saisie à la main', {
          procedureType: null,
          selectivity: 'non_selective',
        }),
        program(ids.engineering, 'Cycle ingénieur', {
          procedureType: 'hors_eef',
          cycle: 'ingenieur',
        }),
      ],
    });
  }, 60_000);

  afterAll(async () => {
    // `finally` : un `deleteMany` qui lève ne doit ni sauter le reste du
    // nettoyage ni laisser la connexion ouverte (Jest ne se terminerait pas).
    try {
      await prisma.eefInterest.deleteMany({ where: { userId: USER_ID } });
      await prisma.userProfile.deleteMany({ where: { id: USER_ID } });
      await prisma.program.deleteMany({ where: { id: { in: programIds } } });
      await prisma.institution.deleteMany({ where: { id: ids.institution } });
      if (createdCountryId !== null) {
        await prisma.country.deleteMany({ where: { id: createdCountryId } });
      }
    } finally {
      await prisma.$disconnect();
    }
  }, 60_000);

  it('ne recommande que les formations qui se demandent par la procédure de l’espace', async () => {
    const { mine, total } = await shortlistOf();

    expect(
      sorted(mine.map((item) => (item.program as { id: string }).id)),
    ).toEqual(sorted(SERVED));
    // Le total compte ce que la liste montre : un total qui compterait la
    // Sciences Po, le DCG ou la ligne sans procédure annoncerait des
    // formations qu'elle ne montrera jamais.
    expect(total - totalBefore).toBe(SERVED.length);
  });

  it('les écarte par la clause de procédure, et par elle seule', async () => {
    const where = buildShortlistWhere({
      path: 'post_bac',
      countryId: franceId,
      declaredFieldIds: [FIELD],
      tier: 'unranked',
      stratum: 'any',
      publishedInstitutionIds: [ids.institution],
    });
    const idsOf = async (clause: Record<string, unknown>) =>
      sorted(
        (
          await prisma.program.findMany({
            where: { AND: [clause, { id: { in: programIds } }] } as never,
            select: { id: true },
          })
        ).map((row) => row.id),
      );

    expect(await idsOf(where)).toEqual(sorted(SERVED));

    // Le témoin : la même clause, sans la procédure. Les trois lignes écartées
    // y reviennent — y compris celle dont la procédure est NULL —, preuve que
    // rien d'autre ne les retenait. Le cycle d'ingénieur, lui, reste dehors :
    // c'est le cycle qui l'écarte.
    const { procedureType, ...withoutProcedure } = where;
    expect(procedureType).toEqual({ in: ['dap_blanche', 'dap_jaune', 'eef'] });
    expect(await idsOf(withoutProcedure)).toEqual(
      sorted([...SERVED, ...OUT_OF_PROCEDURE]),
    );
  });

  it('sert le chemin sans étage : la L1 non sélective n’est pas « sécurité »', async () => {
    const { result, mine } = await shortlistOf();

    expect(result.path).toBe('post_bac');
    expect(result.blocked).toBeNull();
    expect(result.ranking.basis).toBeNull();
    expect(result.disclosures).toContain('no_ranking_data');
    expect(result.tiers.map((tier) => tier.tier)).toEqual(['unranked']);
    // Et rien ne justifie une ligne par sa sélectivité : seul le domaine
    // déclaré, qui est un fait sur l'étudiant.
    for (const item of mine) {
      expect(item.reasons).toEqual([{ code: 'field_declared', value: FIELD }]);
    }
  });
});
