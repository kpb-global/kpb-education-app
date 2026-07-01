// ─────────────────────────────────────────────────────────────────────────────
// Kayak Price-Insights proxy (flight price estimator).
//
// The Flutter app NEVER calls Kayak directly — it calls our `/api/flights/*`
// endpoints, which hold the affiliate secret, forward the tracking headers, and
// map Kayak's nested RAML shapes down to the flat contract the app consumes
// (see scratchpad/kayak_contract.md).
//
// Kayak's endpoints are POST with a JSON body plus `apiKey`/`userTrackId` query
// params, under baseUri path `/i/api/affiliate/priceInsights/flights/v1`.
//
// Degrades gracefully:
//   • unconfigured (no api key / base url) → `{ configured: false, … }` (200)
//   • upstream 4xx / network error         → stale cache if any, else empty
// It NEVER throws to the controller — the app keeps its browser-deeplink
// fallback and shows an empty / "couldn't load" state.
// ─────────────────────────────────────────────────────────────────────────────

import { randomUUID } from 'crypto';
import { Injectable, Logger } from '@nestjs/common';

import {
  CalendarAggregation,
  CalendarParams,
  FlightCalendarDay,
  FlightCalendarResponse,
  FlightRouteResult,
  FlightRoutesResponse,
  KayakCalendarResponse,
  KayakCalendarResult,
  KayakRouteResult,
  KayakRoutesResponse,
  RoutesParams,
} from './kayak.types';

const CACHE_TTL_MS = 6 * 60 * 60 * 1000; // 6 hours — Price-Insights is cached data.
const KAYAK_PATH = '/i/api/affiliate/priceInsights/flights/v1';
const DEFAULT_CURRENCY = 'EUR';
const DEFAULT_USER_AGENT = 'KPB-Education/1.0 (+https://kpb-education.com)';

interface CacheEntry<T> {
  fetchedAt: number;
  payload: T;
}

@Injectable()
export class KayakService {
  private readonly logger = new Logger(KayakService.name);
  private readonly routesCache = new Map<
    string,
    CacheEntry<Omit<FlightRoutesResponse, 'cached'>>
  >();
  private readonly calendarCache = new Map<
    string,
    CacheEntry<Omit<FlightCalendarResponse, 'cached'>>
  >();

  // Best-effort: the `cluster` cookie Kayak sets tells us which data centre to
  // talk to. We capture it from the first response and resend it thereafter.
  private clusterCookie: string | null = null;

  private readonly apiKey = process.env.KPB_KAYAK_API_KEY ?? '';
  private readonly baseUrl = (process.env.KPB_KAYAK_BASE_URL ?? '').replace(
    /\/+$/,
    '',
  );
  private readonly userAgent =
    process.env.KPB_KAYAK_USER_AGENT?.trim() || DEFAULT_USER_AGENT;

  isConfigured(): boolean {
    return !!(this.apiKey && this.baseUrl);
  }

  // ── Endpoint 1 — cheapest price for a route/date ────────────────────────────
  async getRoutes(
    params: RoutesParams,
    nowMs = Date.now(),
  ): Promise<FlightRoutesResponse> {
    const currency = (params.currency || DEFAULT_CURRENCY).toUpperCase();
    const roundTrip = !!params.returnDate;
    const cacheKey = this.routesKey(params, currency);

    const cached = this.routesCache.get(cacheKey);
    if (cached && nowMs - cached.fetchedAt < CACHE_TTL_MS) {
      return { ...cached.payload, cached: true };
    }

    if (!this.isConfigured()) {
      this.logger.warn(
        'KPB_KAYAK_API_KEY / KPB_KAYAK_BASE_URL not configured — returning unconfigured routes response.',
      );
      return { configured: false, cached: false, currency, results: [] };
    }

    const body = {
      origin: { iataCode: params.origin.toUpperCase() },
      destination: { iataCode: params.destination.toUpperCase() },
      dates: {
        departureDate: params.departDate,
        ...(params.returnDate ? { returnDate: params.returnDate } : {}),
      },
      roundTrip,
      currencyCode: currency,
    };

    try {
      const json = await this.postToKayak<KayakRoutesResponse>(
        '/routes',
        body,
        params.userTrackId,
        params.clientIp,
      );
      const results = this.mapRoutes(json, roundTrip);
      const payload: Omit<FlightRoutesResponse, 'cached'> = {
        configured: true,
        currency,
        results,
      };
      this.routesCache.set(cacheKey, { fetchedAt: nowMs, payload });
      return { ...payload, cached: false };
    } catch (error) {
      this.logger.error(`Kayak /routes failed: ${String(error)}`);
      if (cached) return { ...cached.payload, cached: true };
      return { configured: true, cached: false, currency, results: [] };
    }
  }

