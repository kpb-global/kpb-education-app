import {
  BadRequestException,
  Injectable,
  Logger,
  ServiceUnavailableException,
} from '@nestjs/common';
import { createReadStream, promises as fs } from 'fs';
import { extname, resolve } from 'path';
import { randomUUID } from 'crypto';
import { Readable } from 'stream';

import {
  DeleteObjectCommand,
  GetObjectCommand,
  PutObjectCommand,
  S3Client,
  S3ClientConfig,
} from '@aws-sdk/client-s3';

import { AntivirusService } from './antivirus.service';

const DEFAULT_DIR = resolve(process.cwd(), 'uploads');
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB
const STORAGE_URL_PREFIX = 'storage://';

const MIME_TO_EXTENSION: Record<string, string> = {
  'application/pdf': '.pdf',
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/heic': '.heic',
  'image/webp': '.webp',
};

export interface StoredFile {
  key: string;
  /** Opaque reference stored in the database. It is never a public URL. */
  url: string;
  mimeType: string;
  sizeBytes: number;
}

export interface StoredObject {
  stream: Readable;
  mimeType: string;
  sizeBytes?: number;
}

type Driver = 's3' | 'local';

/**
 * Detect the file type from bytes, rather than trusting the multipart MIME
 * value or a filename extension supplied by a browser.
 */
export function detectAllowedMime(buffer: Buffer): string | null {
  if (
    buffer.length >= 5 &&
    buffer.subarray(0, 5).toString('ascii') === '%PDF-'
  ) {
    return 'application/pdf';
  }
  if (
    buffer.length >= 3 &&
    buffer[0] === 0xff &&
    buffer[1] === 0xd8 &&
    buffer[2] === 0xff
  ) {
    return 'image/jpeg';
  }
  if (
    buffer.length >= 8 &&
    buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
  ) {
    return 'image/png';
  }
  if (
    buffer.length >= 12 &&
    buffer.subarray(0, 4).toString('ascii') === 'RIFF' &&
    buffer.subarray(8, 12).toString('ascii') === 'WEBP'
  ) {
    return 'image/webp';
  }
  // HEIC / HEIF files are ISO Base Media containers. The `ftyp` box starts at
  // byte 4; accept only HEIC/HEIF-compatible brands, never arbitrary MP4.
  if (buffer.length >= 12 && buffer.subarray(4, 8).toString('ascii') === 'ftyp') {
    const brands = ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'];
    const header = buffer.subarray(8, Math.min(buffer.length, 64)).toString('ascii');
    if (brands.some((brand) => header.includes(brand))) return 'image/heic';
  }
  return null;
}

export function extensionForMime(mimeType: string): string | null {
  return MIME_TO_EXTENSION[mimeType] ?? null;
}

/**
 * The only accepted object-key shapes: new UUID keys and the timestamped
 * UUID keys issued by previous releases. This deliberately rejects `..`,
 * extra directories, double extensions and arbitrary storage paths.
 */
