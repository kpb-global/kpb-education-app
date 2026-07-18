import { PrismaService } from './prisma.service';

describe('PrismaService safe logging', () => {
  const previousDatabaseUrl = process.env.DATABASE_URL;

  afterEach(() => {
    if (previousDatabaseUrl === undefined) delete process.env.DATABASE_URL;
    else process.env.DATABASE_URL = previousDatabaseUrl;
  });

  it('never logs raw operation errors that can contain PII or secrets', async () => {
    process.env.DATABASE_URL =
      'postgresql://unused:unused@127.0.0.1:1/unused?schema=public';
    const service = new PrismaService();
    const logError = jest.fn();
    Object.defineProperty(service, 'logger', {
      value: { error: logError, warn: jest.fn() },
    });
    const privateError = Object.assign(
      new Error('student@example.test secret-access-token passport-123'),
      { code: 'P2002' },
    );

    await expect(
      service.execute(async () => {
        throw privateError;
      }),
    ).rejects.toBe(privateError);

    const output = JSON.stringify(logError.mock.calls);
    expect(output).toContain('P2002');
    expect(output).not.toContain('student@example.test');
    expect(output).not.toContain('secret-access-token');
    expect(output).not.toContain('passport-123');
    await service.onModuleDestroy();
  });

  it('does not trust an arbitrary error code as safe log material', async () => {
    process.env.DATABASE_URL =
      'postgresql://unused:unused@127.0.0.1:1/unused?schema=public';
    const service = new PrismaService();
    const logError = jest.fn();
    Object.defineProperty(service, 'logger', {
      value: { error: logError, warn: jest.fn() },
    });

    await expect(
      service.execute(async () => {
        throw Object.assign(new Error('private'), {
          code: 'SECRETACCESSTOKEN123',
        });
      }),
    ).rejects.toThrow('private');

    expect(JSON.stringify(logError.mock.calls)).toContain('UNKNOWN');
    expect(JSON.stringify(logError.mock.calls)).not.toContain(
      'SECRETACCESSTOKEN123',
    );
    await service.onModuleDestroy();
  });
});
