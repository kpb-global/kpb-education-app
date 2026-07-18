import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:karatou/app/core/data/success_lab_api_codec.dart';
import 'package:karatou/app/core/models/success_lab.dart';

void main() {
  group('SuccessLabApiCodec workspace-v1', () {
    test('keeps optional Success Lab capabilities fail-closed', () {
      final access = SuccessLabApiCodec.accessFromApi(
        <String, dynamic>{
          'enabled': true,
          'reasons': <String>[],
          'limits': <String, dynamic>{
            'maxActiveWorkspaces': 3,
            'maxPageSize': 20,
          },
        },
      );

      expect(access.enabled, isTrue);
      expect(access.aiDiagnosticEnabled, isFalse);
      expect(access.counsellorStudyEnabled, isFalse);
    });

    test('accepts additive capability flags without weakening access', () {
      final access = SuccessLabApiCodec.accessFromApi(
        <String, dynamic>{
          'enabled': true,
          'features': <String, dynamic>{
            'aiDiagnostic': <String, dynamic>{
              'enabled': false,
              'available': true,
              'requiresConsent': true,
            },
            'studyReview': true,
          },
        },
      );

      expect(access.aiDiagnosticEnabled, isFalse);
      expect(access.aiDiagnosticAvailable, isTrue);
      expect(access.aiDiagnosticRequiresConsent, isTrue);
      expect(access.counsellorStudyEnabled, isTrue);
    });

    test('decodes a completed one-shot diagnostic and verified references', () {
      final diagnostic = SuccessLabApiCodec.diagnosticFromApi(
        <String, dynamic>{
          'schemaVersion': 1,
          'id': 'diagnostic-1',
          'workspaceId': 'workspace-1',
          'status': 'deterministic_fallback',
          'generatedLanguage': 'fr',
          'result': <String, dynamic>{
            'strength': 'Une expérience pertinente est déjà présente.',
            'priorityImprovement': 'Ajoute une preuve mesurable.',
            'rationale': 'Le critère demande un exemple vérifiable.',
            'nextAction': 'Ajoute un résultat chiffré.',
            'criterionReferences': <String>['eligibility-001'],
          },
          'stale': false,
          'promptVersion': 'success-lab-v1',
          'fallbackReason': 'budget_not_configured',
          'completedAt': '2026-07-17T12:00:00.000Z',
          'reviewInvitation': <String, dynamic>{'available': true},
        },
      );

      expect(
        diagnostic.status,
        SuccessLabDiagnosticStatus.deterministicFallback,
      );
      expect(diagnostic.isComplete, isTrue);
      expect(
        diagnostic.result?.criterionReferences,
        <String>['eligibility-001'],
      );
      expect(diagnostic.reviewAvailable, isTrue);
    });

    test('decodes an empty diagnostic entitlement envelope', () {
      final envelope = SuccessLabApiCodec.diagnosticEnvelopeFromApi(
        <String, dynamic>{
          'schemaVersion': 1,
          'diagnostic': null,
          'entitlement': <String, dynamic>{'available': true},
        },
      );

      expect(envelope.diagnostic, isNull);
      expect(envelope.entitlementAvailable, isTrue);
    });

    test(
        'decodes clean versioned artifacts and exposes only current clean file',
        () {
      final artifacts = SuccessLabApiCodec.artifactsFromApi(
        <String, dynamic>{
          'items': <Object?>[
            <String, dynamic>{
              'id': 'artifact-1',
              'kind': 'cv',
              'title': 'CV bourse',
              'currentVersionId': 'version-2',
              'versions': <Object?>[
                <String, dynamic>{
                  'id': 'version-1',
                  'versionNumber': 1,
                  'originalFileName': 'cv-old.pdf',
                  'mimeType': 'application/pdf',
                  'sizeBytes': 1200,
                  'processingStatus': 'deleted',
                },
                <String, dynamic>{
                  'id': 'version-2',
                  'versionNumber': 2,
                  'originalFileName': 'cv.pdf',
                  'mimeType': 'application/pdf',
                  'sizeBytes': 2400,
                  'processingStatus': 'clean',
                },
              ],
            },
          ],
        },
      );

      expect(artifacts, hasLength(1));
      expect(artifacts.single.currentVersion?.id, 'version-2');
      expect(artifacts.single.currentVersion?.isClean, isTrue);
    });

    test('decodes an immutable study-review share snapshot', () {
      final review = SuccessLabApiCodec.studyReviewFromApi(
        _studyReviewFixture(),
      );

      expect(review.requestNumber, 2);
      expect(review.sharedVersionIds, <String>['version-2']);
      expect(review.submittedAt, DateTime.utc(2026, 7, 17, 13));
      expect(review.status, SuccessLabStudyReviewStatus.submitted);
      expect(
        review.nextAction,
        SuccessLabStudyReviewNextAction.waitForTriage,
      );
      expect(review.availability?['weekends'], isFalse);
      expect(review.sharedVersions.single.artifactTitle, 'CV bourse');
    });

    test('decodes active request absence and all fail-forward review states',
        () {
      expect(
        SuccessLabApiCodec.activeStudyReviewFromApi(
          <String, dynamic>{'schemaVersion': 1, 'reviewRequest': null},
        ),
        isNull,
      );

      const statuses = <String, SuccessLabStudyReviewStatus>{
        'draft': SuccessLabStudyReviewStatus.draft,
        'submitted': SuccessLabStudyReviewStatus.submitted,
        'triaged': SuccessLabStudyReviewStatus.triaged,
        'more_information_needed':
            SuccessLabStudyReviewStatus.moreInformationNeeded,
        'call_offered': SuccessLabStudyReviewStatus.callOffered,
        'scheduled': SuccessLabStudyReviewStatus.scheduled,
        'converted_to_case': SuccessLabStudyReviewStatus.convertedToCase,
        'autonomy_recommended': SuccessLabStudyReviewStatus.autonomyRecommended,
        'declined': SuccessLabStudyReviewStatus.declined,
        'closed': SuccessLabStudyReviewStatus.closed,
        'future_state': SuccessLabStudyReviewStatus.unknown,
      };
      for (final entry in statuses.entries) {
        final decoded = SuccessLabApiCodec.studyReviewFromApi(
          _studyReviewFixture()..['status'] = entry.key,
        );
        expect(decoded.status, entry.value, reason: entry.key);
      }
    });

    test('decodes slot offers and confirmed server booking', () {
      final offers = SuccessLabApiCodec.studyReviewSlotOffersFromApi(
        <String, dynamic>{
          'reviewRequestId': 'review-1',
          'reviewRequestVersion': 4,
          'timezone': 'Africa/Niamey',
          'offers': <Object?>[
            <String, dynamic>{
              'slotOfferId': 'offer-1',
              'slotId': 'slot-1',
              'startsAt': '2026-07-20T09:00:00.000Z',
              'endsAt': '2026-07-20T09:30:00.000Z',
              'timezone': 'Africa/Niamey',
              'expiresAt': '2026-07-19T09:00:00.000Z',
              'counsellorName': 'Aïcha KPB',
            },
          ],
        },
      );
      final result = SuccessLabApiCodec.studyReviewBookingFromApi(
        <String, dynamic>{
          'appointment': <String, dynamic>{
            'id': 'appointment-1',
            'reviewRequestId': 'review-1',
            'slotOfferId': 'offer-1',
            'slotId': 'slot-1',
            'counsellorId': 'counsellor-1',
            'startsAt': '2026-07-20T09:00:00.000Z',
            'endsAt': '2026-07-20T09:30:00.000Z',
            'timezone': 'Africa/Niamey',
            'status': 'scheduled',
            'contactMethod': 'in_app',
            'createdAt': '2026-07-18T08:00:00.000Z',
          },
          'reviewRequest': <String, dynamic>{
            'id': 'review-1',
            'version': 5,
            'status': 'scheduled',
          },
        },
      );

      expect(offers.offers.single.counsellorName, 'Aïcha KPB');
      expect(offers.reviewRequestVersion, 4);
      expect(result.isServerConfirmed, isTrue);
      expect(result.appointment.id, 'appointment-1');
    });

    test('decodes the backend workspace-v1 contract fixture', () {
      final fixture = _backendWorkspaceFixture();

      final workspace = SuccessLabApiCodec.workspaceFromApi(fixture);

      expect(workspace.schemaVersion, successLabWorkspaceSchemaVersionV1);
      expect(workspace.id, 'workspace_fixture_1');
      expect(workspace.userId, 'user_fixture_1');
      expect(workspace.scholarshipId, 'scholarship_fixture_1');
      expect(workspace.scholarshipCycleId, 'cycle_fixture_1');
      expect(workspace.status, SuccessLabWorkspaceStatus.preparing);
      expect(workspace.statusWireValue, 'preparing');
      expect(workspace.version, 3);
      expect(workspace.readinessPercent, 45);
      expect(
        workspace.startedAt,
        DateTime.utc(2026, 7, 16, 8),
      );
      expect(
        workspace.lastActivityAt,
        DateTime.utc(2026, 7, 16, 9),
      );
      expect(workspace.steps, hasLength(2));

      final eligibility = workspace.steps.first;
      expect(eligibility.code, 'profile-eligibility');
      expect(
        eligibility.category,
        SuccessLabWorkspaceStepCategory.profileEligibility,
      );
      expect(eligibility.status, SuccessLabWorkspaceStepStatus.completed);
      expect(eligibility.titleForLanguage('fr'), 'Vérifier mon éligibilité');
      expect(eligibility.titleForLanguage('en-GB'), 'Check my eligibility');

      final cv = workspace.steps.last;
      expect(cv.category, SuccessLabWorkspaceStepCategory.documents);
      expect(cv.status, SuccessLabWorkspaceStepStatus.inProgress);
      expect(workspace.hasUnknownEnumValues, isFalse);
    });

    test('ignores additive fields and safely retains future enum values', () {
      final fixture = _backendWorkspaceFixture()
        ..['status'] = 'paused_by_policy'
        ..['futureServerField'] = <String, Object?>{'revision': 2};
      final steps = fixture['steps']! as List<dynamic>;
      final firstStep = steps.first as Map<String, dynamic>
        ..['category'] = 'identity_review'
        ..['status'] = 'waiting_external'
        ..['futureStepField'] = true;
      expect(firstStep, isNotEmpty);

      final workspace = SuccessLabApiCodec.workspaceFromApi(fixture);

      expect(workspace.status, SuccessLabWorkspaceStatus.unknown);
      expect(workspace.statusWireValue, 'paused_by_policy');
      expect(
        workspace.steps.first.category,
        SuccessLabWorkspaceStepCategory.unknown,
      );
      expect(workspace.steps.first.categoryWireValue, 'identity_review');
      expect(
        workspace.steps.first.status,
        SuccessLabWorkspaceStepStatus.unknown,
      );
      expect(workspace.steps.first.statusWireValue, 'waiting_external');
      expect(workspace.hasUnknownEnumValues, isTrue);
    });

    test('preserves future enum wire values through the cache codec', () {
      final fixture = _backendWorkspaceFixture()..['status'] = 'paused';
      final steps = fixture['steps']! as List<dynamic>;
      (steps.first as Map<String, dynamic>)['status'] = 'blocked_external';

      final decoded = SuccessLabApiCodec.workspaceFromApi(fixture);
      final cached = SuccessLabApiCodec.workspaceToJson(decoded);
      final restored = SuccessLabApiCodec.workspaceFromApi(cached);

      expect(cached['status'], 'paused');
      expect(
        (cached['steps']! as List<dynamic>).first,
        containsPair('status', 'blocked_external'),
      );
      expect(restored.status, SuccessLabWorkspaceStatus.unknown);
      expect(restored.statusWireValue, 'paused');
      expect(
        restored.steps.first.statusWireValue,
        'blocked_external',
      );
    });

    test('decodes the documented list summary and cursor envelope', () {
      final page = SuccessLabApiCodec.workspacePageFromApi(
        <String, dynamic>{
          'items': <Object?>[
            <String, dynamic>{
              'id': 'ws_123',
              'status': 'preparing',
              'version': 7,
              'readinessPercent': 45,
              'scholarship': <String, dynamic>{
                'id': 'sch_123',
                'name': 'Chevening',
                'countryName': 'Royaume-Uni',
              },
              'cycle': <String, dynamic>{
                'id': 'cycle_2027',
                'status': 'forecast',
                'dateConfidence': 'estimated',
                'closesAt': null,
                'estimatedCloseAt': '2027-11-05T23:59:00.000Z',
              },
              'nextAction': <String, dynamic>{
                'code': 'upload_cv',
                'label': 'Ajouter ton CV',
              },
              'lastActivityAt': '2026-07-16T12:00:00.000Z',
            },
          ],
          'nextCursor': 'cursor_2',
          'futurePaginationField': 20,
        },
      );

      expect(page.nextCursor, 'cursor_2');
      expect(page.items, hasLength(1));
      final workspace = page.items.single;
      expect(workspace.schemaVersion, successLabWorkspaceSchemaVersionV1);
      expect(workspace.scholarshipId, 'sch_123');
      expect(workspace.scholarship?.name, 'Chevening');
      expect(workspace.cycle?.status, SuccessLabCycleStatus.forecast);
      expect(
        workspace.cycle?.dateConfidence,
        SuccessLabDateConfidence.estimated,
      );
      expect(
        workspace.cycle?.estimatedCloseAt,
        DateTime.utc(2027, 11, 5, 23, 59),
      );
      expect(workspace.nextAction?.code, 'upload_cv');
    });

    test('bounds readiness defensively without changing valid progress', () {
      final over = _backendWorkspaceFixture()..['readinessPercent'] = 140;
      final under = _backendWorkspaceFixture()..['readinessPercent'] = -10;

      expect(
        SuccessLabApiCodec.workspaceFromApi(over).readinessPercent,
        100,
      );
      expect(
        SuccessLabApiCodec.workspaceFromApi(under).readinessPercent,
        0,
      );
    });

    test('rejects a missing critical workspace id', () {
      final fixture = _backendWorkspaceFixture()..remove('id');

      expect(
        () => SuccessLabApiCodec.workspaceFromApi(fixture),
        throwsFormatException,
      );
    });

    test('never encodes an unknown step status as a mutation', () {
      expect(
        () => SuccessLabApiCodec.encodeWorkspaceStepStatus(
          SuccessLabWorkspaceStepStatus.unknown,
        ),
        throwsArgumentError,
      );
    });

    test('opens Outcomes only from an explicit server capability', () {
      final access = SuccessLabApiCodec.accessFromApi(
        <String, dynamic>{
          'enabled': true,
          'features': <String, dynamic>{
            'outcomeEvidence': <String, dynamic>{
              'enabled': false,
              'available': true,
              'requiresConsent': true,
              'reasons': <String>['CONSENT_REQUIRED'],
            },
          },
        },
      );

      expect(access.outcomeEvidenceEnabled, isFalse);
      expect(access.outcomeEvidenceAvailable, isTrue);
      expect(access.outcomeEvidenceRequiresConsent, isTrue);
    });

    test('decodes submission verification without retaining sensitive ids', () {
      final history = SuccessLabApiCodec.submissionHistoryFromApi(
        <String, dynamic>{
          'items': <Object?>[
            <String, dynamic>{
              'id': 'submission-1',
              'workspaceId': 'workspace-1',
              'version': 1,
              'lockVersion': 2,
              'submittedAt': '2026-07-16T12:00:00.000Z',
              'submissionChannel': 'official_portal',
              'hasApplicationReference': true,
              'applicationRefHash': 'must-not-be-retained',
              'evidence': <Object?>[
                <String, dynamic>{'id': 'private-evidence-id'},
              ],
              'verificationStatus': 'needs_information',
              'verificationNotes': 'Page 2 is missing.',
              'verifiedAt': null,
              'createdAt': '2026-07-16T12:01:00.000Z',
              'updatedAt': '2026-07-17T12:01:00.000Z',
            },
          ],
        },
      );

      expect(history.items, hasLength(1));
      expect(history.items.single.lockVersion, 2);
      expect(history.items.single.hasEvidence, isTrue);
      expect(history.items.single.hasApplicationReference, isTrue);
      expect(
        history.items.single.verificationStatus,
        SuccessLabEvidenceVerificationStatus.needsInformation,
      );
      expect(
        history.items.single.toString(),
        isNot(contains('private-evidence-id')),
      );
    });

    test('keeps current and historical admission/funding independent', () {
      final history = SuccessLabApiCodec.decisionHistoryFromApi(
        <String, dynamic>{
          'current': <String, dynamic>{
            'admission': _admissionDecisionFixture(
              id: 'admission-current',
              decision: 'admitted',
              isCurrent: true,
            ),
            'funding': _fundingDecisionFixture(
              id: 'funding-current',
              decision: 'partial',
              isCurrent: true,
              amountMinor: '1500000',
            ),
          },
          'history': <String, dynamic>{
            'admission': <Object?>[
              _admissionDecisionFixture(
                id: 'admission-old',
                decision: 'waitlisted',
                isCurrent: false,
              ),
            ],
            'funding': <Object?>[],
          },
          'workspaceVersion': 7,
        },
      );

      expect(history.workspaceVersion, 7);
      expect(history.currentAdmission?.decision,
          SuccessLabAdmissionDecision.admitted);
      expect(
          history.currentFunding?.decision, SuccessLabFundingDecision.partial);
      expect(history.currentFunding?.fundingAmountMinor, '1500000');
      expect(
        history.admissions.singleWhere((item) => !item.isCurrent).decision,
        SuccessLabAdmissionDecision.waitlisted,
      );
    });
  });
}

