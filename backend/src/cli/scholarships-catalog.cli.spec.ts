import { buildScholarshipCreateData } from '../modules/scholarships-index/data/scholarship-catalog.create-data';
import { SCHOLARSHIP_CATALOG_V1 } from '../modules/scholarships-index/data/scholarship-catalog.v1';
import { validateScholarshipCatalog } from '../modules/scholarships-index/data/scholarship-catalog.validator';

import {
  LEGACY_SEED_IDS,
  decidePublication,
  issuesByRecordIndex,
  parseArgs,
  refuseSwitchReason,
} from './scholarships-catalog.cli';

/**
 * Fabrique la ligne Prisma telle qu'elle existera après `import`, à partir de la
 * fiche du catalogue. On teste donc la décision de publication sur la forme
 * réelle des données, pas sur une maquette qui pourrait diverger.
 */
function rowFromRecord(index: number) {
  const record = SCHOLARSHIP_CATALOG_V1.records[index];
  const data = buildScholarshipCreateData(
    record,
    SCHOLARSHIP_CATALOG_V1.catalogVersion,
  );
  const { applicationSteps, cycles, ...rest } = data;
  return {
    ...rest,
    applicationSteps: applicationSteps.create,
    cycles: [cycles.create],
  } as never;
}

describe('scholarships-catalog CLI', () => {
  describe('parseArgs', () => {
    it('refuses a run without exactly one mode', () => {
      expect(parseArgs(['publish'])).toBe(
        'Choose exactly one mode: --dry-run or --apply.',
      );
      expect(parseArgs(['publish', '--apply', '--dry-run'])).toBe(
        'Choose exactly one mode: --dry-run or --apply.',
      );
    });

    it('refuses an unknown command', () => {
      expect(parseArgs(['deploy', '--apply'])).toContain('Usage:');
    });

    it('refuses --confirmed-only on import, where it would mean nothing', () => {
      expect(parseArgs(['import', '--apply', '--confirmed-only'])).toContain(
        '--confirmed-only applies to publish and switch',
      );
    });

    it('accepts the switch command used for the production cutover', () => {
      expect(parseArgs(['switch', '--apply', '--confirmed-only'])).toEqual({
        command: 'switch',
        apply: true,
        confirmedOnly: true,
      });
    });
  });

  describe('issuesByRecordIndex', () => {
    // C'est le mécanisme qui remplace le refus global. Le refus global était la
    // falaise : une seule campagne close rendait les 33 autres fiches
    // inimportables.
    it('attributes each issue to the record it belongs to', () => {
      const map = issuesByRecordIndex({
        valid: false,
        catalogVersion: '1.3.0',
        uniqueRecordCount: 0,
        uniqueRecordDeficit: 0,
        verifiedCounts: { secondary: 0, bachelor: 0, master: 0 },
        backlogCounts: { secondary: 0, bachelor: 0, master: 0 },
        volumeDeficits: { secondary: 0, bachelor: 0, master: 0 },
        backlogDeficits: { secondary: 0, bachelor: 0, master: 0 },
        issues: [
          {
            code: 'open_cycle_already_closed',
            path: 'records[16].cycle',
            message: 'x',
          },
          { code: 'missing_text', path: 'records[3].scholarship.nameFr', message: 'x' },
          { code: 'invalid_catalog_version', path: 'catalogVersion', message: 'x' },
        ],
      });

      expect(map.get(16)).toEqual(['open_cycle_already_closed']);
      expect(map.get(3)).toEqual(['missing_text']);
      expect(map.has(0)).toBe(false);
      // Une anomalie globale n'est rattachée à aucune fiche et ne doit donc
      // jamais faire écarter une fiche en particulier.
      expect([...map.keys()].sort((a, b) => a - b)).toEqual([3, 16]);
    });
  });

  describe('decidePublication', () => {
    const now = new Date('2026-08-17T18:00:00.000Z');

    // La valeur numérique est le critère : si quelqu'un annule la correction de
    // la porte de qualité, ce compte tombe à 25 et McCall MacBain disparaît de
    // la liste. « Les tests passent » ne l'aurait pas montré.
    it('publishes exactly the 31 eligible records of catalog 1.3.0', () => {
      const decisions = SCHOLARSHIP_CATALOG_V1.records.map((_, index) =>
        decidePublication(rowFromRecord(index), now, false),
      );
      const published = decisions.filter((item) => item.publish).map((i) => i.id);

      expect(published).toHaveLength(31);
      expect(published).toContain('mccall_macbain_2027');
      expect(decisions.filter((item) => !item.publish).map((i) => i.id).sort()).toEqual([
        'daad_helmut_schmidt_2027',
        'rhodes_southern_africa_2027',
        'uct_international_refugee_2027',
      ]);
    });

    it('publishes only the 11 confirmed-date records under --confirmed-only', () => {
      const published = SCHOLARSHIP_CATALOG_V1.records
        .map((_, index) => decidePublication(rowFromRecord(index), now, true))
        .filter((item) => item.publish);

      expect(published).toHaveLength(11);
      expect(published.every((item) => item.confidence === 'confirmed')).toBe(true);
      // La fiche qui justifie la fenêtre du 17 août : sa clôture réelle est le
      // 19 août 2026 à 20:00 UTC.
      expect(published.map((item) => item.id)).toContain('mccall_macbain_2027');
    });

    it('refuses a record whose closing date has already passed', () => {
      const index = SCHOLARSHIP_CATALOG_V1.records.findIndex(
        (record) => record.scholarship.id === 'mccall_macbain_2027',
      );
      const decision = decidePublication(
        rowFromRecord(index),
        new Date('2026-08-20T00:00:00.000Z'),
        false,
      );

      expect(decision.publish).toBe(false);
      expect(decision.reason).toContain('passée');
    });
  });

  describe('LEGACY_SEED_IDS', () => {
    it('names the 11 demonstration records served in production', () => {
      expect(LEGACY_SEED_IDS).toHaveLength(11);
      // Les identifiants legacy et ceux du catalogue vérifié ne se recouvrent
      // pas : dépublier les uns ne touche jamais les autres.
      const verified = new Set(
        SCHOLARSHIP_CATALOG_V1.records.map((record) => record.scholarship.id),
      );
      expect(LEGACY_SEED_IDS.filter((id) => verified.has(id))).toEqual([]);
      expect(LEGACY_SEED_IDS).toContain('mccall_macbain');
    });
  });


  describe('refuseSwitchReason', () => {
    // Reproduit l'incident du 14/08/2026 : `switch` lancé sans `import`, aucune
    // ligne portant le tag du catalogue, 0 fiche publiée, 11 fiches legacy
    // dépubliées quand même, 0 bourse servie aux utilisateurs.
    it('refuses a switch that would publish nothing and unpublish the legacy records', () => {
      const reason = refuseSwitchReason([], true);

      expect(reason).not.toBeNull();
      expect(reason).toContain("laisserait l'onglet Bourses vide");
      expect(reason).toContain('catalog:import --apply');
    });

    it('names the records it discarded when some were found but none eligible', () => {
      const reason = refuseSwitchReason(
        [
          { id: 'a_2027', publish: false, reason: 'clôture passée', confidence: 'confirmed' },
          { id: 'b_2027', publish: false, reason: 'porte de qualité', confidence: 'estimated' },
        ],
        true,
      );

      expect(reason).toContain('a_2027');
      expect(reason).toContain('clôture passée');
      expect(reason).toContain('b_2027');
    });

    it('lets a switch through as soon as one record is publishable', () => {
      expect(
        refuseSwitchReason(
          [
            { id: 'a_2027', publish: true, reason: 'éligible', confidence: 'confirmed' },
            { id: 'b_2027', publish: false, reason: 'écartée', confidence: 'estimated' },
          ],
          true,
        ),
      ).toBeNull();
    });

    // `publish` seul ne dépublie rien : publier 0 fiche est alors sans effet
    // visible, et refuser serait un faux positif.
    it('never blocks a publish-only run, which unpublishes nothing', () => {
      expect(refuseSwitchReason([], false)).toBeNull();
    });
  });
});
