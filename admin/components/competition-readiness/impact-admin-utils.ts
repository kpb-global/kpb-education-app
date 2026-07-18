import type { BadgeVariant } from '../ui';

import type {
  JsonValue,
  PartnershipAgreementStatus,
  PilotStatus,
} from '../../lib/competition-readiness-api';

export type JsonObject = { readonly [key: string]: JsonValue };

export function parseCodeList(value: string): string[] {
  return Array.from(
    new Set(
      value
        .split(/[\s,;]+/)
        .map((item) => item.trim())
        .filter(Boolean),
    ),
  );
}

export function parseCountryCodes(value: string): string[] | null {
  const codes = Array.from(
    new Set(parseCodeList(value).map((item) => item.toUpperCase())),
  );
  return codes.length > 0 && codes.every((code) => /^[A-Z]{2}$/.test(code))
    ? codes
    : null;
}

export function parseJsonObject(value: string): JsonObject | null {
  try {
    const parsed: unknown = JSON.parse(value);
    return parsed !== null && !Array.isArray(parsed) && typeof parsed === 'object'
      ? (parsed as JsonObject)
      : null;
  } catch {
    return null;
  }
}

export function toUtcIso(value: string): string | null {
  if (!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?$/.test(value)) {
    return null;
  }
  const parsed = new Date(`${value}Z`);
  return Number.isNaN(parsed.getTime()) ? null : parsed.toISOString();
}

export function toUtcFormValue(value: string | null | undefined): string {
  if (!value) return '';
  const parsed = new Date(value);
  if (Number.isNaN(parsed.getTime())) return '';
  return parsed.toISOString().slice(0, 16);
}

export function agreementStatusVariant(
  status: PartnershipAgreementStatus,
): BadgeVariant {
  if (status === 'active' || status === 'signed') return 'success';
  if (status === 'expired' || status === 'terminated') return 'danger';
  if (status === 'pending_signature') return 'warning';
  if (status === 'prospect') return 'info';
  return 'neutral';
}

export function pilotStatusVariant(status: PilotStatus): BadgeVariant {
  if (status === 'active' || status === 'completed') return 'success';
  if (status === 'recruiting') return 'info';
  if (status === 'analysis') return 'warning';
  return 'neutral';
}

export function makeIdempotencyKey(prefix: string): string {
  const random = globalThis.crypto?.randomUUID?.();
  if (!random) {
    throw new Error('Secure random identifiers are unavailable.');
  }
  return `${prefix}-${random}`;
}
