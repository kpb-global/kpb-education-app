import type { BadgeVariant } from '../ui';

import type {
  EvidenceVerificationStatus,
  StudyReviewStatus,
} from '../../lib/competition-readiness-api';

export function getApiErrorStatus(error: unknown): number | null {
  if (
    error instanceof Error &&
    'status' in error &&
    typeof error.status === 'number'
  ) {
    return error.status;
  }
  return null;
}

export function isEndpointUnavailable(error: unknown): boolean {
  const status = getApiErrorStatus(error);
  return status === 404 || status === 501;
}

export function normalizeCountryCode(value: string): string {
  return value.trim().toUpperCase().slice(0, 3);
}

export function formatDateTime(
  value: string | null | undefined,
  locale: 'fr' | 'en',
): string {
  if (!value) return '—';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '—';
  return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
    dateStyle: 'medium',
    timeStyle: 'short',
    timeZone: 'UTC',
  }).format(parsed);
}

export function formatDateTimeInZone(
  value: string | null | undefined,
  locale: 'fr' | 'en',
  timeZone: string,
): string {
  if (!value) return '—';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '—';
  try {
    return new Intl.DateTimeFormat(locale === 'fr' ? 'fr-FR' : 'en-GB', {
      year: 'numeric',
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
      timeZone,
      timeZoneName: 'short',
    }).format(parsed);
  } catch {
    return '—';
  }
}

export function formatUsdMicros(
  micros: string | null | undefined,
  locale: 'fr' | 'en',
): string {
  if (micros === null || micros === undefined || !/^-?\d+$/.test(micros)) {
    return '—';
  }
  const value = Number(micros) / 1_000_000;
  if (!Number.isFinite(value)) return '—';
  return new Intl.NumberFormat(locale === 'fr' ? 'fr-FR' : 'en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 4,
  }).format(value);
}

export function reviewStatusVariant(
  status: StudyReviewStatus,
): BadgeVariant {
  if (status === 'closed' || status === 'declined') return 'neutral';
  if (status === 'converted_to_case' || status === 'scheduled') return 'success';
  if (status === 'more_information_needed') return 'warning';
  if (status === 'submitted' || status === 'call_offered') return 'info';
  return 'brand';
}

export function verificationStatusVariant(
  status: EvidenceVerificationStatus,
): BadgeVariant {
  if (status === 'verified') return 'success';
  if (status === 'rejected') return 'danger';
  if (status === 'needs_information' || status === 'pending') return 'warning';
  return 'neutral';
}
