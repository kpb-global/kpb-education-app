import { CSSProperties } from 'react';

/** Split a comma-separated string into a trimmed, non-empty array. */
export function splitList(value: string): string[] {
  return value
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

export const panelStyle: CSSProperties = {
  background: '#fff',
  borderRadius: 20,
  padding: 24,
  boxShadow: '0 12px 32px rgba(18,32,51,0.06)',
};

export const softPanelStyle: CSSProperties = {
  background: '#E9EEF6',
  borderRadius: 20,
  padding: 18,
};

export const inputStyle: CSSProperties = {
  width: '100%',
  border: '1px solid #CBD5E1',
  borderRadius: 14,
  padding: '12px 14px',
  fontSize: 14,
  boxSizing: 'border-box',
};

export const textareaStyle: CSSProperties = {
  ...inputStyle,
  minHeight: 110,
  resize: 'vertical',
};

export const buttonStyle: CSSProperties = {
  border: 'none',
  borderRadius: 14,
  padding: '12px 16px',
  background: '#122033',
  color: '#fff',
  fontWeight: 700,
  cursor: 'pointer',
};

export const secondaryButtonStyle: CSSProperties = {
  ...buttonStyle,
  background: '#E2E8F0',
  color: '#122033',
};

export const labelStyle: CSSProperties = {
  display: 'grid',
  gap: 8,
  fontWeight: 600,
};

export const mutedTextStyle: CSSProperties = {
  color: '#64748B',
  lineHeight: 1.6,
};

export const badgeStyle: CSSProperties = {
  display: 'inline-flex',
  alignItems: 'center',
  gap: 6,
  borderRadius: 999,
  padding: '6px 10px',
  background: '#EEF2FF',
  color: '#4338CA',
  fontSize: 12,
  fontWeight: 700,
};
