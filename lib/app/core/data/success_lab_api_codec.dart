import '../models/success_lab.dart';

/// JSON boundary for the Success Lab workspace-v1 contract.
///
/// Unknown object fields are ignored. Unknown enum values are represented by
/// the corresponding `unknown` enum member and their original wire value is
/// retained on the model for forward-compatible cache round-trips.
abstract final class SuccessLabApiCodec {
  static SuccessLabAccess accessFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'access');
    final limits = _optionalMap(json['limits'], path: 'access.limits');
    final features = _optionalMap(json['features'], path: 'access.features');

    bool featureEnabled(List<String> keys) {
      if (features == null) return false;
      for (final key in keys) {
        final value = features[key];
        if (value is bool) return value;
        if (value is Map) {
          final enabled = value['enabled'];
          if (enabled is bool) return enabled;
        }
      }
      return false;
    }

    bool featureBoolean(List<String> keys, String property) {
      if (features == null) return false;
      for (final key in keys) {
        final value = features[key];
        if (value is Map && value[property] is bool) {
          return value[property] as bool;
        }
      }
      return false;
    }

    return SuccessLabAccess(
      enabled: json['enabled'] is bool && json['enabled'] == true,
      reasons: _stringList(json['reasons']),
      maxActiveWorkspaces: _nonNegativeInteger(limits?['maxActiveWorkspaces']),
      maxPageSize: _boundedInteger(
        limits?['maxPageSize'],
        min: 1,
        max: 50,
        fallback: 20,
      ),
      aiDiagnosticEnabled: featureEnabled(
        const <String>['aiDiagnostic', 'ai_diagnostic'],
      ),
      aiDiagnosticAvailable: featureBoolean(
        const <String>['aiDiagnostic', 'ai_diagnostic'],
        'available',
      ),
      aiDiagnosticRequiresConsent: featureBoolean(
        const <String>['aiDiagnostic', 'ai_diagnostic'],
        'requiresConsent',
      ),
      counsellorStudyEnabled: featureEnabled(
        const <String>['counsellorStudy', 'studyReview', 'study_review'],
      ),
      outcomeEvidenceEnabled: featureEnabled(
        const <String>['outcomeEvidence', 'outcome_evidence'],
      ),
      outcomeEvidenceAvailable: featureBoolean(
        const <String>['outcomeEvidence', 'outcome_evidence'],
        'available',
      ),
      outcomeEvidenceRequiresConsent: featureBoolean(
        const <String>['outcomeEvidence', 'outcome_evidence'],
        'requiresConsent',
      ),
    );
  }

  static Map<String, dynamic> accessToJson(SuccessLabAccess access) {
    return <String, dynamic>{
      'enabled': access.enabled,
      'reasons': access.reasons,
      'limits': <String, dynamic>{
        'maxActiveWorkspaces': access.maxActiveWorkspaces,
        'maxPageSize': access.maxPageSize,
      },
      'features': <String, dynamic>{
        'aiDiagnostic': <String, dynamic>{
          'enabled': access.aiDiagnosticEnabled,
          'available': access.aiDiagnosticAvailable,
          'requiresConsent': access.aiDiagnosticRequiresConsent,
        },
        'counsellorStudy': access.counsellorStudyEnabled,
        'outcomeEvidence': <String, dynamic>{
          'enabled': access.outcomeEvidenceEnabled,
          'available': access.outcomeEvidenceAvailable,
          'requiresConsent': access.outcomeEvidenceRequiresConsent,
        },
      },
    };
  }

  static SuccessLabAiNotice aiNoticeFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'aiNotice');
    return SuccessLabAiNotice(
      version: _requiredNonEmptyString(
        json['version'],
        path: 'aiNotice.version',
      ),
      languageCode: _requiredNonEmptyString(
        json['languageCode'],
        path: 'aiNotice.languageCode',
      ),
      title: _requiredNonEmptyString(json['title'], path: 'aiNotice.title'),
      body: _requiredNonEmptyString(json['body'], path: 'aiNotice.body'),
      contentHash: _requiredNonEmptyString(
        json['contentHash'],
        path: 'aiNotice.contentHash',
      ),
    );
  }

  static SuccessLabDiagnosticEnvelope diagnosticEnvelopeFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'diagnosticEnvelope');
    final entitlement = _optionalMap(
      json['entitlement'],
      path: 'diagnosticEnvelope.entitlement',
    );
    final diagnosticRaw = json['diagnostic'];
    return SuccessLabDiagnosticEnvelope(
      diagnostic:
          diagnosticRaw == null ? null : diagnosticFromApi(diagnosticRaw),
      entitlementAvailable: entitlement?['available'] is bool &&
          entitlement!['available'] == true,
    );
  }

  static SuccessLabDiagnostic diagnosticFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'diagnostic');
    final statusWire = _requiredNonEmptyString(
      json['status'],
      path: 'diagnostic.status',
    );
    final resultJson = _optionalMap(
      json['result'],
      path: 'diagnostic.result',
    );
    final invitation = _optionalMap(
      json['reviewInvitation'],
      path: 'diagnostic.reviewInvitation',
    );
    final result = resultJson == null
        ? null
        : SuccessLabDiagnosticResult(
            strength: _requiredNonEmptyString(
              resultJson['strength'],
              path: 'diagnostic.result.strength',
            ),
            priorityImprovement: _requiredNonEmptyString(
              resultJson['priorityImprovement'],
              path: 'diagnostic.result.priorityImprovement',
            ),
            rationale: _requiredNonEmptyString(
              resultJson['rationale'],
              path: 'diagnostic.result.rationale',
            ),
            nextAction: _requiredNonEmptyString(
              resultJson['nextAction'],
              path: 'diagnostic.result.nextAction',
            ),
            criterionReferences: _stringList(
              resultJson['criterionReferences'],
            ),
          );
    return SuccessLabDiagnostic(
      id: _requiredNonEmptyString(json['id'], path: 'diagnostic.id'),
      workspaceId: _requiredNonEmptyString(
        json['workspaceId'],
        path: 'diagnostic.workspaceId',
      ),
      status: _diagnosticStatusFromWire(statusWire),
      statusWireValue: statusWire,
      generatedLanguage: _nonEmptyString(json['generatedLanguage']),
      result: result,
      stale: json['stale'] is bool && json['stale'] == true,
      promptVersion: _requiredNonEmptyString(
        json['promptVersion'],
        path: 'diagnostic.promptVersion',
      ),
      fallbackReason: _nonEmptyString(json['fallbackReason']),
      completedAt: _dateTime(
        json['completedAt'],
        path: 'diagnostic.completedAt',
      ),
      reviewAvailable:
          invitation?['available'] is bool && invitation!['available'] == true,
    );
  }

  static SuccessLabDiagnosticStatus _diagnosticStatusFromWire(String value) {
    return switch (value) {
      'pending' => SuccessLabDiagnosticStatus.pending,
      'running' => SuccessLabDiagnosticStatus.running,
      'succeeded' => SuccessLabDiagnosticStatus.succeeded,
      'deterministic_fallback' =>
        SuccessLabDiagnosticStatus.deterministicFallback,
      'failed' => SuccessLabDiagnosticStatus.failed,
      'blocked' => SuccessLabDiagnosticStatus.blocked,
      _ => SuccessLabDiagnosticStatus.unknown,
    };
  }

  static List<SuccessLabArtifact> artifactsFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'artifacts');
    final items = json['items'];
    if (items is! List<dynamic>) {
      throw const FormatException('artifacts.items must be a JSON array.');
    }
    return List<SuccessLabArtifact>.unmodifiable(
      items.map((item) {
        final artifact = _requiredMap(item, path: 'artifacts.item');
        final rawVersions = artifact['versions'];
        if (rawVersions is! List<dynamic>) {
          throw const FormatException(
            'artifacts.item.versions must be a JSON array.',
          );
        }
        final versions = rawVersions.map((rawVersion) {
          final version = _requiredMap(
            rawVersion,
            path: 'artifacts.item.version',
          );
          return SuccessLabArtifactVersion(
            id: _requiredNonEmptyString(
              version['id'],
              path: 'artifacts.item.version.id',
            ),
            versionNumber: _boundedInteger(
              version['versionNumber'],
              min: 1,
              max: 100000,
            ),
            originalFileName: _requiredNonEmptyString(
              version['originalFileName'],
              path: 'artifacts.item.version.originalFileName',
            ),
            mimeType: _requiredNonEmptyString(
              version['mimeType'],
              path: 'artifacts.item.version.mimeType',
            ),
            sizeBytes: _nonNegativeInteger(version['sizeBytes']),
            processingStatus: _requiredNonEmptyString(
              version['processingStatus'],
              path: 'artifacts.item.version.processingStatus',
            ),
          );
        }).toList(growable: false);
        return SuccessLabArtifact(
          id: _requiredNonEmptyString(
            artifact['id'],
            path: 'artifacts.item.id',
          ),
          kind: _requiredNonEmptyString(
            artifact['kind'],
            path: 'artifacts.item.kind',
          ),
          title: _requiredNonEmptyString(
            artifact['title'],
            path: 'artifacts.item.title',
          ),
          currentVersionId: _nonEmptyString(artifact['currentVersionId']),
          versions: versions,
        );
      }),
    );
  }

  static SuccessLabStudyReviewRequest studyReviewFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'studyReview');
    final statusWire = _requiredNonEmptyString(
      json['status'],
      path: 'studyReview.status',
    );
    final nextActionWire = _nonEmptyString(json['nextAction']) ?? '';
    final availability = _optionalMap(
      json['availability'],
      path: 'studyReview.availability',
    );
    final rawShares = json['sharedVersions'];
    if (rawShares is! List<dynamic>) {
      throw const FormatException(
        'studyReview.sharedVersions must be a JSON array.',
      );
    }
    final sharedVersions = rawShares.map((rawShare) {
      final share = _requiredMap(
        rawShare,
        path: 'studyReview.sharedVersions.item',
      );
      final artifact = _requiredMap(
        share['artifact'],
        path: 'studyReview.sharedVersions.item.artifact',
      );
      final version = _requiredMap(
        share['version'],
        path: 'studyReview.sharedVersions.item.version',
      );
      return SuccessLabStudyReviewSharedVersion(
        shareId: _requiredNonEmptyString(
          share['shareId'],
          path: 'studyReview.sharedVersions.item.shareId',
        ),
        artifactVersionId: _requiredNonEmptyString(
          share['artifactVersionId'],
          path: 'studyReview.sharedVersions.item.artifactVersionId',
        ),
        artifactId: _requiredNonEmptyString(
          artifact['id'],
          path: 'studyReview.sharedVersions.item.artifact.id',
        ),
        artifactKind: _requiredNonEmptyString(
          artifact['kind'],
          path: 'studyReview.sharedVersions.item.artifact.kind',
        ),
        artifactTitle: _requiredNonEmptyString(
          artifact['title'],
          path: 'studyReview.sharedVersions.item.artifact.title',
        ),
        versionNumber: _boundedInteger(
          version['versionNumber'],
          min: 1,
          max: 100000,
        ),
        originalFileName: _requiredNonEmptyString(
          version['originalFileName'],
          path: 'studyReview.sharedVersions.item.version.originalFileName',
        ),
        mimeType: _requiredNonEmptyString(
          version['mimeType'],
          path: 'studyReview.sharedVersions.item.version.mimeType',
        ),
        sizeBytes: _nonNegativeInteger(version['sizeBytes']),
        processingStatus: _requiredNonEmptyString(
          version['processingStatus'],
          path: 'studyReview.sharedVersions.item.version.processingStatus',
        ),
        grantedAt: _requiredDateTime(
          share['grantedAt'],
          path: 'studyReview.sharedVersions.item.grantedAt',
        ),
        revokedAt: _dateTime(
          share['revokedAt'],
          path: 'studyReview.sharedVersions.item.revokedAt',
        ),
        uploadedAt: _dateTime(
          version['uploadedAt'],
          path: 'studyReview.sharedVersions.item.version.uploadedAt',
        ),
      );
    }).toList(growable: false);
    return SuccessLabStudyReviewRequest(
      id: _requiredNonEmptyString(json['id'], path: 'studyReview.id'),
      workspaceId: _requiredNonEmptyString(
        json['workspaceId'],
        path: 'studyReview.workspaceId',
      ),
      status: decodeStudyReviewStatus(statusWire),
      statusWireValue: statusWire,
      nextAction: decodeStudyReviewNextAction(nextActionWire),
      nextActionWireValue: nextActionWire,
      requestNumber: _boundedInteger(
        json['requestNumber'],
        min: 1,
        max: 100000,
      ),
      version: _boundedInteger(json['version'], min: 1, max: 1000000000),
      studentMessage: _string(json['studentMessage']),
      preferredContact: _nonEmptyString(json['preferredContact']),
      timezone: _requiredNonEmptyString(
        json['timezone'],
        path: 'studyReview.timezone',
      ),
      availability: availability == null
          ? null
          : Map<String, Object?>.unmodifiable(availability),
      missingItems: _stringList(json['missingItems']),
      submittedAt: _dateTime(
        json['submittedAt'],
        path: 'studyReview.submittedAt',
      ),
      triagedAt: _dateTime(
        json['triagedAt'],
        path: 'studyReview.triagedAt',
      ),
      closedAt: _dateTime(
        json['closedAt'],
        path: 'studyReview.closedAt',
      ),
      createdAt: _requiredDateTime(
        json['createdAt'],
        path: 'studyReview.createdAt',
      ),
      updatedAt: _requiredDateTime(
        json['updatedAt'],
        path: 'studyReview.updatedAt',
      ),
      sharedVersions: List<SuccessLabStudyReviewSharedVersion>.unmodifiable(
        sharedVersions,
      ),
    );
  }

  static SuccessLabStudyReviewRequest? activeStudyReviewFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'activeStudyReview');
    final schemaVersion = _integer(json['schemaVersion']);
    if (schemaVersion != successLabWorkspaceSchemaVersionV1) {
      throw const FormatException(
        'activeStudyReview.schemaVersion is unsupported.',
      );
    }
    final review = json['reviewRequest'];
    return review == null ? null : studyReviewFromApi(review);
  }

  static SuccessLabStudyReviewSlotOffers studyReviewSlotOffersFromApi(
    Object? raw,
  ) {
    final json = _requiredMap(raw, path: 'studyReviewSlotOffers');
    final rawOffers = json['offers'];
    if (rawOffers is! List<dynamic>) {
      throw const FormatException(
        'studyReviewSlotOffers.offers must be a JSON array.',
      );
    }
    final offers = rawOffers.map((rawOffer) {
      final offer = _requiredMap(
        rawOffer,
        path: 'studyReviewSlotOffers.offers.item',
      );
      return SuccessLabStudyReviewSlotOffer(
        slotOfferId: _requiredNonEmptyString(
          offer['slotOfferId'],
          path: 'studyReviewSlotOffers.offers.item.slotOfferId',
        ),
        slotId: _requiredNonEmptyString(
          offer['slotId'],
          path: 'studyReviewSlotOffers.offers.item.slotId',
        ),
        startsAt: _requiredDateTime(
          offer['startsAt'],
          path: 'studyReviewSlotOffers.offers.item.startsAt',
        ),
        endsAt: _requiredDateTime(
          offer['endsAt'],
          path: 'studyReviewSlotOffers.offers.item.endsAt',
        ),
        timezone: _requiredNonEmptyString(
          offer['timezone'],
          path: 'studyReviewSlotOffers.offers.item.timezone',
        ),
        expiresAt: _requiredDateTime(
          offer['expiresAt'],
          path: 'studyReviewSlotOffers.offers.item.expiresAt',
        ),
        counsellorName: _requiredNonEmptyString(
          offer['counsellorName'],
          path: 'studyReviewSlotOffers.offers.item.counsellorName',
        ),
      );
    }).toList(growable: false);
    return SuccessLabStudyReviewSlotOffers(
      reviewRequestId: _requiredNonEmptyString(
        json['reviewRequestId'],
        path: 'studyReviewSlotOffers.reviewRequestId',
      ),
      reviewRequestVersion: _boundedInteger(
        json['reviewRequestVersion'],
        min: 1,
        max: 1000000000,
      ),
      timezone: _requiredNonEmptyString(
        json['timezone'],
        path: 'studyReviewSlotOffers.timezone',
      ),
      offers: List<SuccessLabStudyReviewSlotOffer>.unmodifiable(offers),
    );
  }

  static SuccessLabStudyReviewBookingResult studyReviewBookingFromApi(
    Object? raw,
  ) {
    final json = _requiredMap(raw, path: 'studyReviewBooking');
    final appointment = _requiredMap(
      json['appointment'],
      path: 'studyReviewBooking.appointment',
    );
    final review = _requiredMap(
      json['reviewRequest'],
      path: 'studyReviewBooking.reviewRequest',
    );
    final reviewStatusWire = _requiredNonEmptyString(
      review['status'],
      path: 'studyReviewBooking.reviewRequest.status',
    );
    return SuccessLabStudyReviewBookingResult(
      appointment: SuccessLabStudyReviewAppointment(
        id: _requiredNonEmptyString(
          appointment['id'],
          path: 'studyReviewBooking.appointment.id',
        ),
        reviewRequestId: _requiredNonEmptyString(
          appointment['reviewRequestId'],
          path: 'studyReviewBooking.appointment.reviewRequestId',
        ),
        slotOfferId: _requiredNonEmptyString(
          appointment['slotOfferId'],
          path: 'studyReviewBooking.appointment.slotOfferId',
        ),
        slotId: _requiredNonEmptyString(
          appointment['slotId'],
          path: 'studyReviewBooking.appointment.slotId',
        ),
        counsellorId: _requiredNonEmptyString(
          appointment['counsellorId'],
          path: 'studyReviewBooking.appointment.counsellorId',
        ),
        startsAt: _requiredDateTime(
          appointment['startsAt'],
          path: 'studyReviewBooking.appointment.startsAt',
        ),
        endsAt: _requiredDateTime(
          appointment['endsAt'],
          path: 'studyReviewBooking.appointment.endsAt',
        ),
        timezone: _requiredNonEmptyString(
          appointment['timezone'],
          path: 'studyReviewBooking.appointment.timezone',
        ),
        status: _requiredNonEmptyString(
          appointment['status'],
          path: 'studyReviewBooking.appointment.status',
        ),
        contactMethod: _requiredNonEmptyString(
          appointment['contactMethod'],
          path: 'studyReviewBooking.appointment.contactMethod',
        ),
        createdAt: _requiredDateTime(
          appointment['createdAt'],
          path: 'studyReviewBooking.appointment.createdAt',
        ),
      ),
      reviewRequestId: _requiredNonEmptyString(
        review['id'],
        path: 'studyReviewBooking.reviewRequest.id',
      ),
      reviewRequestVersion: _boundedInteger(
        review['version'],
        min: 1,
        max: 1000000000,
      ),
      reviewRequestStatus: decodeStudyReviewStatus(reviewStatusWire),
    );
  }

  static SuccessLabSubmissionHistory submissionHistoryFromApi(Object? raw) {
    final Object? itemsRaw;
    if (raw is List<dynamic>) {
      itemsRaw = raw;
    } else {
      final json = _requiredMap(raw, path: 'submissionHistory');
      itemsRaw = json['items'] ?? json['submissions'] ?? const <Object?>[];
    }
    if (itemsRaw is! List<dynamic>) {
      throw const FormatException(
        'submissionHistory.items must be a JSON array.',
      );
    }
    return SuccessLabSubmissionHistory(
      items: List<SuccessLabApplicationSubmission>.unmodifiable(
        itemsRaw.map(applicationSubmissionFromApi),
      ),
    );
  }

  static SuccessLabApplicationSubmission applicationSubmissionFromApi(
    Object? raw,
  ) {
    final json = _requiredMap(raw, path: 'submission');
    final statusWire = _requiredNonEmptyString(
      json['verificationStatus'],
      path: 'submission.verificationStatus',
    );
    return SuccessLabApplicationSubmission(
      id: _requiredNonEmptyString(json['id'], path: 'submission.id'),
      workspaceId: _requiredNonEmptyString(
        json['workspaceId'],
        path: 'submission.workspaceId',
      ),
      version: _boundedInteger(json['version'], min: 1, max: 100000),
      lockVersion: _boundedInteger(
        json['lockVersion'],
        min: 1,
        max: 100000,
      ),
      submittedAt: _requiredDateTime(
        json['submittedAt'],
        path: 'submission.submittedAt',
      ),
      submissionChannel: _nonEmptyString(json['submissionChannel']),
      hasApplicationReference: json['hasApplicationReference'] == true ||
          _nonEmptyString(json['applicationRefHash']) != null,
      hasEvidence: json['hasEvidence'] == true ||
          _nonEmptyString(json['evidenceId']) != null ||
          json['evidence'] is Map ||
          (json['evidence'] is List && (json['evidence'] as List).isNotEmpty),
      verificationStatus: decodeEvidenceVerificationStatus(statusWire),
      verificationStatusWireValue: statusWire,
      verificationNotes: _nonEmptyString(json['verificationNotes']),
      verifiedAt: _dateTime(
        json['verifiedAt'],
        path: 'submission.verifiedAt',
      ),
      createdAt: _requiredDateTime(
        json['createdAt'],
        path: 'submission.createdAt',
      ),
      updatedAt: _requiredDateTime(
        json['updatedAt'],
        path: 'submission.updatedAt',
      ),
    );
  }

  static SuccessLabDecisionHistory decisionHistoryFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'decisionHistory');
    final history = _requiredMap(
      json['history'],
      path: 'decisionHistory.history',
    );
    final current = _requiredMap(
      json['current'],
      path: 'decisionHistory.current',
    );
    final admissions = _recordList<SuccessLabAdmissionDecisionRecord>(
      history['admission'] ?? const <Object?>[],
      path: 'decisionHistory.admissions',
      decode: admissionDecisionFromApi,
    ).toList(growable: true);
    final funding = _recordList<SuccessLabFundingDecisionRecord>(
      history['funding'] ?? const <Object?>[],
      path: 'decisionHistory.funding',
      decode: fundingDecisionFromApi,
    ).toList(growable: true);

    final currentAdmission = current['admission'];
    if (currentAdmission != null) {
      final decoded = admissionDecisionFromApi(currentAdmission);
      if (!admissions.any((item) => item.id == decoded.id)) {
        admissions.insert(0, decoded);
      }
    }
    final currentFunding = current['funding'];
    if (currentFunding != null) {
      final decoded = fundingDecisionFromApi(currentFunding);
      if (!funding.any((item) => item.id == decoded.id)) {
        funding.insert(0, decoded);
      }
    }
    return SuccessLabDecisionHistory(
      admissions: List<SuccessLabAdmissionDecisionRecord>.unmodifiable(
        admissions,
      ),
      funding: List<SuccessLabFundingDecisionRecord>.unmodifiable(funding),
      workspaceVersion: _boundedInteger(
        json['workspaceVersion'],
        min: 1,
        max: 100000,
      ),
    );
  }

  static SuccessLabAdmissionDecisionRecord admissionDecisionFromApi(
    Object? raw,
  ) {
    final json = _requiredMap(raw, path: 'admissionDecision');
    final decisionWire = _requiredNonEmptyString(
      json['admissionDecision'],
      path: 'admissionDecision.admissionDecision',
    );
    final statusWire = _requiredNonEmptyString(
      json['verificationStatus'],
      path: 'admissionDecision.verificationStatus',
    );
    return SuccessLabAdmissionDecisionRecord(
      id: _requiredNonEmptyString(json['id'], path: 'admissionDecision.id'),
      workspaceId: _requiredNonEmptyString(
        json['workspaceId'],
        path: 'admissionDecision.workspaceId',
      ),
      supersedesId: _nonEmptyString(json['supersedesId']),
      version: _boundedInteger(json['version'], min: 1, max: 100000),
      lockVersion: _boundedInteger(
        json['lockVersion'],
        min: 1,
        max: 100000,
      ),
      isCurrent: json['isCurrent'] == true,
      issuedByName: _requiredNonEmptyString(
        json['issuedByName'],
        path: 'admissionDecision.issuedByName',
      ),
      decision: decodeAdmissionDecision(decisionWire),
      decisionWireValue: decisionWire,
      issuedAt: _dateTime(
        json['issuedAt'],
        path: 'admissionDecision.issuedAt',
      ),
      receivedAt: _requiredDateTime(
        json['receivedAt'],
        path: 'admissionDecision.receivedAt',
      ),
      hasEvidence: json['hasEvidence'] == true ||
          _nonEmptyString(json['evidenceId']) != null ||
          json['evidence'] is Map ||
          (json['evidence'] is List && (json['evidence'] as List).isNotEmpty),
      verificationStatus: decodeEvidenceVerificationStatus(statusWire),
      verificationStatusWireValue: statusWire,
      verificationNotes: _nonEmptyString(json['verificationNotes']),
      verifiedAt: _dateTime(
        json['verifiedAt'],
        path: 'admissionDecision.verifiedAt',
      ),
      createdAt: _requiredDateTime(
        json['createdAt'],
        path: 'admissionDecision.createdAt',
      ),
      updatedAt: _requiredDateTime(
        json['updatedAt'],
        path: 'admissionDecision.updatedAt',
      ),
    );
  }

  static SuccessLabFundingDecisionRecord fundingDecisionFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'fundingDecision');
    final decisionWire = _requiredNonEmptyString(
      json['fundingDecision'],
      path: 'fundingDecision.fundingDecision',
    );
    final statusWire = _requiredNonEmptyString(
      json['verificationStatus'],
      path: 'fundingDecision.verificationStatus',
    );
    return SuccessLabFundingDecisionRecord(
      id: _requiredNonEmptyString(json['id'], path: 'fundingDecision.id'),
      workspaceId: _requiredNonEmptyString(
        json['workspaceId'],
        path: 'fundingDecision.workspaceId',
      ),
      admissionDecisionId: _nonEmptyString(json['admissionDecisionId']),
      supersedesId: _nonEmptyString(json['supersedesId']),
      version: _boundedInteger(json['version'], min: 1, max: 100000),
      lockVersion: _boundedInteger(
        json['lockVersion'],
        min: 1,
        max: 100000,
      ),
      isCurrent: json['isCurrent'] == true,
      issuedByName: _requiredNonEmptyString(
        json['issuedByName'],
        path: 'fundingDecision.issuedByName',
      ),
      decision: decodeFundingDecision(decisionWire),
      decisionWireValue: decisionWire,
      fundingAmountMinor: _decimalString(json['fundingAmountMinor']),
      fundingCurrency: _nonEmptyString(json['fundingCurrency']),
      issuedAt: _dateTime(
        json['issuedAt'],
        path: 'fundingDecision.issuedAt',
      ),
      receivedAt: _requiredDateTime(
        json['receivedAt'],
        path: 'fundingDecision.receivedAt',
      ),
      hasEvidence: json['hasEvidence'] == true ||
          _nonEmptyString(json['evidenceId']) != null ||
          json['evidence'] is Map ||
          (json['evidence'] is List && (json['evidence'] as List).isNotEmpty),
      verificationStatus: decodeEvidenceVerificationStatus(statusWire),
      verificationStatusWireValue: statusWire,
      verificationNotes: _nonEmptyString(json['verificationNotes']),
      verifiedAt: _dateTime(
        json['verifiedAt'],
        path: 'fundingDecision.verifiedAt',
      ),
      createdAt: _requiredDateTime(
        json['createdAt'],
        path: 'fundingDecision.createdAt',
      ),
      updatedAt: _requiredDateTime(
        json['updatedAt'],
        path: 'fundingDecision.updatedAt',
      ),
    );
  }

  static SuccessLabOutcomeEvidence outcomeEvidenceFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'outcomeEvidence');
    final kindWire = _requiredNonEmptyString(
      json['kind'],
      path: 'outcomeEvidence.kind',
    );
    return SuccessLabOutcomeEvidence(
      id: _requiredNonEmptyString(json['id'], path: 'outcomeEvidence.id'),
      workspaceId: _requiredNonEmptyString(
        json['workspaceId'],
        path: 'outcomeEvidence.workspaceId',
      ),
      kind: decodeOutcomeEvidenceKind(kindWire),
      kindWireValue: kindWire,
      originalFileName: _requiredNonEmptyString(
        json['originalFileName'],
        path: 'outcomeEvidence.originalFileName',
      ),
      mimeType: _requiredNonEmptyString(
        json['mimeType'],
        path: 'outcomeEvidence.mimeType',
      ),
      sizeBytes: _nonNegativeInteger(json['sizeBytes']),
      processingStatus: _requiredNonEmptyString(
        json['processingStatus'],
        path: 'outcomeEvidence.processingStatus',
      ),
      createdAt: _requiredDateTime(
        json['createdAt'],
        path: 'outcomeEvidence.createdAt',
      ),
    );
  }

  static SuccessLabWorkspaceMutationSummary workspaceMutationSummaryFromApi(
    Object? raw,
  ) {
    final json = _requiredMap(raw, path: 'workspaceMutation');
    final statusWire = _requiredNonEmptyString(
      json['status'],
      path: 'workspaceMutation.status',
    );
    return SuccessLabWorkspaceMutationSummary(
      id: _requiredNonEmptyString(json['id'], path: 'workspaceMutation.id'),
      status: decodeWorkspaceStatus(statusWire),
      statusWireValue: statusWire,
      version: _boundedInteger(json['version'], min: 1, max: 100000),
    );
  }

  static SuccessLabEvidenceVerificationStatus decodeEvidenceVerificationStatus(
    Object? raw,
  ) {
    return switch (raw) {
      'self_reported' => SuccessLabEvidenceVerificationStatus.selfReported,
      'pending' => SuccessLabEvidenceVerificationStatus.pending,
      'verified' => SuccessLabEvidenceVerificationStatus.verified,
      'needs_information' =>
        SuccessLabEvidenceVerificationStatus.needsInformation,
      'rejected' => SuccessLabEvidenceVerificationStatus.rejected,
      _ => SuccessLabEvidenceVerificationStatus.unknown,
    };
  }

  static SuccessLabAdmissionDecision decodeAdmissionDecision(Object? raw) {
    return switch (raw) {
      'admitted' => SuccessLabAdmissionDecision.admitted,
      'rejected' => SuccessLabAdmissionDecision.rejected,
      'waitlisted' => SuccessLabAdmissionDecision.waitlisted,
      'deferred' => SuccessLabAdmissionDecision.deferred,
      'withdrawn' => SuccessLabAdmissionDecision.withdrawn,
      _ => SuccessLabAdmissionDecision.unknown,
    };
  }

  static SuccessLabFundingDecision decodeFundingDecision(Object? raw) {
    return switch (raw) {
      'full' => SuccessLabFundingDecision.full,
      'partial' => SuccessLabFundingDecision.partial,
      'none' => SuccessLabFundingDecision.none,
      'pending' => SuccessLabFundingDecision.pending,
      'not_applicable' => SuccessLabFundingDecision.notApplicable,
      _ => SuccessLabFundingDecision.unknown,
    };
  }

  static SuccessLabOutcomeEvidenceKind decodeOutcomeEvidenceKind(Object? raw) {
    return switch (raw) {
      'submission_confirmation' =>
        SuccessLabOutcomeEvidenceKind.submissionConfirmation,
      'admission_decision' => SuccessLabOutcomeEvidenceKind.admissionDecision,
      'rejection_decision' => SuccessLabOutcomeEvidenceKind.rejectionDecision,
      'waitlist_decision' => SuccessLabOutcomeEvidenceKind.waitlistDecision,
      'funding_award' => SuccessLabOutcomeEvidenceKind.fundingAward,
      'funding_rejection' => SuccessLabOutcomeEvidenceKind.fundingRejection,
      'enrollment_confirmation' =>
        SuccessLabOutcomeEvidenceKind.enrollmentConfirmation,
      'other' => SuccessLabOutcomeEvidenceKind.other,
      _ => SuccessLabOutcomeEvidenceKind.unknown,
    };
  }

  static String encodeAdmissionDecision(SuccessLabAdmissionDecision value) {
    return switch (value) {
      SuccessLabAdmissionDecision.admitted => 'admitted',
      SuccessLabAdmissionDecision.rejected => 'rejected',
      SuccessLabAdmissionDecision.waitlisted => 'waitlisted',
      SuccessLabAdmissionDecision.deferred => 'deferred',
      SuccessLabAdmissionDecision.withdrawn => 'withdrawn',
      SuccessLabAdmissionDecision.unknown => throw ArgumentError.value(
          value,
          'value',
          'An unknown admission decision cannot be sent.',
        ),
    };
  }

  static String encodeFundingDecision(SuccessLabFundingDecision value) {
    return switch (value) {
      SuccessLabFundingDecision.full => 'full',
      SuccessLabFundingDecision.partial => 'partial',
      SuccessLabFundingDecision.none => 'none',
      SuccessLabFundingDecision.pending => 'pending',
      SuccessLabFundingDecision.notApplicable => 'not_applicable',
      SuccessLabFundingDecision.unknown => throw ArgumentError.value(
          value,
          'value',
          'An unknown funding decision cannot be sent.',
        ),
    };
  }

  static String encodeOutcomeEvidenceKind(SuccessLabOutcomeEvidenceKind value) {
    return switch (value) {
      SuccessLabOutcomeEvidenceKind.submissionConfirmation =>
        'submission_confirmation',
      SuccessLabOutcomeEvidenceKind.admissionDecision => 'admission_decision',
      SuccessLabOutcomeEvidenceKind.rejectionDecision => 'rejection_decision',
      SuccessLabOutcomeEvidenceKind.waitlistDecision => 'waitlist_decision',
      SuccessLabOutcomeEvidenceKind.fundingAward => 'funding_award',
      SuccessLabOutcomeEvidenceKind.fundingRejection => 'funding_rejection',
      SuccessLabOutcomeEvidenceKind.enrollmentConfirmation =>
        'enrollment_confirmation',
      SuccessLabOutcomeEvidenceKind.other => 'other',
      SuccessLabOutcomeEvidenceKind.unknown => throw ArgumentError.value(
          value,
          'value',
          'An unknown evidence kind cannot be sent.',
        ),
    };
  }

  static SuccessLabStudyReviewStatus decodeStudyReviewStatus(Object? raw) {
    return switch (raw) {
      'draft' => SuccessLabStudyReviewStatus.draft,
      'submitted' => SuccessLabStudyReviewStatus.submitted,
      'triaged' => SuccessLabStudyReviewStatus.triaged,
      'more_information_needed' =>
        SuccessLabStudyReviewStatus.moreInformationNeeded,
      'call_offered' => SuccessLabStudyReviewStatus.callOffered,
      'scheduled' => SuccessLabStudyReviewStatus.scheduled,
      'converted_to_case' => SuccessLabStudyReviewStatus.convertedToCase,
      'autonomy_recommended' => SuccessLabStudyReviewStatus.autonomyRecommended,
      'declined' => SuccessLabStudyReviewStatus.declined,
      'closed' => SuccessLabStudyReviewStatus.closed,
      _ => SuccessLabStudyReviewStatus.unknown,
    };
  }

  static SuccessLabStudyReviewNextAction decodeStudyReviewNextAction(
    Object? raw,
  ) {
    return switch (raw) {
      'complete_request' => SuccessLabStudyReviewNextAction.completeRequest,
      'wait_for_triage' => SuccessLabStudyReviewNextAction.waitForTriage,
      'provide_more_information' =>
        SuccessLabStudyReviewNextAction.provideMoreInformation,
      'wait_for_slot_offer' => SuccessLabStudyReviewNextAction.waitForSlotOffer,
      'choose_slot' => SuccessLabStudyReviewNextAction.chooseSlot,
      'appointment_scheduled' =>
        SuccessLabStudyReviewNextAction.appointmentScheduled,
      'case_created' => SuccessLabStudyReviewNextAction.caseCreated,
      'continue_autonomously' =>
        SuccessLabStudyReviewNextAction.continueAutonomously,
      'none' => SuccessLabStudyReviewNextAction.none,
      _ => SuccessLabStudyReviewNextAction.unknown,
    };
  }

  static SuccessLabWorkspace workspaceFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'workspace');
    final scholarshipJson = _optionalMap(
      json['scholarship'],
      path: 'workspace.scholarship',
    );
    final cycleJson = _optionalMap(
      json['cycle'],
      path: 'workspace.cycle',
    );
    final scholarship =
        scholarshipJson == null ? null : _scholarshipFromApi(scholarshipJson);
    final cycle = cycleJson == null ? null : _cycleFromApi(cycleJson);

    final scholarshipId =
        _nonEmptyString(json['scholarshipId']) ?? scholarship?.id;
    if (scholarshipId == null) {
      throw const FormatException(
        'workspace is missing "scholarshipId" or "scholarship.id".',
      );
    }

    final scholarshipCycleId =
        _nonEmptyString(json['scholarshipCycleId']) ?? cycle?.id;
    if (scholarshipCycleId == null) {
      throw const FormatException(
        'workspace is missing "scholarshipCycleId" or "cycle.id".',
      );
    }

    final statusWireValue = _string(json['status']) ?? '';
    return SuccessLabWorkspace(
      schemaVersion:
          _integer(json['schemaVersion']) ?? successLabWorkspaceSchemaVersionV1,
      id: _requiredNonEmptyString(json['id'], path: 'workspace.id'),
      userId: _nonEmptyString(json['userId']),
      scholarshipId: scholarshipId,
      scholarshipCycleId: scholarshipCycleId,
      status: decodeWorkspaceStatus(statusWireValue),
      statusWireValue: statusWireValue,
      version: _nonNegativeInteger(json['version']),
      readinessPercent: _boundedInteger(
        json['readinessPercent'],
        min: 0,
        max: 100,
      ),
      startedAt: _dateTime(json['startedAt'], path: 'workspace.startedAt'),
      lastActivityAt: _dateTime(
        json['lastActivityAt'],
        path: 'workspace.lastActivityAt',
      ),
      submittedAt:
          _dateTime(json['submittedAt'], path: 'workspace.submittedAt'),
      decisionReceivedAt: _dateTime(
        json['decisionReceivedAt'],
        path: 'workspace.decisionReceivedAt',
      ),
      archivedAt: _dateTime(json['archivedAt'], path: 'workspace.archivedAt'),
      steps: _workspaceStepsFromApi(json['steps']),
      scholarship: scholarship,
      cycle: cycle,
      nextAction: _nextActionFromApi(json['nextAction']),
    );
  }

  /// Parses the cursor envelope used by the workspace list endpoint.
  ///
  /// A bare list remains accepted for staged backend rollouts. The canonical
  /// v1 envelope key is `items`; `workspaces` is accepted as a compatibility
  /// alias until the controller contract is frozen.
  static SuccessLabWorkspacePage workspacePageFromApi(Object? raw) {
    if (raw is List<dynamic>) {
      return SuccessLabWorkspacePage(
        items: _workspaceListFromApi(raw, path: 'workspaces'),
      );
    }

    final json = _requiredMap(raw, path: 'workspacePage');
    final itemsRaw = json.containsKey('items')
        ? json['items']
        : json['workspaces'] ?? const <Object?>[];
    if (itemsRaw is! List<dynamic>) {
      throw const FormatException(
        'workspacePage.items must be a JSON array.',
      );
    }

    return SuccessLabWorkspacePage(
      items: _workspaceListFromApi(itemsRaw, path: 'workspacePage.items'),
      nextCursor: _nonEmptyString(json['nextCursor']),
    );
  }

  static Map<String, dynamic> workspacePageToJson(
    SuccessLabWorkspacePage page,
  ) {
    return <String, dynamic>{
      'items': page.items.map(workspaceToJson).toList(growable: false),
      'nextCursor': page.nextCursor,
    };
  }

  static SuccessLabWorkspaceStep workspaceStepFromApi(Object? raw) {
    final json = _requiredMap(raw, path: 'workspaceStep');
    final categoryWireValue = _string(json['category']) ?? '';
    final statusWireValue = _string(json['status']) ?? '';
    return SuccessLabWorkspaceStep(
      id: _requiredNonEmptyString(json['id'], path: 'workspaceStep.id'),
      sourceStepId: _nonEmptyString(json['sourceStepId']),
      code: _requiredNonEmptyString(json['code'], path: 'workspaceStep.code'),
      titleFr: _string(json['titleFr']) ?? '',
      titleEn: _string(json['titleEn']) ?? '',
      category: decodeWorkspaceStepCategory(categoryWireValue),
      categoryWireValue: categoryWireValue,
      weight: _nonNegativeInteger(json['weight']),
      isRequired:
          json['isRequired'] is bool ? json['isRequired']! as bool : true,
      templateVersion: _string(json['templateVersion']) ?? 'v1',
      status: decodeWorkspaceStepStatus(statusWireValue),
      statusWireValue: statusWireValue,
      notApplicableReason: _string(json['notApplicableReason']),
      completedAt: _dateTime(
        json['completedAt'],
        path: 'workspaceStep.completedAt',
      ),
    );
  }

  /// Stable cache representation. It deliberately excludes unknown object
  /// fields but preserves unknown enum wire values.
  static Map<String, dynamic> workspaceToJson(SuccessLabWorkspace workspace) {
    return <String, dynamic>{
      'schemaVersion': workspace.schemaVersion,
      'id': workspace.id,
      if (workspace.userId != null) 'userId': workspace.userId,
      'scholarshipId': workspace.scholarshipId,
      'scholarshipCycleId': workspace.scholarshipCycleId,
      'status': _workspaceStatusToWire(
        workspace.status,
        workspace.statusWireValue,
      ),
      'version': workspace.version,
      'readinessPercent': workspace.readinessPercent,
      if (workspace.startedAt != null)
        'startedAt': _dateTimeToWire(workspace.startedAt!),
      if (workspace.lastActivityAt != null)
        'lastActivityAt': _dateTimeToWire(workspace.lastActivityAt!),
      if (workspace.submittedAt != null)
        'submittedAt': _dateTimeToWire(workspace.submittedAt!),
      if (workspace.decisionReceivedAt != null)
        'decisionReceivedAt': _dateTimeToWire(workspace.decisionReceivedAt!),
      if (workspace.archivedAt != null)
        'archivedAt': _dateTimeToWire(workspace.archivedAt!),
      'steps': workspace.steps.map(workspaceStepToJson).toList(growable: false),
      if (workspace.scholarship != null)
        'scholarship': <String, dynamic>{
          'id': workspace.scholarship!.id,
          'name': workspace.scholarship!.name,
          'countryName': workspace.scholarship!.countryName,
        },
      if (workspace.cycle != null) 'cycle': _cycleToJson(workspace.cycle!),
      if (workspace.nextAction != null)
        'nextAction': <String, dynamic>{
          'code': workspace.nextAction!.code,
          'label': workspace.nextAction!.label,
        },
    };
  }

  static Map<String, dynamic> workspaceStepToJson(
    SuccessLabWorkspaceStep step,
  ) {
    return <String, dynamic>{
      'id': step.id,
      if (step.sourceStepId != null) 'sourceStepId': step.sourceStepId,
      'code': step.code,
      'titleFr': step.titleFr,
      'titleEn': step.titleEn,
      'category': _workspaceStepCategoryToWire(
        step.category,
        step.categoryWireValue,
      ),
      'weight': step.weight,
      'isRequired': step.isRequired,
      'templateVersion': step.templateVersion,
      'status': _workspaceStepStatusToWire(step.status, step.statusWireValue),
      if (step.notApplicableReason != null)
        'notApplicableReason': step.notApplicableReason,
      if (step.completedAt != null)
        'completedAt': _dateTimeToWire(step.completedAt!),
    };
  }

  static SuccessLabWorkspaceStatus decodeWorkspaceStatus(Object? raw) {
    switch (raw) {
      case 'started':
        return SuccessLabWorkspaceStatus.started;
      case 'preparing':
        return SuccessLabWorkspaceStatus.preparing;
      case 'ready_for_review':
        return SuccessLabWorkspaceStatus.readyForReview;
      case 'review_requested':
        return SuccessLabWorkspaceStatus.reviewRequested;
      case 'submitted':
        return SuccessLabWorkspaceStatus.submitted;
      case 'decision_received':
        return SuccessLabWorkspaceStatus.decisionReceived;
      case 'archived':
        return SuccessLabWorkspaceStatus.archived;
      default:
        return SuccessLabWorkspaceStatus.unknown;
    }
  }

  static SuccessLabWorkspaceStepStatus decodeWorkspaceStepStatus(Object? raw) {
    switch (raw) {
      case 'not_started':
        return SuccessLabWorkspaceStepStatus.notStarted;
      case 'in_progress':
        return SuccessLabWorkspaceStepStatus.inProgress;
      case 'completed':
        return SuccessLabWorkspaceStepStatus.completed;
      case 'not_applicable':
        return SuccessLabWorkspaceStepStatus.notApplicable;
      default:
        return SuccessLabWorkspaceStepStatus.unknown;
    }
  }

  static SuccessLabWorkspaceStepCategory decodeWorkspaceStepCategory(
    Object? raw,
  ) {
    switch (raw) {
      case 'profile_eligibility':
        return SuccessLabWorkspaceStepCategory.profileEligibility;
      case 'documents':
        return SuccessLabWorkspaceStepCategory.documents;
      case 'form_and_essays':
        return SuccessLabWorkspaceStepCategory.formAndEssays;
      case 'review_and_submission':
        return SuccessLabWorkspaceStepCategory.reviewAndSubmission;
      default:
        return SuccessLabWorkspaceStepCategory.unknown;
    }
  }

  /// Only known v1 values may be sent in a step mutation. A future value read
  /// by an old client remains displayable, but cannot be echoed as a mutation.
  static String encodeWorkspaceStepStatus(
    SuccessLabWorkspaceStepStatus status,
  ) {
    switch (status) {
      case SuccessLabWorkspaceStepStatus.notStarted:
        return 'not_started';
      case SuccessLabWorkspaceStepStatus.inProgress:
        return 'in_progress';
      case SuccessLabWorkspaceStepStatus.completed:
        return 'completed';
      case SuccessLabWorkspaceStepStatus.notApplicable:
        return 'not_applicable';
      case SuccessLabWorkspaceStepStatus.unknown:
        throw ArgumentError.value(
          status,
          'status',
          'An unknown server status cannot be sent as a mutation.',
        );
    }
  }

  static List<SuccessLabWorkspace> _workspaceListFromApi(
    List<dynamic> raw, {
    required String path,
  }) {
    return List<SuccessLabWorkspace>.unmodifiable(
      raw.indexed.map(
        (entry) {
          try {
            return workspaceFromApi(entry.$2);
          } on FormatException catch (error) {
            throw FormatException('$path[${entry.$1}]: ${error.message}');
          }
        },
      ),
    );
  }

  static List<SuccessLabWorkspaceStep> _workspaceStepsFromApi(Object? raw) {
    if (raw == null) return const <SuccessLabWorkspaceStep>[];
    if (raw is! List<dynamic>) {
      throw const FormatException('workspace.steps must be a JSON array.');
    }
    return List<SuccessLabWorkspaceStep>.unmodifiable(
      raw.indexed.map(
        (entry) {
          try {
            return workspaceStepFromApi(entry.$2);
          } on FormatException catch (error) {
            throw FormatException(
              'workspace.steps[${entry.$1}]: ${error.message}',
            );
          }
        },
      ),
    );
  }

  static SuccessLabScholarshipSummary _scholarshipFromApi(
    Map<String, dynamic> json,
  ) {
    return SuccessLabScholarshipSummary(
      id: _requiredNonEmptyString(
        json['id'],
        path: 'workspace.scholarship.id',
      ),
      name: _string(json['name']) ?? '',
      countryName: _string(json['countryName']) ?? '',
    );
  }

  static SuccessLabCycleSummary _cycleFromApi(Map<String, dynamic> json) {
    final statusWireValue = _string(json['status']) ?? '';
    final dateConfidenceWireValue = _string(json['dateConfidence']) ?? '';
    return SuccessLabCycleSummary(
      id: _requiredNonEmptyString(json['id'], path: 'workspace.cycle.id'),
      status: _decodeCycleStatus(statusWireValue),
      statusWireValue: statusWireValue,
      dateConfidence: _decodeDateConfidence(dateConfidenceWireValue),
      dateConfidenceWireValue: dateConfidenceWireValue,
      opensAt: _dateTime(json['opensAt'], path: 'workspace.cycle.opensAt'),
      closesAt: _dateTime(json['closesAt'], path: 'workspace.cycle.closesAt'),
      estimatedOpenAt: _dateTime(
        json['estimatedOpenAt'],
        path: 'workspace.cycle.estimatedOpenAt',
      ),
      estimatedCloseAt: _dateTime(
        json['estimatedCloseAt'],
        path: 'workspace.cycle.estimatedCloseAt',
      ),
    );
  }

  static SuccessLabNextAction? _nextActionFromApi(Object? raw) {
    final json = _optionalMap(raw, path: 'workspace.nextAction');
    if (json == null) return null;
    return SuccessLabNextAction(
      code: _string(json['code']) ?? '',
      label: _string(json['label']) ?? '',
    );
  }

  static SuccessLabCycleStatus _decodeCycleStatus(Object? raw) {
    switch (raw) {
      case 'forecast':
        return SuccessLabCycleStatus.forecast;
      case 'open':
        return SuccessLabCycleStatus.open;
      case 'closed':
        return SuccessLabCycleStatus.closed;
      case 'suspended':
        return SuccessLabCycleStatus.suspended;
      default:
        return SuccessLabCycleStatus.unknown;
    }
  }

  static SuccessLabDateConfidence _decodeDateConfidence(Object? raw) {
    switch (raw) {
      case 'estimated':
        return SuccessLabDateConfidence.estimated;
      case 'confirmed':
        return SuccessLabDateConfidence.confirmed;
      default:
        return SuccessLabDateConfidence.unknown;
    }
  }

  static Map<String, dynamic> _cycleToJson(SuccessLabCycleSummary cycle) {
    return <String, dynamic>{
      'id': cycle.id,
      'status': _cycleStatusToWire(cycle.status, cycle.statusWireValue),
      'dateConfidence': _dateConfidenceToWire(
        cycle.dateConfidence,
        cycle.dateConfidenceWireValue,
      ),
      if (cycle.opensAt != null) 'opensAt': _dateTimeToWire(cycle.opensAt!),
      if (cycle.closesAt != null) 'closesAt': _dateTimeToWire(cycle.closesAt!),
      if (cycle.estimatedOpenAt != null)
        'estimatedOpenAt': _dateTimeToWire(cycle.estimatedOpenAt!),
      if (cycle.estimatedCloseAt != null)
        'estimatedCloseAt': _dateTimeToWire(cycle.estimatedCloseAt!),
    };
  }

  static String _workspaceStatusToWire(
    SuccessLabWorkspaceStatus status,
    String original,
  ) {
    switch (status) {
      case SuccessLabWorkspaceStatus.started:
        return 'started';
      case SuccessLabWorkspaceStatus.preparing:
        return 'preparing';
      case SuccessLabWorkspaceStatus.readyForReview:
        return 'ready_for_review';
      case SuccessLabWorkspaceStatus.reviewRequested:
        return 'review_requested';
      case SuccessLabWorkspaceStatus.submitted:
        return 'submitted';
      case SuccessLabWorkspaceStatus.decisionReceived:
        return 'decision_received';
      case SuccessLabWorkspaceStatus.archived:
        return 'archived';
      case SuccessLabWorkspaceStatus.unknown:
        return original.isEmpty ? 'unknown' : original;
    }
  }

  static String _workspaceStepStatusToWire(
    SuccessLabWorkspaceStepStatus status,
    String original,
  ) {
    if (status == SuccessLabWorkspaceStepStatus.unknown) {
      return original.isEmpty ? 'unknown' : original;
    }
    return encodeWorkspaceStepStatus(status);
  }

  static String _workspaceStepCategoryToWire(
    SuccessLabWorkspaceStepCategory category,
    String original,
  ) {
    switch (category) {
      case SuccessLabWorkspaceStepCategory.profileEligibility:
        return 'profile_eligibility';
      case SuccessLabWorkspaceStepCategory.documents:
        return 'documents';
      case SuccessLabWorkspaceStepCategory.formAndEssays:
        return 'form_and_essays';
      case SuccessLabWorkspaceStepCategory.reviewAndSubmission:
        return 'review_and_submission';
      case SuccessLabWorkspaceStepCategory.unknown:
        return original.isEmpty ? 'unknown' : original;
    }
  }

  static String _cycleStatusToWire(
    SuccessLabCycleStatus status,
    String original,
  ) {
    switch (status) {
      case SuccessLabCycleStatus.forecast:
        return 'forecast';
      case SuccessLabCycleStatus.open:
        return 'open';
      case SuccessLabCycleStatus.closed:
        return 'closed';
      case SuccessLabCycleStatus.suspended:
        return 'suspended';
      case SuccessLabCycleStatus.unknown:
        return original.isEmpty ? 'unknown' : original;
    }
  }

  static String _dateConfidenceToWire(
    SuccessLabDateConfidence confidence,
    String original,
  ) {
    switch (confidence) {
      case SuccessLabDateConfidence.estimated:
        return 'estimated';
      case SuccessLabDateConfidence.confirmed:
        return 'confirmed';
      case SuccessLabDateConfidence.unknown:
        return original.isEmpty ? 'unknown' : original;
    }
  }

  static Map<String, dynamic> _requiredMap(
    Object? raw, {
    required String path,
  }) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map<dynamic, dynamic>) {
      try {
        return Map<String, dynamic>.from(raw);
      } on TypeError {
        // Fall through to the stable contract error below.
      }
    }
    throw FormatException('$path must be a JSON object.');
  }

  static Map<String, dynamic>? _optionalMap(
    Object? raw, {
    required String path,
  }) {
    if (raw == null) return null;
    return _requiredMap(raw, path: path);
  }

  static String _requiredNonEmptyString(
    Object? raw, {
    required String path,
  }) {
    final value = _nonEmptyString(raw);
    if (value == null) {
      throw FormatException('$path must be a non-empty string.');
    }
    return value;
  }

  static String? _string(Object? raw) => raw is String ? raw : null;

  static String? _nonEmptyString(Object? raw) {
    final value = _string(raw)?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  static int? _integer(Object? raw) {
    if (raw is int) return raw;
    if (raw is num && raw.isFinite && raw == raw.roundToDouble()) {
      return raw.toInt();
    }
    return null;
  }

  static String? _decimalString(Object? raw) {
    if (raw == null) return null;
    if (raw is int && raw >= 0) return raw.toString();
    if (raw is String && RegExp(r'^\d+$').hasMatch(raw)) return raw;
    throw const FormatException('Expected a non-negative decimal string.');
  }

  static Iterable<T> _recordList<T>(
    Object? raw, {
    required String path,
    required T Function(Object?) decode,
  }) {
    if (raw is! List<dynamic>) {
      throw FormatException('$path must be a JSON array.');
    }
    return raw.map(decode);
  }

  static int _nonNegativeInteger(Object? raw) {
    final value = _integer(raw) ?? 0;
    return value < 0 ? 0 : value;
  }

  static int _boundedInteger(
    Object? raw, {
    required int min,
    required int max,
    int? fallback,
  }) {
    final value = _integer(raw) ?? fallback ?? min;
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  static List<String> _stringList(Object? raw) {
    if (raw is! List<dynamic>) return const <String>[];
    return List<String>.unmodifiable(raw.whereType<String>());
  }

  static DateTime? _dateTime(Object? raw, {required String path}) {
    if (raw == null) return null;
    if (raw is! String) {
      throw FormatException('$path must be an ISO-8601 string or null.');
    }
    final value = DateTime.tryParse(raw);
    if (value == null) {
      throw FormatException('$path is not a valid ISO-8601 date.');
    }
    return value.toUtc();
  }

  static DateTime _requiredDateTime(Object? raw, {required String path}) {
    final value = _dateTime(raw, path: path);
    if (value == null) {
      throw FormatException('$path must be an ISO-8601 string.');
    }
    return value;
  }

  static String _dateTimeToWire(DateTime value) =>
      value.toUtc().toIso8601String();
}
