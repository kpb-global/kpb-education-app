import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import type { Request, Response } from 'express';

type ExceptionBody = {
  message?: string | string[];
  errors?: unknown;
  code?: string;
  details?: unknown;
};

function resolveRequestId(request: Request): string {
  const candidate = request.header('X-Request-Id')?.trim();
  if (candidate && /^[A-Za-z0-9._:-]{1,128}$/.test(candidate)) {
    return candidate;
  }
  return randomUUID();
}

// Maps Prisma known-request error codes to sensible HTTP statuses so that
// normal business conditions (unique conflict, missing row, bad FK) surface as
// 4xx instead of opaque 500s that pollute error alerting.
function mapPrismaError(
  code: string,
): { status: HttpStatus; message: string } | null {
  switch (code) {
    case 'P2002':
      return { status: HttpStatus.CONFLICT, message: 'Resource already exists.' };
    case 'P2025':
      return { status: HttpStatus.NOT_FOUND, message: 'Resource not found.' };
    case 'P2003':
    case 'P2000':
      return { status: HttpStatus.BAD_REQUEST, message: 'Invalid request.' };
    default:
      return null;
  }
}

@Catch()
export class GlobalExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger('ExceptionFilter');

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const requestId = resolveRequestId(request);

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message: string | string[] = 'Internal server error';
    let errors: unknown;
    let code: string | undefined;
    let details: unknown;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exResponse = exception.getResponse();
      if (typeof exResponse === 'string') {
        message = exResponse;
      } else if (typeof exResponse === 'object') {
        const body = exResponse as ExceptionBody;
        message = body.message ?? message;
        errors = body.errors;
        code = body.code;
        details = body.details;
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      const mapped = mapPrismaError(exception.code);
      if (mapped) {
        status = mapped.status;
        message = mapped.message;
      } else {
        this.logUnexpected(`Prisma ${exception.code}`, requestId);
      }
    } else if (exception instanceof Error) {
      this.logUnexpected(safeErrorClass(exception), requestId);
    } else {
      // Never serialize arbitrary thrown values. They can contain request
      // bodies, document text, access tokens or other private fields.
      this.logUnexpected('NonErrorThrow', requestId);
    }

    response.setHeader('X-Request-Id', requestId);
    response.status(status).json({
      statusCode: status,
      message,
      requestId,
      ...(code && { code }),
      ...(details !== undefined && { details }),
      ...(errors !== undefined && { errors }),
      timestamp: new Date().toISOString(),
    });
  }

  private logUnexpected(errorClass: string, requestId: string): void {
    // Unexpected exception messages and stacks frequently embed Prisma input,
    // provider payloads or user-entered text. Log only a correlation-safe
    // classification; the response already exposes the request id to support.
    this.logger.error(`Unhandled ${errorClass}; requestId=${requestId}`);
  }
}

function safeErrorClass(error: Error): string {
  return [
    'Error',
    'TypeError',
    'RangeError',
    'ReferenceError',
    'SyntaxError',
    'URIError',
    'EvalError',
  ].includes(error.name)
    ? error.name
    : 'Error';
}
