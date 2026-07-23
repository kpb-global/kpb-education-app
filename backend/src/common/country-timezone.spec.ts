import {
  isWithinQuietHours,
  localHourFor,
  utcOffsetHoursForCountry,
} from './country-timezone';

describe('country-timezone', () => {
  it('maps francophone residences to their offset, accent/format-insensitive', () => {
    expect(utcOffsetHoursForCountry('SN')).toBe(0); // Senegal
    expect(utcOffsetHoursForCountry('Sénégal')).toBe(0);
    expect(utcOffsetHoursForCountry('senegal')).toBe(0);
    expect(utcOffsetHoursForCountry('NE')).toBe(1); // Niger
    expect(utcOffsetHoursForCountry("Côte d'Ivoire")).toBe(0);
    expect(utcOffsetHoursForCountry('Cameroun')).toBe(1);
    expect(utcOffsetHoursForCountry('FRA')).toBe(1);
  });

  it('falls back to UTC+0 for unknown or empty residences', () => {
    expect(utcOffsetHoursForCountry(undefined)).toBe(0);
    expect(utcOffsetHoursForCountry('')).toBe(0);
    expect(utcOffsetHoursForCountry('Atlantis')).toBe(0);
  });

  it('computes the local hour from a UTC date + offset', () => {
    const utc = new Date('2026-07-23T23:00:00Z');
    expect(localHourFor(utc, 0)).toBe(23);
    expect(localHourFor(utc, 1)).toBe(0); // wraps past midnight
    expect(localHourFor(utc, 4)).toBe(3);
  });

  it('detects the midnight-wrapping quiet window (21:00–08:00)', () => {
    const at = (h: number) =>
      new Date(`2026-07-23T${String(h).padStart(2, '0')}:00:00Z`);
    expect(isWithinQuietHours(at(23), 0, 21, 8)).toBe(true);
    expect(isWithinQuietHours(at(3), 0, 21, 8)).toBe(true);
    expect(isWithinQuietHours(at(7), 0, 21, 8)).toBe(true);
    expect(isWithinQuietHours(at(8), 0, 21, 8)).toBe(false); // window end is exclusive
    expect(isWithinQuietHours(at(10), 0, 21, 8)).toBe(false);
    expect(isWithinQuietHours(at(20), 0, 21, 8)).toBe(false);
  });

  it('never marks everything quiet when the window is degenerate', () => {
    const noon = new Date('2026-07-23T12:00:00Z');
    expect(isWithinQuietHours(noon, 0, 8, 8)).toBe(false);
  });
});
