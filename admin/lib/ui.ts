import { CSSProperties } from 'react';

/** Split a comma-separated string into a trimmed, non-empty array. */
export function splitList(value: string): string[] {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

// All values read design tokens defined in app/globals.css (:root). Keep new
// styling token-driven so brand/spacing/dark-mode stay single-sourced.
export const panelStyle: CSSProperties = {
  background: 'var(--surface)',
  borderRadius: 'var(--radius-lg)',
  padding: 'var(--space-5)',
  boxShadow: 'var(--shadow-sm)',
};

export const softPanelStyle: CSSProperties = {
  background: 'var(--surface-2)',
  borderRadius: 'var(--radius-lg)',
  padding: 'var(--space-4)',
};

export const inputStyle: CSSProperties = {
  width: '100%',
  border: '1px solid var(--border)',
  borderRadius: 'var(--radius-md)',
  padding: 'var(--space-3) var(--space-4)',
  fontSize: 'var(--text-base)',
  boxSizing: 'border-box',
};

export const textareaStyle: CSSProperties = {
  ...inputStyle,
  minHeight: 110,
  resize: 'vertical',
};

export const buttonStyle: CSSProperties = {
  border: 'none',
  borderRadius: 'var(--radius-md)',
  padding: 'var(--space-3) var(--space-4)',
  background: 'var(--brand)',
  color: 'var(--brand-fg)',
  fontWeight: 700,
  cursor: 'pointer',
};

export const secondaryButtonStyle: CSSProperties = {
  ...buttonStyle,
  background: 'var(--surface-2)',
  color: 'var(--text)',
};

export const labelStyle: CSSProperties = {
  display: 'grid',
  gap: 'var(--space-2)',
  fontWeight: 600,
};

export const mutedTextStyle: CSSProperties = {
  color: 'var(--text-muted)',
  lineHeight: 1.6,
};

export const badgeStyle: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  borderRadius: 'var(--radius-pill)',
  padding: '6px 10px',
  background: 'var(--info-bg)',
  color: 'var(--info-fg)',
  fontSize: 'var(--text-xs)',
  fontWeight: 700,
};
