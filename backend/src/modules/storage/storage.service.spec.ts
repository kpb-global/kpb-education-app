import { BadRequestException } from '@nestjs/common';
import { mkdtemp, rm } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';

import { AntivirusService } from './antivirus.service';
import {
  detectAllowedMime,
  extensionForMime,
  isSafeStorageKey,
  StorageService,
} from './storage.service';

describe('StorageService private document validation', () => {
  const originalUploadsDir = process.env.KPB_UPLOADS_DIR;
  const originalS3Bucket = process.env.KPB_S3_BUCKET;
  let uploadsDir: string;

  beforeEach(async () => {
    uploadsDir = await mkdtemp(join(tmpdir(), 'kpb-storage-'));
    process.env.KPB_UPLOADS_DIR = uploadsDir;
    delete process.env.KPB_S3_BUCKET;
  });

  afterEach(async () => {
    if (originalUploadsDir === undefined) delete process.env.KPB_UPLOADS_DIR;
    else process.env.KPB_UPLOADS_DIR = originalUploadsDir;
    if (originalS3Bucket === undefined) delete process.env.KPB_S3_BUCKET;
    else process.env.KPB_S3_BUCKET = originalS3Bucket;
    await rm(uploadsDir, { recursive: true, force: true });
  });

  function makeService() {
    const antivirus = {
      assertClean: jest.fn().mockResolvedValue(undefined),
    } as unknown as AntivirusService;
    return { service: new StorageService(antivirus), antivirus };
  }

  it('recognizes only supported binary signatures', () => {
    expect(detectAllowedMime(Buffer.from('%PDF-1.7\n'))).toBe('application/pdf');
    expect(detectAllowedMime(Buffer.from([0xff, 0xd8, 0xff, 0xe0]))).toBe('image/jpeg');
    expect(
      detectAllowedMime(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
    ).toBe('image/png');
    expect(detectAllowedMime(Buffer.from('<html>not an image</html>'))).toBeNull();
    expect(extensionForMime('application/pdf')).toBe('.pdf');
  });

  it('stores an opaque reference and derives the extension from validated content', async () => {
    const { service, antivirus } = makeService();
    const stored = await service.save(
      Buffer.from('%PDF-1.7\nprivate document'),
      '../../passport.html',
      'application/pdf',
    );

    expect(stored.url).toMatch(/^storage:\/\/\d{4}-\d{2}-\d{2}\//);
    expect(stored.key).toMatch(/\.pdf$/);
    expect(isSafeStorageKey(stored.key)).toBe(true);
    expect(antivirus.assertClean).toHaveBeenCalledWith(
      expect.any(Buffer),
      '../../passport.html',
    );

    const object = await service.getObject(stored.key);
    expect(object?.mimeType).toBe('application/pdf');
    expect(object?.sizeBytes).toBeGreaterThan(0);
  });

  it('rejects unsafe content and does not trust a client MIME label', async () => {
    const { service } = makeService();
    await expect(
      service.save(Buffer.from('<html>payload</html>'), 'photo.png', 'image/png'),
    ).rejects.toBeInstanceOf(BadRequestException);
    await expect(
      service.save(Buffer.from('%PDF-1.7\n'), 'photo.png', 'image/png'),
    ).resolves.toMatchObject({ mimeType: 'application/pdf' });
    expect(service.keyFromUrl('storage://2026-07-11/../../etc/passwd')).toBeNull();
    expect(service.keyFromUrl('https://example.test/2026-07-11/x.pdf')).toBeNull();
  });
});
