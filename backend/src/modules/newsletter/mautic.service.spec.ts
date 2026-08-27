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

  it('opt-out sends the e-mail alone, never the profile fields', async () => {
    configure();
    const fetchSpy = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ contact: { id: 42 } }),
    });
    global.fetch = fetchSpy as unknown as typeof fetch;

    // A full profile is handed over on purpose: the caller passes whatever the
    // row holds, so the redaction has to happen here.
    await new MauticService().syncContact(
      {
        email: 'aissatou@example.test',
        fullName: 'Aissatou Ibrahim Diallo',
        phone: '+22790000000',
        whatsApp: '+22790000001',
        countryOfResidence: 'Niger',
        preferredLanguage: 'fr',
      },
      false,
    );

    // toEqual, not toMatchObject: the assertion is about what is ABSENT.
    // Unsubscribing only needs the id the upsert returns.
    const body = JSON.parse(
      (fetchSpy.mock.calls[0][1] as RequestInit).body as string,
    ) as Record<string, string>;
    expect(body).toEqual({ email: 'aissatou@example.test' });
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

  it('deleteContact is a no-op when not configured', async () => {
    delete process.env.MAUTIC_BASE_URL;
    const fetchSpy = jest.fn();
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().deleteContact('a@example.test');

    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('deleteContact looks the contact up by email, then DELETEs it', async () => {
    configure();
    const fetchSpy = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ contacts: { '42': { id: 42 } }, total: 1 }),
      })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) });
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().deleteContact('aissatou@example.test');

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    const [lookupUrl, lookupInit] = fetchSpy.mock.calls[0] as [
      string,
      RequestInit,
    ];
    // Exact email match, URL-encoded; GET, not POST.
    expect(lookupUrl).toBe(
      'https://mautic.example.test/api/contacts?search=email%3Aaissatou%40example.test&limit=1&minimal=true',
    );
    expect(lookupInit.method).toBe('GET');
    const [deleteUrl, deleteInit] = fetchSpy.mock.calls[1] as [
      string,
      RequestInit,
    ];
    expect(deleteUrl).toBe('https://mautic.example.test/api/contacts/42/delete');
    expect(deleteInit.method).toBe('DELETE');
  });

  it('deleteContact is idempotent — no DELETE when no contact matches', async () => {
    configure();
    const fetchSpy = jest.fn().mockResolvedValueOnce({
      ok: true,
      json: async () => ({ contacts: {}, total: 0 }),
    });
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().deleteContact('ghost@example.test');

    // Lookup only; a missing contact is a success, not a DELETE.
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('deleteContact runs on credentials only — no MAUTIC_SEGMENT_ID needed', async () => {
    // Newsletter delivery disabled (segment removed) but historical contacts
    // remain: erasure must still reach them. deleteContact never uses a segment.
    configure();
    delete process.env.MAUTIC_SEGMENT_ID;
    const fetchSpy = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ contacts: { '7': { id: 7 } }, total: 1 }),
      })
      .mockResolvedValueOnce({ ok: true, json: async () => ({}) });
    global.fetch = fetchSpy as unknown as typeof fetch;

    await new MauticService().deleteContact('aissatou@example.test');

    expect(fetchSpy).toHaveBeenCalledTimes(2);
    expect(fetchSpy.mock.calls[1][0]).toBe(
      'https://mautic.example.test/api/contacts/7/delete',
    );
  });
});
