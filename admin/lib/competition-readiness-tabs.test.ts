import { describe, expect, it } from 'vitest';

import { InternalRole } from './admin-capabilities';
import {
  canAccessCompetitionReadiness,
  getVisibleCompetitionReadinessTabs,
  isCompetitionReadinessTab,
  resolveCompetitionReadinessTab,
} from './competition-readiness-tabs';

describe('competition readiness tab visibility', () => {
  it('shows scoped request, partner, and pilot operations to commercial operators', () => {
    expect(
      getVisibleCompetitionReadinessTabs(InternalRole.Commercial),
    ).toEqual(['requests', 'partners', 'pilots']);
  });

  it('shows outcome verification and aggregate impact to moderators', () => {
    expect(
      getVisibleCompetitionReadinessTabs(InternalRole.Moderator),
    ).toEqual(['outcomes', 'impact']);
  });

  it('shows all implemented tabs to administrators', () => {
    expect(getVisibleCompetitionReadinessTabs(InternalRole.Admin)).toEqual([
      'requests',
      'outcomes',
      'partners',
      'pilots',
      'impact',
      'ai',
    ]);
    expect(
      getVisibleCompetitionReadinessTabs(InternalRole.SuperAdmin),
    ).toEqual([
      'requests',
      'outcomes',
      'partners',
      'pilots',
      'impact',
      'ai',
    ]);
  });

  it('fails closed for roles without a readiness operation', () => {
    expect(
      canAccessCompetitionReadiness(InternalRole.ContentManager),
    ).toBe(false);
    expect(getVisibleCompetitionReadinessTabs('unknown')).toEqual([]);
    expect(resolveCompetitionReadinessTab('unknown', 'requests')).toBeNull();
  });

  it('falls back to the first authorized tab', () => {
    expect(
      resolveCompetitionReadinessTab(InternalRole.Moderator, 'ai'),
    ).toBe('outcomes');
    expect(
      resolveCompetitionReadinessTab(InternalRole.Counselor, 'not-a-tab'),
    ).toBe('requests');
    expect(isCompetitionReadinessTab('outcomes')).toBe(true);
    expect(isCompetitionReadinessTab('pilots')).toBe(true);
  });
});
