import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { describe, expect, it } from 'vitest';

import {
  INSTITUTION_REFUSALS,
  PROGRAM_REFUSALS,
  refusalMessageKey,
} from './eef-publication';

// Ce que l'écran de publication affiche doit exister, dans les deux langues, et
// dire la même chose que ce que le serveur refuse. Trois dérives possibles, trois
// tests : un motif serveur sans libellé, un libellé dans une seule langue, une
// clé référencée par la page mais absente des messages.

type Messages = Record<string, unknown>;
const load = (locale: string): Messages =>
  JSON.parse(readFileSync(join(__dirname, '..', 'messages', `${locale}.json`), 'utf8'));
const fr = load('fr');
const en = load('en');

function lookup(messages: Messages, key: string): unknown {
  return key
    .split('.')
    .reduce<unknown>(
      (current, part) =>
        current && typeof current === 'object' ? (current as Messages)[part] : undefined,
      messages,
    );
}

function leafKeys(value: unknown, prefix = ''): string[] {
  if (value && typeof value === 'object') {
    return Object.entries(value as Messages).flatMap(([key, child]) =>
      leafKeys(child, prefix ? `${prefix}.${key}` : key),
    );
  }
  return [prefix];
}

describe('messages de la publication EEF', () => {
  it('donnent les mêmes clés en français et en anglais', () => {
    expect(leafKeys(fr.eefPub).sort()).toEqual(leafKeys(en.eefPub).sort());
  });

  it.each([...INSTITUTION_REFUSALS, ...PROGRAM_REFUSALS])(
    'le motif de refus %s a un libellé dans les deux langues',
    (code) => {
      for (const messages of [fr, en]) {
        const label = lookup(messages, refusalMessageKey(code));
        expect(typeof label).toBe('string');
        expect((label as string).length).toBeGreaterThan(3);
      }
    },
  );

  it('ne laisse aucun texte vide', () => {
    for (const messages of [fr, en]) {
      for (const key of leafKeys(messages.eefPub, 'eefPub')) {
        const text = lookup(messages, key);
        expect(typeof text === 'string' && text.trim() !== '').toBe(true);
      }
    }
  });

  it('couvre chaque clé `t(\'eefPub…\')` que la page utilise', () => {
    const page = readFileSync(
      join(__dirname, '..', 'app', 'etudes-en-france', 'publication', 'page.tsx'),
      'utf8',
    );
    const used = new Set(
      [...page.matchAll(/t\(\s*['`](eefPub\.[A-Za-z_.]+)['`]/g)].map((m) => m[1]),
    );
    expect(used.size).toBeGreaterThan(20);
    for (const key of used) {
      expect({ key, fr: typeof lookup(fr, key) }).toEqual({ key, fr: 'string' });
      expect({ key, en: typeof lookup(en, key) }).toEqual({ key, en: 'string' });
    }
  });

  // Les motifs viennent du serveur : cette liste doit être EXACTEMENT celle de
  // `eef-publication.plan.ts`. Lue sur le fichier, pas recopiée.
  it('énumère exactement les motifs de refus du serveur', () => {
    const plan = readFileSync(
      join(
        __dirname,
        '..',
        '..',
        'backend',
        'src',
        'modules',
        'etudes-en-france',
        'publication',
        'eef-publication.plan.ts',
      ),
      'utf8',
    );
    const declared = (type: string) => {
      const block = plan.match(new RegExp(`export type ${type} =([^;]+);`))?.[1] ?? '';
      return [...block.matchAll(/'([a-z_]+)'/g)].map((m) => m[1]).sort();
    };
    expect([...INSTITUTION_REFUSALS].sort()).toEqual(declared('InstitutionRefusal'));
    expect([...PROGRAM_REFUSALS].sort()).toEqual(declared('ProgramRefusal'));
  });
});
