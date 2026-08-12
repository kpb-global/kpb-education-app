import { detectAllowedMime } from '../storage/storage.service';
import {
  avatarFileEmpty,
  avatarScannerUnavailable,
  avatarTooLarge,
  avatarTypeNotAllowed,
} from './profile-avatar.errors';

/**
 * Avatar rules, deliberately STRICTER than the shared StorageService policy.
 *
 * StorageService allows 10 MB and also accepts PDF and HEIC. A profile photo
 * needs neither: our students pay for their data by the megabyte, so 2 MB is
 * the cap, and the accepted set is narrowed to the three formats every client
 * can decode. Nothing is added to the shared whitelist — this is a subset of
 * what `detectAllowedMime` already recognizes.
 */
export const AVATAR_MAX_BYTES = 2 * 1024 * 1024; // 2 MiB

export const AVATAR_ALLOWED_MIME_TYPES = [
  'image/jpeg',
  'image/png',
  'image/webp',
] as const;

/**
 * Hard multipart ceiling handed to multer: one byte over the cap. Anything
 * bigger is refused while streaming (bounded memory), and a file of exactly
 * cap+1 still reaches the handler so the honest AVATAR_TOO_LARGE code — rather
 * than multer's bare 413 — is what the student sees. Both paths end on the same
 * code (see ProfileAvatarPayloadFilter).
 */
export const AVATAR_MULTIPART_BYTE_CEILING = AVATAR_MAX_BYTES + 1;

/**
 * The authenticated endpoint that streams the image. Exposed in the profile DTO
 * instead of the storage key, which would leak the internal object layout.
 */
export const AVATAR_ENDPOINT_PATH = '/api/profiles/me/avatar';

/**
 * The label handed to the antivirus/storage layer. The student's own filename is
 * never forwarded: filenames routinely carry the person's name.
 */
export const AVATAR_STORAGE_LABEL = 'profile-avatar';

/**
 * Validates the bytes and returns the verified MIME type. The byte signature is
 * the authority — a client-declared `Content-Type` is never trusted, because a
 * renamed PDF or HEIC would otherwise slip past the narrowed avatar whitelist.
 */
export function assertAvatarContent(buffer: Buffer): string {
  if (buffer.byteLength === 0) throw avatarFileEmpty();
  if (buffer.byteLength > AVATAR_MAX_BYTES) throw avatarTooLarge(AVATAR_MAX_BYTES);

  const detected = detectAllowedMime(buffer);
  if (
    !detected ||
    !(AVATAR_ALLOWED_MIME_TYPES as readonly string[]).includes(detected)
  ) {
    throw avatarTypeNotAllowed(AVATAR_ALLOWED_MIME_TYPES);
  }
  return detected;
}

/**
 * Fail-closed in production: if no scanner is configured, an unscanned face
 * photo must not land in the bucket. Mirrors the artifact/outcome upload guards.
 */
export function assertAvatarScannerReady(): void {
  if (
    process.env.NODE_ENV === 'production' &&
    !process.env.CLAMAV_HOST?.trim()
  ) {
    throw avatarScannerUnavailable();
  }
}
