import { ReactNode } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

export type BadgeVariant =
  | 'neutral'
  | 'brand'
  | 'success'
  | 'warning'
  | 'danger'
  | 'info';

const variantClass: Record<BadgeVariant, string> = {
  neutral: styles.badgeNeutral,
  brand: styles.badgeBrand,
  success: styles.badgeSuccess,
  warning: styles.badgeWarning,
  danger: styles.badgeDanger,
  info: styles.badgeInfo,
};

export function Badge({
  variant = 'neutral',
  children,
}: {
  variant?: BadgeVariant;
  children: ReactNode;
}) {
  return <span className={cx(styles.badge, variantClass[variant])}>{children}</span>;
}

/**
 * Maps known KPB statuses to a semantic colour so status carries meaning
 * (replaces the single fixed-indigo badge flagged in the audit). Unknown
 * statuses fall back to neutral.
 */
const STATUS_VARIANT: Record<string, BadgeVariant> = {
  // case / generic lifecycle
  submitted: 'info',
  documents_needed: 'warning',
  counselor_assigned: 'brand',
  in_progress: 'brand',
  application_submitted: 'info',
  completed: 'success',
  approved: 'success',
  published: 'success',
  pending: 'warning',
  rejected: 'danger',
  cancelled: 'danger',
  draft: 'neutral',
  archived: 'neutral',
};

export function StatusBadge({ status }: { status: string }) {
  const key = status.toLowerCase().replace(/\s+/g, '_');
  const variant = STATUS_VARIANT[key] ?? 'neutral';
  return <Badge variant={variant}>{status.replace(/_/g, ' ')}</Badge>;
}