  // ── Endpoint 2 — price calendar (per day / per month) ───────────────────────
  async getCalendar(
    params: CalendarParams,
    nowMs = Date.now(),
  ): Promise<FlightCalendarResponse> {
    const currency = (params.currency || DEFAULT_CURRENCY).toUpperCase();
    const aggregation: CalendarAggregation =
      params.aggregation === 'month' ? 'month' : 'day';
    const roundTrip = params.roundTrip ?? !!params.returnDate;
    const cacheKey = this.calendarKey(params, currency, aggregation, roundTrip);

    const cached = this.calendarCache.get(cacheKey);
    if (cached && nowMs - cached.fetchedAt < CACHE_TTL_MS) {
      return { ...cached.payload, cached: true };
    }

    if (!this.isConfigured()) {
      this.logger.warn(
        'KPB_KAYAK_API_KEY / KPB_KAYAK_BASE_URL not configured — returning unconfigured calendar response.',
      );
      return {
        configured: false,
        cached: false,
        currency,
        aggregation,
        days: [],
      };
    }

    const body = {
      origin: { iataCode: params.origin.toUpperCase() },
      destination: { iataCode: params.destination.toUpperCase() },
      dateFrom: params.dateFrom,
      dateTo: params.dateTo,
      aggregationType: aggregation,
      roundTrip,
      currencyCode: currency,
    };

    try {
      const json = await this.postToKayak<KayakCalendarResponse>(
        '/calendar',
        body,
        params.userTrackId,
        params.clientIp,
      );
      const days = this.mapCalendar(json, roundTrip);
      const payload: Omit<FlightCalendarResponse, 'cached'> = {
        configured: true,
        currency,
        aggregation,
        days,
      };
      this.calendarCache.set(cacheKey, { fetchedAt: nowMs, payload });
      return { ...payload, cached: false };
    } catch (error) {
      this.logger.error(`Kayak /calendar failed: ${String(error)}`);
      if (cached) return { ...cached.payload, cached: true };
      return {
        configured: true,
        cached: false,
        currency,
        aggregation,
        days: [],
      };
    }
  }

  // ── HTTP ────────────────────────────────────────────────────────────────────
  private async postToKayak<T>(
    resourcePath: string,
    body: unknown,
    userTrackId: string | undefined,
    clientIp: string | undefined,
  ): Promise<T> {
    const url = new URL(`${this.baseUrl}${KAYAK_PATH}${resourcePath}`);
    url.searchParams.set('apiKey', this.apiKey);
    // `userTrackId` is required by Kayak; generate a stable-ish fallback.
    url.searchParams.set('userTrackId', userTrackId?.trim() || randomUUID());

    const headers: Record<string, string> = {
      'Content-Type': 'application/json',
      Accept: 'application/json',
      'user-agent': this.userAgent,
    };
    if (clientIp) headers['x-original-client-ip'] = clientIp;
    if (this.clusterCookie) headers['cookie'] = `cluster=${this.clusterCookie}`;

    const response = await fetch(url.toString(), {
      method: 'POST',
      headers,
      body: JSON.stringify(body),
    });

    // Best-effort: capture the `cluster` cookie for subsequent calls.
    this.captureClusterCookie(response);

    if (!response.ok) {
      const text = await response.text().catch(() => '');
      throw new Error(`Kayak HTTP ${response.status}: ${text.slice(0, 200)}`);
    }
    return (await response.json()) as T;
  }

  private captureClusterCookie(response: Response): void {
    try {
      const setCookie = response.headers.get('set-cookie');
      if (!setCookie) return;
      const match = /(?:^|[,;\s])cluster=([^;,\s]+)/i.exec(setCookie);
      if (match?.[1]) this.clusterCookie = match[1];
    } catch {
      // Non-fatal — the cluster cookie is an optimisation, not a requirement.
    }
  }

