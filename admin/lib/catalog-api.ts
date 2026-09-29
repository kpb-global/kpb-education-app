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
  /** Les éléments les plus urgents d'abord, plafonnés côté serveur. */
  items: VerificationQueueItem[];
  /** Le compte COMPLET de la file, pas le nombre d'éléments renvoyés. */
  total: number;
  /**
   * Vrai si la file est plus longue que `items`. Optionnel : un serveur plus
   * ancien ne l'envoie pas, et l'absence veut alors dire « rien n'est tronqué ».
   */
  truncated?: boolean;
  policies: VerificationPolicy[];
}

export function fetchVerificationDue() {
  return apiFetch<VerificationDueResponse>('/admin/catalog/verification-due');
}
