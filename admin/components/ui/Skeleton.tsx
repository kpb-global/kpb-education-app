import { CSSProperties } from 'react';

import styles from './ui.module.css';

export function Skeleton({
  width = '100%',
  height = 16,
  radius,
}: {
  width?: number | string;
  height?: number | string;
  radius?: number | string;
}) {
  const style: CSSProperties = {
    width,
    height,
    ...(radius !== undefined ? { borderRadius: radius } : {}),
  };
  return <span className={styles.skeleton} style={style} aria-hidden="true" />;
}
