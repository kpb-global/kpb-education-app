import { ReactNode, useId } from 'react';

import styles from './ui.module.css';

export interface FieldProps {
  label: string;
  error?: string;
  /** Render-prop receives the generated id + invalid flag to wire the control. */
  children: (props: { id: string; invalid: boolean }) => ReactNode;
}

/**
 * Associates a <label> with its control (htmlFor/id) and renders an inline
 * error — fixes the placeholder-as-label pattern flagged in the audit.
 */
export function Field({ label, error, children }: FieldProps) {
  const id = useId();
  return (
    <div className={styles.field}>
      <label htmlFor={id} className={styles.fieldLabel}>
        {label}
      </label>
      {children({ id, invalid: Boolean(error) })}
      {error ? (
        <span className={styles.fieldError} role="alert">
          {error}
        </span>
      ) : null}
    </div>
  );
}
