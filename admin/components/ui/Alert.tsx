import { ReactNode } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

export type AlertVariant = 'info' | 'success' | 'warning' | 'danger';

const variantClass: Record<AlertVariant, string> = {
  info: styles.alertInfo,
  success: styles.alertSuccess,
  warning: styles.alertWarning,
  danger: styles.alertDanger,
};

export function Alert({
  variant = 'info',
  children,
}: {
  variant?: AlertVariant;
  children: ReactNode;
}) {
  return (
    <div
      className={cx(styles.alert, variantClass[variant])}
      // urgent variants interrupt the SR; informational ones are polite.
      role={variant === 'danger' || variant === 'warning' ? 'alert' : 'status'}
    >
      {children}
    </div>
  );
}
