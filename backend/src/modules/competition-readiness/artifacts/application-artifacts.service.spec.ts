import { createHash } from 'node:crypto';
import { Readable } from 'node:stream';

import type { PrismaService } from '../../prisma/prisma.service';
import type { StorageService } from '../../storage/storage.service';
import type { DomainEventOutboxService } from '../common/domain-event-outbox.service';
import type { FeatureAccessService } from '../common/feature-access.service';
import type { IdempotencyService } from '../common/idempotency.service';
import { ApplicationArtifactsService } from './application-artifacts.service';
import { ArtifactPolicyService } from './artifact-policy.service';

describe('ApplicationArtifactsService', () => {
  const previousFlag = process.env.KPB_APPLICATION_ARTIFACTS_ENABLED;
  const previousNodeEnv = process.env.NODE_ENV;
  const previousClamavHost = process.env.CLAMAV_HOST;
  const execute = jest.fn();
  const prisma = { isEnabled: true, execute } as unknown as PrismaService;
  const storage = {
    maxBytes: 10 * 1024 * 1024,
    save: jest.fn(),
    getObject: jest.fn(),
    delete: jest.fn(),
  } as unknown as StorageService;
  const evaluate = jest
    .fn()
    .mockResolvedValue({ allowed: true, feature: 'success_lab' });
  const featureAccess = { evaluate } as unknown as FeatureAccessService;
  const reserve = jest.fn().mockResolvedValue({
    state: 'acquired',
    recordId: 'idem-1',
    payloadHash: 'hash',
    expiresAt: new Date('2026-07-18T00:00:00.000Z'),
  });
  const complete = jest.fn();
  const idempotency = { reserve, complete } as unknown as IdempotencyService;
  const enqueue = jest.fn();
  const outbox = { enqueue } as unknown as DomainEventOutboxService;
  const policy = new ArtifactPolicyService(storage);
  const service = new ApplicationArtifactsService(
    prisma,
    storage,
    policy,
    featureAccess,
    idempotency,
    outbox,
  );
  const now = new Date('2026-07-17T09:00:00.000Z');

  beforeEach(() => {
    jest.clearAllMocks();
    process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = 'true';
    process.env.NODE_ENV = 'test';
    delete process.env.CLAMAV_HOST;
    evaluate.mockResolvedValue({ allowed: true, feature: 'success_lab' });
    reserve.mockResolvedValue({
      state: 'acquired',
      recordId: 'idem-1',
      payloadHash: 'hash',
      expiresAt: new Date('2026-07-18T00:00:00.000Z'),
    });
  });

  afterAll(() => {
    if (previousFlag === undefined) {
      delete process.env.KPB_APPLICATION_ARTIFACTS_ENABLED;
    } else {
      process.env.KPB_APPLICATION_ARTIFACTS_ENABLED = previousFlag;
    }
    if (previousNodeEnv === undefined) delete process.env.NODE_ENV;
    else process.env.NODE_ENV = previousNodeEnv;
    if (previousClamavHost === undefined) delete process.env.CLAMAV_HOST;
    else process.env.CLAMAV_HOST = previousClamavHost;
  });

  it('fails closed when the artifact feature flag is absent', async () => {
    delete process.env.KPB_APPLICATION_ARTIFACTS_ENABLED;
    await expect(service.list('student-1', 'workspace-1')).rejects.toMatchObject({
      status: 404,
    });
    expect(evaluate).not.toHaveBeenCalled();
    expect(execute).not.toHaveBeenCalled();
  });

  it('scopes listing to the authenticated workspace owner and hides storage keys', async () => {
    const findWorkspace = jest.fn().mockResolvedValue({ id: 'workspace-1' });
    const findArtifacts = jest.fn().mockResolvedValue([
      artifactFixture({
        versions: [
          {
            ...versionFixture(),
            storageKey: 'private/path.pdf',
          },
        ],
      }),
    ]);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        scholarshipWorkspace: { findFirst: findWorkspace },
        applicationArtifact: { findMany: findArtifacts },
      }),
    );

    const result = await service.list('student-1', 'workspace-1');

    expect(findWorkspace).toHaveBeenCalledWith({
      where: { id: 'workspace-1', userId: 'student-1' },
      select: { id: true },
    });
    expect(JSON.stringify(result)).not.toContain('storageKey');
  });

  it('allocates an immutable pending version inside the idempotent transaction', async () => {
    const createdVersion = versionFixture();
    const tx = {
      scholarshipWorkspace: {
        findFirst: jest.fn().mockResolvedValue({ id: 'workspace-1' }),
      },
      applicationArtifact: {
        upsert: jest.fn().mockResolvedValue(artifactFixture()),
      },
      applicationArtifactVersion: {
        findFirst: jest.fn().mockResolvedValue({ versionNumber: 1 }),
        create: jest.fn().mockResolvedValue({
          ...createdVersion,
          versionNumber: 2,
        }),
      },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
      }),
    );

    const result = await service.initiateUpload(
      'student-1',
      'workspace-1',
      {
        kind: 'cv',
        title: 'CV principal',
        originalFileName: 'cv.pdf',
        mimeType: 'application/pdf',
        sizeBytes: 120,
        sha256: 'a'.repeat(64),
      },
      'upload-1',
    );

    expect(result.statusCode).toBe(201);
    expect(result.intent).toMatchObject({
      uploadMode: 'multipart',
      version: { versionNumber: 2, processingStatus: 'pending_upload' },
    });
    expect(tx.scholarshipWorkspace.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ userId: 'student-1' }),
      }),
    );
    expect(complete).toHaveBeenCalledWith(
      expect.objectContaining({ resourceType: 'ApplicationArtifactVersion' }),
      tx,
    );
  });

  it('rejects completion for a version owned by another user', async () => {
    const findFirst = jest.fn().mockResolvedValue(null);
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({ applicationArtifactVersion: { findFirst } }),
    );

    await expect(
      service.completeUpload('student-1', 'version-1', {
        buffer: Buffer.from('%PDF-test'),
        originalname: 'cv.pdf',
        mimetype: 'application/pdf',
        size: 9,
      }),
    ).rejects.toMatchObject({ status: 404 });
    expect(findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          id: 'version-1',
          artifact: { workspace: { userId: 'student-1' } },
        },
      }),
    );
    expect(storage.save).not.toHaveBeenCalled();
  });

  it('rejects completion when the workspace was archived after intent creation', async () => {
    const owned = ownedVersionFixture();
    owned.artifact.workspace.status = 'archived';
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationArtifactVersion: {
          findFirst: jest.fn().mockResolvedValue(owned),
        },
      }),
    );

    await expect(
      service.completeUpload('student-1', 'version-1', {
        buffer: Buffer.from('%PDF-test'),
        originalname: 'cv.pdf',
        mimetype: 'application/pdf',
        size: 9,
      }),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
    expect(storage.save).not.toHaveBeenCalled();
  });

  it('fails closed in production when the malware scanner is not configured', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.CLAMAV_HOST;
    const buffer = Buffer.from('%PDF-test');
    const owned = ownedVersionFixture({
      sizeBytes: buffer.byteLength,
      sha256: createHash('sha256').update(buffer).digest('hex'),
    });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationArtifactVersion: {
          findFirst: jest.fn().mockResolvedValue(owned),
        },
      }),
    );

    await expect(
      service.completeUpload('student-1', 'version-1', {
        buffer,
        originalname: 'cv.pdf',
        mimetype: 'application/pdf',
        size: buffer.byteLength,
      }),
    ).rejects.toMatchObject({
      status: 503,
      response: expect.objectContaining({ code: 'DATABASE_UNAVAILABLE' }),
    });
    expect(storage.save).not.toHaveBeenCalled();
  });

  it('verifies bytes, scans through StorageService and promotes only a clean version', async () => {
    const buffer = Buffer.from('%PDF-clean-document');
    const sha256 = createHash('sha256').update(buffer).digest('hex');
    const owned = ownedVersionFixture({
      sizeBytes: buffer.byteLength,
      sha256,
    });
    const clean = versionFixture({
      sizeBytes: buffer.byteLength,
      sha256,
      processingStatus: 'clean',
      uploadedAt: now,
    });
    const tx = {
      applicationArtifactVersion: {
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUnique: jest.fn().mockResolvedValue(clean),
      },
      applicationArtifact: { update: jest.fn() },
      scholarshipWorkspace: { update: jest.fn() },
    };
    const client = {
      applicationArtifactVersion: {
        findFirst: jest.fn().mockResolvedValue(owned),
      },
      $transaction: async (callback: (value: unknown) => unknown) => callback(tx),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation(client),
    );
    (storage.save as jest.Mock).mockResolvedValue({
      key: '2026-07-17/00000000-0000-4000-8000-000000000000.pdf',
      url: 'storage://private',
      mimeType: 'application/pdf',
      sizeBytes: buffer.byteLength,
    });

    const result = await service.completeUpload('student-1', 'version-1', {
      buffer,
      originalname: 'different-client-name.pdf',
      mimetype: 'application/pdf',
      size: buffer.byteLength,
    });

    expect(storage.save).toHaveBeenCalledWith(
      buffer,
      'cv.pdf',
      'application/pdf',
    );
    expect(tx.applicationArtifactVersion.updateMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: 'version-1',
          processingStatus: 'pending_upload',
        }),
        data: expect.objectContaining({ processingStatus: 'clean' }),
      }),
    );
    expect(result).toMatchObject({ processingStatus: 'clean' });
    expect(JSON.stringify(result)).not.toContain('storageKey');
  });

  it('streams only a clean owned version from private storage', async () => {
    const owned = ownedVersionFixture({
      processingStatus: 'clean',
      storageKey: '2026-07-17/00000000-0000-4000-8000-000000000000.pdf',
      uploadedAt: now,
    });
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        applicationArtifactVersion: { findFirst: jest.fn().mockResolvedValue(owned) },
      }),
    );
    (storage.getObject as jest.Mock).mockResolvedValue({
      stream: Readable.from(Buffer.from('private')),
      mimeType: 'application/pdf',
      sizeBytes: 7,
    });

    await expect(
      service.getDownload('student-1', 'version-1'),
    ).resolves.toMatchObject({
      fileName: 'cv.pdf',
      object: { mimeType: 'application/pdf', sizeBytes: 7 },
    });
  });

  it('treats retrying an already deleted version as an idempotent cleanup', async () => {
    const updateVersion = jest.fn();
    const tx = {
      applicationArtifactVersion: {
        findFirst: jest.fn().mockResolvedValue(
          ownedVersionFixture({
            processingStatus: 'deleted',
            deletedAt: now,
            storageKey: 'private/deleted.pdf',
          }),
        ),
        update: updateVersion,
      },
      studyReviewArtifactShare: { findFirst: jest.fn() },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );
    (storage.delete as jest.Mock).mockResolvedValue(undefined);

    await expect(
      service.deleteVersion('student-1', 'version-1'),
    ).resolves.toBeUndefined();
    expect(updateVersion).not.toHaveBeenCalled();
    expect(tx.studyReviewArtifactShare.findFirst).not.toHaveBeenCalled();
    expect(enqueue).not.toHaveBeenCalled();
    expect(storage.delete).toHaveBeenCalledWith('private/deleted.pdf');
  });

  it('refuses deletion while the exact version has an active review share', async () => {
    const updateVersion = jest.fn();
    const tx = {
      applicationArtifactVersion: {
        findFirst: jest.fn().mockResolvedValue(
          ownedVersionFixture({
            processingStatus: 'clean',
            storageKey: 'private/shared.pdf',
          }),
        ),
        update: updateVersion,
      },
      studyReviewArtifactShare: {
        findFirst: jest.fn().mockResolvedValue({ id: 'share-1' }),
      },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await expect(
      service.deleteVersion('student-1', 'version-1'),
    ).rejects.toMatchObject({
      status: 409,
      response: expect.objectContaining({ code: 'FORBIDDEN_SCOPE' }),
    });
    expect(updateVersion).not.toHaveBeenCalled();
    expect(storage.delete).not.toHaveBeenCalled();
  });

  it('repoints a deleted current version to the latest remaining clean version', async () => {
    const version = ownedVersionFixture({
      processingStatus: 'clean',
      storageKey: 'private/current.pdf',
    });
    (version.artifact as { currentVersionId: string | null }).currentVersionId =
      'version-1';
    const findVersion = jest
      .fn()
      .mockResolvedValueOnce(version)
      .mockResolvedValueOnce({ id: 'version-previous' });
    const updateArtifact = jest.fn();
    const tx = {
      applicationArtifactVersion: {
        findFirst: findVersion,
        update: jest.fn(),
      },
      applicationArtifact: { update: updateArtifact },
      studyReviewArtifactShare: { findFirst: jest.fn().mockResolvedValue(null) },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );
    (storage.delete as jest.Mock).mockResolvedValue(undefined);

    await service.deleteVersion('student-1', 'version-1', 'obsolete');

    expect(findVersion).toHaveBeenNthCalledWith(
      2,
      expect.objectContaining({
        where: expect.objectContaining({
          artifactId: 'artifact-1',
          id: { not: 'version-1' },
          processingStatus: 'clean',
          deletedAt: null,
        }),
        orderBy: { versionNumber: 'desc' },
      }),
    );
    expect(updateArtifact).toHaveBeenCalledWith({
      where: { id: 'artifact-1' },
      data: { currentVersionId: 'version-previous' },
    });
    expect(storage.delete).toHaveBeenCalledWith('private/current.pdf');
  });

  it('clears currentVersionId when no clean version remains', async () => {
    const version = ownedVersionFixture({
      processingStatus: 'clean',
      storageKey: 'private/only.pdf',
    });
    (version.artifact as { currentVersionId: string | null }).currentVersionId =
      'version-1';
    const updateArtifact = jest.fn();
    const tx = {
      applicationArtifactVersion: {
        findFirst: jest
          .fn()
          .mockResolvedValueOnce(version)
          .mockResolvedValueOnce(null),
        update: jest.fn(),
      },
      applicationArtifact: { update: updateArtifact },
      studyReviewArtifactShare: { findFirst: jest.fn().mockResolvedValue(null) },
      $queryRaw: jest.fn(),
    };
    execute.mockImplementation(async (operation: (db: unknown) => unknown) =>
      operation({
        $transaction: async (callback: (value: unknown) => unknown) =>
          callback(tx),
      }),
    );

    await service.deleteVersion('student-1', 'version-1');

    expect(updateArtifact).toHaveBeenCalledWith({
      where: { id: 'artifact-1' },
      data: { currentVersionId: null },
    });
  });
});

function versionFixture(overrides: Record<string, unknown> = {}) {
  const now = new Date('2026-07-17T09:00:00.000Z');
  return {
    id: 'version-1',
    artifactId: 'artifact-1',
    versionNumber: 1,
    originalFileName: 'cv.pdf',
    mimeType: 'application/pdf',
    sizeBytes: 120,
    sha256: 'a'.repeat(64),
    processingStatus: 'pending_upload',
    rejectionCode: null,
    uploadedAt: null,
    deletedAt: null,
    createdAt: now,
    ...overrides,
  };
}

function artifactFixture(overrides: Record<string, unknown> = {}) {
  const now = new Date('2026-07-17T09:00:00.000Z');
  return {
    id: 'artifact-1',
    workspaceId: 'workspace-1',
    kind: 'cv',
    title: 'CV principal',
    currentVersionId: null,
    createdAt: now,
    updatedAt: now,
    versions: [],
    ...overrides,
  };
}

function ownedVersionFixture(overrides: Record<string, unknown> = {}) {
  return {
    ...versionFixture(),
    storageKey: null,
    extractedText: null,
    artifact: {
      ...artifactFixture(),
      workspace: { id: 'workspace-1', userId: 'student-1', status: 'started' },
    },
    ...overrides,
  };
}
