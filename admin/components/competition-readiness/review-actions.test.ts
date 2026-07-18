import { describe, expect, it } from 'vitest';

import {
  canApplyReviewAction,
  canConvertReview,
  canOfferReviewSlots,
  isExplicitOffsetIsoDateTime,
  parseMissingItems,
  validateAvailabilityWindow,
  validateOfferExpiry,
} from './review-actions';

describe('review action presentation rules', () => {
  it('mirrors the backend transition sources', () => {
    expect(canApplyReviewAction('submitted', 'triage')).toBe(true);
    expect(canApplyReviewAction('triaged', 'triage')).toBe(false);
    expect(canApplyReviewAction('triaged', 'request_more_information')).toBe(
      true,
    );
    expect(canApplyReviewAction('call_offered', 'decline')).toBe(true);
    expect(canApplyReviewAction('declined', 'close')).toBe(true);
    expect(canApplyReviewAction('closed', 'assign')).toBe(false);
  });

  it('limits conversion and slot offers to backend-supported states', () => {
    expect(canConvertReview('scheduled')).toBe(true);
    expect(canConvertReview('submitted')).toBe(false);
    expect(canOfferReviewSlots('triaged', 'counsellor-1')).toBe(true);
    expect(canOfferReviewSlots('triaged', null)).toBe(false);
    expect(canOfferReviewSlots('scheduled', 'counsellor-1')).toBe(false);
  });

  it('normalizes missing items without exceeding the DTO limit', () => {
    const repeated = Array.from({ length: 25 }, (_, index) => `item-${index}`);
    expect(
      parseMissingItems(`Passport, transcript\nPassport,${repeated.join(',')}`),
    ).toHaveLength(20);
    expect(parseMissingItems('Passport, transcript\nPassport')).toEqual([
      'Passport',
      'transcript',
    ]);
  });
});

describe('review scheduling validation', () => {
  const now = new Date('2026-08-01T08:00:00.000Z');

  it('requires an explicit UTC offset', () => {
    expect(isExplicitOffsetIsoDateTime('2026-08-02T09:00:00')).toBe(false);
    expect(isExplicitOffsetIsoDateTime('2026-08-02T09:00:00+01:00')).toBe(
      true,
    );
  });

  it('validates the slot interval and IANA timezone', () => {
    expect(
      validateAvailabilityWindow(
        '2026-08-02T09:00:00+01:00',
        '2026-08-02T10:00:00+01:00',
        'Africa/Niamey',
        now,
      ),
    ).toBeNull();
    expect(
      validateAvailabilityWindow(
        '2026-08-02T09:00:00+01:00',
        '2026-08-02T10:00:00+01:00',
        'Not/A_Timezone',
        now,
      ),
    ).toBe('invalid_timezone');
  });

  it('requires offer expiry before every selected slot', () => {
    const slots = [{ startsAt: '2026-08-02T08:00:00.000Z' }];
    expect(
      validateOfferExpiry('2026-08-02T07:00:00.000Z', slots, now),
    ).toBeNull();
    expect(
      validateOfferExpiry('2026-08-02T08:00:00.000Z', slots, now),
    ).toBe('expiry_after_slot');
  });
});
