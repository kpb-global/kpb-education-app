import {
  ArgumentsHost,
  Catch,
  ExceptionFilter,
  HttpStatus,
  PayloadTooLargeException,
} from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';

import { avatarTooLarge } from './profile-avatar.errors';
import { AVATAR_MAX_BYTES } from './profile-avatar.policy';

/**
 * Multer aborts an over-ceiling upload inside the interceptor, before the route
 * handler runs, and Nest turns that into a bare `PayloadTooLargeException` with
 * no error code. That would leave the client with two different bodies for the
 * same cause ("too large"), which is exactly the ambiguity this feature is
 * supposed to avoid — so the interceptor's 413 is rewritten into the coded
 * AVATAR_TOO_LARGE body the handler would have produced.
 *
 * Only PayloadTooLargeException is caught; every other error still falls through
 * to GlobalExceptionFilter, and the response shape here mirrors it.
 */
@Catch(PayloadTooLargeException)
export class ProfileAvatarPayloadFilter implements ExceptionFilter {
  catch(_exception: PayloadTooLargeException, host: ArgumentsHost): void {
    const ctx = host.switchToHttp();
    const request = ctx.getRequest<Request>();
    const response = ctx.getResponse<Response>();

    const candidate = request.header('X-Request-Id')?.trim();
    const requestId =
      candidate && /^[A-Za-z0-9._:-]{1,128}$/.test(candidate)
        ? candidate
        : randomUUID();

    const body = avatarTooLarge(AVATAR_MAX_BYTES).getResponse() as {
      code: string;
      message: string;
      details?: Record<string, unknown>;
    };

    response.setHeader('X-Request-Id', requestId);
    response.status(HttpStatus.PAYLOAD_TOO_LARGE).json({
      statusCode: HttpStatus.PAYLOAD_TOO_LARGE,
      message: body.message,
      requestId,
      code: body.code,
      ...(body.details !== undefined && { details: body.details }),
      timestamp: new Date().toISOString(),
    });
  }
}
