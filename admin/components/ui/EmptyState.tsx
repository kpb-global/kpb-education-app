import { ReactNode } from 'react';

import styles from './ui.module.css';

export function EmptyState({
  title,
  description,
  action,
}: {
  title: ReactNode;
  description?: ReactNode;
  action?: ReactNode;
}) {
  return (
    <div className={styles.empty}>
      <p className={styles.emptyTitle}>{title}</p>
      {description ? <p style={{ margin: 0 }}>{description}</p> : null}
      {action}
    </div>
  );
}