export function isSafeStorageKey(key: string): boolean {
  return /^\d{4}-\d{2}-\d{2}\/(?:\d+-)?[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(?:pdf|jpe?g|png|heic|webp)$/i.test(
    key,
  );
}

function mimeForKey(key: string): string | null {
  const extension = extname(key).toLowerCase();
  return (
    Object.entries(MIME_TO_EXTENSION).find(([, value]) => value === extension)?.[0] ??
    (extension === '.jpeg' ? 'image/jpeg' : null)
  );
}

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  // Local-disk fallback config
  private readonly baseDir = process.env.KPB_UPLOADS_DIR
    ? resolve(process.env.KPB_UPLOADS_DIR)
    : DEFAULT_DIR;
  // Retained only to locate legacy records that stored a public URL. New
  // documents store an opaque `storage://` reference and have no public URL.
  private readonly legacyPublicBaseUrl =
    process.env.KPB_UPLOADS_PUBLIC_URL?.trim() || '/uploads';

  // S3-compatible config (Scaleway Paris, Bunny Storage, AWS S3, MinIO, …)
  private readonly s3Bucket = process.env.KPB_S3_BUCKET;
  private readonly s3Region = process.env.KPB_S3_REGION ?? 'fr-par';
  private readonly s3Endpoint = process.env.KPB_S3_ENDPOINT;
  private readonly s3AccessKey = process.env.KPB_S3_ACCESS_KEY_ID;
  private readonly s3SecretKey = process.env.KPB_S3_SECRET_ACCESS_KEY;
  // Legacy public base used only to translate old database values during the
  // private-download migration. It is not used for newly stored documents.
  private readonly s3PublicBaseUrl = process.env.KPB_S3_PUBLIC_BASE_URL;
  private readonly s3ForcePathStyle =
    (process.env.KPB_S3_FORCE_PATH_STYLE ?? 'false').toLowerCase() === 'true';

  private readonly driver: Driver;
  private readonly s3Client: S3Client | null;

  constructor(private readonly antivirusService: AntivirusService) {
    const hasS3 =
      !!this.s3Bucket &&
      !!this.s3AccessKey &&
      !!this.s3SecretKey;

    if (hasS3) {
      const config: S3ClientConfig = {
        region: this.s3Region,
        credentials: {
          accessKeyId: this.s3AccessKey!,
          secretAccessKey: this.s3SecretKey!,
        },
        forcePathStyle: this.s3ForcePathStyle,
      };
      if (this.s3Endpoint) {
        config.endpoint = this.s3Endpoint;
      }
      this.s3Client = new S3Client(config);
      this.driver = 's3';
      this.logger.log(
        `Storage: S3 driver (bucket=${this.s3Bucket}, region=${this.s3Region}, endpoint=${this.s3Endpoint ?? 'aws-default'})`,
      );
    } else {
      this.s3Client = null;
      this.driver = 'local';
      if (process.env.NODE_ENV === 'production') {
        this.logger.warn(
          'Storage: falling back to local disk in production. Set KPB_S3_BUCKET/KEY/SECRET to enable S3.',
        );
      } else {
        this.logger.log('Storage: local disk driver (dev fallback)');
      }
    }
  }

  get maxBytes() {
    return MAX_BYTES;
  }

  getLocalPath(key: string) {
    if (!isSafeStorageKey(key)) {
      throw new BadRequestException('Invalid storage key.');
    }
    const target = resolve(this.baseDir, key);
    if (!target.startsWith(`${this.baseDir}/`)) {
      throw new BadRequestException('Invalid storage key.');
    }
    return target;
  }

  async save(
    fileBuffer: Buffer,
    originalName: string,
    declaredMimeType: string,
  ): Promise<StoredFile> {
    if (fileBuffer.byteLength === 0) {
      throw new BadRequestException('The uploaded file is empty.');
    }
    if (fileBuffer.byteLength > MAX_BYTES) {
      throw new BadRequestException('File exceeds 10 MB limit.');
    }

    const detectedMimeType = detectAllowedMime(fileBuffer);
    if (!detectedMimeType) {
      throw new BadRequestException(
        'Unsupported file content. Allowed: PDF, JPEG, PNG, HEIC, WebP.',
      );
    }
    if (declaredMimeType.trim().toLowerCase() !== detectedMimeType) {
      // Android and iOS upload clients can report application/octet-stream for
      // an otherwise valid PDF/photo. The byte signature is the authority, so
      // record the mismatch but never promote the client-declared type.
      this.logger.debug('Upload MIME metadata differs from verified content.');
    }

    // Antivirus gate BEFORE anything is persisted: an infected file must never
    // reach the uploads volume/bucket (422 if infected, 503 if the scanner is
    // configured but unavailable — fail-closed).
    await this.antivirusService.assertClean(fileBuffer, originalName);

    const extension = extensionForMime(detectedMimeType);
    if (!extension) {
      throw new BadRequestException('Unsupported file type.');
    }
    const key = `${new Date().toISOString().slice(0, 10)}/${randomUUID()}${extension}`;

    if (this.driver === 's3') {
      return this.saveToS3(key, fileBuffer, detectedMimeType);
    }
    return this.saveToLocal(key, fileBuffer, detectedMimeType);
  }

  private async saveToLocal(
    key: string,
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<StoredFile> {
    const target = this.getLocalPath(key);
    await fs.mkdir(resolve(target, '..'), { recursive: true });
    await fs.writeFile(target, fileBuffer, { flag: 'wx' });
    this.logger.log(
      `Stored private object locally (${fileBuffer.byteLength} bytes).`,
    );
    return {
      key,
      url: `${STORAGE_URL_PREFIX}${key}`,
      mimeType,
      sizeBytes: fileBuffer.byteLength,
    };
  }

  private async saveToS3(
    key: string,
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<StoredFile> {
    if (!this.s3Client || !this.s3Bucket) {
      throw new ServiceUnavailableException('S3 storage not configured.');
    }
    try {
      await this.s3Client.send(
        new PutObjectCommand({
          Bucket: this.s3Bucket,
          Key: key,
          Body: fileBuffer,
          ContentType: mimeType,
          CacheControl: 'private, no-store',
        }),
      );
    } catch {
      this.logger.error('S3 private-object write failed.');
      throw new ServiceUnavailableException('Upload failed. Please retry.');
    }
    this.logger.log(
      `Stored private object in S3 (${fileBuffer.byteLength} bytes).`,
    );
    return {
      key,
      url: `${STORAGE_URL_PREFIX}${key}`,
      mimeType,
      sizeBytes: fileBuffer.byteLength,
    };
  }

  /**
   * Recover a validated object key from a stored reference. Old records that
   * contain /uploads or S3 public URLs continue to work through the new
   * authenticated endpoint; arbitrary URL paths are never accepted.
   */
  keyFromUrl(url: string | null | undefined): string | null {
    if (!url) return null;
    if (url.startsWith(STORAGE_URL_PREFIX)) {
      const key = url.slice(STORAGE_URL_PREFIX.length);
      return isSafeStorageKey(key) ? key : null;
    }
    for (const base of [this.legacyPublicBaseUrl, this.s3PublicBaseUrl]) {
      if (base) {
        const normalizedBase = base.replace(/\/+$/, '');
        if (url.startsWith(`${normalizedBase}/`)) {
          const key = url.slice(normalizedBase.length + 1);
          return isSafeStorageKey(key) ? key : null;
        }
      }
    }
    return null;
  }

  /** Fetch a private object only after its caller has completed authorization. */
  async getObject(key: string): Promise<StoredObject | null> {
    if (!isSafeStorageKey(key)) return null;
    const mimeType = mimeForKey(key);
    if (!mimeType) return null;

    if (this.driver === 'local') {
      try {
        const stat = await fs.stat(this.getLocalPath(key));
        if (!stat.isFile()) return null;
        return {
          stream: createReadStream(this.getLocalPath(key)),
          mimeType,
          sizeBytes: stat.size,
        };
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code === 'ENOENT') return null;
        this.logger.error('Local private-object read failed.');
        throw new ServiceUnavailableException('File storage unavailable.');
      }
    }

    if (!this.s3Client || !this.s3Bucket) {
      throw new ServiceUnavailableException('S3 storage not configured.');
    }
    try {
      const object = await this.s3Client.send(
        new GetObjectCommand({ Bucket: this.s3Bucket, Key: key }),
      );
      if (!object.Body) return null;
      const body = object.Body as Readable & {
        transformToByteArray?: () => Promise<Uint8Array>;
      };
      const stream =
        typeof body.transformToByteArray === 'function'
          ? Readable.from(Buffer.from(await body.transformToByteArray()))
          : body;
      return {
        stream,
        mimeType: object.ContentType ?? mimeType,
        sizeBytes: object.ContentLength,
      };
    } catch (error) {
      if ((error as { $metadata?: { httpStatusCode?: number } }).$metadata?.httpStatusCode === 404) {
        return null;
      }
      this.logger.error('S3 private-object read failed.');
      throw new ServiceUnavailableException('File storage unavailable.');
    }
  }

  /**
   * Best-effort deletion of a stored object by its key. Never throws — used on
   * the account-deletion path where a failed file delete must not abort the DB
   * purge (the caller logs and moves on).
   */
  async delete(key: string | null | undefined): Promise<void> {
    if (!key || !isSafeStorageKey(key)) return;
    try {
      if (this.driver === 's3') {
        if (!this.s3Client || !this.s3Bucket) return;
        await this.s3Client.send(
          new DeleteObjectCommand({ Bucket: this.s3Bucket, Key: key }),
        );
      } else {
        await fs.unlink(this.getLocalPath(key)).catch(() => undefined);
      }
      this.logger.log(`Deleted private object (${this.driver}).`);
    } catch {
      this.logger.error(`Private-object deletion failed (${this.driver}).`);
    }
  }
}
