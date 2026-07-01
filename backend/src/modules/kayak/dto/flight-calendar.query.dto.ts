import {
  IsEnum,
  IsISO4217CurrencyCode,
  IsOptional,
  IsString,
  Matches,
} from 'class-validator';

import { CalendarAggregation } from '../kayak.types';

/** Query params for `GET /api/flights/calendar`. */
export class FlightCalendarQueryDto {
  @Matches(/^[A-Za-z]{3}$/, { message: 'origin must be a 3-letter IATA code' })
  origin!: string;

  @Matches(/^[A-Za-z]{3}$/, {
    message: 'destination must be a 3-letter IATA code',
  })
  destination!: string;

  @Matches(/^\d{4}-\d{2}$/, {
    message: 'dateFrom must be in YYYY-MM format',
  })
  dateFrom!: string;

  @Matches(/^\d{4}-\d{2}$/, {
    message: 'dateTo must be in YYYY-MM format',
  })
  dateTo!: string;

  @IsOptional()
  @IsEnum(['day', 'month'], {
    message: 'aggregation must be either "day" or "month"',
  })
  aggregation?: CalendarAggregation;

  @IsOptional()
  @Matches(/^\d{4}-\d{2}-\d{2}$/, {
    message: 'returnDate must be in YYYY-MM-DD format',
  })
  returnDate?: string;

  // `roundTrip=true` (string) flags a round-trip calendar.
  @IsOptional()
  @IsString()
  roundTrip?: string;

  @IsOptional()
  @IsISO4217CurrencyCode({ message: 'currency must be an ISO-4217 code' })
  currency?: string;

  @IsOptional()
  @IsString()
  userTrackId?: string;
}
