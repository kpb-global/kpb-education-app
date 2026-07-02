import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Response } from 'express';

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

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let errors: any = undefined;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exResponse = exception.getResponse();
      if (typeof exResponse === 'string') {
        message = exResponse;
      } else if (typeof exResponse === 'object') {
        message = (exResponse as any).message ?? message;
        errors = (exResponse as any).errors;
      }
    } else if (exception instanceof Prisma.PrismaClientKnownRequestError) {
      const mapped = mapPrismaError(exception.code);
      if (mapped) {
        status = mapped.status;
        message = mapped.message;
      } else {
        this.logger.error(`Prisma ${exception.code}: ${exception.message}`);
      }
    } else if (exception instanceof Error) {
      this.logger.error(exception.message, exception.stack);
    } else {
      // Non-Error throw (e.g. a thrown string/object) — still record it.
      this.logger.error(`Non-error exception: ${JSON.stringify(exception)}`);
    }

    response.status(status).json({
      statusCode: status,
      message,
      ...(errors && { errors }),
      timestamp: new Date().toISOString(),
    });
  }
}
