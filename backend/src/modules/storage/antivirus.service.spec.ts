import {
  ServiceUnavailableException,
  UnprocessableEntityException,
} from '@nestjs/common';

import {
  AntivirusService,
  AntivirusUnavailableError,
  InfectedFileError,
  parseClamdResponse,
} from './antivirus.service';

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
    // Typed so a caller can say "this file is infected" rather than a catch-all.
    await expect(
      service.assertClean(Buffer.from('evil'), 'doc.pdf'),
    ).rejects.toBeInstanceOf(InfectedFileError);
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
    // A distinct type from InfectedFileError: "no verdict" is our problem, not
    // the student's, and the two must never be reported with one message.
    await expect(
      service.assertClean(Buffer.from('anything'), 'doc.pdf'),
    ).rejects.toBeInstanceOf(AntivirusUnavailableError);
    await expect(
      service.assertClean(Buffer.from('anything'), 'doc.pdf'),
    ).rejects.not.toBeInstanceOf(InfectedFileError);
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

describe('AntivirusService.selfTest', () => {
  const previous = process.env.CLAMAV_HOST;
  afterEach(() => {
    if (previous === undefined) delete process.env.CLAMAV_HOST;
    else process.env.CLAMAV_HOST = previous;
    jest.restoreAllMocks();
  });

  /** Construit un service configuré, avec `assertClean` remplacé. */
  function withVerdict(impl: () => Promise<void>) {
    process.env.CLAMAV_HOST = 'clamav';
    const service = new AntivirusService();
    jest.spyOn(service, 'assertClean').mockImplementation(impl);
    return service;
  }

  // Le seul résultat qui prouve que la chaîne complète fonctionne : la
  // connexion, le protocole INSTREAM, la base chargée, et l'analyse du verdict.
  it('rend true quand EICAR est DÉTECTÉ', async () => {
    const service = withVerdict(() => {
      throw new InfectedFileError('infected');
    });
    await expect(service.selfTest()).resolves.toBe(true);
  });

  // Un daemon qui répond mais ne détecte pas EICAR laisserait passer un vrai
  // fichier infecté. Ce n'est pas « sain » — c'est une panne silencieuse, et
  // c'est précisément ce qu'un PING n'aurait jamais vu.
  it('rend false quand EICAR est déclaré PROPRE', async () => {
    const service = withVerdict(async () => {});
    await expect(service.selfTest()).resolves.toBe(false);
  });

  it('rend false quand le scanner ne rend aucun verdict', async () => {
    const service = withVerdict(() => {
      throw new AntivirusUnavailableError('down');
    });
    await expect(service.selfTest()).resolves.toBe(false);
  });

  // Sans hôte configuré il n'y a rien à sonder — et surtout rien à alarmer.
  it('rend false, sans rien sonder, quand CLAMAV_HOST est vide', async () => {
    delete process.env.CLAMAV_HOST;
    const service = new AntivirusService();
    const spy = jest.spyOn(service, 'assertClean');
    await expect(service.selfTest()).resolves.toBe(false);
    expect(spy).not.toHaveBeenCalled();
  });

  // Une sonde de santé ne doit jamais faire tomber la route qui l'appelle.
  it('ne laisse échapper aucune exception inattendue', async () => {
    const service = withVerdict(() => {
      throw new TypeError('socket explosé');
    });
    await expect(service.selfTest()).resolves.toBe(false);
  });
});
