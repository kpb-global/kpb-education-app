import type { StorageService } from '../../storage/storage.service';
import {
  ArtifactPolicyService,
  effectiveArtifactMaxBytes,
} from './artifact-policy.service';

describe('ArtifactPolicyService', () => {
  const storage = { maxBytes: 10 * 1024 * 1024 } as StorageService;
  const service = new ArtifactPolicyService(storage);

  afterEach(() => delete process.env.KPB_APPLICATION_ARTIFACT_MAX_BYTES);

  it('normalizes an allowed PDF intent and strips client paths', () => {
    expect(
      service.normalizeIntent({
        kind: 'cv',
        originalFileName: 'C:\\fakepath\\Mon CV.pdf',
        mimeType: ' APPLICATION/PDF ',
        sizeBytes: 1024,
        sha256: 'A'.repeat(64),
      }),
    ).toEqual({
      kind: 'cv',
      title: 'Mon CV',
      originalFileName: 'Mon CV.pdf',
      mimeType: 'application/pdf',
      sizeBytes: 1024,
      sha256: 'a'.repeat(64),
    });
  });

  it.each(['application/msword', 'image/webp', 'image/heic'])(
    'rejects MIME type %s outside the P0 allowlist',
    (mimeType) => {
      expect(() =>
        service.normalizeIntent({
          kind: 'cv',
          originalFileName: 'cv.bin',
          mimeType,
          sizeBytes: 100,
          sha256: 'a'.repeat(64),
        }),
      ).toThrow(expect.objectContaining({ status: 422 }));
    },
  );

  it('enforces the lower configured limit without exceeding StorageService', () => {
    process.env.KPB_APPLICATION_ARTIFACT_MAX_BYTES = '100';
    expect(() =>
      service.normalizeIntent({
        kind: 'cv',
        originalFileName: 'cv.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 101,
        sha256: 'a'.repeat(64),
      }),
    ).toThrow(expect.objectContaining({ status: 413 }));
  });

  it('uses the same effective cap for Multer and StorageService policy', () => {
    process.env.KPB_APPLICATION_ARTIFACT_MAX_BYTES = '2048';
    expect(effectiveArtifactMaxBytes(storage.maxBytes)).toBe(2048);
    expect(service.maxBytes).toBe(2048);
    process.env.KPB_APPLICATION_ARTIFACT_MAX_BYTES = String(20 * 1024 * 1024);
    expect(effectiveArtifactMaxBytes(storage.maxBytes)).toBe(storage.maxBytes);
  });

  it('rejects completion when real bytes differ from declared metadata', () => {
    expect(() =>
      service.assertCompletion({
        expectedMimeType: 'application/pdf',
        expectedSizeBytes: 100,
        expectedSha256: 'a'.repeat(64),
        actualMimeType: 'image/png',
        actualSizeBytes: 100,
        actualSha256: 'a'.repeat(64),
      }),
    ).toThrow(expect.objectContaining({ status: 422 }));
  });
});
