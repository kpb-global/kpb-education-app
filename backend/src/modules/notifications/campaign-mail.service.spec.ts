import { CampaignMailService } from './campaign-mail.service';

describe('CampaignMailService', () => {
  const previousKey = process.env.RESEND_API_KEY;
  const previousFetch = global.fetch;

  afterEach(() => {
    if (previousKey === undefined) {
      delete process.env.RESEND_API_KEY;
    } else {
      process.env.RESEND_API_KEY = previousKey;
    }
    global.fetch = previousFetch;
  });

  it('is disabled and returns false without RESEND_API_KEY', async () => {
    delete process.env.RESEND_API_KEY;
    const fetchSpy = jest.fn();
    global.fetch = fetchSpy as unknown as typeof fetch;

    const service = new CampaignMailService();
    expect(service.isEnabled).toBe(false);
    await expect(service.send('a@b.com', 'Sujet', 'Corps')).resolves.toBe(false);
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('posts to Resend and returns true on success', async () => {
    process.env.RESEND_API_KEY = 'test-key';
    const fetchSpy = jest.fn().mockResolvedValue({ ok: true });
    global.fetch = fetchSpy as unknown as typeof fetch;

    const service = new CampaignMailService();
    expect(service.isEnabled).toBe(true);
    await expect(service.send('a@b.com', 'Sujet', 'Corps')).resolves.toBe(true);

    expect(fetchSpy).toHaveBeenCalledWith(
      'https://api.resend.com/emails',
      expect.objectContaining({
        method: 'POST',
        headers: expect.objectContaining({
          Authorization: 'Bearer test-key',
        }),
      }),
    );
    const body = JSON.parse(
      (fetchSpy.mock.calls[0][1] as { body: string }).body,
    ) as Record<string, unknown>;
    expect(body.to).toEqual(['a@b.com']);
    expect(body.subject).toBe('Sujet');
    expect(body.text).toBe('Corps');
  });

  it('returns false on a non-ok Resend response', async () => {
    process.env.RESEND_API_KEY = 'test-key';
    global.fetch = jest.fn().mockResolvedValue({
      ok: false,
      status: 422,
      text: async () => 'invalid recipient',
    }) as unknown as typeof fetch;

    const service = new CampaignMailService();
    await expect(service.send('a@b.com', 'Sujet', 'Corps')).resolves.toBe(false);
  });

  it('returns false when the request itself throws', async () => {
    process.env.RESEND_API_KEY = 'test-key';
    global.fetch = jest
      .fn()
      .mockRejectedValue(new Error('network down')) as unknown as typeof fetch;

    const service = new CampaignMailService();
    await expect(service.send('a@b.com', 'Sujet', 'Corps')).resolves.toBe(false);
  });
});
