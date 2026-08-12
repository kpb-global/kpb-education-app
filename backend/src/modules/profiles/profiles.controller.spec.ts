import { ArgumentsHost, PayloadTooLargeException } from '@nestjs/common';
import { Readable } from 'stream';

import { ProfileAvatarPayloadFilter } from './profile-avatar-payload.filter';
import { ProfileAvatarHttpException } from './profile-avatar.errors';
import {
  AVATAR_MAX_BYTES,
  AVATAR_MULTIPART_BYTE_CEILING,
} from './profile-avatar.policy';
import { ProfilesController } from './profiles.controller';
import type { ProfilesService } from './profiles.service';

function makeResponse() {
  const headers: Record<string, string> = {};
  const state: { status?: number; body?: unknown; ended: boolean } = {
    ended: false,
  };
  const response = {
    headersSent: false,
    setHeader: (name: string, value: string) => {
      headers[name.toLowerCase()] = value;
    },
    status: (code: number) => {
      state.status = code;
      return response;
    },
    json: (body: unknown) => {
      state.body = body;
      return response;
    },
    end: () => {
      state.ended = true;
      return response;
    },
    destroy: () => undefined,
    on: () => response,
    once: () => response,
    emit: () => false,
    write: () => true,
  };
  return { response, headers, state };
}

describe('ProfilesController — avatar HTTP surface', () => {
  it('demands the multipart field before touching the service', () => {
    const service = { uploadAvatar: jest.fn() } as unknown as ProfilesService;
    const controller = new ProfilesController(service);

    expect(() =>
      controller.uploadAvatar(undefined, { studentUser: { id: 'user-1' } }),
    ).toThrow(ProfileAvatarHttpException);
    expect(service.uploadAvatar).not.toHaveBeenCalled();
  });

  it('streams the image privately: no shared caching, no sniffing, no public URL', async () => {
    const stream = Readable.from([Buffer.from('jpeg bytes')]);
    const service = {
      streamAvatar: jest.fn().mockResolvedValue({
        etag: 'W/"abc"',
        object: { stream, mimeType: 'image/jpeg', sizeBytes: 10 },
      }),
    } as unknown as ProfilesService;
    const controller = new ProfilesController(service);
    const { response, headers } = makeResponse();

    await controller.getAvatar(
      { studentUser: { id: 'user-1' } },
      undefined,
      response as never,
    );

    expect(service.streamAvatar).toHaveBeenCalledWith('user-1', undefined);
    expect(headers['content-type']).toBe('image/jpeg');
    expect(headers['content-length']).toBe('10');
    expect(headers['etag']).toBe('W/"abc"');
    expect(headers['cache-control']).toContain('private');
    expect(headers['cache-control']).not.toContain('public');
    expect(headers['x-content-type-options']).toBe('nosniff');
    expect(headers['cross-origin-resource-policy']).toBe('same-origin');
  });

  it('answers 304 with no body when the client revalidates a known image', async () => {
    const service = {
      streamAvatar: jest
        .fn()
        .mockResolvedValue({ etag: 'W/"abc"', object: null }),
    } as unknown as ProfilesService;
    const controller = new ProfilesController(service);
    const { response, headers, state } = makeResponse();

    await controller.getAvatar(
      { studentUser: { id: 'user-1' } },
      'W/"abc"',
      response as never,
    );

    expect(state.status).toBe(304);
    expect(state.ended).toBe(true);
    expect(headers['etag']).toBe('W/"abc"');
    // No payload headers on a 304.
    expect(headers['content-length']).toBeUndefined();
  });

  it('caps the multipart stream one byte above the avatar limit', () => {
    // Bounded memory for an abusive upload, while a file of exactly cap+1 still
    // reaches the handler and gets the honest code instead of multer's bare 413.
    expect(AVATAR_MULTIPART_BYTE_CEILING).toBe(AVATAR_MAX_BYTES + 1);
  });

  it('rewrites multer bare 413 into the coded AVATAR_TOO_LARGE body', () => {
    const { response, state } = makeResponse();
    const host = {
      switchToHttp: () => ({
        getRequest: () => ({ header: () => undefined }),
        getResponse: () => response,
      }),
    } as unknown as ArgumentsHost;

    new ProfileAvatarPayloadFilter().catch(
      new PayloadTooLargeException('File too large'),
      host,
    );

    expect(state.status).toBe(413);
    expect(state.body).toMatchObject({
      statusCode: 413,
      code: 'AVATAR_TOO_LARGE',
      details: { maxBytes: AVATAR_MAX_BYTES },
    });
    // Same shape as GlobalExceptionFilter, so the client parses one body.
    expect(state.body).toHaveProperty('requestId');
    expect(state.body).toHaveProperty('timestamp');
  });
});
