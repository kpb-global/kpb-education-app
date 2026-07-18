import { HttpException, HttpStatus } from '@nestjs/common';

import type { CompetitionReadinessErrorCode } from './competition-readiness.contract';

export type CompetitionReadinessErrorDetails = Record<
  string,
  string | number | boolean | null
>;

/**
 * Stable, client-readable domain error. Messages remain intentionally generic:
 * Flutter and admin localize from `code`; `details` must never contain PII.
 */
export class CompetitionReadinessHttpException extends HttpException {
  constructor(
    code: CompetitionReadinessErrorCode,
    status: HttpStatus,
    message: string,
    details?: CompetitionReadinessErrorDetails,
  ) {
    super(
      {
        code,
        message,
        ...(details ? { details } : {}),
      },
      status,
    );
  }
}

export function featureDisabled(feature: string) {
  return new CompetitionReadinessHttpException(
    'FEATURE_DISABLED',
    HttpStatus.NOT_FOUND,
    'Feature is not available.',
    { feature },
  );
}

export function workspaceNotFound() {
  return new CompetitionReadinessHttpException(
    'WORKSPACE_NOT_FOUND',
    HttpStatus.NOT_FOUND,
    'Workspace not found.',
  );
}

export function workspaceCycleMismatch() {
  return new CompetitionReadinessHttpException(
    'WORKSPACE_CYCLE_MISMATCH',
    HttpStatus.UNPROCESSABLE_ENTITY,
    'Scholarship cycle is not available for this workspace.',
  );
}

export function versionConflict(currentVersion: number) {
  return new CompetitionReadinessHttpException(
    'VERSION_CONFLICT',
    HttpStatus.CONFLICT,
    'Resource version is stale.',
    { currentVersion },
  );
}

export function idempotencyKeyRequired() {
  return new CompetitionReadinessHttpException(
    'IDEMPOTENCY_KEY_REQUIRED',
    HttpStatus.BAD_REQUEST,
    'A valid idempotency key is required.',
  );
}

export function idempotencyPayloadMismatch() {
  return new CompetitionReadinessHttpException(
    'IDEMPOTENCY_PAYLOAD_MISMATCH',
    HttpStatus.CONFLICT,
    'The idempotency key was already used for another request.',
  );
}

export function idempotencyInProgress() {
  return new CompetitionReadinessHttpException(
    'IDEMPOTENCY_IN_PROGRESS',
    HttpStatus.CONFLICT,
    'An equivalent request is already being processed.',
  );
}

export function databaseUnavailable() {
  return new CompetitionReadinessHttpException(
    'DATABASE_UNAVAILABLE',
    HttpStatus.SERVICE_UNAVAILABLE,
    'The service is temporarily unavailable.',
  );
}

export function outboxEventConflict() {
  return new CompetitionReadinessHttpException(
    'OUTBOX_EVENT_CONFLICT',
    HttpStatus.CONFLICT,
    'A domain event conflict occurred.',
  );
}
