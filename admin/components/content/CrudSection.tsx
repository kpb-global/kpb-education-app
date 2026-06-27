import { ReactNode } from 'react';

import { Card } from '../ui';
import { mutedTextStyle } from '../../lib/ui';

export interface CrudSectionProps<T> {
  title: string;
  description: string;
  /** The create/edit form (each section owns its own fields + handlers). */
  form: ReactNode;
  items: T[];
  getKey: (item: T) => string;
  editingId: string | null;
  onSelect: (item: T) => void;
  /** Rendered inside each selectable list button. */
  renderItem: (item: T) => ReactNode;
  emptyLabel: string;
}

/**
 * Shared chrome for the content CRUD domains (offers/destinations/articles):
 * a titled Card holding the form plus an accessible, keyboard-navigable
 * click-to-edit list. Each section supplies its own form + item rendering.
 */
export function CrudSection<T>({
  title,
  description,
  form,
  items,
  getKey,
  editingId,
  onSelect,
  renderItem,
  emptyLabel,
}: CrudSectionProps<T>) {
  return (
    <Card style={{ display: 'grid', gap: 'var(--space-4)' }}>
      <div>
        <h3 style={{ marginTop: 0 }}>{title}</h3>
        <p style={mutedTextStyle}>{description}</p>
      </div>
      {form}
      <div style={{ display: 'grid', gap: 'var(--space-2)' }}>
        {items.length === 0 ? (
          <p style={mutedTextStyle}>{emptyLabel}</p>
        ) : (
          items.map((item) => {
            const key = getKey(item);
            return (
              <button
                key={key}
                type="button"
                onClick={() => onSelect(item)}
                aria-pressed={editingId === key}
                style={{
                  textAlign: 'left',
                  border:
                    editingId === key
                      ? '2px solid var(--brand)'
                      : '1px solid var(--border)',
                  borderRadius: 'var(--radius-md)',
                  padding: 'var(--space-3)',
                  background: 'var(--surface)',
                  cursor: 'pointer',
                  display: 'grid',
                  gap: 'var(--space-2)',
                }}
              >
                {renderItem(item)}
              </button>
            );
          })
        )}
      </div>
    </Card>
  );
}
