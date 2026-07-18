import type {
  AvailabilitySlot,
  StudyReviewStatus,
  TriageReviewRequestInput,
} from '../../lib/competition-readiness-api';

export type ReviewMutationAction = TriageReviewRequestInput['action'];

const ACTION_SOURCES: Readonly<
  Record<ReviewMutationAction, readonly StudyReviewStatus[]>
> = {
  triage: ['submitted', 'more_information_needed'],
  assign: [
    'draft',
    'submitted',
    'triaged',
    'more_information_needed',
    'call_offered',
    'scheduled',
    'autonomy_recommended',
    'declined',
  ],
  request_more_information: ['submitted', 'triaged'],
  recommend_autonomy: ['triaged'],
  decline: ['triaged', 'call_offered'],
  close: [
    'autonomy_recommended',
    'declined',
    'converted_to_case',
  ],
};

const CONVERTIBLE_STATUSES: readonly StudyReviewStatus[] = Object.freeze([
  'triaged',
  'call_offered',
  'scheduled',
]);

const SLOT_OFFER_STATUSES: readonly StudyReviewStatus[] = Object.freeze([
  'triaged',
  'call_offered',
]);

export type AvailabilityValidationError =
  | 'invalid_datetime'
  | 'invalid_timezone'
  | 'start_not_future'
  | 'end_before_start'
  | 'duration_too_long';

export type OfferExpiryValidationError =
  | 'invalid_datetime'
  | 'expiry_not_future'
  | 'expiry_too_late'
  | 'expiry_after_slot';

export function canApplyReviewAction(
  status: StudyReviewStatus,
  action: ReviewMutationAction,
): boolean {
  return ACTION_SOURCES[action].includes(status);
}

export function canConvertReview(status: StudyReviewStatus): boolean {
  return CONVERTIBLE_STATUSES.includes(status);
}

export function canOfferReviewSlots(
  status: StudyReviewStatus,
  assignedCounsellorId: string | null,
): boolean {
  return Boolean(assignedCounsellorId) && SLOT_OFFER_STATUSES.includes(status);
}

export function parseMissingItems(value: string): string[] {
  return Array.from(
    new Set(
      value
        .split(/[\n,]/)
        .map((item) => item.trim())
        .filter(Boolean),
    ),
  ).slice(0, 20);
}

export function isExplicitOffsetIsoDateTime(value: string): boolean {
  if (!/(?:Z|[+-]\d{2}:\d{2})$/.test(value.trim())) return false;
  return !Number.isNaN(new Date(value).getTime());
}

export function isIanaTimezone(value: string): boolean {
  try {
    new Intl.DateTimeFormat('en-US', { timeZone: value.trim() }).format();
    return Boolean(value.trim());
  } catch {
    return false;
  }
}

export function validateAvailabilityWindow(
  startsAt: string,
  endsAt: string,
  timezone: string,
  now = new Date(),
): AvailabilityValidationError | null {
  if (
    !isExplicitOffsetIsoDateTime(startsAt) ||
    !isExplicitOffsetIsoDateTime(endsAt)
  ) {
    return 'invalid_datetime';
  }
  if (!isIanaTimezone(timezone)) return 'invalid_timezone';
  const start = new Date(startsAt);
  const end = new Date(endsAt);
  if (start <= now) return 'start_not_future';
  if (end <= start) return 'end_before_start';
  if (end.getTime() - start.getTime() > 8 * 60 * 60 * 1000) {
    return 'duration_too_long';
  }
  return null;
}

export function validateOfferExpiry(
  expiresAt: string,
  slots: readonly Pick<AvailabilitySlot, 'startsAt'>[],
  now = new Date(),
): OfferExpiryValidationError | null {
  if (!isExplicitOffsetIsoDateTime(expiresAt)) return 'invalid_datetime';
  const expiry = new Date(expiresAt);
  if (expiry <= now) return 'expiry_not_future';
  if (expiry.getTime() - now.getTime() > 30 * 24 * 60 * 60 * 1000) {
    return 'expiry_too_late';
  }
  if (slots.some((slot) => expiry >= new Date(slot.startsAt))) {
    return 'expiry_after_slot';
  }
  return null;
}
