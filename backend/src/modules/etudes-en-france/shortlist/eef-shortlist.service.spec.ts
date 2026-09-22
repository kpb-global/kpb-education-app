// Le service de shortlist, contre une doublure qui INSPECTE les requêtes.
//
// Ce que ces tests vérifient n'est pas « la liste contient cinq éléments »,
// c'est « quelle question a-t-on posée à la base ». Une shortlist est une
// recommandation nominative : les deux façons dont elle peut mentir sans
// planter sont de recommander des lignes non relues, et d'annoncer un total
// qui ne décrit pas ce qu'elle montre.
import { HttpException } from '@nestjs/common';

import { EefShortlistService } from './eef-shortlist.service';
import { PrismaService } from '../../prisma/prisma.service';

function programRow(over: Record<string, unknown> = {}) {
  return {
    id: 'p-1',
    institutionId: 'eef-univ-0353074b',
    countryId: 'france',
    fieldId: 'd02',
    nameFr: 'Master — Management',
    nameEn: 'Master — Management',
    levelFr: 'Bac+5 — Master',
    levelEn: 'Bac+5 — Master',
    durationFr: '2 ans',
    durationEn: '2 years',
    tuitionFr: 'x',
    tuitionEn: 'x',
    languageFr: 'Français',
    languageEn: 'French',
    requirementsFr: ['x'],
    requirementsEn: ['x'],
    campusOfferings: null,
    minGpaRequired: null,
    tuitionMinEur: null,
    applicationDeadline: null,
    teachingLanguages: ['fr'],
    cycle: 'master',
    selectivity: 'selective',
    recommendedBachelors: ['Economie et gestion'],
    recommendedFieldIds: ['d02'],
    admissionModes: ['Dossier'],
    lastVerifiedAt: null,
    sourceUrl: 'https://exemple.gouv.fr/x',
    verifiedById: null,
    verifiedByName: null,
    ...over,
  };
}

type Captured = { calls: Record<string, unknown>[] };

/**
 * Une clause qui ne peut rendre aucune ligne — `{ id: { in: [] } }`.
 *
 * C'est ainsi que `tierWhere` interdit un étage qui n'a pas de socle publié :
 * « cible » sur l'axe sélectivité, et les trois étages classés sur un chemin
 * sans axe. La doublure l'honore, sans quoi elle rendrait les mêmes lignes à
 * chaque requête et ces garanties ne seraient testées par rien.
 */
function isImpossible(clause: unknown): boolean {
  if (Array.isArray(clause)) return clause.some(isImpossible);
  if (!clause || typeof clause !== 'object') return false;
  const entries = Object.entries(clause as Record<string, unknown>);
  return entries.some(([key, value]) => {
    if (key === 'id') {
      const op = value as { in?: unknown[] };
      if (Array.isArray(op?.in) && op.in.length === 0) return true;
    }
    return isImpossible(value);
  });
}

function serviceWith(opts: {
  interest?: Record<string, unknown> | null;
  rows?: Record<string, unknown>[];
  total?: number;
  countries?: { id: string; code: string }[];
  isEnabled?: boolean;
  throws?: boolean;
}) {
  const captured: Captured = { calls: [] };
  const client: Record<string, unknown> = {
    country: {
      findMany: async () => opts.countries ?? [{ id: 'france', code: 'FRA' }],
    },
    eefInterest: {
      findUnique: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'interest', ...args });
        return opts.interest === undefined
          ? {
              currentLevel: 'licence',
              targetLevel: 'master',
              fieldIds: ['d02'],
            }
          : opts.interest;
      },
    },
    program: {
      findMany: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'findMany', ...args });
        return isImpossible(args.where) ? [] : (opts.rows ?? []);
      },
      count: async (args: Record<string, unknown>) => {
        captured.calls.push({ kind: 'count', ...args });
        return isImpossible(args.where) ? 0 : (opts.total ?? 0);
      },
    },
    $transaction: async (
      ps: Promise<unknown>[],
      options?: Record<string, unknown>,
    ) => {
      captured.calls.push({ kind: 'transaction', ...options });
      return Promise.all(ps);
    },
  };
  const prisma = {
    isEnabled: opts.isEnabled ?? true,
    execute: async (op: (c: unknown) => Promise<unknown>) => {
      if (opts.throws) throw new Error('ECONNREFUSED');
      return op(client);
    },
  } as unknown as PrismaService;
  return { service: new EefShortlistService(prisma), captured };
}

function findManyWheres(captured: Captured): Record<string, unknown>[] {
  return captured.calls
    .filter((call) => call.kind === 'findMany')
    .map((call) => call.where as Record<string, unknown>);
}

