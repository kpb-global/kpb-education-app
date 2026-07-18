import { describe, expect, it } from 'vitest';

import {
  agreementStatusVariant,
  parseCodeList,
  parseCountryCodes,
  parseJsonObject,
  pilotStatusVariant,
  toUtcFormValue,
  toUtcIso,
} from './impact-admin-utils';

describe('impact administration UI utilities', () => {
  it('normalizes deduplicated codes without accepting malformed countries', () => {
    expect(parseCodeList('pilot_recruitment, aggregate_reporting;pilot_recruitment')).toEqual([
      'pilot_recruitment',
      'aggregate_reporting',
    ]);
    expect(parseCountryCodes('ne, ci NE')).toEqual(['NE', 'CI']);
    expect(parseCountryCodes('NER')).toBeNull();
  });

  it('accepts JSON objects only', () => {
    expect(parseJsonObject('{"level":"master"}')).toEqual({ level: 'master' });
    expect(parseJsonObject('["master"]')).toBeNull();
    expect(parseJsonObject('{invalid')).toBeNull();
  });

  it('converts explicitly labelled UTC form values and rejects ambiguity', () => {
    expect(toUtcIso('2026-08-01T09:30')).toBe('2026-08-01T09:30:00.000Z');
    expect(toUtcFormValue('2026-08-01T09:30:45.000Z')).toBe('2026-08-01T09:30');
    expect(toUtcIso('2026-08-01')).toBeNull();
    expect(toUtcIso('not-a-date')).toBeNull();
  });

  it('keeps lifecycle badges semantic', () => {
    expect(agreementStatusVariant('active')).toBe('success');
    expect(agreementStatusVariant('terminated')).toBe('danger');
    expect(pilotStatusVariant('recruiting')).toBe('info');
    expect(pilotStatusVariant('analysis')).toBe('warning');
  });
});
