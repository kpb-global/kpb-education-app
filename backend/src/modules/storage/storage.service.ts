import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { promises as fs } from 'fs';
import { extname, join, resolve } from 'path';
import { randomUUID } from 'crypto';

import {
  DeleteObjectCommand,
  PutObjectCommand,
  S3Client,
  S3ClientConfig,
} from '@aws-sdk/client-s3';

const DEFAULT_DIR = resolve(process.cwd(), 'uploads');
const MAX_BYTES = 10 * 1024 * 1024; // 10 MB
const ALLOWED_MIME = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
  'image/heic',
  'image/webp',
]);

export interface StoredFile {
  key: string;
  url: string;
  mimeType: string;
  sizeBytes: number;
}

type Driver = 's3' | 'local';

@Injectable()
export class StorageService {
  private readonly logger = new Logger(StorageService.name);

  // Local-disk fallback config
  private readonly baseDir = process.env.KPB_UPLOADS_DIR
    ? resolve(process.env.KPB_UPLOADS_DIR)
    : DEFAULT_DIR;
  private readonly publicBaseUrl =
    process.env.KPB_UPLOADS_PUBLIC_URL ?? '/uploads';

  // S3-compatible config (Scaleway Paris, Bunny Storage, AWS S3, MinIO, …)
  private readonly s3Bucket = process.env.KPB_S3_BUCKET;
  private readonly s3Region = process.env.KPB_S3_REGION ?? 'fr-par';
  private readonly s3Endpoint = process.env.KPB_S3_ENDPOINT;
  private readonly s3AccessKey = process.env.KPB_S3_ACCESS_KEY_ID;
  private readonly s3SecretKey = process.env.KPB_S3_SECRET_ACCESS_KEY;
  private readonly s3PublicBaseUrl = process.env.KPB_S3_PUBLIC_BASE_URL;
  private readonly s3ForcePathStyle =
    (process.env.KPB_S3_FORCE_PATH_STYLE ?? 'false').toLowerCase() === 'true';

  private readonly driver: Driver;
  private readonly s3Client: S3Client | null;

  constructor() {
    const hasS3 =
      !!this.s3Bucket &&
      !!this.s3AccessKey &&
      !!this.s3SecretKey &&
      !!this.s3PublicBaseUrl;

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
          'Storage: falling back to local disk in production. Set KPB_S3_BUCKET/KEY/SECRET/PUBLIC_BASE_URL to enable S3.',
        );
      } else {
        this.logger.log('Storage: local disk driver (dev fallback)');
      }
    }
  }

  get maxBytes() {
    return MAX_BYTES;
  }

  isAllowedMime(mime: string) {
    return ALLOWED_MIME.has(mime);
  }

  getLocalPath(key: string) {
    const safe = key.replace(/[^a-zA-Z0-9_\-./]/g, '');
    return join(this.baseDir, safe);
  }

  async save(
    fileBuffer: Buffer,
    originalName: string,
    mimeType: string,
  ): Promise<StoredFile> {
    if (!this.isAllowedMime(mimeType)) {
      throw new Error(`Unsupported file type: ${mimeType}`);
    }
    if (fileBuffer.byteLength > MAX_BYTES) {
      throw new Error('File exceeds 10 MB limit.');
    }

    const ext = extname(originalName).toLowerCase() || '.bin';
    const key = `${new Date().toISOString().slice(0, 10)}/${Date.now()}-${randomUUID()}${ext}`;

    if (this.driver === 's3') {
      return this.saveToS3(key, fileBuffer, mimeType);
    }
    return this.saveToLocal(key, fileBuffer, mimeType);
  }

  private async saveToLocal(
    key: string,
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<StoredFile> {
    const target = join(this.baseDir, key);
    await fs.mkdir(resolve(target, '..'), { recursive: true });
    await fs.writeFile(target, fileBuffer);
    this.logger.log(`Stored (local) ${key} (${fileBuffer.byteLength} bytes)`);
    return {
      key,
      url: `${this.publicBaseUrl}/${key}`,
      mimeType,
      sizeBytes: fileBuffer.byteLength,
    };
  }

  private async saveToS3(
    key: string,
    fileBuffer: Buffer,
    mimeType: string,
  ): Promise<StoredFile> {
    if (!this.s3Client || !this.s3Bucket || !this.s3PublicBaseUrl) {
      throw new ServiceUnavailableException('S3 storage not configured.');
    }
    try {
      await this.s3Client.send(
        new PutObjectCommand({
          Bucket: this.s3Bucket,
          Key: key,
          Body: fileBuffer,
          ContentType: mimeType,
          CacheControl: 'private, max-age=300',
        }),
      );
    } catch (err) {
      this.logger.error(`S3 put failed for ${key}`, err as Error);
      throw new ServiceUnavailableException('Upload failed. Please retry.');
    }
    const publicBase = this.s3PublicBaseUrl.replace(/\/+$/, '');
    this.logger.log(`Stored (s3) ${key} (${fileBuffer.byteLength} bytes)`);
    return {
      key,
      url: `${publicBase}/${key}`,
      mimeType,
      sizeBytes: fileBuffer.byteLength,
    };
  }

  /**
   * Recover the storage key from a stored file URL (inverse of save()'s
   * `${base}/${key}`). Returns null when the URL can't be mapped to a key.
   */
  keyFromUrl(url: string | null | undefined): string | null {
    if (!url) return null;
    for (const base of [this.publicBaseUrl, this.s3PublicBaseUrl]) {
      if (base) {
        const b = base.replace(/\/+$/, '');
        if (url.startsWith(`${b}/`)) return url.slice(b.length + 1);
      }
    }
    // Fallback: keys always have the shape `YYYY-MM-DD/<file>`, i.e. the last
    // two path segments of the URL.
    try {
      const path = url.startsWith('http') ? new URL(url).pathname : url;
      const parts = path.split('/').filter(Boolean);
      if (parts.length >= 2) return parts.slice(-2).join('/');
    } catch {
      // ignore malformed URLs
    }
    return null;
  }

  /**
   * Best-effort deletion of a stored object by its key. Never throws — used on
   * the account-deletion path where a failed file delete must not abort the DB
   * purge (the caller logs and moves on).
   */
  async delete(key: string | null | undefined): Promise<void> {
    const safeKey = key?.replace(/^\/+/, '');
    if (!safeKey) return;
    try {
      if (this.driver === 's3') {
        if (!this.s3Client || !this.s3Bucket) return;
        await this.s3Client.send(
          new DeleteObjectCommand({ Bucket: this.s3Bucket, Key: safeKey }),
        );
      } else {
        await fs.unlink(this.getLocalPath(safeKey)).catch(() => undefined);
      }
      this.logger.log(`Deleted (${this.driver}) ${safeKey}`);
    } catch (err) {
      this.logger.error(`Delete failed for ${safeKey}`, err as Error);
    }
  }
}
