import { apiFetch } from './api-client';

export interface VerificationPolicy {
  key: string;
  label: string;
  cadenceDays: number;
  owner: string;
}

export interface VerificationQueueItem {
  entityType: 'country' | 'institution' | 'program' | 'scholarship';
  id: string;
  label: string;
  context: string | null;
  category: string;
  categoryLabel: string;
  cadenceDays: number;
  owner: string;
  lastVerifiedAt: string | null;
  verifiedByName: string | null;
  sourceUrl: string | null;
  dueAt: string | null;
  daysSinceVerification: number | null;
  isOverdue: boolean;
}

export interface VerificationDueResponse {
  items: VerificationQueueItem[];
  total: number;
  policies: VerificationPolicy[];
}

export function fetchVerificationDue() {
  return apiFetch<VerificationDueResponse>('/admin/catalog/verification-due');
}
