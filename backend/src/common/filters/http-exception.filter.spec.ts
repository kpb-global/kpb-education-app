import { HttpStatus } from '@nestjs/common';
import type { ArgumentsHost } from '@nestjs/common';

import { CompetitionReadinessHttpException } from '../../modules/competition-readiness/common/competition-readiness.errors';
import { GlobalExceptionFilter } from './http-exception.filter';

describe('GlobalExceptionFilter request contract', () => {
  it('preserves stable domain error fields and echoes a valid request id', () => {
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const setHeader = jest.fn();
    const request = { header: jest.fn().mockReturnValue('request-123') };
    const response = { status, setHeader };
    const host = {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => response,
      }),
    } as unknown as ArgumentsHost;

    new GlobalExceptionFilter().catch(
      new CompetitionReadinessHttpException(
        'VERSION_CONFLICT',
        HttpStatus.CONFLICT,
        'Resource version is stale.',
        { currentVersion: 4 },
      ),
      host,
    );

    expect(setHeader).toHaveBeenCalledWith('X-Request-Id', 'request-123');
    expect(status).toHaveBeenCalledWith(HttpStatus.CONFLICT);
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: HttpStatus.CONFLICT,
        code: 'VERSION_CONFLICT',
        message: 'Resource version is stale.',
        requestId: 'request-123',
        details: { currentVersion: 4 },
      }),
    );
  });

  it('does not write unexpected error messages, stacks or thrown payloads to logs', () => {
    const json = jest.fn();
    const status = jest.fn().mockReturnValue({ json });
    const setHeader = jest.fn();
    const request = { header: jest.fn().mockReturnValue('private-log-test') };
    const response = { status, setHeader };
    const host = {
      switchToHttp: () => ({
        getRequest: () => request,
        getResponse: () => response,
      }),
    } as unknown as ArgumentsHost;
    const filter = new GlobalExceptionFilter();
    const error = new Error(
      'student@example.test Authorization: Bearer secret-access-token',
    );
    error.name = 'SECRETACCESSTOKEN123';
    error.stack = 'private stack with passport-123';
    const logError = jest.fn();
    Object.defineProperty(filter, 'logger', {
      value: { error: logError },
    });

    filter.catch(error, host);

    const logOutput = JSON.stringify(logError.mock.calls);
    expect(logOutput).toContain('private-log-test');
    expect(logOutput).toContain('Error');
    expect(logOutput).not.toContain('student@example.test');
    expect(logOutput).not.toContain('secret-access-token');
    expect(logOutput).not.toContain('passport-123');
    expect(logOutput).not.toContain('SECRETACCESSTOKEN123');
    expect(json).toHaveBeenCalledWith(
      expect.objectContaining({
        statusCode: HttpStatus.INTERNAL_SERVER_ERROR,
        message: 'Internal server error',
        requestId: 'private-log-test',
      }),
    );
  });
});