  // ── Mapping: Kayak → flat contract ──────────────────────────────────────────
  private mapRoutes(
    json: KayakRoutesResponse,
    roundTrip: boolean,
  ): FlightRouteResult[] {
    const airlineNameByCode = new Map<string, string>();
    for (const a of json.airlines ?? []) {
      if (a.iataCode && a.name) airlineNameByCode.set(a.iataCode, a.name);
    }

    const results: FlightRouteResult[] = [];
    for (const r of json.results ?? []) {
      const leg = r.outboundLeg;
      if (!r.deeplinkUrl) continue; // deeplink is required for a usable result.
      const airlineCodes = leg?.airlineCodes ?? [];
      results.push({
        origin: leg?.origin ?? '',
        destination: leg?.destination ?? '',
        airlineCodes,
        airlineNames: airlineCodes.map(
          (code) => airlineNameByCode.get(code) ?? code,
        ),
        departureDateTime: leg?.departureDateTime ?? null,
        arrivalDateTime: leg?.arrivalDateTime ?? null,
        stops: leg?.stops ?? null,
        roundTrip,
        price: r.price?.price ?? null,
        deeplinkUrl: r.deeplinkUrl, // VERBATIM — affiliate tracking.
        cabin: r.cabin ?? null,
      });
    }

    // Ascending by price; the app shows the cheapest first. Nulls last.
    results.sort((a, b) => this.byPriceAsc(a.price, b.price));
    return results;
  }

  private mapCalendar(
    json: KayakCalendarResponse,
    roundTrip: boolean,
  ): FlightCalendarDay[] {
    const days: FlightCalendarDay[] = [];
    for (const r of json.results ?? []) {
      if (!r.aggregationKey) continue;
      const { price, deeplinkUrl } = this.cheapestLeg(r, roundTrip);
      days.push({
        date: r.aggregationKey,
        price,
        predicted: r.predicted ?? false,
        deeplinkUrl, // VERBATIM — may be null for predicted entries.
      });
    }

    // Ascending by date.
    days.sort((a, b) => a.date.localeCompare(b.date));
    return days;
  }

  /**
   * Kayak carries the price on the inbound leg for round trips and on the
   * outbound leg for one-way. Inbound is an array (one per candidate return
   * date/month): take the cheapest available, and use the deeplink from the
   * leg that carries the winning price.
   */
  private cheapestLeg(
    result: KayakCalendarResult,
    roundTrip: boolean,
  ): { price: number | null; deeplinkUrl: string | null } {
    const legs = roundTrip
      ? result.inboundLegs ?? []
      : result.outboundLeg
        ? [result.outboundLeg]
        : [];

    let best: { price: number | null; deeplinkUrl: string | null } = {
      price: null,
      deeplinkUrl: null,
    };
    for (const leg of legs) {
      const price = leg.price?.price ?? null;
      const deeplinkUrl = leg.deeplinkUrl ?? null;
      if (best.price === null || (price !== null && price < best.price)) {
        best = { price, deeplinkUrl };
      }
    }

    // Predicted (or one-way with no leg price) entries may lack a deeplink — the
    // outbound leg can still carry one, so fall back to it when we found none.
    if (best.deeplinkUrl === null && result.outboundLeg?.deeplinkUrl) {
      best = { ...best, deeplinkUrl: result.outboundLeg.deeplinkUrl };
    }
    return best;
  }

  private byPriceAsc(a: number | null, b: number | null): number {
    if (a === null && b === null) return 0;
    if (a === null) return 1;
    if (b === null) return -1;
    return a - b;
  }

  // ── Cache keys (normalized query) ────────────────────────────────────────────
  private routesKey(p: RoutesParams, currency: string): string {
    return [
      p.origin.toUpperCase(),
      p.destination.toUpperCase(),
      p.departDate,
      p.returnDate ?? '',
      currency,
    ].join('|');
  }

  private calendarKey(
    p: CalendarParams,
    currency: string,
    aggregation: CalendarAggregation,
    roundTrip: boolean,
  ): string {
    return [
      p.origin.toUpperCase(),
      p.destination.toUpperCase(),
      p.dateFrom,
      p.dateTo,
      aggregation,
      roundTrip ? 'rt' : 'ow',
      currency,
    ].join('|');
  }
}
