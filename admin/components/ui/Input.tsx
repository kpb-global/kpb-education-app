import { InputHTMLAttributes, TextareaHTMLAttributes, forwardRef } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  invalid?: boolean;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { invalid, className, ...rest },
  ref,
) {
  return (
    <input
      ref={ref}
      aria-invalid={invalid || undefined}
      className={cx(styles.input, invalid && styles.invalid, className)}
      {...rest}
    />
  );
});

export interface TextareaProps
  extends TextareaHTMLAttributes<HTMLTextAreaElement> {
  invalid?: boolean;
}

export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(
  function Textarea({ invalid, className, ...rest }, ref) {
    return (
      <textarea
        ref={ref}
        aria-invalid={invalid || undefined}
        className={cx(
          styles.input,
          styles.textarea,
          invalid && styles.invalid,
          className,
        )}
        {...rest}
      />
    );
  },
);
