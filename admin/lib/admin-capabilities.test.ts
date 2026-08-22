import { describe, expect, it } from 'vitest';

import {
  AdminCapability,
  getAdminCapabilities,
  hasAdminCapability,
  InternalRole,
  isInternalRole,
} from './admin-capabilities';

describe('admin capability presentation matrix', () => {
  it.each(Object.values(InternalRole))('recognizes the %s role', (role) => {
    expect(isInternalRole(role)).toBe(true);
  });

  it('fails closed for missing and unknown roles', () => {
    expect(isInternalRole('advisor')).toBe(false);
    expect(getAdminCapabilities('advisor')).toEqual([]);
    expect(
      hasAdminCapability('advisor', AdminCapability.ViewScholarshipContent),
    ).toBe(false);
    expect(
      hasAdminCapability(null, AdminCapability.ViewScholarshipContent),
    ).toBe(false);
  });

  it('limits outcome verification to moderators and administrators', () => {
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.VerifyOutcomes),
    );

    expect(allowed).toEqual([
      InternalRole.Moderator,
      InternalRole.Admin,
      InternalRole.SuperAdmin,
    ]);
  });

  it('keeps global AI controls super-admin-only', () => {
    for (const capability of [
      AdminCapability.ManageAiBudget,
      AdminCapability.ManageAiPrompt,
      AdminCapability.ManageFeatureFlags,
    ]) {
      const allowed = Object.values(InternalRole).filter((role) =>
        hasAdminCapability(role, capability),
      );
      expect(allowed).toEqual([InternalRole.SuperAdmin]);
    }
  });

  it('distinguishes assigned review access from commercial metadata access', () => {
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.ViewAssignedReviewRequests,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ViewReviewRequestMetadata,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ViewAssignedReviewRequests,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ViewSharedReviewDocuments,
      ),
    ).toBe(false);
  });

  it('separates counselor self-service from administrator assignment controls', () => {
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.TriageReviewRequests,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.ManageOwnAvailability,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Counselor,
        AdminCapability.AssignReviewRequests,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Admin,
        AdminCapability.ManageCounsellorAvailability,
      ),
    ).toBe(true);
  });

  it('grants the interest list to the four roles that call prospects', () => {
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ViewInterestList),
    );

    // Exactement le `@Roles` de classe d'AdminEefInterestController. Les deux
    // côtés doivent dire la même chose : le menu du back-office proposait cette
    // page à `moderator` et `content_manager`, que le contrôleur refuse — un
    // menu qui invite vers une porte fermée apprend à ignorer les erreurs.
    expect(allowed.sort()).toEqual(
      [
        InternalRole.Admin,
        InternalRole.SuperAdmin,
        InternalRole.Commercial,
        InternalRole.Counselor,
      ].sort(),
    );
  });

  it('keeps the personal-data export strictly narrower than the interest list', () => {
    // Formulé comme une RELATION et non comme deux listes : si demain on élargit
    // la lecture, cette assertion continue de dire ce qui compte — faire sortir
    // la table dans un fichier n'est pas le même acte que lire une page.
    const canView = Object.values(InternalRole).filter((r) =>
      hasAdminCapability(r, AdminCapability.ViewInterestList),
    );
    const canExport = Object.values(InternalRole).filter((r) =>
      hasAdminCapability(r, AdminCapability.ExportPersonalData),
    );

    expect(canExport.length).toBeLessThan(canView.length);
    for (const role of canExport) {
      expect(canView).toContain(role);
    }
  });

  it('requires an administrator role before showing personal-data export', () => {
    const allowed = Object.values(InternalRole).filter((role) =>
      hasAdminCapability(role, AdminCapability.ExportPersonalData),
    );

    expect(allowed).toEqual([
      InternalRole.Admin,
      InternalRole.SuperAdmin,
    ]);
  });

  it('separates partnership, pilot recruitment, and impact governance', () => {
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ManagePartnerAgreements,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.RecruitPilotParticipants,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Commercial,
        AdminCapability.ManagePilots,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Moderator,
        AdminCapability.ViewPilotAggregates,
      ),
    ).toBe(true);
    expect(
      hasAdminCapability(
        InternalRole.Moderator,
        AdminCapability.FreezeImpactSnapshots,
      ),
    ).toBe(false);
    expect(
      hasAdminCapability(
        InternalRole.Admin,
        AdminCapability.FreezeImpactSnapshots,
      ),
    ).toBe(true);
  });

  it('returns frozen capability collections', () => {
    expect(Object.isFrozen(getAdminCapabilities(InternalRole.Counselor))).toBe(
      true,
    );
    expect(Object.isFrozen(getAdminCapabilities('unknown'))).toBe(true);
  });
});
