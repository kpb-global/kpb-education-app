import {
  AdminCapability,
  hasAdminCapability,
} from './admin-capabilities';

export const COMPETITION_READINESS_TABS = [
  'requests',
  'outcomes',
  'partners',
  'pilots',
  'impact',
  'ai',
] as const;

export type CompetitionReadinessTab =
  (typeof COMPETITION_READINESS_TABS)[number];

const TAB_CAPABILITIES: Record<
  CompetitionReadinessTab,
  readonly AdminCapability[]
> = {
  requests: [
    AdminCapability.ViewReviewRequestMetadata,
    AdminCapability.ViewAssignedReviewRequests,
  ],
  outcomes: [AdminCapability.VerifyOutcomes],
  partners: [AdminCapability.ManagePartnerAgreements],
  pilots: [
    AdminCapability.ManagePilots,
    AdminCapability.RecruitPilotParticipants,
  ],
  impact: [
    AdminCapability.ViewPilotAggregates,
    AdminCapability.FreezeImpactSnapshots,
  ],
  ai: [AdminCapability.ViewAiOperations],
};

export function isCompetitionReadinessTab(
  value: string | null | undefined,
): value is CompetitionReadinessTab {
  return COMPETITION_READINESS_TABS.includes(
    value as CompetitionReadinessTab,
  );
}

/**
 * Presentation-only tab visibility. Every endpoint still enforces backend
 * role, scope, assignment, purpose and separation-of-duties policies.
 */
export function getVisibleCompetitionReadinessTabs(
  role: string | null | undefined,
): CompetitionReadinessTab[] {
  return COMPETITION_READINESS_TABS.filter((tab) =>
    TAB_CAPABILITIES[tab].some((capability) =>
      hasAdminCapability(role, capability),
    ),
  );
}

export function canAccessCompetitionReadiness(
  role: string | null | undefined,
): boolean {
  return getVisibleCompetitionReadinessTabs(role).length > 0;
}

export function resolveCompetitionReadinessTab(
  role: string | null | undefined,
  requestedTab: string | null | undefined,
): CompetitionReadinessTab | null {
  const visibleTabs = getVisibleCompetitionReadinessTabs(role);
  if (
    isCompetitionReadinessTab(requestedTab) &&
    visibleTabs.includes(requestedTab)
  ) {
    return requestedTab;
  }
  return visibleTabs[0] ?? null;
}
