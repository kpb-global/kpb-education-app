// ─────────────────────────────────────────────────────────────────────────────
// Types for the Kayak Price-Insights proxy.
//
// Two layers live here:
//   1. The FLAT app-facing contract shapes (`FlightRouteResult`, …) the Flutter
//      app consumes — see scratchpad/kayak_contract.md.
//   2. The minimal subset of Kayak's RAML response shapes we map FROM
//      (`KayakRoutesResponse`, …). We only declare the fields we read.
// ─────────────────────────────────────────────────────────────────────────────

// ── App-facing (flat) contract ───────────────────────────────────────────────

export type FlightCabin =
  | 'economy'
  | 'business'
  | 'first'
  | 'premium'
  | 'mixed'
  | 'student';

export type CalendarAggregation = 'day' | 'month';

/** One cheapest-route result, flattened from a Kayak `RouteResultResponse`. */
export interface FlightRouteResult {
  origin: string;
  destination: string;
  airlineCodes: string[];
  airlineNames: string[];
  departureDateTime: string | null;
  arrivalDateTime: string | null;
  stops: number | null;
  roundTrip: boolean;
  price: number | null;
  deeplinkUrl: string;
  cabin: FlightCabin | null;
}

/** `GET /api/flights/routes` response envelope. */
export interface FlightRoutesResponse {
  configured: boolean;
  cached: boolean;
  currency: string;
  results: FlightRouteResult[];
}

/** One calendar day/month entry, flattened from a Kayak `CalendarResultResponse`. */
export interface FlightCalendarDay {
  date: string;
  price: number | null;
  predicted: boolean;
  deeplinkUrl: string | null;
}

/** `GET /api/flights/calendar` response envelope. */
export interface FlightCalendarResponse {
  configured: boolean;
  cached: boolean;
  currency: string;
  aggregation: CalendarAggregation;
  days: FlightCalendarDay[];
}

// ── Service-layer input params ────────────────────────────────────────────────

export interface RoutesParams {
  origin: string;
  destination: string;
  departDate: string;
  returnDate?: string;
  currency?: string;
  userTrackId?: string;
  /** Real client IP, forwarded to Kayak as `x-original-client-ip`. */
  clientIp?: string;
}

export interface CalendarParams {
  origin: string;
  destination: string;
  dateFrom: string;
  dateTo: string;
  aggregation?: CalendarAggregation;
  returnDate?: string;
  roundTrip?: boolean;
  currency?: string;
  userTrackId?: string;
  clientIp?: string;
}

// ── Kayak upstream response shapes (subset we read) ──────────────────────────

export interface KayakPrice {
  price?: number;
  currency?: string;
}

export interface KayakFlightLeg {
  origin?: string;
  destination?: string;
  airlineCodes?: string[];
  departureDateTime?: string;
  arrivalDateTime?: string;
  stops?: number;
}

export interface KayakRouteResult {
  aggregationKey?: string;
  outboundLeg?: KayakFlightLeg;
  inboundLeg?: KayakFlightLeg;
  deeplinkUrl?: string;
  price?: KayakPrice;
  cabin?: FlightCabin;
}

export interface KayakAirline {
  iataCode?: string;
  name?: string;
  logoUrl?: string;
}

export interface KayakRoutesResponse {
  results?: KayakRouteResult[];
  airlines?: KayakAirline[];
}

export interface KayakCalendarFlightLeg {
  origin?: string;
  destination?: string;
  departureDate?: string;
  price?: KayakPrice;
  noStops?: boolean;
  deeplinkUrl?: string;
}

export interface KayakCalendarResult {
  aggregationKey?: string;
  outboundLeg?: KayakCalendarFlightLeg;
  inboundLegs?: KayakCalendarFlightLeg[];
  predicted?: boolean;
  cabin?: FlightCabin;
}

export interface KayakCalendarResponse {
  results?: KayakCalendarResult[];
}
