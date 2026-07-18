import { describe, expect, it } from 'vitest';

import {
  formatDateTime,
  formatDateTimeInZone,
  formatUsdMicros,
  getApiErrorStatus,
  isEndpointUnavailable,
  normalizeCountryCode,
} from './readiness-utils';

describe('competition readiness UI utilities', () => {
  it('recognizes missing endpoint responses without masking other failures', () => {
    const notFound = Object.assign(new Error('Not found'), { status: 404 });
    const forbidden = Object.assign(new Error('Forbidden'), { status: 403 });

    expect(getApiErrorStatus(notFound)).toBe(404);
    expect(isEndpointUnavailable(notFound)).toBe(true);
    expect(isEndpointUnavailable(forbidden)).toBe(false);
  });

  it('normalizes bounded country filters', () => {
    expect(normalizeCountryCode(' ne ')).toBe('NE');
    expect(normalizeCountryCode('civ-long')).toBe('CIV');
  });

  it('does not manufacture invalid date or cost values', () => {
    expect(formatDateTime('invalid', 'fr')).toBe('—');
    expect(
      formatDateTimeInZone(
        '2026-08-02T09:00:00.000Z',
        'fr',
        'Not/A_Timezone',
      ),
    ).toBe('—');
    expect(formatUsdMicros('not-a-number', 'fr')).toBe('—');
  });

  it('formats real micro-dollar values without integer truncation', () => {
    expect(formatUsdMicros('1250000', 'en')).toBe('$1.25');
  });

  it('formats scheduling dates in their recorded timezone', () => {
    expect(
      formatDateTimeInZone(
        '2026-08-02T09:00:00.000Z',
        'fr',
        'Africa/Niamey',
      ),
    ).not.toBe('—');
  });
});
