import {
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';

import { AntivirusService, parseClamdResponse } from './antivirus.service';

describe('parseClamdResponse', () => {
  it('parses a clean verdict', () => {
    expect(parseClamdResponse('stream: OK\0')).toEqual({
      ok: true,
      infected: false,
    });
  });

  it('parses an infected verdict with its signature', () => {
    expect(
      parseClamdResponse('stream: Eicar-Test-Signature FOUND\0'),
    ).toEqual({ ok: false, infected: true, signature: 'Eicar-Test-Signature' });
  });

  it('treats an ERROR response as not-ok and not-infected', () => {
    expect(parseClamdResponse('INSTREAM size limit exceeded. ERROR')).toEqual({
      ok: false,
      infected: false,
    });
  });
});

describe('AntivirusService', () => {
  const previousEnv = {
    CLAMAV_HOST: process.env.CLAMAV_HOST,
    CLAMAV_PORT: process.env.CLAMAV_PORT,
  };

  afterEach(() => {
    for (const [key, value] of Object.entries(previousEnv)) {
      if (value === undefined) {
        delete process.env[key];
      } else {
        process.env[key] = value;
      }
    }
    jest.restoreAllMocks();
  });

  function makeEnabledService(): AntivirusService {
    process.env.CLAMAV_HOST = 'clamav';
    return new AntivirusService();
  }

  it('is a no-op when CLAMAV_HOST is unset', async () => {
    delete process.env.CLAMAV_HOST;
    const service = new AntivirusService();
    expect(service.isEnabled).toBe(false);
    // No socket is opened: instream would reject immediately if called.
    await expect(
      service.assertClean(Buffer.from('anything'), 'doc.pdf'),
    ).resolves.toBeUndefined();
  });

  it('passes a clean file through', async () => {
    const service = makeEnabledService();
    jest
      .spyOn(
        service as unknown as { instream: (b: Buffer) => Promise<string> },
        'instream',
      )
      .mockResolvedValue('stream: OK\0');
    await expect(
      service.assertClean(Buffer.from('clean'), 'doc.pdf'),
    ).resolves.toBeUndefined();
  });

  it('rejects an infected file with 422', async () => {
    const service = makeEnabledService();
    jest
      .spyOn(
        service as unknown as { instream: (b: Buffer) => Promise<string> },
        'instream',
      )
      .mockResolvedValue('stream: Eicar-Test-Signature FOUND\0');
    await expect(
      service.assertClean(Buffer.from('evil'), 'doc.pdf'),
    ).rejects.toBeInstanceOf(UnprocessableEntityException);
  });

  it('fails closed with 503 when the scanner is unreachable', async () => {
    const service = makeEnabledService();
    jest
      .spyOn(
        service as unknown as { instream: (b: Buffer) => Promise<string> },
        'instream',
      )
      .mockRejectedValue(new Error('ECONNREFUSED'));
    await expect(
      service.assertClean(Buffer.from('anything'), 'doc.pdf'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });

  it('fails closed with 503 on a clamd ERROR response', async () => {
    const service = makeEnabledService();
    jest
      .spyOn(
        service as unknown as { instream: (b: Buffer) => Promise<string> },
        'instream',
      )
      .mockResolvedValue('INSTREAM size limit exceeded. ERROR\0');
    await expect(
      service.assertClean(Buffer.from('big'), 'doc.pdf'),
    ).rejects.toBeInstanceOf(ServiceUnavailableException);
  });
});
