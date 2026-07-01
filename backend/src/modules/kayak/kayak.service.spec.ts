import { Test, TestingModule } from '@nestjs/testing';

import { KayakService } from './kayak.service';
import { KayakRoutesResponse } from './kayak.types';

// The service reads KPB_KAYAK_* in field initialisers, so env must be set (or
// cleared) BEFORE the module is compiled. Each `buildService` helper does that.
const ROUTES_PARAMS = {
  origin: 'ABJ',
  destination: 'CDG',
  departDate: '2025-12-01',
  currency: 'EUR',
  userTrackId: 'device-123',
  clientIp: '41.0.0.1',
};

// A Kayak /routes response with two results out of price order, so we can
// assert ascending-by-price sorting and airline-name resolution.
const KAYAK_ROUTES_JSON: KayakRoutesResponse = {
  results: [
    {
      outboundLeg: {
        origin: 'ABJ',
        destination: 'CDG',
        airlineCodes: ['AF'],
        departureDateTime: '2025-12-01T12:00:00',
        arrivalDateTime: '2025-12-01T18:30:00',
        stops: 0,
      },
      deeplinkUrl: 'https://www.kayak.com/in?a=kan_AF&url=/flights/ABJ-CDG',
      price: { price: 512, currency: 'EUR' },
      cabin: 'economy',
    },
    {
      outboundLeg: {
        origin: 'ABJ',
        destination: 'CDG',
        airlineCodes: ['TK', 'XX'],
        departureDateTime: '2025-12-01T06:00:00',
        arrivalDateTime: '2025-12-01T14:00:00',
        stops: 1,
      },
      deeplinkUrl: 'https://www.kayak.com/in?a=kan_TK&url=/flights/ABJ-CDG',
      price: { price: 420, currency: 'EUR' },
      cabin: 'economy',
    },
  ],
  airlines: [
    { iataCode: 'AF', name: 'Air France' },
    { iataCode: 'TK', name: 'Turkish Airlines' },
  ],
};

async function buildService(
  env: Partial<Record<'KPB_KAYAK_API_KEY' | 'KPB_KAYAK_BASE_URL', string>>,
): Promise<KayakService> {
  delete process.env.KPB_KAYAK_API_KEY;
  delete process.env.KPB_KAYAK_BASE_URL;
  if (env.KPB_KAYAK_API_KEY) process.env.KPB_KAYAK_API_KEY = env.KPB_KAYAK_API_KEY;
  if (env.KPB_KAYAK_BASE_URL) process.env.KPB_KAYAK_BASE_URL = env.KPB_KAYAK_BASE_URL;

  const module: TestingModule = await Test.createTestingModule({
    providers: [KayakService],
  }).compile();
  return module.get<KayakService>(KayakService);
}

function mockFetchOnce(json: unknown, ok = true, status = 200): jest.Mock {
  const fn = jest.fn().mockResolvedValue({
    ok,
    status,
    headers: { get: () => null },
    json: async () => json,
    text: async () => JSON.stringify(json),
  });
  global.fetch = fn as unknown as typeof fetch;
  return fn;
}

describe('KayakService', () => {
  const originalFetch = global.fetch;

  afterEach(() => {
    global.fetch = originalFetch;
    jest.clearAllMocks();
  });

  it('returns configured:false with an empty result set when unconfigured', async () => {
    const service = await buildService({});
    const fetchSpy = mockFetchOnce({});

    const res = await service.getRoutes(ROUTES_PARAMS);

    expect(service.isConfigured()).toBe(false);
    expect(res).toEqual({
      configured: false,
      cached: false,
      currency: 'EUR',
      results: [],
    });
    // Must NOT reach out to Kayak when unconfigured.
    expect(fetchSpy).not.toHaveBeenCalled();
  });

  it('maps a Kayak /routes response to the flat contract, sorted ascending by price', async () => {
    const service = await buildService({
      KPB_KAYAK_API_KEY: 'test-key',
      KPB_KAYAK_BASE_URL: 'https://api.kayak.com',
    });
    const fetchSpy = mockFetchOnce(KAYAK_ROUTES_JSON);

    const res = await service.getRoutes(ROUTES_PARAMS);

    expect(res.configured).toBe(true);
    expect(res.cached).toBe(false);
    expect(res.currency).toBe('EUR');
    expect(res.results).toHaveLength(2);

    // Ascending by price: the 420 result comes first.
    expect(res.results[0].price).toBe(420);
    expect(res.results[1].price).toBe(512);

    // Airline names resolved from `airlines[]`; unknown code falls back to code.
    expect(res.results[0].airlineCodes).toEqual(['TK', 'XX']);
    expect(res.results[0].airlineNames).toEqual(['Turkish Airlines', 'XX']);
    expect(res.results[1].airlineNames).toEqual(['Air France']);

    // Deeplink passed through VERBATIM (affiliate tracking).
    expect(res.results[1].deeplinkUrl).toBe(
      'https://www.kayak.com/in?a=kan_AF&url=/flights/ABJ-CDG',
    );

    // Called Kayak once with the api key + userTrackId query params.
    expect(fetchSpy).toHaveBeenCalledTimes(1);
    const calledUrl = (fetchSpy.mock.calls[0][0] as string);
    expect(calledUrl).toContain(
      '/i/api/affiliate/priceInsights/flights/v1/routes',
    );
    expect(calledUrl).toContain('apiKey=test-key');
    expect(calledUrl).toContain('userTrackId=device-123');

    // Forwarded affiliate-tracking headers.
    const init = fetchSpy.mock.calls[0][1] as RequestInit;
    const headers = init.headers as Record<string, string>;
    expect(headers['x-original-client-ip']).toBe('41.0.0.1');
    expect(headers['user-agent']).toBeDefined();
  });

  it('serves the cached payload with cached:true on a repeat call', async () => {
    const service = await buildService({
      KPB_KAYAK_API_KEY: 'test-key',
      KPB_KAYAK_BASE_URL: 'https://api.kayak.com',
    });
    const fetchSpy = mockFetchOnce(KAYAK_ROUTES_JSON);

    const first = await service.getRoutes(ROUTES_PARAMS, 1_000);
    expect(first.cached).toBe(false);

    // Within the 6h TTL → served from cache, no second network call.
    const second = await service.getRoutes(ROUTES_PARAMS, 2_000);
    expect(second.cached).toBe(true);
    expect(second.results).toEqual(first.results);
    expect(fetchSpy).toHaveBeenCalledTimes(1);
  });

  it('serves stale cache when a later fetch fails', async () => {
    const service = await buildService({
      KPB_KAYAK_API_KEY: 'test-key',
      KPB_KAYAK_BASE_URL: 'https://api.kayak.com',
    });
    mockFetchOnce(KAYAK_ROUTES_JSON);

    // Warm the cache.
    const first = await service.getRoutes(ROUTES_PARAMS, 1_000);
    expect(first.cached).toBe(false);
    expect(first.results).toHaveLength(2);

    // Advance past the TTL and make the upstream fail.
    global.fetch = jest
      .fn()
      .mockResolvedValue({
        ok: false,
        status: 400,
        headers: { get: () => null },
        json: async () => ({}),
        text: async () => 'VALIDATION_ERROR',
      }) as unknown as typeof fetch;

    const afterTtl = 1_000 + 7 * 60 * 60 * 1000; // 7h later
    const res = await service.getRoutes(ROUTES_PARAMS, afterTtl);

    // Stale cache served (never throws to the controller).
    expect(res.cached).toBe(true);
    expect(res.results).toHaveLength(2);
    expect(res.results[0].price).toBe(420);
  });
});
