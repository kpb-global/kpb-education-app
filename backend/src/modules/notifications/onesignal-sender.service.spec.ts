import { Logger } from '@nestjs/common';

import { OneSignalSenderService } from './onesignal-sender.service';

/**
 * Le seul code qui parle à OneSignal, et il n'avait aucun test — alors qu'il
 * décide, pour chaque destinataire, si la livraison est inscrite « delivered »
 * ou « failed ». Les six autres services du même dossier en avaient un.
 */
describe('OneSignalSenderService', () => {
  const previous = {
    id: process.env.ONESIGNAL_APP_ID,
    key: process.env.ONESIGNAL_REST_API_KEY,
  };
  let errors: string[] = [];
  let warns: string[] = [];

  beforeEach(() => {
    process.env.ONESIGNAL_APP_ID = 'app-id';
    process.env.ONESIGNAL_REST_API_KEY = 'rest-key';
    errors = [];
    warns = [];
    jest
      .spyOn(Logger.prototype, 'error')
      .mockImplementation((m: unknown) => void errors.push(String(m)));
    jest
      .spyOn(Logger.prototype, 'warn')
      .mockImplementation((m: unknown) => void warns.push(String(m)));
  });

  afterEach(() => {
    for (const [k, v] of [
      ['ONESIGNAL_APP_ID', previous.id],
      ['ONESIGNAL_REST_API_KEY', previous.key],
    ] as const) {
      if (v === undefined) delete process.env[k];
      else process.env[k] = v;
    }
    jest.restoreAllMocks();
  });

  function mockFetch(impl: () => Promise<unknown>) {
    global.fetch = jest.fn(impl) as unknown as typeof fetch;
  }

  const jsonResponse = (body: unknown, ok = true, status = 200) =>
    ({
      ok,
      status,
      json: async () => body,
      text: async () => JSON.stringify(body),
    }) as unknown as Response;

  it('rend true et n’alerte pas quand OneSignal livre', async () => {
    mockFetch(async () => jsonResponse({ id: 'n1', recipients: 3 }));
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(true);
    expect(errors).toEqual([]);
  });

  // Le défaut central : la charge `errors` était désérialisée puis JETÉE. Le
  // 04/09/2026 la production n'a su dire que « provider errors », ce qui rendait
  // la cause indiagnosticable depuis les journaux.
  it('journalise la charge d’erreur d’OneSignal, pas une phrase fixe', async () => {
    mockFetch(async () =>
      jsonResponse({ errors: ['App has no delivery platform configured'] }),
    );
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(errors.join(' ')).toContain('no delivery platform configured');
  });

  it('journalise le corps quand OneSignal répond en erreur HTTP', async () => {
    mockFetch(async () =>
      jsonResponse({ errors: ['Invalid app_id format'] }, false, 400),
    );
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    const joined = errors.join(' ');
    expect(joined).toContain('400');
    expect(joined).toContain('Invalid app_id format');
  });

  // « Zéro destinataire » était compté comme un SUCCÈS : l'appelant inscrivait
  // alors la livraison comme `delivered`, et les statistiques décrivaient une
  // distribution qui n'avait pas eu lieu.
  it('ne compte pas « 0 destinataire » comme une livraison', async () => {
    mockFetch(async () => jsonResponse({ id: 'n1', recipients: 0 }));
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(warns.join(' ')).toContain('0 device');
  });

  it('nomme le motif quand la requête elle-même échoue', async () => {
    mockFetch(async () => {
      const e = new Error('The operation was aborted');
      e.name = 'AbortError';
      throw e;
    });
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(errors.join(' ')).toContain('AbortError');
  });

  it('ne tente rien sans identifiants, et le dit', async () => {
    delete process.env.ONESIGNAL_APP_ID;
    mockFetch(async () => jsonResponse({ recipients: 1 }));
    await expect(
      new OneSignalSenderService().sendToUser('u1', 't', 'b'),
    ).resolves.toBe(false);
    expect(global.fetch).not.toHaveBeenCalled();
    expect(warns.join(' ')).toContain('not configured');
  });

  // La clé REST ne doit jamais atterrir dans un journal : elle ne circule que
  // dans l'en-tête `authorization`.
  it('ne journalise jamais la clé REST', async () => {
    process.env.ONESIGNAL_REST_API_KEY = 'os_v2_supersecret';
    mockFetch(async () => jsonResponse({ errors: ['boom'] }, false, 500));
    await new OneSignalSenderService().sendToUser('u1', 't', 'b');
    expect([...errors, ...warns].join(' ')).not.toContain('os_v2_supersecret');
  });
});
