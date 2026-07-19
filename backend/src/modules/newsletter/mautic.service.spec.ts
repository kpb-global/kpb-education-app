import { MauticService } from './mautic.service';

describe('MauticService', () => {
  const previousFetch = global.fetch;
  const previousEnv = { ...process.env };

  const configure = () => {
    process.env.MAUTIC_BASE_URL = 'https://mautic.example.test/';
    process.env.MAUTIC_USERNAME = 'api-user';
    process.env.MAUTIC_PASSWORD = 'api-pass';
    process.env.MAUTIC_SEGMENT_ID = '7';
  };

  afterEach(() => {
    global.fetch = previousFetch;
    process.env = { ...previousEnv };
    jest.restoreAllMocks();
  });

  it('is a no-op when not configured', async () => {
    delete process.env.MAUTIC_BASE_URL;
    const fetchSpy = jest.fn();
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().syncContact(
      { email: 'a@example.test' },
      true,
    );

    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('opt-in upserts the contact, clears DNC and adds it to the segment', async () => {
    configure();
    const fetchSpy = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ contact: { id: 42 } }),
    });
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().syncContact(
      {
        email: 'aissatou@example.test',
        fullName: 'Aissatou Ibrahim Diallo',
        phone: '+22790000000',
        whatsApp: '+22790000001',
        countryOfResidence: 'Niger',
        preferredLanguage: 'fr',
      },
      true,
    );

    expect(fetchSpy).toHaveBeenCalledTimes(3);
    const [upsertUrl, upsertInit] = fetchSpy.mock.calls[0] as [
      string,
      RequestInit,
    ];
    // Trailing slash of MAUTIC_BASE_URL must not double up.
    expect(upsertUrl).toBe('https://mautic.example.test/api/contacts/new');
    expect(upsertInit.headers).toMatchObject({
      authorization: `Basic ${Buffer.from('api-user:api-pass').toString('base64')}`,
    });
    const body = JSON.parse(upsertInit.body as string) as Record<
      string,
      string
    >;
    expect(body).toMatchObject({
      email: 'aissatou@example.test',
      firstname: 'Aissatou',
      lastname: 'Ibrahim Diallo',
      phone: '+22790000000',
      mobile: '+22790000001',
      country: 'Niger',
    });
    expect(fetchSpy.mock.calls[1][0]).toBe(
      'https://mautic.example.test/api/contacts/42/dnc/email/remove',
    );
    expect(fetchSpy.mock.calls[2][0]).toBe(
      'https://mautic.example.test/api/segments/7/contact/42/add',
    );
  });

  it('opt-out removes the contact from the segment and flags email DNC', async () => {
    configure();
    const fetchSpy = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ contact: { id: 42 } }),
    });
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().syncContact(
      { email: 'aissatou@example.test' },
      false,
    );

    expect(fetchSpy.mock.calls[1][0]).toBe(
      'https://mautic.example.test/api/segments/7/contact/42/remove',
    );
    expect(fetchSpy.mock.calls[2][0]).toBe(
      'https://mautic.example.test/api/contacts/42/dnc/email/add',
    );
  });

  it('throws on a provider error so the reconciliation cron retries', async () => {
    configure();
    global.fetch = jest
      .fn()
      .mockResolvedValue({ ok: false, status: 503 }) as unknown as typeof fetch;

    await expect(
      new MauticService().syncContact({ email: 'a@example.test' }, true),
    ).rejects.toThrow('status 503');
  });

  it('skips (without throwing) a profile that has no email', async () => {
    configure();
    const fetchSpy = jest.fn();
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().syncContact({ email: '  ' }, true);

    expect(fetchSpy).not.toHaveBeenCalled();
  });
});