Map<String, dynamic> _admissionDecisionFixture({
  required String id,
  required String decision,
  required bool isCurrent,
}) =>
    <String, dynamic>{
      'id': id,
      'workspaceId': 'workspace-1',
      'supersedesId': null,
      'version': 1,
      'lockVersion': 1,
      'isCurrent': isCurrent,
      'issuedByName': 'Example University',
      'admissionDecision': decision,
      'issuedAt': '2026-07-15T09:00:00.000Z',
      'receivedAt': '2026-07-16T09:00:00.000Z',
      'evidence': <Object?>[
        <String, dynamic>{'id': 'not-retained'},
      ],
      'verificationStatus': 'self_reported',
      'verificationNotes': null,
      'verifiedAt': null,
      'createdAt': '2026-07-16T09:01:00.000Z',
      'updatedAt': '2026-07-16T09:01:00.000Z',
    };

Map<String, dynamic> _fundingDecisionFixture({
  required String id,
  required String decision,
  required bool isCurrent,
  String? amountMinor,
}) =>
    <String, dynamic>{
      'id': id,
      'workspaceId': 'workspace-1',
      'admissionDecisionId': 'admission-current',
      'supersedesId': null,
      'version': 1,
      'lockVersion': 1,
      'isCurrent': isCurrent,
      'issuedByName': 'Example University',
      'fundingDecision': decision,
      'fundingAmountMinor': amountMinor,
      'fundingCurrency': amountMinor == null ? null : 'EUR',
      'issuedAt': '2026-07-15T09:00:00.000Z',
      'receivedAt': '2026-07-16T09:00:00.000Z',
      'evidence': <Object?>[
        <String, dynamic>{'id': 'not-retained'},
      ],
      'verificationStatus': 'pending',
      'verificationNotes': null,
      'verifiedAt': null,
      'createdAt': '2026-07-16T09:01:00.000Z',
      'updatedAt': '2026-07-16T09:01:00.000Z',
    };

