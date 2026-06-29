'use client';

import { useState } from 'react';

import { ArticlesSection } from '../../components/content/ArticlesSection';
import { DestinationsSection } from '../../components/content/DestinationsSection';
import { OffersSection } from '../../components/content/OffersSection';
import { DashboardShell } from '../../components/dashboard-shell';
import { Button } from '../../components/ui';

const TABS = [
  { key: 'offers', label: 'Service offers' },
  { key: 'destinations', label: 'Support destinations' },
  { key: 'articles', label: 'Editorial content' },
] as const;

type TabKey = (typeof TABS)[number]['key'];

export default function ContentPage() {
  const [tab, setTab] = useState<TabKey>('offers');

  return (
    <DashboardShell title="Content">
      <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
        <div
          aria-label="Content sections"
          style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap' }}
        >
          {TABS.map((item) => (
            <Button
              key={item.key}
              size="sm"
              variant={tab === item.key ? 'primary' : 'secondary'}
              aria-pressed={tab === item.key}
              onClick={() => setTab(item.key)}
            >
              {item.label}
            </Button>
          ))}
        </div>

        {tab === 'offers' ? <OffersSection /> : null}
        {tab === 'destinations' ? <DestinationsSection /> : null}
        {tab === 'articles' ? <ArticlesSection /> : null}
      </div>
    </DashboardShell>
  );
}