describe('EefShortlistService', () => {
  describe('la barrière du relu', () => {
    it('ne recommande que des lignes publiées, sur le bon pays', async () => {
      // Recommander nominativement une fiche que personne n'a relue est la
      // pire surface possible pour cette barrière.
      const { service, captured } = serviceWith({ rows: [programRow()] });
      await service.getShortlist('u-1');
      const wheres = findManyWheres(captured);
      expect(wheres.length).toBeGreaterThan(0);
      for (const where of wheres) {
        expect(where.isActive).toBe(true);
        expect(where.countryId).toBe('france');
      }
    });

    it('résout le pays par son CODE, alpha-3 comme alpha-2', async () => {
      const { service, captured } = serviceWith({
        rows: [programRow()],
        countries: [{ id: 'fra', code: 'FRA' }, { id: 'mar', code: 'MA' }],
      });
      await service.getShortlist('u-1');
      expect(findManyWheres(captured)[0].countryId).toBe('fra');
    });

    it('refuse d’avancer si la France est ambiguë ou absente', async () => {
      for (const countries of [
        [],
        [{ id: 'a', code: 'FR' }, { id: 'b', code: 'FRA' }],
      ]) {
        const { service } = serviceWith({ countries });
        await expect(service.getShortlist('u-1'))
          .rejects.toBeInstanceOf(HttpException);
      }
    });

    it('rend 503 plutôt qu’un échantillon quand la base est absente', async () => {
      // `/catalog/*` sait dégrader vers les jeux de démonstration. Ici non :
      // il n'existe aucun échantillon « Études en France », et en fabriquer un
      // ferait recommander des établissements qui n'existent pas.
      for (const opts of [{ isEnabled: false }, { throws: true }]) {
        const { service } = serviceWith(opts);
        await expect(service.getShortlist('u-1'))
          .rejects.toBeInstanceOf(HttpException);
      }
    });
  });

  describe('l’état « je ne peux pas encore »', () => {
    it('rend 200 et un motif, pas une erreur', async () => {
      // La lecture a réussi ; ce qui manque est une réponse de l'étudiant. Un
      // 4xx ferait afficher un écran de panne là où il faut poser une question.
      const { service, captured } = serviceWith({ interest: null });
      const result = await service.getShortlist('u-1');

      expect(result.blocked).toBe('no_declaration');
      expect(result.path).toBeNull();
      expect(result.tiers).toEqual([]);
      expect(result.declaration).toBeNull();
      // Et surtout : aucune requête de catalogue n'a été posée.
      expect(findManyWheres(captured)).toEqual([]);
    });

    it('n’interroge pas le catalogue pour une déclaration illisible', async () => {
      const { service, captured } = serviceWith({
        interest: { currentLevel: 'terminale', targetLevel: 'master', fieldIds: [] },
      });
      const result = await service.getShortlist('u-1');
      expect(result.blocked).toBe('declaration_unmappable');
      expect(findManyWheres(captured)).toEqual([]);
    });

    it('dit ce qui manque, même bloqué', async () => {
      const { service } = serviceWith({
        interest: { currentLevel: 'licence', targetLevel: null, fieldIds: ['d02'] },
      });
      const result = await service.getShortlist('u-1');
      expect(result.blocked).toBe('target_level_missing');
      // La déclaration partielle est RENVOYÉE : l'écran doit pouvoir
      // pré-remplir ce que l'étudiant avait déjà dit.
      expect(result.declaration).toEqual({
        currentLevel: 'licence',
        targetLevel: null,
        fieldIds: ['d02'],
      });
      expect(result.disclosures).toContain('tuition_not_published');
    });
  });

  describe('la cohérence de ce qui est servi', () => {
    it('lit les étages et leurs totaux dans UNE transaction isolée', async () => {
      // Servis séparément, un import concurrent rendrait « 412 formations »
      // au-dessus d'un étage qui en montre cinq autres.
      const { service, captured } = serviceWith({ rows: [programRow()] });
      await service.getShortlist('u-1');
      const transactions = captured.calls.filter(
        (call) => call.kind === 'transaction',
      );
      expect(transactions).toHaveLength(1);
      expect(transactions[0].isolationLevel).toBe('RepeatableRead');
    });

    it('compte l’étage ENTIER, pas la strate qui l’a rempli', async () => {
      // Compter la seule strate « liée » pouvait annoncer un total inférieur
      // au nombre servi — « 5 formations sur 3 ».
      const { service, captured } = serviceWith({
        rows: [programRow()],
        total: 412,
      });
      const result = await service.getShortlist('u-1');
      const counts = captured.calls.filter((call) => call.kind === 'count');
      expect(counts.length).toBeGreaterThan(0);
      for (const tier of result.tiers) {
        expect(tier.total).toBe(412);
        expect(tier.items.length).toBeLessThanOrEqual(tier.total);
      }
    });

    it('ne sert jamais deux fois la même formation dans un étage', async () => {
      // Les deux strates peuvent rendre la même ligne : la seconde ne fait que
      // compléter.
      const { service } = serviceWith({ rows: [programRow(), programRow()] });
      const result = await service.getShortlist('u-1');
      for (const tier of result.tiers) {
        const ids = tier.items.map(
          (item) => (item.program as { id: string }).id,
        );
        expect(new Set(ids).size).toBe(ids.length);
      }
    });

    // Une colonne vide se lit « rien pour toi », ce qui est faux quand les
    // autres étages sont pleins.
    it('ne sert pas un étage vide', async () => {
      const { service } = serviceWith({ rows: [] });
      const result = await service.getShortlist('u-1');
      expect(result.tiers).toEqual([]);
      expect(result.blocked).toBeNull();
      expect(result.path).toBe('master');
    });

    it('borne la taille demandée sans refuser la liste', async () => {
      const { service, captured } = serviceWith({ rows: [programRow()] });
      const result = await service.getShortlist('u-1', '999');
      expect(result.limit).toBe(10);
      for (const call of captured.calls.filter((c) => c.kind === 'findMany')) {
        expect(call.take).toBe(10);
      }
    });
  });

  describe('ce que la réponse avoue', () => {
    it('nomme l’axe de classement pour que l’écran puisse le dire', async () => {
      const { service } = serviceWith({ rows: [programRow()] });
      const result = await service.getShortlist('u-1');
      expect(result.ranking.basis).toBe('admission_effort');
    });

    // Le constat qui a façonné la fonctionnalité : sur ce chemin, aucune donnée
    // ouverte ne classe. La réponse le DIT au lieu de rendre trois colonnes.
    it('avoue l’absence d’axe sur le chemin L2/L3', async () => {
      const { service, captured } = serviceWith({
        interest: { currentLevel: 'licence', targetLevel: 'licence', fieldIds: ['d02'] },
        rows: [programRow({ cycle: 'licence3', admissionModes: [] })],
      });
      const result = await service.getShortlist('u-1');
      expect(result.path).toBe('licence_continuation');
      expect(result.ranking.basis).toBeNull();
      expect(result.disclosures).toContain('no_ranking_data');
      // Les trois étages classés sont interrogés avec une clause qui ne peut
      // rien rendre : la garantie vit dans la REQUÊTE, pas dans la confiance.
      expect(result.tiers.map((tier) => tier.tier)).toEqual(['unranked']);
      const asked = findManyWheres(captured);
      expect(asked.filter((where) => isImpossible(where))).toHaveLength(6);
    });

    it('avoue qu’aucun domaine n’a été déclaré', async () => {
      const { service } = serviceWith({
        interest: { currentLevel: 'licence', targetLevel: 'master', fieldIds: [] },
        rows: [programRow()],
      });
      const result = await service.getShortlist('u-1');
      expect(result.disclosures).toContain('no_field_declared');
    });

    it('dit toujours ce qu’il ne sait pas des frais, du français et des dates',
      async () => {
        const { service } = serviceWith({ rows: [programRow()] });
        const result = await service.getShortlist('u-1');
        expect(result.disclosures).toEqual(
          expect.arrayContaining([
            'tuition_not_published',
            'french_level_not_published',
            'campaign_dates_served_separately',
          ]),
        );
      });

    it('ne sert aucun pourcentage, nulle part', async () => {
      // Le catalogue ne publie ni taux d'admission, ni capacité d'accueil, ni
      // nombre de candidats : un « 72 % de chances » aurait été un nombre
      // inventé portant l'autorité d'un nombre mesuré.
      const { service } = serviceWith({ rows: [programRow()], total: 12 });
      const result = await service.getShortlist('u-1');
      const serialized = JSON.stringify(result);
      expect(serialized).not.toMatch(/probability|percent|score|chance/i);
    });

    it('justifie chaque formation par des faits attestés', async () => {
      const { service } = serviceWith({
        rows: [programRow({ fieldId: 'd11', recommendedFieldIds: ['d02'] })],
      });
      const result = await service.getShortlist('u-1');
      const [item] = result.tiers[0].items;
      // Le domaine du master n'est PAS celui déclaré ; c'est sa licence
      // conseillée qui l'est. Exactement l'ouverture qu'un filtre par domaine
      // ne montrerait jamais.
      expect(item.reasons).toContainEqual({
        code: 'bachelor_domain_recommended',
        value: 'd02',
      });
      expect(item.reasons).not.toContainEqual({
        code: 'field_declared',
        value: 'd11',
      });
      expect(item.reasons).toContainEqual({
        code: 'admission_file_only',
        value: 'Dossier',
      });
    });
  });
});
