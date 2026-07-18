import { beforeEach, describe, expect, it, vi } from 'vitest';

import { apiFetch } from './api-client';
import {
  cancelAvailabilitySlot,
  createAvailabilitySlot,
  createImpactCohort,
  createImpactDataRoomExport,
  freezeImpactSnapshot,
  listImpactCohorts,
  listImpactDataRoomExports,
  listImpactSnapshots,
  createPartnerAgreement,
  updatePartnerAgreement,
  updateImpactPilot,
  listActiveCounsellors,
  listAvailabilitySlots,
  listOutcomes,
  listReviewRequests,
  offerReviewSlots,
  requestOutcomeEvidenceAccess,
  triageReviewRequest,
  verifyOutcome,
} from './competition-readiness-api';

vi.mock('./api-client', () => ({
  apiFetch: vi.fn(),
}));

const apiFetchMock = vi.mocked(apiFetch);

describe('competition readiness API client', () => {
  beforeEach(() => {
    apiFetchMock.mockReset();
  });

  it('serializes paginated multi-value filters without undefined values', () => {
    listReviewRequests({
      cursor: 'next page',
      limit: 25,
      statuses: ['submitted', 'triaged'],
      countryCode: 'NE',
      overdueOnly: false,
    });

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/review-requests' +
        '?cursor=next+page&limit=25&status=submitted&status=triaged' +
        '&countryCode=NE&overdueOnly=false',
    );
  });

  it('keeps optimistic concurrency data in verification mutations', () => {
    verifyOutcome('admission', 'decision/1', {
      expectedVersion: 4,
      status: 'verified',
      reasonCode: 'official_document_reviewed',
      notes: 'Issuer and date match.',
    });

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/outcomes/admission/decision%2F1/verification',
      {
        method: 'PATCH',
        body: {
          expectedVersion: 4,
          status: 'verified',
          reasonCode: 'official_document_reviewed',
          notes: 'Issuer and date match.',
        },
      },
    );
  });

  it('uses scalar backend filters for the outcome queue', () => {
    listOutcomes({
      cursor: 'outcome page',
      limit: 20,
      type: 'funding',
      verificationStatus: 'pending',
      countryCode: 'NE',
    });

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/outcomes' +
        '?cursor=outcome+page&limit=20&type=funding' +
        '&verificationStatus=pending&countryCode=NE',
    );
  });

  it('requests an audited no-store access token for outcome evidence', () => {
    requestOutcomeEvidenceAccess('evidence/1');

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/outcome-evidence/evidence%2F1/file' +
        '?purposeCode=outcome_verification',
    );
  });

  it('sends an idempotency header on creation endpoints', () => {
    createPartnerAgreement(
      {
        agreementKey: 'partner-ne-2026',
        partnerId: 'partner-1',
        status: 'draft',
        agreementType: 'pilot',
        purposeCodes: ['pilot_recruitment'],
        countryCodes: ['NE'],
        canRecruitPilot: true,
        canVerifySubmission: false,
        canVerifyDecision: false,
        canShareAggregateData: false,
        canPubliclyNamePartner: false,
        canUsePartnerLogo: false,
        reasonCode: 'pilot_preparation',
      },
      ' agreement-create-1 ',
    );

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/partner-agreements',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Idempotency-Key': 'agreement-create-1' },
      }),
    );
  });

  it('sends idempotency headers on agreement and pilot updates', () => {
    updatePartnerAgreement(
      'agreement/1',
      {
        expectedVersion: 2,
        changes: { status: 'active' },
        reasonCode: 'partner_agreement_activated',
      },
      ' agreement-update-1 ',
    );
    updateImpactPilot(
      'pilot/1',
      {
        expectedVersion: 3,
        changes: { status: 'active' },
        reasonCode: 'impact_pilot_activated',
      },
      'pilot-update-1',
    );

    expect(apiFetchMock).toHaveBeenNthCalledWith(
      1,
      '/admin/competition-readiness/partner-agreements/agreement%2F1',
      expect.objectContaining({
        method: 'PATCH',
        headers: { 'Idempotency-Key': 'agreement-update-1' },
      }),
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      2,
      '/admin/competition-readiness/pilots/pilot%2F1',
      expect.objectContaining({
        method: 'PATCH',
        headers: { 'Idempotency-Key': 'pilot-update-1' },
      }),
    );
  });

  it('keeps cohort and snapshot identifiers in encoded path segments', () => {
    listImpactCohorts('pilot/1', { cursor: 'next cohort', limit: 25 });
    listImpactSnapshots('pilot/1', { limit: 50, publicSafeOnly: true });

    expect(apiFetchMock).toHaveBeenNthCalledWith(
      1,
      '/admin/competition-readiness/pilots/pilot%2F1/cohorts' +
        '?cursor=next+cohort&limit=25',
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      2,
      '/admin/competition-readiness/pilots/pilot%2F1/snapshots' +
        '?limit=50&publicSafeOnly=true',
    );
  });

  it('requires idempotency and strips private data-room fields', async () => {
    apiFetchMock.mockResolvedValue({
      id: 'export-1',
      pilotId: 'pilot-1',
      snapshotId: 'snapshot-1',
      purposeCode: 'competition_due_diligence',
      format: 'json',
      expiresAt: null,
      createdAt: '2026-07-18T12:00:00.000Z',
      sha256: 'a'.repeat(64),
      storageKey: 'private/never-retain-this',
      manifest: { private: true },
    });
    createImpactCohort(
      'pilot-1',
      {
        code: 'cohort-a',
        label: 'Cohort A',
        cohortType: 'pilot',
        inclusionRules: { countryCodes: ['NE'] },
        exclusionRules: {},
        reasonCode: 'impact_cohort_created',
      },
      'cohort-create-1',
    );
    freezeImpactSnapshot(
      'pilot-1',
      {
        expectedVersion: 3,
        periodStart: '2026-01-01T00:00:00.000Z',
        periodEnd: '2026-06-30T23:59:59.000Z',
        sourceWatermark: '2026-07-01T00:00:00.000Z',
        reasonCode: 'impact_snapshot_frozen',
      },
      'snapshot-create-1',
    );
    const receipt = await createImpactDataRoomExport(
      {
        snapshotId: 'snapshot-1',
        purposeCode: 'competition_due_diligence',
        format: 'json',
        reasonCode: 'impact_data_room_export_created',
      },
      'export-create-1',
    );

    expect(apiFetchMock).toHaveBeenNthCalledWith(
      1,
      '/admin/competition-readiness/pilots/pilot-1/cohorts',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Idempotency-Key': 'cohort-create-1' },
      }),
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      2,
      '/admin/competition-readiness/pilots/pilot-1/snapshots',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Idempotency-Key': 'snapshot-create-1' },
      }),
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      3,
      '/admin/competition-readiness/data-room-exports',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Idempotency-Key': 'export-create-1' },
        body: expect.not.objectContaining({ storageKey: expect.anything() }),
      }),
    );
    expect(receipt).not.toHaveProperty('storageKey');
    expect(receipt).not.toHaveProperty('manifest');
  });

  it('filters data-room list receipts before returning them to UI state', async () => {
    apiFetchMock.mockResolvedValue({
      items: [
        {
          id: 'export-1',
          pilotId: 'pilot-1',
          snapshotId: 'snapshot-1',
          purposeCode: 'competition_due_diligence',
          format: 'json',
          expiresAt: null,
          createdAt: '2026-07-18T12:00:00.000Z',
          sha256: 'b'.repeat(64),
          storageKey: 'private/export.json',
          manifest: { metrics: [] },
        },
      ],
    });

    const response = await listImpactDataRoomExports({
      pilotId: 'pilot/1',
      snapshotId: 'snapshot/1',
    });

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/data-room-exports' +
        '?pilotId=pilot%2F1&snapshotId=snapshot%2F1',
    );
    expect(response.items[0]).not.toHaveProperty('storageKey');
    expect(response.items[0]).not.toHaveProperty('manifest');
  });

  it('fails locally when a creation omits its idempotency key', () => {
    expect(() =>
      offerReviewSlots(
        'review-1',
        {
          expectedVersion: 2,
          slotIds: ['slot-1'],
          expiresAt: '2026-08-01T10:00:00.000Z',
          reasonCode: 'student_requested_call',
        },
        ' ',
      ),
    ).toThrow('An Idempotency-Key is required');
    expect(apiFetchMock).not.toHaveBeenCalled();
  });

  it('uses the redacted request-scoped counselor contract for assignment', () => {
    listActiveCounsellors(true, 'review/1');

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/counsellors' +
        '?activeOnly=true&reviewRequestId=review%2F1',
    );
  });

  it('serializes availability filters and optimistic cancellation', () => {
    listAvailabilitySlots({
      counsellorId: 'counsellor/1',
      from: '2026-08-01T00:00:00.000Z',
      status: 'available',
      limit: 20,
    });
    cancelAvailabilitySlot('slot/1', {
      expectedVersion: 3,
      reasonCode: 'availability_withdrawn',
    });

    expect(apiFetchMock).toHaveBeenNthCalledWith(
      1,
      '/admin/competition-readiness/availability-slots' +
        '?counsellorId=counsellor%2F1&from=2026-08-01T00%3A00%3A00.000Z' +
        '&status=available&limit=20',
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      2,
      '/admin/competition-readiness/availability-slots/slot%2F1/cancel',
      {
        method: 'PATCH',
        body: {
          expectedVersion: 3,
          reasonCode: 'availability_withdrawn',
        },
      },
    );
  });

  it('adds idempotency to availability creation', () => {
    createAvailabilitySlot(
      {
        counsellorId: 'counsellor-1',
        startsAt: '2026-08-02T09:00:00+01:00',
        endsAt: '2026-08-02T10:00:00+01:00',
        timezone: 'Africa/Niamey',
        capacity: 1,
        reasonCode: 'review_availability_created',
      },
      ' slot-create-1 ',
    );

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/availability-slots',
      expect.objectContaining({
        method: 'POST',
        headers: { 'Idempotency-Key': 'slot-create-1' },
      }),
    );
  });

  it('preserves assignment and missing-items form payloads', () => {
    triageReviewRequest('review-1', {
      expectedVersion: 4,
      action: 'assign',
      assignedCounsellorId: 'counsellor-1',
      reasonCode: 'review_assignment_updated',
    });
    triageReviewRequest('review-1', {
      expectedVersion: 5,
      action: 'request_more_information',
      missingItems: ['Passport', 'Transcript'],
      reasonCode: 'review_missing_information_requested',
    });

    expect(apiFetchMock).toHaveBeenNthCalledWith(
      1,
      '/admin/competition-readiness/review-requests/review-1/triage',
      {
        method: 'PATCH',
        body: expect.objectContaining({
          expectedVersion: 4,
          action: 'assign',
          assignedCounsellorId: 'counsellor-1',
        }),
      },
    );
    expect(apiFetchMock).toHaveBeenNthCalledWith(
      2,
      '/admin/competition-readiness/review-requests/review-1/triage',
      {
        method: 'PATCH',
        body: expect.objectContaining({
          expectedVersion: 5,
          action: 'request_more_information',
          missingItems: ['Passport', 'Transcript'],
        }),
      },
    );
  });

  it('sends selected slots, explicit expiry, and idempotency together', () => {
    offerReviewSlots(
      'review-1',
      {
        expectedVersion: 6,
        slotIds: ['slot-1', 'slot-2'],
        expiresAt: '2026-08-01T18:00:00+01:00',
        reasonCode: 'review_call_slots_offered',
      },
      'slot-offer-1',
    );

    expect(apiFetchMock).toHaveBeenCalledWith(
      '/admin/competition-readiness/review-requests/review-1/slot-offers',
      {
        method: 'POST',
        body: expect.objectContaining({
          expectedVersion: 6,
          slotIds: ['slot-1', 'slot-2'],
          expiresAt: '2026-08-01T18:00:00+01:00',
        }),
        headers: { 'Idempotency-Key': 'slot-offer-1' },
      },
    );
  });
});
