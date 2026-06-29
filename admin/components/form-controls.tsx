'use client';

import { CSSProperties } from 'react';

import {
  inputStyle,
  labelStyle,
  panelStyle,
  textareaStyle,
} from '../lib/ui';

const fullWidthStyle: CSSProperties = { gridColumn: '1 / -1' };

export function TextField({
  label,
  value,
  onChange,
  placeholder,
  type = 'text',
  fullWidth = false,
}: Readonly<{
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  type?: string;
  fullWidth?: boolean;
}>) {
  return (
    <label style={fullWidth ? { ...labelStyle, ...fullWidthStyle } : labelStyle}>
      {label}
      <input
        value={value}
        type={type}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        style={inputStyle}
      />
    </label>
  );
}

export function TextAreaField({
  label,
  value,
  onChange,
  placeholder,
  fullWidth = true,
}: Readonly<{
  label: string;
  value: string;
  onChange: (value: string) => void;
  placeholder?: string;
  fullWidth?: boolean;
}>) {
  return (
    <label style={fullWidth ? { ...labelStyle, ...fullWidthStyle } : labelStyle}>
      {label}
      <textarea
        value={value}
        placeholder={placeholder}
        onChange={(event) => onChange(event.target.value)}
        style={textareaStyle}
      />
    </label>
  );
}

export function SelectField({
  label,
  value,
  onChange,
  options,
  fullWidth = false,
}: Readonly<{
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: ReadonlyArray<{ value: string; label: string }>;
  fullWidth?: boolean;
}>) {
  return (
    <label style={fullWidth ? { ...labelStyle, ...fullWidthStyle } : labelStyle}>
      {label}
      <select
        value={value}
        onChange={(event) => onChange(event.target.value)}
        style={inputStyle}
      >
        {options.map((option) => (
          <option key={option.value} value={option.value}>
            {option.label}
          </option>
        ))}
      </select>
    </label>
  );
}

export function CheckboxField({
  label,
  checked,
  onChange,
}: Readonly<{
  label: string;
  checked: boolean;
  onChange: (checked: boolean) => void;
}>) {
  return (
    <label style={{ ...labelStyle, alignContent: 'end' }}>
      <span>{label}</span>
      <input
        type="checkbox"
        checked={checked}
        onChange={(event) => onChange(event.target.checked)}
      />
    </label>
  );
}

export function StatusBanners({
  statusMessage,
  errorMessage,
}: Readonly<{
  statusMessage: string | null;
  errorMessage: string | null;
}>) {
  return (
    <>
      {statusMessage ? (
        <div style={{ ...panelStyle, background: '#ECFDF5', color: '#166534' }}>
          {statusMessage}
        </div>
      ) : null}
      {errorMessage ? (
        <div style={{ ...panelStyle, background: '#FEF2F2', color: '#B91C1C' }}>
          {errorMessage}
        </div>
      ) : null}
    </>
  );
}
