import { mkdtemp, readdir, rm, stat } from 'fs/promises';
import { tmpdir } from 'os';
import { join } from 'path';

import type { PrismaClient } from '@prisma/client';

import type { PrismaService } from '../prisma/prisma.service';
import {
  AntivirusService,
  AntivirusUnavailableError,
  InfectedFileError,
} from '../storage/antivirus.service';
import { StorageService } from '../storage/storage.service';
import { ProfileAvatarHttpException } from './profile-avatar.errors';
import { AVATAR_MAX_BYTES } from './profile-avatar.policy';
import { ProfilesService, type UploadedAvatarFile } from './profiles.service';

// ── Fixtures: real byte signatures, because the avatar whitelist is enforced on
// content and never on the client-declared MIME type. ────────────────────────
const PNG = Buffer.concat([
  Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
  Buffer.from('png pixels'),
]);
const JPEG = Buffer.concat([
  Buffer.from([0xff, 0xd8, 0xff, 0xe0]),
  Buffer.from('jpeg pixels'),
]);
const WEBP = Buffer.concat([
  Buffer.from('RIFF'),
  Buffer.from([0x1a, 0x00, 0x00, 0x00]),
  Buffer.from('WEBP'),
  Buffer.from('vp8 pixels'),
]);
const PDF = Buffer.from('%PDF-1.7\nnot a photo');
const HEIC = Buffer.concat([
  Buffer.from([0x00, 0x00, 0x00, 0x18]),
  Buffer.from('ftypheic'),
  Buffer.from('heic payload'),
]);

function upload(
  buffer: Buffer,
  declaredMimeType = 'image/png',
): UploadedAvatarFile {
  return {
    buffer,
    originalname: 'Aissatou Ibrahim selfie.png',
    mimetype: declaredMimeType,
    size: buffer.byteLength,
  };
}

type Row = Record<string, unknown> & {
  id: string;
  avatarStorageKey: string | null;
};

function profileRow(overrides: Partial<Row> = {}): Row {
  return {
    id: 'user-1',
    accountType: 'student',
    preferredLanguage: 'fr',
    fullName: 'Aissatou Ibrahim',
    email: 'aissatou@example.com',
    phone: '+22790000000',
    whatsApp: null,
    countryOfResidence: 'Niger',
    currentLevel: null,
    targetLevel: null,
    languageLevel: null,
    gradeRange: null,
    annualTuitionBudgetEur: null,
    monthlyBudgetEur: null,
    preferredCurrency: 'XOF',
    wantsScholarship: false,
    newsletterOptIn: false,
    disabledNotificationTypes: [],
    fieldIds: [],
    targetCountryIds: [],
    availableDocuments: [],
    aiConsentedAt: null,
    birthDate: null,
    guardianName: null,
    guardianContact: null,
    guardianConsentedAt: null,
    avatarStorageKey: null,
    updatedAt: new Date('2026-08-12T10:00:00.000Z'),
    ...overrides,
  };
}

/**
 * Minimal Postgres stand-in with the semantics the avatar path depends on: a
 * conditional `updateMany` that reports 0 rows when the guard column moved. Two
 * hooks let a test simulate a commit failure or a concurrent writer.
 */
function makePrisma(initial: Row | null) {
  const state: { row: Row | null; failUpdate: boolean; raceTo?: string | null } =
    { row: initial, failUpdate: false };

  const client = {
    userProfile: {
      findUnique: async ({ where }: { where: { id: string } }) =>
        state.row && state.row.id === where.id ? { ...state.row } : null,
      update: async ({
        where,
        data,
      }: {
        where: { id: string };
        data: Record<string, unknown>;
      }) => {
        if (state.failUpdate) throw new Error('connection terminated');
        if (!state.row || state.row.id !== where.id) {
          throw new Error('record not found');
        }
        state.row = { ...state.row, ...data, updatedAt: new Date() };
        return { ...state.row };
      },
      updateMany: async ({
        where,
        data,
      }: {
        where: { id: string; avatarStorageKey?: string | null };
        data: Record<string, unknown>;
      }) => {
        if (state.failUpdate) throw new Error('connection terminated');
        // A concurrent upload committed while this one was being scanned.
        if (state.raceTo !== undefined && state.row) {
          state.row = { ...state.row, avatarStorageKey: state.raceTo };
          state.raceTo = undefined;
        }
        if (!state.row || state.row.id !== where.id) return { count: 0 };
        if (
          'avatarStorageKey' in where &&
          state.row.avatarStorageKey !== where.avatarStorageKey
        ) {
          return { count: 0 };
        }
        state.row = { ...state.row, ...data, updatedAt: new Date() };
        return { count: 1 };
      },
    },
    $transaction: async <T>(fn: (tx: unknown) => Promise<T>) => fn(client),
  };

  const prismaService = {
    isEnabled: true,
    execute: async <T>(operation: (c: PrismaClient) => Promise<T>) =>
      operation(client as unknown as PrismaClient),
  } as unknown as PrismaService;

  return { prismaService, state };
}

