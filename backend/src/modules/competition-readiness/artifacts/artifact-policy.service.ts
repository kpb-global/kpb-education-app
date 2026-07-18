import { Injectable } from '@nestjs/common';
import type { ApplicationArtifactKind } from '@prisma/client';

import { StorageService } from '../../storage/storage.service';
import { CompetitionReadinessHttpException } from '../common/competition-readiness.errors';

const ALLOWED_MIME_TYPES = new Set([
  'application/pdf',
  'image/jpeg',
  'image/png',
]);

export const DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES = 10 * 1024 * 1024;

export function effectiveArtifactMaxBytes(
  storageMaxBytes = DEFAULT_APPLICATION_ARTIFACT_MAX_BYTES,
): number {
  const configured = Number(process.env.KPB_APPLICATION_ARTIFACT_MAX_BYTES);
  return Number.isInteger(configured) && configured > 0
    ? Math.min(configured, storageMaxBytes)
    : storageMaxBytes;
}

export interface ArtifactIntentMetadata {
  kind: ApplicationArtifactKind;
  title?: string;
  originalFileName: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
}

export interface NormalizedArtifactIntent {
  kind: ApplicationArtifactKind;
  title: string;
  originalFileName: string;
  mimeType: string;
  sizeBytes: number;
  sha256: string;
}

@Injectable()
export class ArtifactPolicyService {
  constructor(private readonly storage: StorageService) {}

  get maxBytes(): number {
    return effectiveArtifactMaxBytes(this.storage.maxBytes);
  }

  normalizeIntent(input: ArtifactIntentMetadata): NormalizedArtifactIntent {
    const mimeType = input.mimeType.trim().toLowerCase();
    if (!ALLOWED_MIME_TYPES.has(mimeType)) {
      throw this.typeNotAllowed();
    }
    if (!Number.isInteger(input.sizeBytes) || input.sizeBytes <= 0) {
      throw this.typeNotAllowed('File must not be empty.');
    }
    if (input.sizeBytes > this.maxBytes) {
      throw new CompetitionReadinessHttpException(
        'ARTIFACT_TOO_LARGE',
        413,
        'Artifact exceeds the configured size limit.',
        { maxBytes: this.maxBytes },
      );
    }
    if (!/^[0-9a-fA-F]{64}$/.test(input.sha256)) {
      throw this.typeNotAllowed('Invalid SHA-256 digest.');
    }

    const originalFileName = this.safeFileName(input.originalFileName);
    const title = this.safeTitle(input.title, originalFileName);
    return {
      kind: input.kind,
      title,
      originalFileName,
      mimeType,
      sizeBytes: input.sizeBytes,
      sha256: input.sha256.toLowerCase(),
    };
  }

  assertCompletion(input: {
    expectedMimeType: string;
    expectedSizeBytes: number;
    expectedSha256: string;
    actualMimeType: string | null;
    actualSizeBytes: number;
    actualSha256: string;
  }): void {
    if (
      !input.actualMimeType ||
      !ALLOWED_MIME_TYPES.has(input.actualMimeType) ||
      input.actualMimeType !== input.expectedMimeType
    ) {
      throw this.typeNotAllowed('Uploaded bytes do not match the declared MIME type.');
    }
    if (input.actualSizeBytes !== input.expectedSizeBytes) {
      throw this.rejected('Uploaded size does not match the upload intent.');
    }
    if (input.actualSha256 !== input.expectedSha256) {
      throw this.rejected('Uploaded SHA-256 does not match the upload intent.');
    }
  }

  private safeFileName(value: string): string {
    const name = value
      .replace(/\\/g, '/')
      .split('/')
      .at(-1)
      ?.replace(/[\u0000-\u001f\u007f]/g, '')
      .trim();
    if (!name || name.length > 255) {
      throw this.typeNotAllowed('Invalid original file name.');
    }
    return name;
  }

  private safeTitle(value: string | undefined, fileName: string): string {
    const fallback = fileName.replace(/\.[^.]+$/, '');
    const title = (value ?? fallback).trim().replace(/\s+/g, ' ');
    if (!title || title.length > 120) {
      throw this.typeNotAllowed('Invalid artifact title.');
    }
    return title;
  }

  private typeNotAllowed(message = 'Artifact type is not allowed.') {
    return new CompetitionReadinessHttpException(
      'ARTIFACT_KIND_NOT_ALLOWED',
      422,
      message,
    );
  }

  private rejected(message: string) {
    return new CompetitionReadinessHttpException(
      'EVIDENCE_REJECTED',
      422,
      message,
    );
  }
}
