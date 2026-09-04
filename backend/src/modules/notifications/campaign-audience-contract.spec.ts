import { readFileSync } from 'fs';
import { join } from 'path';

import {
  AUDIENCE_REQUIRED_FILTER,
  AUDIENCE_TYPES,
  audienceFilterMissing,
} from './campaign-audience';

/**
 * Le contrat d'audience doit tenir des deux côtés : chaque valeur acceptée par
 * le DTO doit avoir une branche dans l'exécuteur (sinon 0 destinataire en
 * silence), et chaque branche de l'exécuteur doit être acceptée par le DTO
 * (sinon 400 sur une fonctionnalité qui existe).
 */
function executorAudiences(): Set<string> {
  const source = readFileSync(
    join(__dirname, 'campaign-executor.service.ts'),
    'utf8',
  );
  const start = source.indexOf('private async resolveRecipients');
  expect(start).toBeGreaterThan(-1);
  const body = source.slice(start);
  return new Set(
    Array.from(
      body.slice(0, body.indexOf('\n  }\n')).matchAll(/case '([a-z_]+)':/g),
    ).map((m) => m[1]),
  );
}

describe('Contrat d’audience des campagnes', () => {
  it('chaque audience déclarée a une branche dans l’exécuteur', () => {
    const missing = AUDIENCE_TYPES.filter((a) => !executorAudiences().has(a));
    expect(missing).toEqual([]);
  });

  it('chaque branche de l’exécuteur est déclarée', () => {
    const orphans = [...executorAudiences()].filter(
      (a) => !AUDIENCE_TYPES.includes(a),
    );
    expect(orphans).toEqual([]);
  });

  it('la liste n’est pas vide (le test lit bien quelque chose)', () => {
    expect(AUDIENCE_TYPES.length).toBeGreaterThan(4);
  });

  // ── L'asymétrie qui rendait une diffusion accidentelle possible ──────────
  //
  // Seules les audiences dont le NOM annonce une diffusion peuvent se passer
  // de filtre. Toute autre doit en exiger un : `where: undefined` en Prisma ne
  // veut pas dire « personne » mais « tous les comptes ».
  it('seules all_users et all_students peuvent se passer de filtre', () => {
    const unfiltered = AUDIENCE_TYPES.filter(
      (a) => AUDIENCE_REQUIRED_FILTER[a] === null,
    );
    expect(unfiltered.sort()).toEqual(['all_students', 'all_users']);
  });

  describe('audienceFilterMissing', () => {
    it('accepte un filtre présent', () => {
      expect(audienceFilterMissing('country', { countryId: 'NE' })).toBe(false);
      expect(audienceFilterMissing('study_level', { levels: ['L1'] })).toBe(
        false,
      );
    });

    it('refuse absent, vide, blanc, ou tableau vide', () => {
      expect(audienceFilterMissing('country', {})).toBe(true);
      expect(audienceFilterMissing('country', { countryId: '' })).toBe(true);
      expect(audienceFilterMissing('country', { countryId: '   ' })).toBe(true);
      expect(audienceFilterMissing('country', { countryId: null })).toBe(true);
      expect(audienceFilterMissing('study_level', { levels: [] })).toBe(true);
    });

    it('ne bloque jamais une diffusion assumée', () => {
      expect(audienceFilterMissing('all_users', {})).toBe(false);
      expect(audienceFilterMissing('all_students', {})).toBe(false);
    });

    // Une clé mal orthographiée ne doit pas passer pour un filtre valide.
    it('ne se laisse pas berner par une clé voisine', () => {
      expect(audienceFilterMissing('country', { country: 'NE' })).toBe(true);
      expect(audienceFilterMissing('account_type', { type: 'student' })).toBe(
        true,
      );
    });
  });
});