describe('Profile avatar', () => {
  const previousEnv = {
    KPB_UPLOADS_DIR: process.env.KPB_UPLOADS_DIR,
    KPB_S3_BUCKET: process.env.KPB_S3_BUCKET,
    NODE_ENV: process.env.NODE_ENV,
    CLAMAV_HOST: process.env.CLAMAV_HOST,
  };
  let uploadsDir: string;

  beforeEach(async () => {
    uploadsDir = await mkdtemp(join(tmpdir(), 'kpb-avatar-'));
    process.env.KPB_UPLOADS_DIR = uploadsDir;
    delete process.env.KPB_S3_BUCKET;
    delete process.env.CLAMAV_HOST;
  });

  afterEach(async () => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
    await rm(uploadsDir, { recursive: true, force: true });
  });

  /** Every object written under the uploads root, so orphans are visible. */
  async function storedObjects(): Promise<string[]> {
    const days = await readdir(uploadsDir, { withFileTypes: true });
    const files: string[] = [];
    for (const day of days) {
      if (!day.isDirectory()) continue;
      for (const name of await readdir(join(uploadsDir, day.name))) {
        files.push(`${day.name}/${name}`);
      }
    }
    return files.sort();
  }

  function makeService(
    row: Row | null,
    assertClean: jest.Mock = jest.fn().mockResolvedValue(undefined),
  ) {
    const antivirus = { assertClean } as unknown as AntivirusService;
    const storage = new StorageService(antivirus);
    const deleteSpy = jest.spyOn(storage, 'delete');
    const { prismaService, state } = makePrisma(row);
    return {
      service: new ProfilesService(prismaService, storage),
      storage,
      deleteSpy,
      assertClean,
      state,
    };
  }

  async function expectAvatarError(
    promise: Promise<unknown>,
    code: string,
    status: number,
  ) {
    await expect(promise).rejects.toBeInstanceOf(ProfileAvatarHttpException);
    await promise.catch((error: ProfileAvatarHttpException) => {
      expect(error.code).toBe(code);
      expect(error.getStatus()).toBe(status);
    });
  }

  // ── Upload: acceptance ─────────────────────────────────────────────────────

  it.each([
    ['png', PNG, 'image/png', '.png'],
    ['jpeg', JPEG, 'image/jpeg', '.jpg'],
    ['webp', WEBP, 'image/webp', '.webp'],
  ])(
    'accepts a %s photo and exposes a flag plus the authenticated endpoint',
    async (_label, buffer, declared, extension) => {
      const { service, state } = makeService(profileRow());

      const profile = (await service.uploadAvatar(
        upload(buffer, declared),
        'user-1',
      )) as Record<string, unknown>;

      expect(profile.hasAvatar).toBe(true);
      expect(profile.avatarUrl).toBe('/api/profiles/me/avatar');
      // The storage key must not appear anywhere in the payload.
      expect(JSON.stringify(profile)).not.toContain(
        String(state.row?.avatarStorageKey),
      );
      expect(Object.keys(profile)).not.toContain('avatarStorageKey');
      expect(state.row?.avatarStorageKey).toMatch(
        new RegExp(`^\\d{4}-\\d{2}-\\d{2}/[0-9a-f-]{36}\\${extension}$`),
      );
      expect(await storedObjects()).toHaveLength(1);
    },
  );

  it('never trusts the declared MIME type: content decides', async () => {
    const { service, state } = makeService(profileRow());
    // A WebP photo uploaded by a client that reports application/octet-stream.
    await service.uploadAvatar(upload(WEBP, 'application/octet-stream'), 'user-1');
    expect(state.row?.avatarStorageKey).toMatch(/\.webp$/);
  });

  // ── Upload: honest, distinct rejections ────────────────────────────────────

  // The boundary is pinned with LITERAL sizes on purpose. Deriving the fixture
  // from AVATAR_MAX_BYTES would make the test follow the constant instead of
  // guarding it: raising the cap to 10 MB would still "pass".
  const TWO_MIB = 2 * 1024 * 1024;

  /** A valid PNG of exactly `bytes` total length. */
  function pngOfSize(bytes: number): Buffer {
    return Buffer.concat([PNG, Buffer.alloc(bytes - PNG.byteLength)]);
  }

  it('rejects a photo of 2 MiB + 1 byte with AVATAR_TOO_LARGE and stores nothing', async () => {
    const { service, assertClean } = makeService(profileRow());
    const oversize = pngOfSize(TWO_MIB + 1);
    expect(oversize.byteLength).toBe(2_097_153);

    await expectAvatarError(
      service.uploadAvatar(upload(oversize), 'user-1'),
      'AVATAR_TOO_LARGE',
      413,
    );
    // Refused before the scanner is even asked: no wasted scan, no bytes stored.
    expect(assertClean).not.toHaveBeenCalled();
    expect(await storedObjects()).toEqual([]);
  });

  it('accepts a photo of exactly 2 MiB', async () => {
    const { service, state } = makeService(profileRow());
    await service.uploadAvatar(upload(pngOfSize(TWO_MIB)), 'user-1');
    expect(state.row?.avatarStorageKey).toMatch(/\.png$/);
  });

  it('keeps the avatar cap stricter than the shared 10 MB storage cap', async () => {
    const { storage } = makeService(profileRow());
    expect(AVATAR_MAX_BYTES).toBe(2 * 1024 * 1024);
    expect(AVATAR_MAX_BYTES).toBeLessThan(storage.maxBytes);
  });

  it.each([
    ['a PDF', PDF, 'application/pdf'],
    ['a HEIC image', HEIC, 'image/heic'],
    ['arbitrary bytes', Buffer.from('<html>not an image</html>'), 'image/png'],
  ])(
    'rejects %s with AVATAR_TYPE_NOT_ALLOWED even though storage may accept it',
    async (_label, buffer, declared) => {
      const { service, assertClean } = makeService(profileRow());
      await expectAvatarError(
        service.uploadAvatar(upload(buffer, declared), 'user-1'),
        'AVATAR_TYPE_NOT_ALLOWED',
        415,
      );
      expect(assertClean).not.toHaveBeenCalled();
      expect(await storedObjects()).toEqual([]);
    },
  );

  it('rejects an empty file distinctly from an unsupported one', async () => {
    const { service } = makeService(profileRow());
    await expectAvatarError(
      service.uploadAvatar(upload(Buffer.alloc(0)), 'user-1'),
      'AVATAR_FILE_EMPTY',
      400,
    );
  });

  it('separates "your file is infected" from "our scanner is down"', async () => {
    const infected = makeService(
      profileRow(),
      jest.fn().mockRejectedValue(new InfectedFileError('rejected')),
    );
    await expectAvatarError(
      infected.service.uploadAvatar(upload(PNG), 'user-1'),
      'AVATAR_INFECTED',
      422,
    );
    expect(await storedObjects()).toEqual([]);
    expect(infected.state.row?.avatarStorageKey).toBeNull();

    const scannerDown = makeService(
      profileRow(),
      jest.fn().mockRejectedValue(new AntivirusUnavailableError('unavailable')),
    );
    await expectAvatarError(
      scannerDown.service.uploadAvatar(upload(PNG), 'user-1'),
      'AVATAR_SCANNER_UNAVAILABLE',
      503,
    );
    expect(await storedObjects()).toEqual([]);
  });

  it('fails closed in production when no scanner is configured', async () => {
    process.env.NODE_ENV = 'production';
    delete process.env.CLAMAV_HOST;
    const { service, assertClean } = makeService(profileRow());

    await expectAvatarError(
      service.uploadAvatar(upload(PNG), 'user-1'),
      'AVATAR_SCANNER_UNAVAILABLE',
      503,
    );
    expect(assertClean).not.toHaveBeenCalled();
    expect(await storedObjects()).toEqual([]);
  });

  it('reports a missing profile as PROFILE_NOT_FOUND, not a generic failure', async () => {
    const { service } = makeService(null);
    await expectAvatarError(
      service.uploadAvatar(upload(PNG), 'ghost-user'),
      'PROFILE_NOT_FOUND',
      404,
    );
    expect(await storedObjects()).toEqual([]);
  });

  // ── Replacement: no orphaned objects, ever ─────────────────────────────────

  it('deletes the previous object when the photo is replaced', async () => {
    const { service, deleteSpy, state } = makeService(profileRow());

    await service.uploadAvatar(upload(PNG), 'user-1');
    const firstKey = state.row?.avatarStorageKey;
    await service.uploadAvatar(upload(JPEG, 'image/jpeg'), 'user-1');
    const secondKey = state.row?.avatarStorageKey;

    expect(secondKey).not.toBe(firstKey);
    expect(deleteSpy).toHaveBeenCalledWith(firstKey);
    // Exactly one object survives: the current one.
    expect(await storedObjects()).toEqual([secondKey]);
  });

  it('deletes the new object when the database write fails (no orphan)', async () => {
    const { service, state } = makeService(profileRow());
    state.failUpdate = true;

    await expect(
      service.uploadAvatar(upload(PNG), 'user-1'),
    ).rejects.toBeDefined();

    expect(await storedObjects()).toEqual([]);
    expect(state.row?.avatarStorageKey).toBeNull();
  });

  it('discards its own object when a concurrent upload wins the row', async () => {
    const { service, state } = makeService(profileRow());
    // A parallel request commits `2026-08-12/other.png` mid-flight.
    state.raceTo = '2026-08-12/other.png';

    await expectAvatarError(
      service.uploadAvatar(upload(PNG), 'user-1'),
      'AVATAR_UPLOAD_CONFLICT',
      409,
    );

    // The winner's key stands and our object is gone rather than orphaned.
    expect(state.row?.avatarStorageKey).toBe('2026-08-12/other.png');
    expect(await storedObjects()).toEqual([]);
  });

  it('keeps the stored object when the same key is re-claimed', async () => {
    const { service, state } = makeService(profileRow());
    await service.uploadAvatar(upload(PNG), 'user-1');
    const key = String(state.row?.avatarStorageKey);
    await stat(join(uploadsDir, key)); // throws if the file was removed
  });

  // ── Authenticated delivery ─────────────────────────────────────────────────

  it('streams the caller own image and revalidates with an ETag', async () => {
    const { service, state } = makeService(profileRow());
    await service.uploadAvatar(upload(JPEG, 'image/jpeg'), 'user-1');

    const first = await service.streamAvatar('user-1');
    expect(first.object?.mimeType).toBe('image/jpeg');
    expect(first.etag).toMatch(/^W\/"[0-9a-f]{32}"$/);
    // The validator must not embed the storage key.
    expect(first.etag).not.toContain(String(state.row?.avatarStorageKey));
    first.object?.stream.destroy();

    // A client that already holds the image spends bytes on headers only.
    const revalidated = await service.streamAvatar('user-1', first.etag);
    expect(revalidated.object).toBeNull();
    expect(revalidated.etag).toBe(first.etag);

    // The validator changes when the photo changes.
    await service.uploadAvatar(upload(PNG), 'user-1');
    const afterChange = await service.streamAvatar('user-1');
    expect(afterChange.etag).not.toBe(first.etag);
    afterChange.object?.stream.destroy();
  });

  it('answers 404 AVATAR_NOT_FOUND when the profile has no photo', async () => {
    const { service } = makeService(profileRow());
    await expectAvatarError(service.streamAvatar('user-1'), 'AVATAR_NOT_FOUND', 404);
  });

  it('answers 404 — not 500 — when the row points at a vanished object', async () => {
    const { service } = makeService(
      profileRow({ avatarStorageKey: '2026-08-12/00000000-0000-4000-8000-000000000000.png' }),
    );
    await expectAvatarError(service.streamAvatar('user-1'), 'AVATAR_NOT_FOUND', 404);
  });

  it('refuses to serve an unknown profile', async () => {
    const { service } = makeService(null);
    await expectAvatarError(
      service.streamAvatar('ghost-user'),
      'PROFILE_NOT_FOUND',
      404,
    );
  });

  // ── Removal ────────────────────────────────────────────────────────────────

  it('clears the key and removes the object on delete', async () => {
    const { service, deleteSpy, state } = makeService(profileRow());
    await service.uploadAvatar(upload(PNG), 'user-1');
    const key = state.row?.avatarStorageKey;

    const profile = (await service.deleteAvatar('user-1')) as Record<
      string,
      unknown
    >;

    expect(profile.hasAvatar).toBe(false);
    expect(profile.avatarUrl).toBeNull();
    expect(state.row?.avatarStorageKey).toBeNull();
    expect(deleteSpy).toHaveBeenCalledWith(key);
    expect(await storedObjects()).toEqual([]);
  });

  it('is idempotent when there is nothing to delete', async () => {
    const { service, deleteSpy } = makeService(profileRow());
    const profile = (await service.deleteAvatar('user-1')) as Record<
      string,
      unknown
    >;
    expect(profile.hasAvatar).toBe(false);
    expect(deleteSpy).not.toHaveBeenCalled();
  });

  // ── The profile DTO / GDPR export must never carry the key ─────────────────

  it('reports hasAvatar=false for a profile without a photo', async () => {
    const { service } = makeService(profileRow());
    const profile = (await service.getMe('user-1')) as Record<string, unknown>;
    expect(profile.hasAvatar).toBe(false);
    expect(profile.avatarUrl).toBeNull();
    expect(Object.keys(profile)).not.toContain('avatarStorageKey');
  });
});
