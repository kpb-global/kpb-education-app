import { CSSProperties, ReactNode } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

/**
 * Handoff "generic table pages" pattern: a white bordered card with an
 * uppercase column-header row, soft rounded grid rows, and an optional
 * muted footnote under the rows. Column widths are a CSS grid template
 * shared between the header and every row via the --table-cols variable.
 */
export function AdminTable({
  title,
  columns,
  cols,
  footnote,
  children,
  'aria-label': ariaLabel,
}: Readonly<{
  /** Optional visible card title above the header row. */
  title?: string;
  /** Already-translated column labels, rendered uppercase. */
  columns: string[];
  /** grid-template-columns value, e.g. "1.2fr 1fr 0.8fr". */
  cols: string;
  /** Optional muted footnote line under the rows. */
  footnote?: ReactNode;
  children: ReactNode;
  'aria-label'?: string;
}>) {
  return (
    <section
      className={styles.table}
      aria-label={ariaLabel ?? title}
      style={{ '--table-cols': cols } as CSSProperties}
    >
      {title ? <h3 className={styles.tableTitle}>{title}</h3> : null}
      <div className={styles.tableHead} aria-hidden="true">
        {columns.map((label) => (
          <div key={label} className={styles.tableHeadCell}>
            {label}
          </div>
        ))}
      </div>
      {children}
      {footnote ? <p className={styles.tableNote}>{footnote}</p> : null}
    </section>
  );
}

/**
 * One table row. When `onSelect` is provided the whole row becomes a button
 * (do not nest other buttons inside in that case — put per-row actions in
 * plain rows instead).
 */
export function AdminTableRow({
  selected,
  onSelect,
  children,
}: Readonly<{
  selected?: boolean;
  onSelect?: () => void;
  children: ReactNode;
}>) {
  const className = cx(
    styles.tableRow,
    onSelect && styles.tableRowInteractive,
    selected && styles.tableRowSelected,
  );
  if (onSelect) {
    return (
      <button
        type="button"
        onClick={onSelect}
        aria-pressed={selected}
        className={className}
      >
        {children}
      </button>
    );
  }
  return <div className={className}>{children}</div>;
}

/** Text cell: primary line plus an optional faint sub-line, both ellipsized. */
export function CellText({
  primary,
  sub,
  muted,
}: Readonly<{
  primary: ReactNode;
  sub?: ReactNode;
  muted?: boolean;
}>) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', minWidth: 0 }}>
      <div className={cx(styles.cellPrimary, muted && styles.cellMuted)}>
        {primary}
      </div>
      {sub ? <div className={styles.cellSub}>{sub}</div> : null}
    </div>
  );
}
