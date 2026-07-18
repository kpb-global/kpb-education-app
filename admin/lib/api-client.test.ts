import { afterEach, describe, expect, it, vi } from 'vitest';

import { apiFetch } from './api-client';

describe('apiFetch', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it('forwards additive request headers and the abort signal', async () => {
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 204,
      text: vi.fn(),
    });
    vi.stubGlobal('fetch', fetchMock);
    const controller = new AbortController();

    await apiFetch('/admin/competition-readiness/pilots', {
      method: 'POST',
      body: { code: 'pilot-ne-2026' },
      headers: { 'Idempotency-Key': 'pilot-create-1' },
      signal: controller.signal,
    });

    expect(fetchMock).toHaveBeenCalledWith(
      'http://127.0.0.1:4000/api/admin/competition-readiness/pilots',
      {
        method: 'POST',
        cache: 'no-store',
        credentials: 'include',
        headers: {
          'Content-Type': 'application/json',
          'Idempotency-Key': 'pilot-create-1',
        },
        signal: controller.signal,
        body: JSON.stringify({ code: 'pilot-ne-2026' }),
      },
    );
  });
});