Map<String, dynamic> _backendWorkspaceFixture() {
  final file = File(
    'backend/src/modules/competition-readiness/contracts/fixtures/'
    'workspace-v1.fixture.json',
  );
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

Map<String, dynamic> _studyReviewFixture() => <String, dynamic>{
      'id': 'review-1',
      'workspaceId': 'workspace-1',
      'requestNumber': 2,
      'version': 3,
      'status': 'submitted',
      'nextAction': 'wait_for_triage',
      'studentMessage': 'Merci de relire mon dossier.',
      'preferredContact': 'in_app',
      'timezone': 'Africa/Niamey',
      'availability': <String, Object?>{'weekends': false},
      'missingItems': <String>[],
      'submittedAt': '2026-07-17T13:00:00.000Z',
      'triagedAt': null,
      'closedAt': null,
      'createdAt': '2026-07-17T12:59:00.000Z',
      'updatedAt': '2026-07-17T13:00:00.000Z',
      'sharedVersions': <Object?>[
        <String, dynamic>{
          'shareId': 'share-1',
          'artifactVersionId': 'version-2',
          'consentReceiptId': 'receipt-1',
          'grantedAt': '2026-07-17T13:00:00.000Z',
          'revokedAt': null,
          'artifact': <String, dynamic>{
            'id': 'artifact-1',
            'kind': 'cv',
            'title': 'CV bourse',
          },
          'version': <String, dynamic>{
            'id': 'version-2',
            'versionNumber': 2,
            'originalFileName': 'cv.pdf',
            'mimeType': 'application/pdf',
            'sizeBytes': 2400,
            'sha256': 'ignored-on-mobile',
            'processingStatus': 'clean',
            'uploadedAt': '2026-07-17T12:00:00.000Z',
          },
        },
      ],
    };
