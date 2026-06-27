import { HTMLAttributes } from 'react';

import { cx } from './cx';
import styles from './ui.module.css';

export interface CardProps extends HTMLAttributes<HTMLDivElement> {
  interactive?: boolean;
}

export function Card({ interactive, className, ...rest }: CardProps) {
  return (
    <div
      className={cx(styles.card, interactive && styles.cardInteractive, className)}
      {...rest}
    />
  );
}
