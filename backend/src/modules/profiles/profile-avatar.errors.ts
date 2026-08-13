import { HttpException, HttpStatus } from '@nestjs/common';

/**
 * Stable, client-readable avatar error codes.
 *
 * One code per real cause. A catch-all message ("check your connection") once
 * hid a server-side 404 on this project for weeks, so the four failure modes an
 * avatar upload actually has are never collapsed together:
 *   - the file is too big                → AVATAR_TOO_LARGE
 *   - the file is not a supported image  → AVATAR_TYPE_NOT_ALLOWED
 *   - the scan found something in it     → AVATAR_INFECTED (the file is at fault)
 *   - the scan could not run (fail-closed) → AVATAR_SCANNER_UNAVAILABLE (we are)
 *
 * `message` stays generic and PII-free: the Flutter client localizes from
 * `code`, and `details` carries only bounded, non-sensitive numbers/labels.
 */
export type ProfileAvatarErrorCode =
  | 'AVATAR_FILE_REQUIRED'
  | 'AVATAR_FILE_EMPTY'
  | 'AVATAR_TOO_LARGE'
  | 'AVATAR_TYPE_NOT_ALLOWED'
  | 'AVATAR_INFECTED'
  | 'AVATAR_SCANNER_UNAVAILABLE'
  | 'AVATAR_STORAGE_UNAVAILABLE'
  | 'AVATAR_UPLOAD_CONFLICT'
  | 'AVATAR_NOT_FOUND'
  | 'PROFILE_NOT_FOUND';

export type ProfileAvatarErrorDetails = Record<
  string,
  string | number | boolean | null
>;

export class ProfileAvatarHttpException extends HttpException {
  constructor(
    code: ProfileAvatarErrorCode,
    status: HttpStatus,
    message: string,
    details?: ProfileAvatarErrorDetails,
  ) {
    super({ code, message, ...(details ? { details } : {}) }, status);
  }

  get code(): ProfileAvatarErrorCode {
    return (this.getResponse() as { code: ProfileAvatarErrorCode }).code;
  }
}

export function avatarFileRequired() {
  return new ProfileAvatarHttpException(
    'AVATAR_FILE_REQUIRED',
    HttpStatus.BAD_REQUEST,
    'An image is required under multipart field "file".',
  );
}

export function avatarFileEmpty() {
  return new ProfileAvatarHttpException(
    'AVATAR_FILE_EMPTY',
    HttpStatus.BAD_REQUEST,
    'The uploaded image is empty.',
  );
}

export function avatarTooLarge(maxBytes: number) {
  return new ProfileAvatarHttpException(
    'AVATAR_TOO_LARGE',
    HttpStatus.PAYLOAD_TOO_LARGE,
    'The image is larger than the profile-photo limit.',
    { maxBytes },
  );
}

export function avatarTypeNotAllowed(allowed: readonly string[]) {
  return new ProfileAvatarHttpException(
    'AVATAR_TYPE_NOT_ALLOWED',
    HttpStatus.UNSUPPORTED_MEDIA_TYPE,
    'Unsupported image content.',
    { allowed: allowed.join(',') },
  );
}

/** The scan returned a detection: the uploaded file itself is the problem. */
export function avatarInfected() {
  return new ProfileAvatarHttpException(
    'AVATAR_INFECTED',
    HttpStatus.UNPROCESSABLE_ENTITY,
    'The image was rejected by the antivirus scan.',
  );
}

/**
 * Fail-closed: no verdict could be obtained, so nothing was stored. This is our
 * fault, not the student's — the client must say so and offer a retry.
 */
export function avatarScannerUnavailable() {
  return new ProfileAvatarHttpException(
    'AVATAR_SCANNER_UNAVAILABLE',
    HttpStatus.SERVICE_UNAVAILABLE,
    'Image scanning is temporarily unavailable. Please retry.',
  );
}

export function avatarStorageUnavailable() {
  return new ProfileAvatarHttpException(
    'AVATAR_STORAGE_UNAVAILABLE',
    HttpStatus.SERVICE_UNAVAILABLE,
    'Image storage is temporarily unavailable. Please retry.',
  );
}

/** Two uploads raced; the loser is discarded rather than left orphaned. */
export function avatarUploadConflict() {
  return new ProfileAvatarHttpException(
    'AVATAR_UPLOAD_CONFLICT',
    HttpStatus.CONFLICT,
    'Another profile-photo change was applied first. Please retry.',
  );
}

export function avatarNotFound() {
  return new ProfileAvatarHttpException(
    'AVATAR_NOT_FOUND',
    HttpStatus.NOT_FOUND,
    'This profile has no photo.',
  );
}

export function avatarProfileNotFound() {
  return new ProfileAvatarHttpException(
    'PROFILE_NOT_FOUND',
    HttpStatus.NOT_FOUND,
    'Profile not found.',
  );
}
